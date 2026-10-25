#!/usr/bin/env python3
"""Exercise scoped envs and the evaluated initializer with disposable application files.

Needs Node 22, Bun, PostgreSQL 17, and directories api/worker/web/migrate.
api/worker/web contain deployed /app files; migrate contains reviewed packages/db
and packages/domain plus their dependencies. Never point this at an app checkout.
On macOS the app processes are sandboxed to loopback network access.
"""

import json
import os
from pathlib import Path
import re
import runpy
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request


def port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def run(args, env, **kwargs):
    result = subprocess.run(args, env=env, capture_output=True, text=True, **kwargs)
    assert result.returncode == 0, f"fixture command failed: {Path(args[0]).name} (output suppressed)"
    return result


def podman_fixture(state_path, args):
    state = json.loads(Path(state_path).read_text())
    if args[:2] == ["image", "inspect"]:
        print("sha256:" + "a" * 64)
        return
    if args[0] == "exec":
        # Preserve the production psql invocation and stdin, but replace the
        # container's local socket/environment with our disposable PostgreSQL.
        command = args[args.index("unprompted-postgres") + 1:]
        env = state["postgres"] | state["local"]
        result = subprocess.run(command, env=env)
    else:
        assert args[0] == "run" and "--pull=never" in args
        assert f"--env-file={state['migrateFile']}" in args, "initializer granted wrong environment"
        assert args[-1] == "sha256:" + "a" * 64, "initializer lost immutable image identity"
        result = subprocess.run(
            state["sandbox"] + [state["bun"], "run", "packages/db/src/migrate.ts"],
            cwd=state["migrateRoot"], env=state["migrate"],
        )
    sys.exit(result.returncode)


