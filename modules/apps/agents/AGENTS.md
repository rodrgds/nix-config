# Global agent instructions

## Core

- Favor simple, robust designs that remain correct and maintainable as the system grows. Implementation effort comes second.
- Take the simplest direct path for one-off or infrequent operations. Add wrappers, policy layers, custom checks, or automation only when a concrete blocker or repeated need warrants them.
- Prefer a maintained library to custom code when it fits.
- Keep changes focused on the task. Do not refactor, reformat, or comment unrelated code. Fix an unrelated defect only when it is obvious, safe, verified, and not owned by another agent, then commit it separately.
- During visual tests, inspect the UI for defects. Treat visible problems, lint failures, test failures, and flaky tests as bugs. Fix them when safe and not owned by another agent.
- Group commits by concern. Name each commit for why the change exists, not which files changed.
- Update the project's `AGENTS.md` when a change introduces a convention, architectural boundary, constraint, or workflow that future agents must follow.
- Use `$writing-for-agents` when editing agent instructions. Remove no-ops and duplication, put narrow rules in the narrowest useful scope, and give each step a checkable completion condition.

## Testing and bug fixes

- Reproduce a bug through the closest practical user-facing interface. Add the smallest stable regression test for the same behavior. Confirm that it fails because of the bug, apply the fix, and confirm that it passes.
- Test observable behavior through stable public interfaces. Derive expected results independently from the implementation. The test must fail on a plausible regression, not assert implementation details, mock internal collaborators, or repeat the production logic.
- Executing changed code or increasing coverage does not make a test useful. Delete tautological tests.

## Engineering

- Name recurring or meaningful values with constants or enums. Keep obvious one-off values inline. Use named constants supplied by protocols and specifications when available.
- Keep control flow shallow. Prefer early returns, guards, and `continue` over deeply nested branches.
- Replace ambiguous boolean parameters with an enum, options object, or separate operation. Calls such as `foo(true, false)` hide their meaning.
- Keep fields and functions private unless callers need access. Treat wider visibility as an API and design change.
- Put raw I/O, parsing, sockets, storage, and hardware access behind dedicated adapters or drivers. Higher-level code should use domain concepts instead of reaching through those boundaries.
- Respect architectural boundaries. If a boundary is wrong, redesign it instead of bypassing its service or abstraction.
- Comments should explain intent, constraints, trade-offs, or other facts the code cannot express. Do not narrate readable code. Use a short example or ASCII diagram when it clarifies a complex protocol, state machine, or data flow.

## Delegation

- Use Worktrunk (`wt`) for all worktree operations. Do not use raw `git worktree` or another worktree manager.
- Give each parallel editing agent its own branch and Worktrunk-managed worktree. Tell the agent its absolute worktree path and require all edits to stay there.
- Create agent worktrees with `wt switch --create <branch> --no-cd`. Use `wt list`, `wt merge`, and `wt remove` to inspect, integrate, and remove them.

## Managed machines

`~/.config/home` is the source of truth for Rodrigo's machines. Its `AGENTS.md` defines compatibility and repo-specific rules.

All machines use Tailscale. Make lasting machine changes in `~/.config/home`, then run the repo's `rebuild` command. Its `AGENTS.md` lists the rebuild targets.

Use a project's Devenv environment for project dependencies when available.

## Agent harness setup

Configure Pi, Codex, Claude, and OpenCode through `modules/apps/<harness>/default.nix`.

Persist harness configuration in its Nix module, model catalog, theme, resources, or host options, then rebuild. Edits to generated files and imperative commands such as `pi install`, `pi remove`, `pi config`, or `/settings` are temporary and unsupported.

Global instructions live in `modules/apps/agents/AGENTS.md`. `modules/apps/agents/default.nix` deploys them to `~/.pi/agent/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, and `~/.config/opencode/AGENTS.md`.

Configure global Agent Skills in `modules/apps/agents/default.nix`. The `skills` CLI installs the approved set in `~/.agents/skills`, which links to `modules/apps/agents/skills` for discovery by every harness. Add upstream skills through the module instead of vendoring them.

## Project operating stack

- Use Vikunja through Executor for private active work. Create and update internal tasks there, not in private GitHub Issues, `.scratch` files, or repo-local task boards. Keep public reports and contributor discussions in GitHub Issues and pull requests.
- Use Hindsight bank `rodrigo` for durable cross-agent context, decisions, preferences, constraints, and project history. Recall relevant memory before substantial work. Retain only verified durable facts tagged `project:<slug>` and `source:<agent>`. Never retain secrets, raw logs, temporary task state, completed-work reports, or unverified assistant claims.
- Repositories own code, tests, build commands, public docs, and engineering contracts that must travel with the code. Keep project `AGENTS.md` files small and current.
- Google Calendar is authoritative for events.

## One-off tools

Use Nix when a task needs an uninstalled program. Do not install a program permanently for one job.

```bash
# Executable name known, package unknown
, ffmpeg -version

# Package known, temporarily expose its commands
nix shell nixpkgs#shellcheck -c shellcheck scripts/release.sh

# Run a one-off CLI directly
nix run nixpkgs#hyperfine -- 'rg TODO .' 'grep -R TODO .'
```

Use `, <command>` from comma/nix-index when you know the executable name but not the package. Use `nix shell nixpkgs#<package> -c <command> ...` for commands from a known package. Use `nix run nixpkgs#<package> -- ...` to invoke a package's CLI directly.

Add a package to the repo only when a machine, service, build, or repeated workflow needs it.

## Writing

- Never use em dashes. Separate clauses with commas or periods.
- Use the fewest words that preserve the meaning. Put the answer or action first. Cut filler.
- Skip flattery, praise, and default superlatives. State disagreement, risk, uncertainty, and bad ideas plainly.
- Prefer short words, active voice, and direct sentences. Use technical terms when they are more precise than everyday words.
- Avoid clichés, stock metaphors, corporate prose, and marketing language unless the task requires them.
- Break a writing rule when following it would make the result less clear, accurate, or natural.
