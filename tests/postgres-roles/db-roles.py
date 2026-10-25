#!/usr/bin/env python3
"""Real cached Linux-image security and compatibility fixtures, sequential only.

Usage: db-roles.py AFTER.json BEFORE.json [--baseline] [--service NAME] [--roles-only]
Consumes only undecrypted evaluated config and dummy credentials. No production
mounts, ports, networks, environment, image pulls, or production SQL writes.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import time
import uuid

APP_PASSWORD = "fixture-app-'password"
ADMIN_PASSWORD = "fixture-admin-'different-password"
FLAGS = "SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_catalog.pg_roles WHERE rolname=current_user;"
EXTENSIONS = {"montra": ["vector", "unaccent", "pg_trgm"], "umami": ["pgcrypto"], "openpost": [], "shlink": []}


def podman(*args, input=None, check=True, timeout=150):
    result = subprocess.run(["podman", *args], input=input, text=True, capture_output=True, timeout=timeout)
    if check and result.returncode:
        raise AssertionError(f"fixture {args[0]} failed: {result.stderr[-1800:]}")
    return result


def shim(state_path, args):
    state = json.loads(Path(state_path).read_text())
    assert args[0] == "exec", "role initializer must only exec its database"
    i = args.index(state["service"] + "-postgres")
    injected = [] if state.get("old") else ["--env", "POSTGRES_PASSWORD=" + ADMIN_PASSWORD,
                      "--env", "APP_POSTGRES_PASSWORD=" + APP_PASSWORD]
    args = args[:i] + injected + [state["db"]] + args[i + 1:]
    result = podman(*args, input=sys.stdin.read() if "-i" in args else None, check=False)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    sys.exit(result.returncode)


def main(config, old, baseline=False, selected=None, roles_only=False, only_scenario=None, delayed_init=False):
    assert sys.platform.startswith("linux"), "Linux fixture host required"
    for service in ([selected] if selected else EXTENSIONS):
        containers = config["containers"]
        app_name = "montra-api" if service == "montra" else service
        images = {key: podman("image", "inspect", containers[name]["image"], "--format", "{{.Id}}").stdout.strip()
                  for key, name in [("postgres", service + "-postgres"), ("app", app_name)]}
        assert all(re.fullmatch(r"(?:sha256:)?[0-9a-f]{64}", value) for value in images.values())
        print(service + " cached images: " + json.dumps(images), flush=True)
        for scenario in (["existing"] if baseline else [only_scenario] if only_scenario else ["existing", "fresh"]):
            prefix = "rgo-pg-roles-" + uuid.uuid4().hex[:12]
            created = []
            user = ('Fixture-Umami"Role' if roles_only and scenario == "fresh" else "Fixture-UmamiRole") if service == "umami" else service
            database = ("Fixture-Umami Database" if roles_only else "fixture_umami_database") if service == "umami" else service
            admin = service + "_cluster_admin"
            def start(name, image, env, options=(), command=()):
                cid = podman("run", "-d", "--pull=never", "--name", prefix + "-" + name,
                             "--label", "rgo.audit.postgres-roles=" + prefix,
                             "--cpus=0.5", "--pids-limit=128", *options,
                             *[a for k, v in env.items() for a in ["--env", k + "=" + v]], image, *command).stdout.strip()
                assert re.fullmatch(r"[0-9a-f]{64}", cid)
                created.append(cid)
                return cid
            def stop(cid):
                podman("rm", "--force", cid)
                created.remove(cid)
            def sql(statement, role=None, password=None, check=True, dbname=None):
                options = ["--env", "PGPASSWORD=" + password] if password is not None else []
                host = ["-h", "127.0.0.1"] if password is not None else []
                return podman("exec", "-i", *options, db, "psql", "-XqAt", *host,
                              "-U", role or user, "-d", dbname or database,
                              "-v", "ON_ERROR_STOP=1", input=statement, check=check)
            def wait(command, description):
                for _ in range(240):
                    if podman(*command, check=False).returncode == 0:
                        return
                    if podman("inspect", db, "--format", "{{.State.Running}}").stdout.strip() != "true":
                        raise AssertionError(description + " exited: " + podman("logs", db).stderr[-1800:])
                    time.sleep(.5)
                raise AssertionError(description + " timed out")
            def application():
                if roles_only:
                    return
                # Use URL-safe dummy transport password without changing the SQL
                # quoting challenge exercised by the role helper and SCRAM below.
                from urllib.parse import quote
                url = "postgres://" + quote(user, safe="") + ":" + quote(APP_PASSWORD, safe="") + "@127.0.0.1:5432/" + quote(database, safe="")
                if service == "montra":
                    env = {"DATABASE_URL": url, "NODE_ENV": "test", "DATABASE_POOL_SIZE": "2"}
                    cid = start("migrate", images["app"], env,
                                ["--network=container:" + db, "--memory=384m"], ["bun", "run", "db:migrate"])
                    code = podman("wait", cid, timeout=240).stdout.strip()
                    if code != "0":
                        raise AssertionError("Montra real migration failed: " + podman("logs", cid).stderr[-2400:])
                    stop(cid)
                    env |= {"NODE_ENV": "production", "CATALOG_PREWARM": "0", "API_PORT": "8787",
                            "API_ORIGIN": "http://127.0.0.1:8787", "WEB_ORIGIN": "http://127.0.0.1:8787",
                            "BETTER_AUTH_SECRET": "fixture-montra-auth-secret-0123456789abcdef",
                            "GOOGLE_CLIENT_ID": "fixture", "GOOGLE_CLIENT_SECRET": "fixture",
                            "SEARCH_PROVIDER": "snapshot", "VISUAL_SEARCH_PROVIDER": "local",
                            "VISUAL_EMBEDDING_URL": "", "FASHION_DETECTOR_URL": "",
                            "NODE_OPTIONS": "--max-old-space-size=256"}
                    probe = ["node", "-e", "fetch('http://127.0.0.1:8787/health/ready').then(async r=>{const j=await r.json();process.exit(r.ok&&j.dependencies.postgres.ok?0:1)}).catch(()=>process.exit(1))"]
                elif service == "openpost":
                    env = {"OPENPOST_DATABASE_DRIVER": "postgres", "OPENPOST_DATABASE_URL": url + "?sslmode=disable",
                           "OPENPOST_HOST": "0.0.0.0", "OPENPOST_PORT": "8080", "OPENPOST_ENV": "production",
                           "OPENPOST_JWT_SECRET": "fixture-jwt-secret-that-is-long-enough-123456789",
                           "OPENPOST_ENCRYPTION_KEY": "0123456789abcdef0123456789abcdef",
                           "OPENPOST_EDITION": "cloud", "OPENPOST_PUBLIC_URL": "http://127.0.0.1:8080",
                           "OPENPOST_APP_URL": "http://127.0.0.1:8080", "OPENPOST_STORAGE_DRIVER": "s3",
                           "OPENPOST_S3_ENDPOINT": "http://127.0.0.1:19999", "OPENPOST_S3_REGION": "fixture",
                           "OPENPOST_S3_BUCKET": "fixture", "OPENPOST_S3_ACCESS_KEY_ID": "fixture",
                           "OPENPOST_S3_SECRET_ACCESS_KEY": "fixture", "OPENPOST_S3_PUBLIC_BASE_URL": "http://127.0.0.1:19999",
                           "OPENPOST_PADDLE_API_KEY": "pdl_sdbx_fixture", "OPENPOST_PADDLE_ENVIRONMENT": "sandbox",
                           "OPENPOST_PADDLE_CLIENT_TOKEN": "test_fixture", "OPENPOST_PADDLE_WEBHOOK_SECRET": "fixture",
                           "OPENPOST_PADDLE_API_BASE_URL": "http://127.0.0.1:19999",
                           "OPENPOST_POSTHOG_API_HOST": "http://127.0.0.1:19999", "OPENPOST_POSTHOG_PROJECT_TOKEN": "fixture"}
                    for tier in ["FOUNDER", "TEAM", "AGENCY"]:
                        for cycle in ["MONTHLY", "ANNUAL"]:
                            env["OPENPOST_PADDLE_" + tier + "_" + cycle + "_PRICE_ID"] = "pri_fixture_" + tier.lower() + cycle.lower()
                    probe = ["wget", "-qO-", "http://127.0.0.1:8080/api/v1/ready"]
                elif service == "umami":
                    env = {"DATABASE_URL": url, "DATABASE_TYPE": "postgres", "APP_SECRET": "fixture-umami-secret",
                           "HOSTNAME": "0.0.0.0", "DISABLE_TELEMETRY": "1", "NODE_OPTIONS": "--max-old-space-size=256"}
                    probe = ["node", "-e", "fetch('http://127.0.0.1:3000/api/heartbeat').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
                else:
                    env = {"DB_DRIVER": "postgres", "DB_HOST": "127.0.0.1", "DB_PORT": "5432", "DB_NAME": database,
                           "DB_USER": user, "DB_PASSWORD": APP_PASSWORD, "DEFAULT_DOMAIN": "fixture.invalid",
                           "IS_HTTPS_ENABLED": "true", "GEOLITE_LICENSE_KEY": "", "SKIP_INITIAL_GEOLITE_DOWNLOAD": "true",
                           "PORT": "8080", "WEB_WORKER_NUM": "1", "TASK_WORKER_NUM": "1", "SHELL_VERBOSITY": "3"}
                    probe = ["curl", "-fs", "http://127.0.0.1:8080/rest/health"]
                controls = [o for o in containers[app_name]["extraOptions"] if o.startswith(("--cap-", "--security-opt="))]
                options = ["--network=container:" + db, "--memory=384m", *controls]
                if containers[app_name].get("user"):
                    options += ["--user=" + containers[app_name]["user"]]
                cid = start("app", images["app"], env, options)
                try:
                    for _ in range(240):
                        if podman("exec", cid, *probe, check=False).returncode == 0:
                            print(f"PASS {service}/{scenario}: cached app readiness", flush=True)
                            break
                        if podman("inspect", cid, "--format", "{{.State.Running}}").stdout.strip() != "true":
                            raise AssertionError("cached app exited (OOM=" + podman("inspect", cid, "--format", "{{.State.OOMKilled}}").stdout.strip() + "): " + (podman("logs", cid).stdout + podman("logs", cid).stderr)[-3500:])
                        time.sleep(.5)
                    else:
                        raise AssertionError("cached app readiness timeout: " + (podman("logs", cid).stdout + podman("logs", cid).stderr)[-3500:])
                finally:
                    stop(cid)
            try:
                initial_user = user if scenario == "existing" else admin
                initial_password = APP_PASSWORD if scenario == "existing" else ADMIN_PASSWORD
                env = {"POSTGRES_USER": initial_user, "POSTGRES_DB": database, "POSTGRES_PASSWORD": initial_password,
                       "APP_POSTGRES_PASSWORD": APP_PASSWORD, "POSTGRES_INITDB_ARGS": "--auth-host=scram-sha-256 --auth-local=trust",
                       "FIXTURE_USER": user, "FIXTURE_DATABASE": database, "FIXTURE_APP_PASSWORD": APP_PASSWORD,
                       "FIXTURE_ADMIN_PASSWORD": ADMIN_PASSWORD}
                if service in ["umami", "shlink"]:
                    # Exercise the evaluated _FILE bootstrap interface, including
                    # non-default Umami role/database values, with private files.
                    env.pop("POSTGRES_DB")
                    env["POSTGRES_DB_FILE"] = "/run/secrets/db_name"
                    env.pop("POSTGRES_PASSWORD")
                    env["POSTGRES_PASSWORD_FILE"] = "/run/secrets/" + (
                        ("postgres_password" if service == "umami" else "db_password")
                        if scenario == "existing" else "admin_password")
                    if scenario == "existing":
                        env.pop("POSTGRES_USER")
                        env["POSTGRES_USER_FILE"] = "/run/secrets/db_user"
                # Runtime files are fixture-only container tmpfs, never host files.
                entry = '''mkdir -p /run/secrets
printf %s "$FIXTURE_USER" > /run/secrets/db_user
printf %s "$FIXTURE_DATABASE" > /run/secrets/db_name
printf %s "$FIXTURE_APP_PASSWORD" > /run/secrets/db_password
printf %s "$FIXTURE_APP_PASSWORD" > /run/secrets/postgres_password
printf %s "$FIXTURE_ADMIN_PASSWORD" > /run/secrets/admin_password
chmod 0400 /run/secrets/*
exec docker-entrypoint.sh postgres -c shared_buffers=16MB -c max_connections=30'''
                if delayed_init:
                    # Executed by the official entrypoint while its socket-only
                    # temporary PostgreSQL server is live, before final TCP boot.
                    delay = "mkdir -p /docker-entrypoint-initdb.d\ncat > /docker-entrypoint-initdb.d/00-fixture-delay.sh <<'DELAY'\n#!/bin/sh\ntouch /tmp/role-temp-server-active\nsleep 15\nrm /tmp/role-temp-server-active\ntouch /tmp/role-init-done\nDELAY\nchmod 755 /docker-entrypoint-initdb.d/00-fixture-delay.sh\n"
                    entry = entry.replace("exec docker-entrypoint.sh", delay + "exec docker-entrypoint.sh")
                db = start("db", images["postgres"], env,
                           ["--network=none", "--memory=192m", "--tmpfs=/var/lib/postgresql/data:rw,size=128m",
                            "--tmpfs=/run/secrets:rw,size=1m", "--entrypoint=sh"], ["-ec", entry])
                if delayed_init:
                    wait(["exec", db, "test", "-e", "/tmp/role-temp-server-active"], "temporary server marker")
                    podman("exec", db, "pg_isready", "-U", initial_user, "-d", database)
                    assert podman("exec", db, "pg_isready", "-h", "127.0.0.1", "-U", initial_user, "-d", database, check=False).returncode != 0
                else:
                    wait(["exec", "--env", "PGPASSWORD=" + initial_password, db, "psql", "-h", "127.0.0.1", "-U", initial_user, "-d", database, "-Atc", "SELECT 1"], "database")
                podman("exec", db, "sh", "-ec", "printf fixture-sentinel > /tmp/role-sentinel")
                if service == "openpost" and not roles_only:
                    # External storage stand-in, not a storage/security test.
                    # Runs within the existing DB memory/CPU/PID cgroup and its
                    # isolated network, with no third container or host service.
                    storage_handler = Path(__file__).with_name("storage-standin.sh").read_text()
                    podman("exec", "-i", db, "sh", "-ec",
                           "cat > /tmp/fixture-s3-handler; chmod 700 /tmp/fixture-s3-handler", input=storage_handler)
                    podman("exec", "-d", db, "sh", "-ec",
                           "while :; do busybox nc -l -p 19999 -e /tmp/fixture-s3-handler; done")
                system_before = sql("SELECT oid,datdba FROM pg_catalog.pg_database WHERE datname<>current_database() ORDER BY oid;", role=initial_user).stdout
                if scenario == "existing":
                    for extension in EXTENSIONS[service]:
                        sql("CREATE EXTENSION " + extension + " WITH SCHEMA public;")
                    assert sql("SELECT pg_read_file('/tmp/role-sentinel');").stdout.strip() == "fixture-sentinel"
                    sql("COPY (SELECT 'before') TO PROGRAM 'cat > /tmp/role-program-before';")
                    if baseline:
                        role = sql(FLAGS).stdout.strip()
                        assert role == "f|f|f|f|f", "application retains cluster privileges: " + role
                    application()
                    sql('''CREATE TABLE public.role_fixture (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, value text);
INSERT INTO public.role_fixture(value) VALUES ('retained');
CREATE TYPE public.role_enum AS ENUM ('before');
CREATE DOMAIN public.role_domain AS text CHECK (length(VALUE)>0);
CREATE VIEW public.role_view AS SELECT value FROM public.role_fixture;
CREATE AGGREGATE public.role_sum(integer) (SFUNC=int4pl, STYPE=integer, INITCOND='0');
CREATE FUNCTION public.role_function() RETURNS integer LANGUAGE sql AS 'SELECT 42';
CREATE TABLE public.role_extension_owners AS
SELECT d.classid,d.objid,coalesce(c.relowner,p.proowner,t.typowner) AS owner
FROM pg_catalog.pg_depend d
LEFT JOIN pg_catalog.pg_class c ON d.classid='pg_catalog.pg_class'::regclass AND c.oid=d.objid
LEFT JOIN pg_catalog.pg_proc p ON d.classid='pg_catalog.pg_proc'::regclass AND p.oid=d.objid
LEFT JOIN pg_catalog.pg_type t ON d.classid='pg_catalog.pg_type'::regclass AND t.oid=d.objid
WHERE d.deptype='e' AND coalesce(c.relowner,p.proowner,t.typowner) IS NOT NULL;''')
                # Snapshot immediately before the transition, after any baseline
                # app bootstrap, so its temporary-database work is not attributed
                # to the role helper.
                system_before = sql("SELECT oid,datdba FROM pg_catalog.pg_database WHERE datname<>current_database() ORDER BY oid;", role=initial_user).stdout
                with tempfile.TemporaryDirectory(prefix=prefix) as directory:
                    work = Path(directory)
                    state = work / "state.json"
                    state.write_text(json.dumps({"db": db, "service": service}))
                    wrapper = work / "podman-fixture"
                    wrapper.write_text(f"#!{sys.executable}\nimport runpy,sys\nrunpy.run_path({str(Path(__file__).resolve())!r})['shim']({str(state)!r},sys.argv[1:])\n")
                    wrapper.chmod(0o700)
                    script = re.sub(r"/nix/store/[^/]+/bin/podman", str(wrapper), config["roleScripts"][service])
                    path = work / "roles.sh"
                    path.write_text(script)
                    def initialize(expect_error=None):
                        result = subprocess.run(["bash", str(path)], capture_output=True, text=True, timeout=150)
                        if expect_error:
                            assert result.returncode and expect_error in result.stderr, "expected atomic guard failure: " + result.stderr[-2200:]
                        else:
                            assert not result.returncode, "real role initializer failed: " + result.stderr[-2200:]
                    initialize()
                    if delayed_init:
                        assert podman("exec", db, "test", "!", "-e", "/tmp/role-temp-server-active", check=False).returncode == 0, "initializer returned while entrypoint temporary server was still active"
                        podman("exec", db, "test", "-e", "/tmp/role-init-done")
                        podman("exec", db, "pg_isready", "-h", "127.0.0.1", "-U", admin, "-d", database)
                        print(f"PASS {service}/delayed-init: helper invoked during socket-only temporary server waited through final TCP startup", flush=True)
                    if scenario == "fresh":
                        # Prisma migrate deploy requires an empty initial schema;
                        # exercise real fresh startup before synthetic test DDL.
                        application()
                    assert sql(FLAGS).stdout.strip() == "f|f|f|f|f"
                    health = next(o.removeprefix("--health-cmd=") for o in containers[service + "-postgres"]["extraOptions"] if o.startswith("--health-cmd="))
                    podman("exec", db, *shlex.split(health))
                    assert sql("SELECT 1", password=APP_PASSWORD).stdout.strip() == "1"
                    assert sql("SELECT 1", password="fixture-wrong", check=False).returncode
                    assert sql("SELECT 1", role=admin, password=ADMIN_PASSWORD).stdout.strip() == "1"
                    assert sql("SELECT 1", role=admin, password=APP_PASSWORD, check=False).returncode
                    for statement in ["SELECT pg_read_file('/tmp/role-sentinel');", "COPY (SELECT 'after') TO PROGRAM 'cat > /tmp/role-program-after';",
                                      "CREATE ROLE role_escape SUPERUSER;", "CREATE DATABASE role_escape;", "SET ROLE " + admin + ";", "SELECT rolpassword FROM pg_catalog.pg_authid;"]:
                        result = sql(statement, check=False)
                        assert result.returncode and ("permission denied" in result.stderr or "must be superuser" in result.stderr), result.stderr
                    assert podman("exec", db, "test", "!", "-e", "/tmp/role-program-after").returncode == 0
                    system_after = sql("SELECT oid,datdba FROM pg_catalog.pg_database WHERE datname<>current_database() ORDER BY oid;").stdout
                    assert system_after == system_before, f"non-app database metadata changed: {system_before!r} -> {system_after!r}"
                    assert sql("SELECT datdba=(SELECT oid FROM pg_catalog.pg_roles WHERE rolname=current_user) FROM pg_catalog.pg_database WHERE datname=current_database();").stdout.strip() == "t"
                    if scenario == "existing":
                        assert sql("SELECT value FROM public.role_fixture").stdout.strip() == "retained"
                        assert sql("""SELECT count(*) FROM public.role_extension_owners x
