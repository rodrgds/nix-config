# Services, processes, and tasks

Verified against devenv 2.1.x.

These three options model *running things*. Keep them distinct:

- **`services.*`** — pre-packaged daemons (databases, caches, brokers) with sensible config, data dirs, and lifecycle handled for you.
- **`processes.*`** — arbitrary long-running commands you define (your web server, a worker, a watcher).
- **`tasks`** — ordered, cacheable one-shot steps (build, codegen, migrations, setup).

A key mental model: **enabling a service or declaring a process does not start it.** They run when you run `devenv up` (or `devenv processes up`). The shell (`devenv shell`) gives you the tools and env, not the running daemons.

## Services

```nix
services.postgres = {
  enable = true;
  package = pkgs.postgresql_16;
  listen_addresses = "127.0.0.1";
  port = 5432;
  initialDatabases = [{ name = "myapp"; }];
  initialScript = "CREATE ROLE myuser WITH LOGIN PASSWORD 'pw' SUPERUSER;";
  extensions = ext: [ ext.postgis ];     # function selecting from available extensions
};

services.redis.enable = true;
```

devenv ships 40+ services (mysql, mongodb, elasticsearch/opensearch, kafka, rabbitmq, nginx, caddy, minio, mailpit, temporal, …). Find options with `devenv search services.<name>` or `https://devenv.sh/services/`.

Services store state under `$DEVENV_STATE/<service>`. **`initialDatabases` / `initialScript` only run when that data dir is created.** To re-run init after changing them, delete the dir (e.g. `rm -rf .devenv/state/postgres`) and `devenv up` again.

## Processes

```nix
processes = {
  web.exec = "uvicorn app.main:app --reload --port 8000";

  worker = {
    exec = "celery -A app worker";
    process-compose = {
      depends_on.postgres.condition = "process_healthy";
      readiness_probe.http_get = { host = "127.0.0.1"; port = 8000; path = "/health"; };
    };
  };
};
```

devenv runs processes under **process-compose** by default. The `process-compose.*` attribute on a process passes through that tool's config: `depends_on` with conditions (`process_started`, `process_healthy`, `process_completed_successfully`), `readiness_probe`, `availability` (restart policy), etc. Services expose a process name (e.g. `postgres`) you can `depends_on`.

Run them:

- `devenv up` — start all processes + services in the foreground.
- `devenv up -d` / `--detach` — background; stop with `devenv down`.
- `devenv up web worker` — start only named processes.
- `devenv up --strict-ports` — fail instead of auto-incrementing when a port is taken.

## Tasks

Tasks are one-shot, ordered, and cached — the right home for setup that would otherwise bloat `enterShell`, plus build/codegen/migration steps.

```nix
tasks = {
  "myapp:generate".exec = "buf generate";

  "myapp:build" = {
    exec = "npm run build";
    after = [ "myapp:generate" ];                 # ordering (or use `before`)
    execIfModified = [ "src/**/*.ts" "package.json" ];  # skip unless these changed
  };

  # run setup before the shell is ready:
  "devenv:enterShell".after = [ "myapp:build" ];
};
```

- `after` / `before` — dependency edges between task names (namespaced `ns:name`).
- `execIfModified` — glob list; the task is skipped when none of the files changed since last run. This is the caching mechanism — use it for expensive steps.
- `status` — a command; exit 0 means "already done", skip `exec`.
- Lifecycle hooks: depend on / be depended on by `devenv:enterShell` and `devenv:enterTest` to slot setup into activation and tests.

Run and inspect:

- `devenv tasks run myapp:build` — run a task and its dependencies.
- `devenv tasks run myapp:build --mode single` — just this task, skip deps.
- `devenv tasks list` — list tasks.

Why prefer tasks over `enterShell` for heavy work: `enterShell` runs on every activation (including every `cd` with auto-activation), is not cached, and runs serially. Tasks are cached via `execIfModified`, can run in parallel where the graph allows, and also execute under `devenv test`.

## Putting it together (Python + Postgres web app)

```nix
{ pkgs, config, ... }:
{
  env.DATABASE_URL = "postgresql://localhost:5432/myapp";

  languages.python = {
    enable = true;
    version = "3.12";
    uv.enable = true;
    uv.sync.enable = true;
  };

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_16;
    listen_addresses = "127.0.0.1";
    initialDatabases = [{ name = "myapp"; }];
  };

  processes.web.exec = "uvicorn app.main:app --reload --port 8000";

  tasks."myapp:migrate" = {
    exec = "alembic upgrade head";
    before = [ "devenv:enterShell" ];
  };

  git-hooks.hooks = { ruff.enable = true; ruff-format.enable = true; };

  enterTest = ''
    wait_for_port 5432
    python -c "import app"
  '';
}
```
