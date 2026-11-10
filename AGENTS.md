# AGENTS

Instructions for agents working in this repository. Rules that apply everywhere live in the shared global file (`modules/apps/agents/AGENTS.md`); this file covers what is specific to this repo.

## Source of truth

This repo is the single source of truth for my machines. Change it and rebuild rather than making ad-hoc machine changes. `~/.config/home` is the checkout on every machine; `rebuild` is the only supported way to apply changes:

```bash
rebuild             # this machine (rgo-desktop or rgo-laptop)
rebuild update      # update flake inputs, then rebuild this machine
rebuild vps         # deploy-rs to rgo-vps, from either machine
rebuild secrets     # edit secrets/secrets.yaml with sops
```

When you change a VPS-hosted repository, image name, unit name, domain, health endpoint, or build directory, update the project's workflow/AGENTS and the matching Nix module under `modules/hosting/` or `modules/services/`. All delivery runs through the deployment webhook and systemd units. For locally built Montra images, use `sudo montra-deploy-local REVISION COMPONENTS_JSON`; the map contains reviewed `sha256:` image IDs. This shares registry deployment locks, migrations, health checks, and rollback.

## Compatibility

The three machines are `rgo-desktop` (NixOS), `rgo-laptop` (macOS), `rgo-vps` (NixOS).

- Write OS-agnostic modules: one module works on NixOS and nix-darwin, with systemd/launchd and nixpkgs/Homebrew handled inside it. `modules/apps/ghostty/default.nix` is the model.
- Keep changes working on every host they apply to. Linux-only modules still exist in the shared tree, so gate platform-specific options; note why when a module is single-platform.
- The rebuild wizard (`tools/rebuild-wizard`) is the one interface for every machine. Extend it rather than adding per-machine build scripts.
- `rgo-nas` runs Synology DSM, outside these Nix host configurations. Its owned backup receiver and Montra Compose definitions do not cover the whole NAS. Apply DSM changes through a reviewed procedure and verify effective DSM ACLs, not Unix modes alone.

## Secrets

`sops-nix` is the only secrets mechanism. Resolve secrets at runtime instead of embedding them in Nix strings or derivations: `config.sops.secrets.<name>.path` in Home Manager, `config.sops.placeholder.<name>` at system level.

macOS uses Home Manager `sops.secrets.<name>.path`; `sops.templates` and `config.sops.placeholder.*` are not available on Darwin in this setup.

Declare each secret in its narrowest consuming module under the same enable condition. `secrets/default.nix` owns only the SOPS backend, default file, and age key. Dormant modules keep encrypted values without creating runtime secret files.

Plaintext secrets never reach a commit or the Nix store. The wizard blocks rebuilds and its lock commit while `secrets/**/*_plain*` paths exist, including extensionless files. Preserve both checks even though the wizard builds the Git flake (`.`), which excludes ignored files: a `.gitignore` mistake must not leak plaintext.

## Validation

Before finishing work on modified Nix:

```bash
nixfmt <files>
statix check .
nix flake check --no-build --all-systems --impure
```

nixd formats on save with `nixfmt`. Write idiomatic Nix (prefer `inherit`) so nixd and statix stay quiet.

## Architecture