LEFT JOIN pg_catalog.pg_class c ON x.classid='pg_catalog.pg_class'::regclass AND c.oid=x.objid
LEFT JOIN pg_catalog.pg_proc p ON x.classid='pg_catalog.pg_proc'::regclass AND p.oid=x.objid
LEFT JOIN pg_catalog.pg_type t ON x.classid='pg_catalog.pg_type'::regclass AND t.oid=x.objid
WHERE coalesce(c.relowner,p.proowner,t.typowner) IS DISTINCT FROM x.owner;""").stdout.strip() == "0"
                        sql("ALTER TABLE public.role_fixture ADD COLUMN extra text; INSERT INTO public.role_fixture(value) VALUES ('after'); ALTER TYPE public.role_enum ADD VALUE 'after'; ALTER DOMAIN public.role_domain SET NOT NULL; ALTER VIEW public.role_view SET (security_barrier=true); ALTER AGGREGATE public.role_sum(integer) RENAME TO role_sum_after; CREATE OR REPLACE FUNCTION public.role_function() RETURNS integer LANGUAGE sql AS 'SELECT 43';")
                    sql("CREATE TABLE public.role_new (id integer GENERATED ALWAYS AS IDENTITY, value text); INSERT INTO public.role_new(value) VALUES ('ok'); ALTER TABLE public.role_new ADD COLUMN extra text;")
                    dump = podman("exec", db, "pg_dump", "-U", user, "-d", database,
                                  "--no-owner", "--no-privileges").stdout
                    assert "CREATE TABLE public.role_new" in dump
                    assert not re.search(r"\b(?:CREATE|ALTER)\s+ROLE\b", dump, re.I), "app dump contains cluster role statements"
                    if service == "shlink":
                        cluster_dump = podman("exec", db, "pg_dumpall", "-U", user, check=False)
                        assert cluster_dump.returncode and "pg_authid" in cluster_dump.stderr and "permission denied" in cluster_dump.stderr
                        print(f"PASS shlink/{scenario}: old pg_dumpall denied at password catalog; app pg_dump succeeds without role DDL", flush=True)
                    assert sql("SELECT count(*) FROM pg_catalog.pg_extension WHERE extowner <> '" + admin + "'::regrole;").stdout.strip() == "0"
                    assert sql("SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_depend d ON d.classid='pg_catalog.pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e' WHERE p.proowner <> '" + admin + "'::regrole;").stdout.strip() == "0"
                    if service == "montra":
                        assert sql("SELECT unaccent('café'), '[1,2,3]'::vector <-> '[1,2,3]'::vector, similarity('hello','hello');").stdout.strip() == "cafe|0|1"
                    elif service == "umami":
                        assert sql("SELECT length(gen_random_bytes(8));").stdout.strip() == "8"
                    # A persisted hostile catalog view must never run as admin.
                    inventory = sql("SELECT rolname,rolcanlogin FROM pg_catalog.pg_roles ORDER BY rolname;").stdout
                    sql('''CREATE TABLE public.role_callbacks(actor text);
CREATE FUNCTION public.role_callback() RETURNS boolean LANGUAGE plpgsql AS $$ BEGIN INSERT INTO public.role_callbacks VALUES(current_user); RETURN true; END $$;
CREATE VIEW public.pg_roles AS SELECT * FROM pg_catalog.pg_roles WHERE public.role_callback();''')
                    quoted_database = '"' + database.replace('"', '""') + '"'
                    sql("ALTER DATABASE " + quoted_database + " SET search_path=public,pg_catalog;")
                    initialize()
                    assert sql("SELECT count(*) FROM public.role_callbacks;").stdout.strip() == "0"
                    assert sql(FLAGS).stdout.strip() == "f|f|f|f|f"
                    assert sql("SELECT rolname,rolcanlogin FROM pg_catalog.pg_roles ORDER BY rolname;").stdout == inventory
                    sql("ALTER DATABASE " + quoted_database + " RESET search_path; DROP VIEW public.pg_roles; DROP FUNCTION public.role_callback(); DROP TABLE public.role_callbacks;")
                    # Exact role lookup must enforce the same atomic guard for
                    # quoted/mixed-case roles as for simple names. regrole input
                    # parsing can return NULL and silently bypass this policy.
                    sql("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO PUBLIC;")
                    initialize(expect_error="custom application role policies require a reviewed transition")
                    assert sql(FLAGS).stdout.strip() == "f|f|f|f|f"
                    assert sql("SELECT rolname,rolcanlogin FROM pg_catalog.pg_roles ORDER BY rolname;").stdout == inventory
                    sql("ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM PUBLIC;")
                    initialize()
                    if EXTENSIONS[service]:
                        # Moving a required extension after the split must fail
                        # atomically, rather than initialize in an app-owned path.
                        extension = EXTENSIONS[service][0]
                        sql("CREATE SCHEMA role_extension_admin; ALTER EXTENSION " + extension + " SET SCHEMA role_extension_admin;", role=admin)
                        initialize(expect_error="extension inventory changed")
                        assert sql(FLAGS).stdout.strip() == "f|f|f|f|f"
                        assert sql("SELECT rolname,rolcanlogin FROM pg_catalog.pg_roles ORDER BY rolname;").stdout == inventory
                        sql("ALTER EXTENSION " + extension + " SET SCHEMA public; DROP SCHEMA role_extension_admin;", role=admin)
                    # Old credential reconciliation and old application migration/
                    # startup continue to work, with the original app password.
                    if service == "openpost" and scenario == "existing":
                        original = old["units"]["openpost-postgres-credential-reconcile"]["script"]
                        assert original, "baseline evaluated reconciler unavailable"
                        state.write_text(json.dumps({"db": db, "service": service, "old": True}))
                        original = re.sub(r"/nix/store/[^/]+/bin/podman", str(wrapper), original)
                        original = re.sub(r"/nix/store/[^/]+/bin/([a-z0-9-]+)", r"\1", original)
                        original_path = work / "old-reconcile.sh"
                        original_path.write_text(original)
                        result = subprocess.run(["bash", str(original_path)], capture_output=True, text=True,
                                                env=os.environ | {"POSTGRES_PASSWORD": APP_PASSWORD}, timeout=150)
                        assert result.returncode == 0, "old evaluated reconciliation failed: " + result.stderr[-1800:]
                        state.write_text(json.dumps({"db": db, "service": service}))
                    # Synthetic enums/domains are not part of these apps'
                    # schemas and can confuse global ORM schema introspection.
                    # Their ownership/row/DDL assertions are complete; remove
                    # only fixture-owned objects before the real ORM restart.
                    sql("DROP TABLE public.role_new;")
                    if scenario == "existing":
                        sql("DROP VIEW public.role_view; DROP TABLE public.role_fixture, public.role_extension_owners; DROP TYPE public.role_enum; DROP DOMAIN public.role_domain; DROP FUNCTION public.role_function(); DROP AGGREGATE public.role_sum_after(integer);")
                        application()
                    initialize()
                    assert sql(FLAGS).stdout.strip() == "f|f|f|f|f"
                mode = "SQL-only" if roles_only else "cached app/ORM"
                print(f"PASS {service}/{scenario}: five flags false, denied cluster/file capabilities, SCRAM passwords, owners/rows, extensions, DDL, dump, hostile path, idempotence, {mode} compatibility", flush=True)
            finally:
                for cid in reversed(created):
                    podman("rm", "--force", cid, check=False)
                for name in ["db", "app", "migrate"]:
                    podman("rm", "--force", prefix + "-" + name, check=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("config")
    parser.add_argument("old")
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--service", choices=list(EXTENSIONS))
    parser.add_argument("--roles-only", action="store_true")
    parser.add_argument("--scenario", choices=["existing", "fresh"])
    parser.add_argument("--delayed-init", action="store_true")
    args = parser.parse_args()
    if args.delayed_init:
        args.roles_only = True
        args.scenario = "fresh"
        assert not args.baseline
    main(json.loads(Path(args.config).read_text()), json.loads(Path(args.old).read_text()), args.baseline, args.service, args.roles_only, args.scenario, args.delayed_init)
