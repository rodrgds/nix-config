# Global Agent Context

## Managed machines

This flake is the source of truth for Rodrigo's machines:

- `rgo-desktop`: x86_64 NixOS workstation with Hyprland, Quickshell, gaming, media, and local development tools.
- `rgo-laptop`: aarch64 macOS laptop managed by nix-darwin, Home Manager, Homebrew, Aerospace, SketchyBar, and JankyBorders.
- `rgo-vps`: x86_64 NixOS server for Caddy, Tailscale, Podman services, authenticated deployment hooks, and hosted apps.

Prefer changing this repo and rebuilding over making ad-hoc machine changes. Local rebuilds use `rebuild --desktop` or `rebuild --laptop`; VPS changes use `rebuild --vps` unless a direct fallback command is explicitly needed.

## Pi coding agent setup

Pi is configured declaratively in this repo through `modules/apps/pi/default.nix` and enabled per host with `apps.pi.enable = true`.

Nix/Home Manager owns Pi's static configuration:

- Pi CLI bootstrap/update wrapper: `modules/apps/pi/default.nix`
- Generated global settings: `~/.pi/agent/settings.json`
- Generated global models: `~/.pi/agent/models.json`
- Generated keybindings: `~/.pi/agent/keybindings.json`
- Generated Flexoki theme: `~/.pi/agent/themes/flexoki.json`
- Local Pi extension/prompt directories: `modules/apps/pi/resources/`
- LiteLLM model catalog shared with OpenCode: `modules/shared/litellm.nix`

Do not persist Pi configuration by editing generated files or by relying on `pi install`, `pi remove`, `pi config`, or `/settings`. Change the Nix module, model catalog, theme, resources, or host options, then rebuild.

Pi's mutable runtime state stays writable under `~/.pi/agent`: auth, trust decisions, sessions, package caches, logs, and provider token refreshes. OAuth/subscription auth should still be done interactively with `/login`.

Pi uses the LiteLLM provider by default. The provider endpoint and model aliases come from the Pi module plus `modules/shared/litellm.nix`; the LiteLLM master key is resolved at request time from the `sops-nix` secret and must not be copied into Nix strings.

Pi also discovers global skills from `~/.agents/skills` when they are installed manually or by another agent harness.

## One-off tools

When a task needs a one-off program that is not installed, use Nix instead of permanently adding packages just to complete the task.

Preferred quick paths:

```bash
, jq --version
, ripgrep --version
, imagemagick --version
nix shell nixpkgs#jq -c jq --version
nix run nixpkgs#nixpkgs-fmt -- --help
```

Use `, <command>` from comma/nix-index when you know the executable name. Use `nix shell nixpkgs#<package> -c <command> ...` or `nix run nixpkgs#<package> -- ...` when you know the package name or need a pinned package invocation.

Only add a package to the repo when it should be part of the machine's lasting environment, a service, a build, or a repeated workflow.
