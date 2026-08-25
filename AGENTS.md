# AGENTS

Instructions for agents working in this repository. Rules that apply everywhere live in the shared global file (`modules/apps/agents/AGENTS.md`); this file covers what is specific to this repo.

## Source of truth

This repo is the single source of truth for my machines. Change it and rebuild rather than making ad-hoc machine changes. `~/.config/home` is the checkout on every machine; `rebuild` is the only supported way to apply changes:

```bash
rebuild --desktop   # NixOS, on rgo-desktop
rebuild --laptop    # nix-darwin, on rgo-laptop
rebuild --vps       # deploy-rs, from either machine
```

When you change a VPS-hosted repository, image name, unit name, domain, health endpoint, or build directory, update the project's workflow/AGENTS and the matching Nix module under `modules/hosting/` or `modules/services/`. All delivery runs through the deployment webhook and systemd units.

## Compatibility

The three machines are `rgo-desktop` (NixOS), `rgo-laptop` (macOS), `rgo-vps` (NixOS).

- Write OS-agnostic modules: one module works on NixOS and nix-darwin, with systemd/launchd and nixpkgs/Homebrew handled inside it. `modules/apps/ghostty/default.nix` is the model.
- Keep changes working on every host they apply to. Linux-only modules still exist in the shared tree, so gate platform-specific options; note why when a module is single-platform.
- The rebuild wizard (`tools/rebuild-wizard`) is the one interface for every machine. Extend it rather than adding per-machine build scripts.

## Secrets

`sops-nix` is the only secrets mechanism. Resolve secrets at runtime instead of embedding them in Nix strings or derivations: `config.sops.secrets.<name>.path` in Home Manager, `config.sops.placeholder.<name>` at system level.

macOS uses Home Manager `sops.secrets.<name>.path`; `sops.templates` and `config.sops.placeholder.*` are not available on Darwin in this setup.

Plaintext secrets never reach a commit; the wizard refuses to commit while `secrets/*_plain*` files exist. Preserve that check if you change the wizard.

## Validation

Before finishing work on modified Nix:

```bash
nixfmt <files>
statix check .
nix flake check --no-build --all-systems --impure
```

nixd formats on save with `nixfmt`. Write idiomatic Nix (prefer `inherit`) so nixd and statix stay quiet. The wizard runs `statix` and `nixfmt` itself.

## Architecture

- **Shared source of truth** - when several modules need the same data, keep it in one shared place and import it. `modules/shared/9router.nix` is the model: one 9Router combo catalog consumed by opencode and Pi. The rebuild wizard refreshes its `9router/combos.json` snapshot from the proxy before every rebuild.
- **Declarative wiring, self-updating tools** - machine wiring is declarative; upstream-managed tools stay mutable when Nix pinning would hurt reliability. Shared npm CLI ownership lives in `modules/apps/javascript-toolchain/default.nix`; harness modules contribute package needs and hook behavior there instead of owning their own prefix or timer.
- **Agent skills** - install upstream skills through the declarative mechanism in `modules/apps/agents/default.nix` rather than vendoring them. Project skills live in `modules/apps/agents/skills/` (symlinked to `~/.agents/skills/`).
- **Rebuild commits** - the wizard owns commit semantics (default `<target>: generation <n>` or `<target>: rebuild <date>`, plus OpenRouter or manual messages). Document changes there.
- **One-off tools** - the global file owns this rule. Repo-specific addition: when the nix-config repo itself needs a tool, use `devenv`.

## Pi configuration

Agents (global `AGENTS.md` + skills) are configured in `modules/apps/agents/default.nix`; Pi is configured in `modules/apps/pi/default.nix`. Change them there and rebuild.

Model preferences are configuration, not rules. The default provider/model and picker ordering live in the Pi module; change them where they are defined rather than restating them in a doc.
