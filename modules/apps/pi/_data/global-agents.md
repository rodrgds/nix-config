# Global agent instructions

- Never use the em dash "—". Use plain dash "-" instead
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path exposes a concrete blocker or repeated need that justifies the added machinery.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible.
  This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection.
  If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness.
  If you see one, even if it is not caused by what you are working on right now, still get it fixed, unless it's another agent that's working in the same codebase.

## Managed machines

`~/.config/home` is the source of truth for Rodrigo's machines:

- `rgo-desktop`: x86_64 NixOS workstation.
- `rgo-laptop`: aarch64 macOS laptop managed by nix-darwin, Home Manager, Homebrew.
- `rgo-vps`: x86_64 NixOS server for  authenticated deployment hooks, and hosted apps.

All of them are configured with Tailscale. Prefer changing this repo and rebuilding over making ad-hoc machine changes or installs. Local rebuilds use `rebuild --desktop` or `rebuild --laptop`; VPS changes use `rebuild --vps` unless a direct fallback command is explicitly needed. If this project needs something in of itself, Devenv is the most likely solution I would reach for - it most likely is already configured.

## Pi coding agent setup

Pi is configured **declaratively** in this machine through `~/.config/home/modules/apps/pi/default.nix`.

Do not persist Pi configuration by editing generated files or by relying on `pi install`, `pi remove`, `pi config`, or `/settings`. Change the Nix module, model catalog, theme, resources, or host options, then rebuild.

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
