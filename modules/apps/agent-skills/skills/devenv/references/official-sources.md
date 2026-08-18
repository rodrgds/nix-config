# Official sources

Read these when an option name, default, or behavior is uncertain. devenv's option surface is large and changes between releases — prefer the live source over memory.

## Canonical docs

- Home / overview — `https://devenv.sh/`
- Getting started — `https://devenv.sh/getting-started/`
- Basics (`devenv.nix`, env, scripts, enterShell) — `https://devenv.sh/basics/`
- **Options reference (authoritative, exhaustive)** — `https://devenv.sh/reference/options/`
- CLI reference — `https://devenv.sh/reference/command-line-interface/`
- Languages index — `https://devenv.sh/languages/` (per language: `https://devenv.sh/languages/<lang>/`)
- Services index — `https://devenv.sh/services/`
- Processes — `https://devenv.sh/processes/`
- Scripts — `https://devenv.sh/scripts/`
- Tasks — `https://devenv.sh/tasks/`
- Tests — `https://devenv.sh/tests/`
- Git hooks — `https://devenv.sh/git-hooks/`
- Containers — `https://devenv.sh/containers/`
- Inputs (`devenv.yaml`) — `https://devenv.sh/inputs/`
- Files & variables — `https://devenv.sh/files-and-variables/`
- direnv integration — `https://devenv.sh/integrations/direnv/`
- dotenv integration — `https://devenv.sh/integrations/dotenv/`
- Garbage collection — `https://devenv.sh/garbage-collection/`
- Source repo — `https://github.com/cachix/devenv`

## Live introspection (prefer over fetching docs when devenv is installed)

- `devenv search <term>` — search nixpkgs packages **and** devenv options. Best first move for "does this option/package exist and what's it called?"
- `devenv info` — resolved config (packages, env, scripts, processes); forces evaluation so it doubles as a syntax check.
- `devenv eval <attr>` — print any attribute's resolved value as JSON.
- `devenv repl` — interactive REPL over the config for deep inspection.
- `devenv <cmd> --help` — authoritative, version-matched flags for each subcommand.
- `devenv changelogs` — changelog entries relevant to your version (catches renames/deprecations).

## When memory and docs disagree

Trust, in order: the installed CLI's `--help` and `devenv search` → the docs at the version you're on → general docs → model memory (lowest). Known stale-memory traps: `pre-commit.hooks.*` (now `git-hooks.hooks.*`), `allowUnfree` (in `devenv.yaml` it's `allow_unfree`), and assuming services start without `devenv up`.
