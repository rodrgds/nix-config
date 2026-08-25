---
name: devenv
description: Author, review, and operate devenv.sh developer environments (devenv.nix / devenv.yaml / devenv.lock) backed by Nix. Use whenever the user works with devenv — creating or editing devenv.nix, enabling languages/services/processes/scripts/tasks/git-hooks, wiring auto-activation (devenv hook / direnv), running devenv shell / up / test / tasks / update / gc, setting up a new project from scratch, or debugging a devenv build or activation failure. Trigger this even when the user says "dev environment", "reproducible shell", or names a devenv file without saying "devenv" explicitly.
---

# devenv

Use current official devenv sources, not stale model memory. devenv moves quickly and several option names differ from what older training data suggests.

This skill snapshot is written against **devenv `2.1.x`** (verified on `2.1.2`), current on 2026-06-12.

Verify the local version before relying on version-specific behavior: `devenv version`. If the repo or CI pins a different version, prefer that version's docs.

## What devenv is (orientation)

devenv is a Nix-backed tool for declaring a project's whole dev environment in **`devenv.nix`** — packages, env vars, language toolchains, background services (databases, etc.), long-running processes, scripts, ordered tasks, git hooks, and tests. **`devenv.yaml`** declares inputs (the nixpkgs source and any extra flakes). **`devenv.lock`** pins every input to an exact revision. All three are committed. It exposes a simplified module system over Nix — you do not need flakes knowledge, but `devenv.nix` *is* a Nix file and must be valid Nix.

## Start here

1. **Confirm the version and what already exists.** Run `devenv version`. Look for `devenv.nix`, `devenv.yaml`, `devenv.lock`, `.envrc`. Read them before editing — match the existing structure and input pinning.
2. **Prefer `languages.*` and `services.*` modules over raw `packages`.** Dropping `pkgs.python312` into `packages` skips the integration (env vars, venv wiring, PATH ordering) that the language module sets up. Reach for `packages` only for plain CLI tools.
3. **Verify option names against the live reference, don't guess.** The options surface is large and renames happen (e.g. the git-hooks option is `git-hooks.hooks.*`, not the older `pre-commit.hooks.*`; `devenv.yaml` uses snake_case `allow_unfree`, not `allowUnfree`). When unsure, search: `devenv search <term>` or the options reference (see [references/official-sources.md](references/official-sources.md)).
4. **After editing, prove it evaluates.** A config that looks right but doesn't build is worse than none. Run `devenv info` (fast, evaluates the whole config) or `devenv shell true`, and read the Nix error if it fails.

## Classify the task first

Sort the request into one or more buckets, then load only the matching reference:

- **Config authoring/editing** — `devenv.nix` structure, `env`, `packages`, `scripts`, `enterShell`/`enterTest`, `dotenv`, `devenv.yaml` inputs/imports/`follows`, module args (`pkgs`/`lib`/`config`/`inputs`), Nix syntax pitfalls → [references/config-reference.md](references/config-reference.md)
- **Language toolchains** — enabling Python/JS/Rust/Go/etc., venv/uv/poetry, package-manager auto-install, native libraries, pinning versions → [references/languages.md](references/languages.md)
- **Services, processes, and tasks** — databases and other `services.*`, long-running `processes.*`, process-compose dependencies/health checks, ordered/cached `tasks` → [references/services-processes.md](references/services-processes.md)
- **Operating the environment** — the CLI (`init`/`shell`/`up`/`test`/`tasks`/`update`/`gc`/`container`/`mcp`/`lsp`), auto-activation via `devenv hook` or direnv, CI, and troubleshooting build/activation failures → [references/cli-operations.md](references/cli-operations.md)
- **Finding the authoritative answer** — exact doc URLs, how to search options/packages live, changelogs → [references/official-sources.md](references/official-sources.md)

## Setting up a project from scratch (common path)

1. `devenv init` scaffolds `devenv.nix`, `devenv.yaml`, and appends to `.gitignore`. Run it in the project root (a git repo). Don't hand-write the scaffold — let `init` produce the current template, then edit.
2. Enable the language module(s) the project needs and turn on the package manager's auto-install so dependencies install on activation (see [references/languages.md](references/languages.md)).
3. Add any `services.*` the app talks to (Postgres, Redis, …). Remember services only run under `devenv up` — enabling one does not start it (see [references/services-processes.md](references/services-processes.md)).
4. Wire auto-activation so the environment loads on `cd`: native `devenv hook` + `devenv allow`, or direnv. See [references/cli-operations.md](references/cli-operations.md).
5. Commit `devenv.nix`, `devenv.yaml`, `devenv.lock`, and `.envrc` (if used). Never commit `.devenv/`, `.direnv/`, or `devenv.local.nix` — `init` gitignores these.
6. Verify: `devenv info`, then `devenv shell` and run the project's smoke command.

## Review heuristics

When reviewing or fixing a devenv config, check whether:

- Toolchains use `languages.*` modules rather than being smuggled in through `packages`.
- Each `services.*` / `languages.*` / package-manager block that should be active actually has `enable = true` — most default to off, and version/option keys do nothing without it.
- The config still **evaluates** (`devenv info`) — verify, don't assume.
- `devenv.lock` is committed and `devenv update` is run only intentionally (it bumps pinned versions; running it casually causes surprise upgrades).
- Heavy setup lives in `tasks` (cacheable via `execIfModified`, ordered, also run for `devenv test`) rather than bloating `enterShell`, which should stay fast because it runs on every activation.
- `processes`/`services` aren't assumed to be running just because they're declared — they require `devenv up`.
- Secrets aren't being placed where they land in the world-readable Nix store (prefer `dotenv` / a secrets integration over inlining into `env`).
- Git-hooks use the current `git-hooks.hooks.*` option, not the deprecated `pre-commit.hooks.*`.

## Reference map

- [references/config-reference.md](references/config-reference.md) — `devenv.nix` anatomy, `devenv.yaml` inputs/imports/follows, env vars devenv sets, files to commit vs ignore, Nix syntax pitfalls.
- [references/languages.md](references/languages.md) — language modules, venv/uv/poetry, JS package managers, Rust channels, version pinning, native libraries.
- [references/services-processes.md](references/services-processes.md) — `services.*` (Postgres et al.), `processes.*`, process-compose dependencies/health, `tasks` ordering and caching.
- [references/cli-operations.md](references/cli-operations.md) — full CLI reference, auto-activation, CI/`devenv test`, garbage collection, `mcp`/`lsp`, and a troubleshooting playbook.
- [references/official-sources.md](references/official-sources.md) — canonical doc URLs and live-search commands; read this whenever an option name or behavior is uncertain.