def main(config, root):
    assert not (root / ".env").exists(), "fixture must not contain an application .env"
    boundary = runpy.run_path(str(Path(__file__).with_name("env-boundary.py")))
    envs, markers = boundary["environments"](config)
    boundary["check"](config)
    sandbox = []
    if sys.platform == "darwin":
        sandbox = ["/usr/bin/sandbox-exec", "-p", '(version 1) (allow default) (deny network*) (allow network-outbound (remote ip "localhost:*")) (allow network-inbound (local ip "localhost:*"))']
    binaries = {name: shutil.which(name) for name in ["node", "bun", "initdb", "pg_ctl", "createdb", "psql"]}
    assert all(binaries.values()), "run inside the test Devenv tool shell"
    assert all((root / name).is_dir() for name in ["api", "worker", "web", "migrate"])
    with tempfile.TemporaryDirectory(prefix="unprompted-runtime-", dir="/tmp") as directory:
        work = Path(directory)
        # Keep the Unix socket path below PostgreSQL's platform length limit.
        db_port, api_port, web_port = port(), port(), port()
        base = {"PATH": os.environ["PATH"], "HOME": str(work), "LC_ALL": "C"}
        local = base | {"PGHOST": str(work), "PGPORT": str(db_port), "PGUSER": "unprompted"}
        initial_password = work / "initial-password"
        initial_password.write_text("dummy-old-database-password\n")
        initial_password.chmod(0o600)
        data = work / "pg"
        run([binaries["initdb"], "-D", str(data), "-U", "unprompted", "--auth-local=trust", "--auth-host=scram-sha-256", "--pwfile=" + str(initial_password), "--locale=C", "--encoding=UTF8"], base)
        run([binaries["pg_ctl"], "-D", str(data), "-l", str(work / "postgres.log"), "-o", f"-h 127.0.0.1 -k {work} -p {db_port}", "-w", "start"], base)
        processes = []
        logs = []
        try:
            run([binaries["createdb"], "unprompted"], local)
            for env in envs.values():
                env.update(base)
                # Every configured service/provider endpoint is a fixture endpoint.
                for key in ["API_ORIGIN", "API_URL", "NEXT_PUBLIC_API_URL", "BETTER_AUTH_URL", "WEB_ORIGIN", "AI_BASE_URL"]:
                    if key in env:
                        env[key] = f"http://127.0.0.1:{api_port}"
                if "SMTP_HOST" in env:
                    env["SMTP_HOST"] = "127.0.0.1"
                if "POSTGRES_HOST" in env:
                    env.update(POSTGRES_HOST="127.0.0.1", POSTGRES_PORT=str(db_port))
            state = {
                "postgres": envs["postgres"], "local": local,
                "migrate": envs["migrate"], "migrateFile": config["deployInitialize"],
                "migrateRoot": str(root / "migrate"), "bun": binaries["bun"], "sandbox": sandbox,
            }
            state_path = work / "podman.json"
            state_path.write_text(json.dumps(state))
            wrapper = work / "podman-fixture"
            wrapper.write_text(f"#!{sys.executable}\nimport runpy,sys\nns=runpy.run_path({str(Path(__file__).resolve())!r})\nns['podman_fixture']({str(state_path)!r}, sys.argv[1:])\n")
            wrapper.chmod(0o700)
            initializer = work / "initialize"
            initializer.write_text(re.sub(r"/nix/store/[^/]+/bin/podman", str(wrapper), config["initializeScript"]))
            # Run the actual evaluated initializer twice, including psql \getenv,
            # ALTER ROLE quoting, immutable image selection and migration env-file.
            for _ in range(2):
                run(["/bin/bash", str(initializer)], base, timeout=60)
            tcp = local | {"PGHOST": "127.0.0.1", "PGPASSWORD": envs["migrate"]["POSTGRES_PASSWORD"]}
            run([binaries["psql"], "-d", "unprompted", "-Atc", "SELECT 1"], tcp)
            rejected = subprocess.run([binaries["psql"], "-d", "unprompted", "-Atc", "SELECT 1"], env=tcp | {"PGPASSWORD": "dummy-wrong-password"}, capture_output=True)
            assert rejected.returncode != 0, "fixture database did not enforce password authentication"
            print("PASS: boot/deploy initializer password synchronization and repeatable DB-only migration")

            envs["api"]["PORT"] = str(api_port)
            envs["web"].update(PORT=str(web_port), HOSTNAME="127.0.0.1")
            commands = {"api": "apps/api/dist/server.js", "worker": "apps/worker/dist/index.js", "web": "apps/web/server.js"}
            for name, entry in commands.items():
                log = (work / f"{name}.log").open("w+")
                logs.append(log)
                processes.append(subprocess.Popen(sandbox + [binaries["node"], entry], cwd=root / name, env=envs[name], stdout=log, stderr=log))
            def assert_running():
                for name, process, log in zip(commands, processes, logs):
                    if process.poll() is not None:
                        log.seek(0)
                        # Only error classifications, never a raw application log.
                        codes = re.findall(r"ERR_[A-Z_]+|MODULE_NOT_FOUND|Operation not permitted|Could not load", log.read())
                        raise AssertionError(f"{name} exited ({process.returncode}), error classes: {codes}")

            for path in [f"http://127.0.0.1:{api_port}/ready", f"http://127.0.0.1:{web_port}/"]:
                for _ in range(100):
                    assert_running()
                    try:
                        with urllib.request.urlopen(path, timeout=1) as response:
                            assert response.status == 200
                            body = response.read().decode()
                            assert not any(marker in body for marker in markers.values())
                        break
                    except (OSError, TimeoutError):
                        time.sleep(0.1)
                else:
                    raise AssertionError("fixture health endpoint did not become ready")
            time.sleep(2)
            assert all(p.poll() is None for p in processes), "application did not remain running"
            logs[1].seek(0)
            worker_output = logs[1].read()
            # Evaluation, daily email, three privacy jobs and two derived jobs
            # must remain registered with push notifications disabled.
            assert "worker started with 7 handlers and an active email scheduler" in worker_output
            print("PASS: deployed API /ready, worker startup/scheduler, standalone web HTTP 200 with scoped dummy envs")
        finally:
            for process in reversed(processes):
                process.terminate()
            for process in processes:
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            for log in logs:
                log.close()
            run([binaries["pg_ctl"], "-D", str(data), "-m", "immediate", "-w", "stop"], base)


if __name__ == "__main__":
    main(json.loads(Path(sys.argv[1]).read_text()), Path(sys.argv[2]).resolve())
