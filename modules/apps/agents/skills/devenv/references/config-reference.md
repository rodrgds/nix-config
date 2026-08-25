# Config reference: devenv.nix and devenv.yaml

Verified against devenv 2.1.x.

## Contents

- [The files and what they're for](#the-files)
- [devenv.nix anatomy](#devenvnix-anatomy)
- [Module arguments](#module-arguments)
- [Top-level options](#top-level-options)
- [Environment variables](#environment-variables)
- [Scripts](#scripts)
- [enterShell / enterTest](#entershell--entertest)
- [dotenv](#dotenv)
- [devenv.yaml: inputs, imports, settings](#devenvyaml)
- [Env vars devenv sets at runtime](#env-vars-devenv-sets)
- [Nix syntax pitfalls](#nix-syntax-pitfalls)

## The files

| File                                     | Commit?               | Purpose                                                |
| ---------------------------------------- | --------------------- | ------------------------------------------------------ |
| `devenv.nix`                             | yes                   | The environment. Only required file.                   |
| `devenv.yaml`                            | yes                   | Inputs (nixpkgs + extra flakes), imports, allow flags. |
| `devenv.lock`                            | yes                   | Auto-generated; pins every input to an exact revision. |
| `.envrc`                                 | yes (if using direnv) | direnv activation hook.                                |
| `devenv.local.nix` / `devenv.local.yaml` | **no**                | Per-developer overrides; gitignore.                    |
| `.devenv/`, `.direnv/`                   | **no**                | Build/state output; gitignored by `devenv init`.       |

`devenv init` writes the first three (+ `.gitignore`). Let it generate the scaffold rather than hand-writing — the template tracks the current API.

## devenv.nix anatomy

`devenv.nix` is a Nix function: it takes module arguments and returns an attribute set of options. The scaffold from `devenv init`:

```nix
{ pkgs, lib, config, inputs, ... }:

{
  env.GREET = "devenv";

  packages = [ pkgs.git ];

  # languages.rust.enable = true;
  # services.postgres.enable = true;
  # processes.dev.exec = "${lib.getExe pkgs.watchexec} -n -- ls -la";

  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  enterShell = ''
    hello
    git --version
  '';

  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # git-hooks.hooks.shellcheck.enable = true;
}
```

## Module arguments

The header `{ pkgs, lib, config, inputs, ... }:` destructures what devenv passes in. Use `...` to ignore the rest.

- `pkgs` — the package set from your `nixpkgs` input. `pkgs.git`, `pkgs.nodejs_22`, etc.
- `lib` — nixpkgs library helpers. Common: `lib.getExe pkg` (absolute path to a package's main binary), `lib.mkIf cond {…}`, `lib.mkDefault val`, `lib.optionals cond [ … ]`.
- `config` — the **resolved** config. Reference one option from another: `config.languages.python.package`, `config.env.DATABASE_URL`, `config.devenv.isTesting` (true during `devenv test`), `config.devenv.root`.
- `inputs` — the inputs declared in `devenv.yaml`, usable to pull packages from an alternate source. See [devenv.yaml](#devenvyaml).

## Top-level options

The frequently used ones (full surface: `https://devenv.sh/reference/options/`):

- `env.<NAME> = value;` — environment variables (see below).
- `packages = [ pkgs.foo pkgs.bar ];` — extra packages on PATH. Prefer `languages.*` for toolchains.
- `scripts.<name>.exec = ''…'';` — commands available in the shell (see below).
- `enterShell = ''…'';` — bash run on every activation. Keep it light.
- `enterTest = ''…'';` — bash run by `devenv test`.
- `languages.<lang>.enable = true;` — see [languages.md](languages.md).
- `services.<svc>.enable = true;` and `processes.<name>.exec` — see [services-processes.md](services-processes.md).
- `tasks."ns:name" = { … };` — ordered, cacheable build steps; see [services-processes.md](services-processes.md).
- `git-hooks.hooks.<name>.enable = true;` — pre-commit hooks (current name; **not** the older `pre-commit.hooks`). devenv 2.x bundles the `git-hooks` input, so no extra `devenv.yaml` entry is needed; older snapshots required declaring it.
- `dotenv.enable = true;` — load a `.env` file (see below).
- `containers.<name>.* ` — OCI image config; see [cli-operations.md](cli-operations.md).

## Environment variables

```nix
env.DATABASE_URL = "postgres://localhost:5432/myapp";
env.RUST_LOG = "debug";
```

Values are Nix expressions; interpolate with `${}`: `env.PROJECT_ROOT = config.devenv.root;`. To reference a store path, interpolate a package: `env.PYTHONPATH = "${pkgs.foo}/lib";`. Non-string values (ints, bools) are coerced — wrap in quotes if you need an exact string.

## Scripts

`scripts` become executables on PATH inside the shell — handy for project commands:

```nix
scripts = {
  migrate.exec = "alembic upgrade head";
  deploy = {
    exec = ''rsync -av ./dist/ user@host:/srv'';
    description = "Deploy the app";        # shown in `devenv info`
    packages = [ pkgs.rsync ];             # tools only this script needs
  };
};
```

A script can specify its interpreter: `scripts.report.package = pkgs.python3;` then `exec` is Python source.

## enterShell / enterTest

- `enterShell` runs on **every** activation, including auto-activation on `cd`. Keep it to quick echoes / lightweight checks. Push slow or ordered setup into `tasks` (cacheable, parallel, and they also run under `devenv test`) — hook them with `tasks."devenv:enterShell".after = [ "myproj:setup" ];`.
- `enterTest` is the body of `devenv test`. devenv provides a `wait_for_port <port> [timeout]` helper for waiting on services/processes. Gate test-only behavior with `config.devenv.isTesting`.

## dotenv

```nix
dotenv.enable = true;            # loads ./.env
dotenv.filename = ".env.development";   # or a custom file / list
```

`.env` values are set with `mkDefault`, so an explicit `env.FOO` in `devenv.nix` overrides them. The Nix store is world-readable — keep real secrets in `.env` (gitignored) or a secrets integration, not inlined into `env`.

## devenv.yaml

Declares inputs and global flags. The scaffold:

```yaml
# yaml-language-server: $schema=https://devenv.sh/devenv.schema.json
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
# allow_unfree: true
# allow_unsupported_system: false
# permitted_insecure_packages:
#   - "openssl-1.1.1w"
# imports:
#   - ./backend
```

Note the **snake_case** keys: `allow_unfree`, `allow_unsupported_system`, `permitted_insecure_packages` (older docs/memory may show `allowUnfree` — that's wrong for `devenv.yaml`).

**Extra inputs** — declare, then consume via the `inputs` module arg:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  nixpkgs-stable:
    url: github:NixOS/nixpkgs/nixos-24.11
  git-hooks:
    url: github:cachix/git-hooks.nix
```

```nix
{ inputs, pkgs, ... }:
let
  stable = import inputs.nixpkgs-stable { system = pkgs.stdenv.system; };
in {
  packages = [ stable.someTool ];
}
```

`devenv inputs add <name> <url>` edits this for you (with `--follows nixpkgs` to dedupe). **`follows`** points one input's transitive nixpkgs at your top-level one, avoiding duplicate downloads:

```yaml
inputs:
  some-flake:
    url: github:org/some-flake
    inputs:
      nixpkgs:
        follows: nixpkgs
```

`imports:` merges other devenv modules (local dirs or inputs) — useful for monorepos.

## Env vars devenv sets at runtime

Available inside the shell and to processes/services:

- `DEVENV_ROOT` — project root.
- `DEVENV_DOTFILE` — `$DEVENV_ROOT/.devenv` (build artifacts).
- `DEVENV_STATE` — `$DEVENV_DOTFILE/state`; where services persist data (db data dirs, etc.).
- `DEVENV_RUNTIME` — runtime sockets dir.
- `DEVENV_PROFILE` — Nix store path of the assembled profile.

Service config that only applies on first init (e.g. `initialDatabases`, `initialScript`) won't re-run unless you delete that service's dir under `$DEVENV_STATE`.

## Nix syntax pitfalls

`devenv.nix` must be valid Nix. The errors that bite most:

- **List items are space-separated, not comma-separated:** `[ pkgs.git pkgs.jq ]`, never `[pkgs.git, pkgs.jq]`.
- **Every attribute binding ends with `;`:** `env.FOO = "bar";`. Missing semicolons are the most common parse error.
- **Multi-line strings use `''…''`** (two single quotes). Escape `${` inside them as `''${` when you want a literal (e.g. shell variable expansion in `enterShell` is fine as `$VAR`, but `${...}` is Nix interpolation).
- **The file must start with the function header** `{ pkgs, ... }:` before the returned attrset.
- **`enable = true` is mandatory** to activate languages, services, and most package managers — setting only `version`/options does nothing.
- Use `lib.mkIf`/`lib.mkDefault`/`lib.mkForce` for conditional and priority-controlled values rather than ad-hoc `if` at the wrong level.

When a build fails, read the Nix evaluation error — it names the offending attribute path. `devenv info` is the fastest way to force evaluation.