- **Shared source of truth** - when several modules need the same data, keep it in one shared place and import it. `rebuild update` refreshes the OpenCode 9Router combo catalog in `modules/shared/9router/combos.json` from the proxy.
- **Declarative wiring, self-updating tools** - machine wiring is declarative; upstream-managed tools stay mutable when Nix pinning would hurt reliability or freshness. Shared npm CLI ownership lives in `modules/apps/javascript-toolchain/default.nix`; harness modules contribute package needs and hook behavior there instead of owning their own prefix or timer. Fast-moving GUI apps use vendor updaters: Homebrew casks marked `auto_updates` on macOS, and on Linux a verified first-install bootstrap of the vendor build (T3 Code's AppImage in `modules/apps/t3-code`). Do not move these back into the Nix closure.
- **Rebuild speed** - every package should come from a binary cache. Avoid `overrideAttrs` on common packages, flake inputs that compile apps from source, and import-from-derivation; prefer `pkgs.unstable.<name>` for fresher builds. Remove a substituter once nothing uses it, since each one adds lookups. Rebuilds evaluate purely; do not reintroduce `--impure`. Each generation pins its flake inputs at `/etc/nix/flake-inputs`, so GC never forces a rebuild to download nixpkgs again. On Darwin, an empty `/etc/nix/machines` stops activation from restarting the Nix daemon.
- **Web apps** - `apps.brave.webApps` (name to URL, set in `modules/profiles`) force-installs sites as Brave PWAs through managed policy on both platforms.
- **Role profiles first** - shared workstation defaults belong in `modules/profiles/default.nix`. Host files should mostly pick profiles, keep true host-specific apps explicit, and keep explicit `false` toggles for dormant modules the user may re-enable.
- **Agent skills** - declare upstream sources in `modules/apps/agents/_skill-sources.nix`. The skills CLI installs and updates them in `~/.agents/skills/`. Activation only installs missing declared skills and removes retired ones, so unchanged rebuilds stay offline; the background npm updater (started by `rebuild update` and daily) runs `skills update`. Keep them out of Git and do not patch them locally. Repo-owned skills live in `modules/apps/agents/skills/` and are linked individually into the shared directory. Add local instructions there or in project `AGENTS.md` files.
- **Rebuild flow** - `rebuild` builds without root and activates only when the build differs from the running system or its last activation failed; Darwin activation is `nix-env --set` plus `activate`, as darwin-rebuild does. `rebuild update` offers to commit only `flake.lock` and the 9Router catalog as `flake: update inputs <date>`; other commits are made by hand or by agents.
- **VPS backups** - `modules/shared/nas-backup/` owns NAS transport. Keep its restricted receiver, SOPS identity, existing timers and restore checks compatible. Install receiver changes before `rebuild --vps`; see its README for provisioning and one-run verification.
- **Database major upgrades** - preserve a complete protected cold copy before migration. A binary-only rollback can corrupt compatibility, so prevent automatic old-image rollback during the migration window and restore normal rollback settings after acceptance. Restore the matching data before starting an older major version.
- **Restore isolation** - a NAS writer can replace both an archive and its checksum. Treat downloads and SQL as untrusted, bound host-side staging/parsing, and keep PostgreSQL restore clients and servers outside production containers, volumes, credentials and networks.
- **PostgreSQL authority** - keep cluster-admin credentials inside PostgreSQL initialization. Application logins must not have superuser, role/database creation, replication or RLS-bypass privileges. Privileged maintenance must select `pg_catalog, pg_temp` before querying catalogs, regardless of database-owned defaults. Preserve application ownership and migration compatibility through the reviewed role helpers.
- **Registry authentication** - require registry login for image preparation, not the lifetime of cached application/database processes. Restarting even an inactive oneshot propagates stops to units with `Requires`; a credential refresh must not restart unrelated services.
- **OCI startup readiness** - use `podman.sdnotify = "healthy"` when activation must wait for application/database readiness. Startup probes can legitimately fail while booting; declaring the unit ready early exposes their transient failures to NixOS activation and can trigger rollback. Preserve startup migration grace and test the real systemd readiness boundary.
- **Nix daemon trust** - workstations grant daemon administration only to root. Approve needed signed caches in `modules/core/nix/default.nix`; do not restore user trust or disable signatures to fix cache compatibility. VPS deployment trust is a separate boundary.
- **Blender MCP** - upgrade the server and bundled add-on together in `modules/apps/blender/default.nix`. After activation, enable `blender_mcp` in Blender and verify scene inspection and viewport capture before claiming a working connection.
- **One-off tools** - the global file owns this rule. This repo has no Devenv environment; use `nix run`, `nix shell`, or a temporary package for repo tooling.

## Claude Code

The Claude module uses the shared npm updater, agent instructions, and skills. Activation merges Executor into `~/.claude.json`, which also holds account and project state; preserve every unrelated key. Keep Claude-only skill directories and mutable settings intact. Run `python3 modules/apps/claude/test_configure.py` after changing activation.

## Darwin desktop runtime

- Caps Lock is Super on `rgo-laptop`: hold sends Command+Control+Option, tap sends Escape. Keep both the Super bindings and the user's direct Option aliases. Leave Option+Arrow to apps and text editors.
- AeroSpace uses the pinned omacosy split-hint helper for dwindle-like placement. `automaticSplitHints = false` enables a reversible native-tiling comparison. Keep both normalization options off while preserving split trees. Floating exceptions precede app assignments and continue callback processing.
- The laptop uses the native menu bar and KeepingYouAwake, whose startup is owned by Home Manager launchd. SketchyBar remains an opt-in renderer; keep its workspace and metric state in shared observers.
- Laptop activation installs and removes declared Homebrew packages only; it never runs `brew update` or upgrades. The `pt.rgo.homebrew-upgrade` launchd agent upgrades non-self-updating packages daily. Screenshot and OCR shortcuts target Macshot through its URL scheme.
- Macshot screenshot and OCR bindings use `macshot-launch`, which waits for AppKit launch completion before sending the URL. Direct URL cold launches can wedge 4.2.1; login-only prewarming does not cover later app exits. Run `modules/apps/screenshot-tools/test-launch.sh` on macOS when changing this ordering.
- Automatic cache pressure cleanup preserves recent files and records failed attempts for its cooldown. Keep its rescue threshold separate from rebuild preflight space requirements. Test changes in temporary fixtures, never against real caches.
- Routine user-cache cleanup uses explicit disposable-cache paths and writer guards, never a sweep of `.cache`. Prune file by file only where files are independent entries (npm, Turbo); package stores (Bun) lose whole entries or nothing. Caches that bound themselves (Go, Playwright, uv, Nix) stay unmanaged. Agent scratch, worktrees and session history are only reported in the log, never deleted. Run it as the user; Darwin logs live in `~/Library/Logs/rgo-cache-cleanup`, separate from legacy root-owned logs.
- `darwin.apps.lightweight-borders` builds the pinned omacosy single-layer ring with Apple's Swift compiler. Update the source pin and both helper build IDs together when adopting upstream helper changes.
- macOS 26 protects the default browser choice from command-line writes. Keep browser activation idempotent and nonfatal, verify the result, and make a changed choice in System Settings under Desktop & Dock.
- Every successful local laptop rebuild runs `rgo-laptop-health`. Extend that check when a required desktop service, security setting, or launchd label changes.
