# CLI and operations

Verified against devenv 2.1.2. Confirm locally with `devenv version` and `devenv <cmd> --help` — help text is the authoritative flag source.

## Command reference

| Command                                      | Purpose                                                                                                                                  |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `devenv init [TARGET]`                       | Scaffold `devenv.nix`, `devenv.yaml`, `.gitignore` (in `TARGET` dir or cwd).                                                             |
| `devenv shell [CMD …]`                       | Enter the environment as a subshell, or run one command in it (`devenv shell true` to just evaluate/build). Installs git hooks on entry. |
| `devenv up [PROCESSES…]`                     | Start services + processes in the foreground. `-d`/`--detach` for background; `--strict-ports` to fail on taken ports.                   |
| `devenv down`                                | Stop detached processes/services.                                                                                                        |
| `devenv processes up/down`                   | Lower-level process control.                                                                                                             |
| `devenv test`                                | Build env, start processes, run `enterTest`, tear down. The CI command. `--override-dotfile` isolates state in a temp dir.               |
| `devenv tasks run <ns:name>`                 | Run a task (+deps). `tasks list` to enumerate.                                                                                           |
| `devenv info`                                | Print resolved packages/env/scripts/processes — fast way to force full evaluation.                                                       |
| `devenv search <term>`                       | Search nixpkgs packages and devenv options.                                                                                              |
| `devenv update`                              | Re-resolve `devenv.lock` from `devenv.yaml` inputs (i.e. upgrade).                                                                       |
| `devenv inputs add <name> <url>`             | Add an input to `devenv.yaml` (`--follows nixpkgs` to dedupe nixpkgs).                                                                   |
| `devenv gc`                                  | Delete old shell generations to reclaim disk.                                                                                            |
| `devenv container build/run/copy <name>`     | Build/run/push an OCI image from the env.                                                                                                |
| `devenv build <attr>` / `devenv eval <attr>` | Build / JSON-evaluate an arbitrary attribute of `devenv.nix`.                                                                            |
| `devenv repl`                                | Interactive Nix REPL over the config — inspect option values.                                                                            |
| `devenv changelogs`                          | Show relevant changelogs.                                                                                                                |
| `devenv hook <shell>`                        | Print the shell hook for native auto-activation.                                                                                         |
| `devenv allow` / `devenv revoke`             | Allow/revoke auto-activation for the current directory.                                                                                  |
| `devenv direnvrc`                            | Print a direnvrc for direnv-based activation.                                                                                            |
| `devenv mcp`                                 | Run an MCP server exposing devenv to AI assistants.                                                                                      |
| `devenv lsp`                                 | Start the `nixd` language server for editing `devenv.nix`.                                                                               |
| `devenv generate`                            | AI-assisted generation of `devenv.{yaml,nix}`.                                                                                           |

Global flags worth knowing:

- `-O, --option <name>:<type> <value>` — override a config option ad hoc. Types: `string|int|float|bool|path|pkg|pkgs`. E.g. `devenv -O services.postgres.enable:bool true up`.
- `-o, --override-input <name> <uri>` — swap an input without editing `devenv.yaml` (e.g. point nixpkgs at a local checkout).
- `--from <path|flake-ref>` — run against a `devenv.nix` located elsewhere.

## Auto-activation

Two ways to make the environment load on `cd` into the project (and unload on leaving). Both require allowing the directory once.

**Native (devenv 2.x, no direnv needed)** — add the hook to your shell rc once, then allow per-project:

```bash
# in ~/.zshrc (or bashrc / fish / nu — see `devenv hook --help`)
eval "$(devenv hook zsh)"
```

```bash
cd my-project
devenv allow      # trust this directory; devenv revoke to undo
```

**direnv** — create `.envrc`:

```bash
eval "$(devenv direnvrc)"
use devenv
```

```bash
direnv allow      # re-run after every .envrc change
```

You can pass option overrides through direnv: `use devenv -O services.postgres.enable:bool true`. Commit `.envrc`; never commit `.direnv/`.

## CI / devenv test

`devenv test` is the single command for CI: it builds the environment, brings up processes/services, runs `enterTest`, and tears everything down. In `enterTest`, use the provided `wait_for_port <port> [timeout]` helper before hitting a service, and gate test-only logic with `config.devenv.isTesting`.

GitHub Actions sketch:

```yaml
- uses: cachix/install-nix-action@v30
- uses: cachix/cachix-action@v15
  with: { name: devenv }
- run: nix profile install nixpkgs#devenv
- run: devenv test
```

The Cachix step pulls prebuilt artifacts so CI doesn't recompile the world. `devenv processes wait --timeout <s>` is available if you orchestrate processes manually instead of via `enterTest`.

## Garbage collection

devenv keeps old generations (and they pin Nix store paths against `nix-collect-garbage`). Reclaim space with `devenv gc`. Run it periodically, not in hot paths.

## Editing support

- `devenv lsp` starts `nixd` configured for `devenv.nix` — gives completion and option docs in editors.
- `devenv mcp` exposes devenv over MCP for AI assistants.

## Troubleshooting playbook

Work from symptom to cause:

1. **"Does it even evaluate?"** Run `devenv info` (or `devenv shell true`). Most failures are Nix evaluation errors — the message names the offending attribute path (e.g. `error: attribute 'enabel' missing`). Fix syntax/option-name issues first.
2. **Unknown option / option does nothing.** Verify the name with `devenv search <option>` or the options reference. Common renames: `git-hooks.hooks.*` (not `pre-commit.hooks.*`); `devenv.yaml` uses `allow_unfree` (snake_case). Confirm `enable = true` is set — language/service options are inert without it.
3. **"unfree"/"broken"/"insecure" package refused.** Set `allow_unfree: true` (or `permitted_insecure_packages: [...]`) in `devenv.yaml`.
4. **Package or version not found.** `devenv search <name>` to find the real attribute. Pin via `package = pkgs.<attr>` when a `version` string won't resolve.
5. **A service "isn't running."** It only runs under `devenv up`. Check it's actually started; check the port (auto-incremented unless `--strict-ports`); for stale init (`initialDatabases`/`initialScript` ignored), delete `$DEVENV_STATE/<service>` and bring it up again.
6. **Auto-activation not triggering.** Native: confirm `devenv hook <shell>` is in your rc and you ran `devenv allow`. direnv: re-run `direnv allow` after editing `.envrc`.
7. **Stale environment after edits.** A fresh `devenv shell` rebuilds. If something is wedged, `devenv gc` then re-enter, or use `--clean` to ignore ambient env.
8. **Surprise version changes.** `devenv.lock` pins inputs; only `devenv update` changes them. If versions drifted, check whether `update` was run and whether `devenv.lock` is committed.
9. **Disk filling up.** `devenv gc` (devenv generations) and, separately, `nix-collect-garbage -d` for the wider store.

When the cause is still unclear, read the relevant doc page or changelog (see [official-sources.md](official-sources.md)) rather than guessing at option names.
