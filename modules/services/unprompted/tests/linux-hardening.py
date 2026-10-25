#!/usr/bin/env python3
"""Observe kernel privileges and exact-image startup in isolated Linux containers.

Run on a Linux Podman host with evaluated, undecrypted evaluate.expr JSON.
Uses cached image IDs, dummy credentials, private tmpfs data, no published ports,
and only an isolated PostgreSQL container's otherwise disconnected network.
Never consumes production environment files, mounts, databases or networks.
"""

import json
from pathlib import Path
import re
import runpy
import shlex
import subprocess
import sys
import time
import uuid


def run(*args, check=True, input=None):
    result = subprocess.run(["podman", *args], input=input, capture_output=True, text=True, timeout=120)
    if check and result.returncode:
        raise AssertionError(f"fixture command failed: {args[0]}: {result.stderr[-1000:]}")
    return result


def security_options(container):
    # Preserve actual configured controls; replace production connectivity and
    # mounts with fixture resources below. Do not manufacture security controls.
    options = [x for x in container["extraOptions"] if x.startswith(("--cap-", "--security-opt=", "--tmpfs=", "--user="))]
    if container.get("user"):
        options.append("--user=" + container["user"])
    return options


def main(config):
    assert sys.platform.startswith("linux"), "requires Linux Podman"
    envs, _ = runpy.run_path(str(Path(__file__).with_name("env-boundary.py")))["environments"](config)
    containers = config["containers"] | {"directus": config["directus"]}
    images = {name: run("image", "inspect", c["image"], "--format", "{{.Id}}").stdout.strip() for name, c in containers.items()}
    images["migrate"] = run("image", "inspect", "ghcr.io/rodrgds/unprompted-migrate:latest", "--format", "{{.Id}}").stdout.strip()
    assert all(re.fullmatch(r"(?:sha256:)?[0-9a-f]{64}", x) for x in images.values())
    migration = re.search(r"/bin/podman run (.*?)--env-file=", config["initializeScript"], re.S)
    assert migration, "cannot find evaluated migration runtime command"
    migration_options = security_options({"extraOptions": shlex.split(migration[1].replace("\\\n", ""))})
    kernel_probe = r"""
const fs = require('node:fs');
const status = fs.readFileSync('/proc/self/status', 'utf8');
const fields = Object.fromEntries(status.trim().split('\n').map(line => {
  const i = line.indexOf(':'); return [line.slice(0, i), line.slice(i + 1).trim()];
}));
const get = key => fields[key];
console.log(JSON.stringify({uid: process.getuid(), noNewPrivs: get('NoNewPrivs'),
  caps: ['CapInh', 'CapPrm', 'CapEff', 'CapBnd', 'CapAmb'].map(get)}));
"""
    for name in ["unprompted-api", "unprompted-worker", "unprompted-web", "directus", "migrate"]:
        options = migration_options if name == "migrate" else security_options(containers[name])
        result = run("run", "--rm", "--pull=never", "--network=none", "--memory=96m", "--pids-limit=64", *options, "--entrypoint=node", images[name], "-e", kernel_probe)
        state = json.loads(result.stdout)
        assert state["uid"] != 0, f"{name}: process still runs as root"
        assert state["noNewPrivs"] == "1", f"{name}: kernel permits new privileges"
        assert all(int(x, 16) == 0 for x in state["caps"]), f"{name}: kernel capabilities remain"
        print(f"PASS: {name} unprivileged UID, zero capabilities and no-new-privileges", flush=True)

    prefix = "rgo-app-hardening-" + uuid.uuid4().hex[:12]
    created = []

    def start(name, image, options, env, command=()):
        full_name = prefix + "-" + name
        created.append(full_name)
        grants = [arg for key, value in env.items() for arg in ["--env", f"{key}={value}"]]
        run("run", "--detach", "--name", full_name, "--pull=never", "--cpus=0.5", "--pids-limit=128", *options, *grants, image, *command)
        return full_name

    def stop(name):
        run("rm", "--force", name)
        created.remove(name)

    def wait(name, args):
        for _ in range(100):
            if run("exec", name, *args, check=False).returncode == 0:
                return
            if run("inspect", name, "--format", "{{.State.Running}}").stdout.strip() != "true":
                logs = run("logs", name, check=False)
                raise AssertionError("fixture exited before readiness: " + (logs.stdout + logs.stderr)[-2000:])
            time.sleep(0.3)
        raise AssertionError("fixture did not become ready")

    try:
        db = start("db", images["unprompted-postgres"], ["--network=none", "--memory=192m", "--tmpfs=/var/lib/postgresql/data:rw,size=128m"], envs["postgres"])
        wait(db, ["pg_isready", "-h", "127.0.0.1", "-U", "unprompted", "-d", "unprompted"])
        # Fresh clusters start with the cluster admin. Use the real initializer's
        # SQL to create the application owner before exercising app hardening.
        role_sql = re.search(r"<<'SQL'\n(.*?)\nSQL", config["initializeScript"], re.S)
        assert role_sql, "evaluated role initialization SQL is unavailable"
        run("exec", "-i", db, "psql", "-X", "-U", envs["postgres"]["POSTGRES_USER"],
            "-d", "unprompted", "-v", "ON_ERROR_STOP=1", input=role_sql[1])
        connected = ["--network=container:" + db, "--memory=384m"]
        for env in envs.values():
            for key in ["API_ORIGIN", "API_URL", "NEXT_PUBLIC_API_URL", "BETTER_AUTH_URL", "WEB_ORIGIN", "AI_BASE_URL"]:
                if key in env:
                    env[key] = "http://127.0.0.1:4100"
            if "SMTP_HOST" in env:
                env["SMTP_HOST"] = "127.0.0.1"
            if "POSTGRES_HOST" in env:
                env.update(POSTGRES_HOST="127.0.0.1", POSTGRES_PORT="5432")
        migration_name = start("migrate", images["migrate"], connected + migration_options, envs["migrate"])
        assert run("wait", migration_name).stdout.strip() == "0", "fixture migration failed"
        stop(migration_name)
        print("PASS: exact Linux migration image with DB-only dummy grants", flush=True)

        api = start("api", images["unprompted-api"], connected + security_options(containers["unprompted-api"]), envs["api"])
        wait(api, ["node", "-e", "fetch('http://127.0.0.1:4100/ready').then(r=>{if(r.status!==200)process.exit(1)}).catch(()=>process.exit(1))"])
        stop(api)
        worker = start("worker", images["unprompted-worker"], connected + security_options(containers["unprompted-worker"]), envs["worker"])
        for _ in range(100):
            if "worker started with 7 handlers and an active email scheduler" in run("logs", worker).stdout:
                break
            assert run("inspect", worker, "--format", "{{.State.Running}}").stdout.strip() == "true", "worker fixture exited"
            time.sleep(0.2)
        else:
            raise AssertionError("worker handlers/scheduler did not start")
        stop(worker)
        print("PASS: exact Linux API /ready and worker handlers/scheduler", flush=True)

        envs["web"].update(API_URL="http://127.0.0.1:4100", WEB_ORIGIN="http://127.0.0.1:3000")
        web = start("web", images["unprompted-web"], connected + security_options(containers["unprompted-web"]), envs["web"])
        wait(web, ["node", "-e", "fetch('http://127.0.0.1:3000/').then(r=>{if(r.status!==200)process.exit(1)}).catch(()=>process.exit(1))"])
        # Read-only landing PNG exercises native Sharp and a real Next cache write.
        run("exec", web, "node", "-e", "(async()=>{const r=await fetch('http://127.0.0.1:3000/_next/image?url=%2Fplates%2Festimate-icon.png&w=640&q=75');if(!r.ok||!(r.headers.get('content-type')||'').startsWith('image/'))throw Error('image');const fs=require('node:fs');if(!fs.readdirSync('/app/apps/web/.next/cache/images').length)throw Error('cache');console.log('PASS: standalone SSR, native image optimization and cache write')})().catch(()=>process.exit(1))")
        # A local 404 API lets the real OpenGraph route render its fallback.
        # No real share/account is created and image/font code stays offline.
        run("exec", "--detach", web, "node", "-e", "require('node:http').createServer((q,r)=>{r.writeHead(404);r.end('{}')}).listen(4100,'127.0.0.1')")
        wait(web, ["node", "-e", "fetch('http://127.0.0.1:4100').then(r=>{if(r.status!==404)process.exit(1)}).catch(()=>process.exit(1))"])
        run("exec", web, "node", "-e", "(async()=>{const r=await fetch('http://127.0.0.1:3000/share/fixture/opengraph-image');const b=new Uint8Array(await r.arrayBuffer());if(!r.ok||r.headers.get('content-type')!=='image/png'||b[0]!==137||b[1]!==80)throw Error('OpenGraph')})().catch(()=>process.exit(1))")
        stop(web)
        stop(db)
        print("PASS: exact Linux web SSR, native image optimization/cache write, OpenGraph fallback PNG", flush=True)

        directus = start("directus", images["directus"], ["--network=none", "--memory=768m", *security_options(containers["directus"]), "--tmpfs=/directus/database:rw,mode=1777,size=64m", "--tmpfs=/directus/uploads:rw,mode=1777,size=8m", "--tmpfs=/directus/extensions:rw,mode=1777,size=1m"], config["directus"]["environment"] | {"KEY": "fixture-key-012345678901234567890123456789", "SECRET": "fixture-secret-012345678901234567890123456789", "ADMIN_EMAIL": "fixture@example.com", "ADMIN_PASSWORD": "Fixture-Dummy-Password-0123456789"})
        wait(directus, ["node", "-e", "fetch('http://127.0.0.1:8055/server/ping').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"])
        run("exec", directus, "node", "-e", "(async()=>{const base='http://127.0.0.1:8055';const anon=await fetch(base+'/users');if(anon.status!==403)throw Error('anonymous');const auth=await fetch(base+'/auth/login',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:'fixture@example.com',password:'Fixture-Dummy-Password-0123456789'})});const token=(await auth.json()).data?.access_token;if(!token)throw Error('login');const h={'content-type':'application/json',authorization:'Bearer '+token};const c=await fetch(base+'/collections',{method:'POST',headers:h,body:JSON.stringify({collection:'hardening_fixture',schema:{},fields:[{field:'id',type:'integer',schema:{is_primary_key:true,has_auto_increment:true}}]})});if(!c.ok)throw Error('create');const w=await fetch(base+'/items/hardening_fixture',{method:'POST',headers:h,body:'{}'});if(!w.ok)throw Error('write');const r=await fetch(base+'/items/hardening_fixture',{headers:h});if((await r.json()).data?.length!==1)throw Error('read')})().catch(()=>process.exit(1))")
        stop(directus)
        print("PASS: exact Directus baseline bootstrap, login, permission denial, DB write/read", flush=True)
    finally:
        for name in reversed(created):
            run("rm", "--force", name, check=False)


if __name__ == "__main__":
    main(json.loads(Path(sys.argv[1]).read_text()))
