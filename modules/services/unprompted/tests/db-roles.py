#!/usr/bin/env python3
"""Exercise evaluated boot/deploy initialization against isolated cached Linux images.

Usage: db-roles.py AFTER.json BEFORE.json [--baseline]
No host ports, production mounts/data/secrets, image pulls or external networking.
Each database uses bounded tmpfs and at most one additional app container.
"""
import json
from pathlib import Path
import re
import runpy
import subprocess
import sys
import tempfile
import time
import uuid


def podman(*args, input=None, check=True):
    result = subprocess.run(["podman", *args], input=input, text=True,
                            capture_output=True, timeout=120)
    if check and result.returncode:
        raise AssertionError(f"fixture podman {args[0]} failed (output suppressed)")
    return result


def shim(state_path, args):
    state = json.loads(Path(state_path).read_text())
    if args[:2] == ["image", "inspect"]:
        print(state["images"]["migrate"])
        return
    if args[0] == "exec":
        i = args.index("unprompted-postgres")
        env = [item for k, v in state["postgres"].items() for item in ["--env", f"{k}={v}"]]
        args = args[:i] + env + [state["db"]] + args[i + 1:]
    else:
        assert args[0] == "run" and "--pull=never" in args
        assert f"--env-file={state['migrateFile']}" in args
        assert args[-1] == state["images"]["migrate"]
        args = [a for a in args if not a.startswith(("--network=", "--env-file="))]
        env = [item for k, v in state["migrate"].items() for item in ["--env", f"{k}={v}"]]
        args = args[:-1] + ["--name", state["migrationName"],
                "--label", state["label"], "--network=container:" + state["db"],
                "--memory=384m", "--cpus=0.5", "--pids-limit=128", *env, args[-1]]
    result = podman(*args, input=sys.stdin.read() if args[0] == "exec" and "-i" in args else None, check=False)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    sys.exit(result.returncode)


