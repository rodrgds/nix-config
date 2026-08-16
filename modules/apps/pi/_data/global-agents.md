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
- Commit in logical chunks grouped by concern. Name your commits based on WHY the change was made, not WHAT changed.
- Keep project `AGENTS.md` files current when the work changes conventions/architecture/workflows future agents need to know.
- Prefer established, maintained libraries over bespoke implementations when they fit.
- Use Worktrunk (`wt`) and it's skill as the canonical worktree manager. Don't use raw `git worktree`.

## Managed machines

`~/.config/home` is the source of truth for Rodrigo's machines. It identifies the machines and their platforms; compatibility expectations and repo-specific rules live in that repo's `AGENTS.md`.

All machines are configured with Tailscale. Prefer changing this repo and rebuilding over making ad-hoc machine changes or installs. The repo's `rebuild` command is the single rebuild interface; see its `AGENTS.md` for targets. If a project needs something in and of itself, Devenv is the most likely solution - it is most likely already configured.

## Pi coding agent setup

Pi is configured **declaratively** in this machine through `~/.config/home/modules/apps/pi/default.nix`.

Do not persist Pi configuration by editing generated files or by relying on `pi install`, `pi remove`, `pi config`, or `/settings`. Change the Nix module, model catalog, theme, resources, or host options, then rebuild.

Global Agent Skills are configured declaratively in `modules/apps/agent-skills/default.nix`; the `skills` CLI reconciles approved skills into `~/.agents/skills`, which Pi discovers automatically. Add upstream skills through that module rather than vendoring them.

## Autonomous coding loops

For long autonomous multi-iteration coding work, use `/goal <objective>` when the user explicitly asks for it. Goal runs are session-scoped through the `@narumitw/pi-goal` extension and do not create separate worktrees.

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

## Writing rules

1. Never use a metaphor, simile, or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word, or a jargon word if you can think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.