def main(config, old, baseline=False):
    assert sys.platform.startswith("linux"), "Linux Podman fixture required"
    boundary = runpy.run_path(str(Path(__file__).with_name("env-boundary.py")))
    envs, _ = boundary["environments"](config)
    old_envs, _ = boundary["environments"](old)
    containers = config["containers"]
    images = {key: podman("image", "inspect", value["image"], "--format", "{{.Id}}").stdout.strip()
              for key, value in containers.items() if key in ["unprompted-postgres", "unprompted-api", "unprompted-worker"]}
    images["migrate"] = podman("image", "inspect", "ghcr.io/rodrgds/unprompted-migrate:latest", "--format", "{{.Id}}").stdout.strip()
    assert all(re.fullmatch(r"(?:sha256:)?[a-f0-9]{64}", value) for value in images.values())
    print("Cached fixture image IDs: " + json.dumps(images), flush=True)
    for scenario in (["existing"] if baseline else ["existing", "fresh"]):
        prefix = "rgo-up-db-roles-" + uuid.uuid4().hex[:12]
        label = "rgo.audit.unprompted-db-roles=" + prefix
        created = []
        def start(name, image, options, env, command=()):
            full = prefix + "-" + name
            env_args = [item for k, v in env.items() for item in ["--env", f"{k}={v}"]]
            result = podman("run", "-d", "--name", full, "--label", label,
                            "--pull=never", "--cpus=0.5", "--pids-limit=128",
                            *options, *env_args, image, *command)
            cid = result.stdout.strip()
            assert re.fullmatch(r"[a-f0-9]{64}", cid)
            created.append(cid)
            return cid
        def stop(cid):
            podman("rm", "--force", cid)
            created.remove(cid)
        def sql(statement, user="unprompted", check=True, tcp_password=None, database="unprompted"):
            options = ["--env", "PGPASSWORD=" + tcp_password] if tcp_password is not None else []
            host = ["-h", "127.0.0.1"] if tcp_password is not None else []
            return podman("exec", "-i", *options, db, "psql", "-X", *host, "-U", user,
                          "-d", database, "-At", "-v", "ON_ERROR_STOP=1", input=statement, check=check)
        def wait(args):
            for _ in range(160):
                if podman(*args, check=False).returncode == 0:
                    return
                time.sleep(.25)
            raise AssertionError("fixture readiness timed out")
        try:
            initial = old_envs["postgres"] if scenario == "existing" else envs["postgres"]
            db = start("db", images["unprompted-postgres"], ["--network=none", "--memory=192m",
                       "--tmpfs=/var/lib/postgresql/data:rw,size=128m"], initial | {"POSTGRES_INITDB_ARGS": "--auth-host=scram-sha-256 --auth-local=trust"})
            wait(["exec", "--env", "PGPASSWORD=" + initial["POSTGRES_PASSWORD"], db, "psql", "-h", "127.0.0.1", "-U", initial["POSTGRES_USER"], "-d", "unprompted", "-Atc", "SELECT 1"])
            # Immutable fixture-local sentinel, never a host mount or real credential.
            podman("exec", db, "sh", "-c", "printf fixture-sentinel > /tmp/db-role-sentinel")
            system_before = sql("SELECT oid,datdba FROM pg_database WHERE datname <> 'unprompted' ORDER BY oid;", user=initial["POSTGRES_USER"]).stdout
            with tempfile.TemporaryDirectory(prefix=prefix) as directory:
                work = Path(directory)
                state = {"db": db, "images": images, "label": label,
                         "migrationName": prefix + "-migrate", "migrateFile": config["deployInitialize"]}
                state_path = work / "state.json"
                wrapper = work / "podman-fixture"
                wrapper.write_text(f"#!{sys.executable}\nimport runpy,sys\nrunpy.run_path({str(Path(__file__).resolve())!r})['shim']({str(state_path)!r},sys.argv[1:])\n")
                wrapper.chmod(0o700)
                def initialize(selected, selected_envs):
                    state.update(postgres=selected_envs["postgres"], migrate=selected_envs["migrate"] | {"POSTGRES_HOST": "127.0.0.1"})
                    state_path.write_text(json.dumps(state))
                    script = re.sub(r"/nix/store/[^/]+/bin/podman", str(wrapper), selected["initializeScript"])
                    script_path = work / "initialize.sh"
                    script_path.write_text(script)
                    result = subprocess.run(["bash", str(script_path)], text=True, capture_output=True, timeout=150)
                    assert result.returncode == 0, "evaluated initializer/migration failed (output suppressed)"
                if scenario == "existing":
                    initialize(old, old_envs)
                    assert sql("SELECT pg_read_file('/tmp/db-role-sentinel');").stdout.strip() == "fixture-sentinel"
                    sql("COPY (SELECT 'before') TO PROGRAM 'cat > /tmp/db-role-program-before';")
                    print("PASS: baseline app role reads server sentinel and executes server program", flush=True)
                    denied = sql("ALTER ROLE unprompted NOSUPERUSER;", check=False)
                    assert denied.returncode and "bootstrap superuser" in denied.stderr
                    sql('''CREATE TABLE public.role_transition_fixture (id integer GENERATED ALWAYS AS IDENTITY, value text);
                        INSERT INTO public.role_transition_fixture(value) VALUES ('retained');
                        CREATE SCHEMA pgboss;
                        CREATE FUNCTION pgboss.fixture() RETURNS integer LANGUAGE sql AS 'SELECT 42';
                        CREATE TYPE pgboss.fixture_enum AS ENUM ('ok');''')
                initialize(config, envs)
                role = sql("SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=current_user;").stdout.strip()
                assert role == "f|f|f|f|f", "application retains cluster privileges: " + role
                for statement in ["SELECT pg_read_file('/tmp/db-role-sentinel');", "COPY (SELECT 'after') TO PROGRAM 'cat > /tmp/db-role-program-after';",
                                  "CREATE ROLE fixture_escape SUPERUSER;", "CREATE DATABASE fixture_escape;", "SET ROLE unprompted_cluster_admin;", "SELECT rolpassword FROM pg_authid;"]:
                    result = sql(statement, check=False)
                    assert result.returncode and ("permission denied" in result.stderr or "must be superuser" in result.stderr), "privileged app operation was not denied by authorization"
                assert podman("exec", db, "test", "-e", "/tmp/db-role-program-before", check=False).returncode == (0 if scenario == "existing" else 1)
                assert podman("exec", db, "test", "!", "-e", "/tmp/db-role-program-after").returncode == 0
                assert sql("SELECT 1;", tcp_password=old_envs["migrate"]["POSTGRES_PASSWORD"]).stdout.strip() == "1"
                assert sql("SELECT 1;", tcp_password="fixture-wrong-password", check=False).returncode != 0
                assert sql("SELECT 1;", user="unprompted_cluster_admin", tcp_password=envs["postgres"]["POSTGRES_PASSWORD"]).stdout.strip() == "1"
                assert sql("SELECT 1;", user="unprompted_cluster_admin", tcp_password=old_envs["migrate"]["POSTGRES_PASSWORD"], check=False).returncode != 0
                assert sql("SELECT datdba=(SELECT oid FROM pg_roles WHERE rolname='unprompted') FROM pg_database WHERE datname='unprompted';").stdout.strip() == "t"
                assert sql("SELECT oid,datdba FROM pg_database WHERE datname <> 'unprompted' ORDER BY oid;").stdout == system_before
                if scenario == "existing":
                    assert sql("SELECT value FROM public.role_transition_fixture;").stdout.strip() == "retained"
                    sql("ALTER TABLE public.role_transition_fixture ADD COLUMN after_transition text; INSERT INTO public.role_transition_fixture(value) VALUES ('after'); ALTER TYPE pgboss.fixture_enum ADD VALUE 'after'; CREATE OR REPLACE FUNCTION pgboss.fixture() RETURNS integer LANGUAGE sql AS 'SELECT 43';")
                sql("CREATE TABLE public.role_new_table (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, value text); INSERT INTO public.role_new_table(value) VALUES ('write'); ALTER TABLE public.role_new_table ADD COLUMN extra text;")
                dump = podman("exec", db, "pg_dump", "-U", "unprompted", "-d", "unprompted", "--no-owner", "--no-privileges")
                assert "CREATE TABLE public.role_new_table" in dump.stdout
                # The database owner can persist a hostile path for future admin
                # connections. Plant everything as the restricted application,
                # then exercise the unchanged evaluated initializer transport.
                roles_before = sql("SELECT rolname,rolcanlogin FROM pg_catalog.pg_roles ORDER BY rolname;").stdout
                sql('''CREATE TABLE public.role_search_path_calls (actor text);
                    CREATE FUNCTION public.role_search_path_probe() RETURNS boolean
                    LANGUAGE plpgsql SECURITY INVOKER AS $attack$
                    BEGIN
                      INSERT INTO public.role_search_path_calls VALUES (current_user);
                      RETURN true;
                    END
                    $attack$;
                    CREATE VIEW public.pg_roles AS SELECT * FROM pg_catalog.pg_roles
                      WHERE public.role_search_path_probe();
                    ALTER DATABASE unprompted SET search_path = public, pg_catalog;''')
                assert sql("SHOW search_path;").stdout.strip() == "public, pg_catalog"
                initialize(config, envs)
                calls = sql("SELECT actor FROM public.role_search_path_calls ORDER BY actor;").stdout.strip()
                role = sql("SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_catalog.pg_roles WHERE rolname=current_user;").stdout.strip()
                print(f"Hostile reinitializer ({scenario}): callbacks={calls!r}, app_flags={role}", flush=True)
                assert not calls, "privileged initializer executed the application-controlled catalog callback: " + calls
                assert role == "f|f|f|f|f", "hostile reinitializer elevated the application: " + role
                assert sql("SELECT rolname,rolcanlogin FROM pg_catalog.pg_roles ORDER BY rolname;").stdout == roles_before
                sql('''ALTER DATABASE unprompted RESET search_path;
                    DROP VIEW public.pg_roles;
                    DROP FUNCTION public.role_search_path_probe();
                    DROP TABLE public.role_search_path_calls;''')
                print(f"PASS: {scenario} hostile app-owned schema cannot execute in admin reinitializer, elevate app flags or create a login", flush=True)
                if scenario == "existing":
                    initialize(old, old_envs)
                    assert sql("SELECT rolsuper FROM pg_roles WHERE rolname='unprompted';").stdout.strip() == "f"
                for consumer in ["api", "worker"]:
                    configured = containers["unprompted-" + consumer]
                    controls = [x for x in configured["extraOptions"] if x.startswith(("--cap-", "--security-opt="))]
                    fixture_env = envs[consumer] | {"POSTGRES_HOST": "127.0.0.1", "SMTP_HOST": "127.0.0.1", "API_ORIGIN": "http://127.0.0.1:4100", "WEB_ORIGIN": "http://127.0.0.1:4100", "BETTER_AUTH_URL": "http://127.0.0.1:4100", "AI_BASE_URL": "http://127.0.0.1:4100"}
                    cid = start(consumer, images["unprompted-" + consumer], ["--network=container:" + db, "--memory=384m", "--user=1000:1000", *controls], fixture_env)
                    if consumer == "api":
                        wait(["exec", cid, "node", "-e", "fetch('http://127.0.0.1:4100/ready').then(r=>{if(r.status!==200)process.exit(1)}).catch(()=>process.exit(1))"])
                    else:
                        for _ in range(160):
                            logs = podman("logs", cid).stdout
                            if "worker started with 7 handlers and an active email scheduler" in logs:
                                break
                            time.sleep(.25)
                        else:
                            raise AssertionError("worker startup/scheduler failed")
                        sql("INSERT INTO jobs(kind,idempotency_key,payload) VALUES ('fixture_unknown_handler','fixture-queue','{}');")
                        for _ in range(160):
                            if sql("SELECT status || ':' || coalesce(last_error_code,'') FROM jobs WHERE idempotency_key='fixture-queue';").stdout.strip() == "retryable_failed:UNKNOWN_JOB_KIND":
                                break
                            time.sleep(.25)
                        else:
                            raise AssertionError("worker did not claim and update new job")
                    stop(cid)
                print(f"PASS: {scenario} scoped ownership, denied cluster operations, unchanged app password, admin isolation, migrations, API, worker queue, dump, idempotence/rollback", flush=True)
        finally:
            # Only UUID-owned fixture CIDs, plus an exact UUID migration name if interrupted.
            podman("rm", "--force", prefix + "-migrate", check=False)
            for cid in reversed(created):
                podman("rm", "--force", cid, check=False)


if __name__ == "__main__":
    main(json.loads(Path(sys.argv[1]).read_text()), json.loads(Path(sys.argv[2]).read_text()), "--baseline" in sys.argv)
