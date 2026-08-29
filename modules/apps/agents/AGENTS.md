# Global agent instructions

## Core

* Optimize technical decisions for correctness, simplicity, robustness, long-term maintainability, and scalability. Treat implementation effort as secondary; do not trade lasting design quality for short-term speed.
* For one-off or infrequent operational work, take the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation until a concrete blocker or repeated need justifies them.
* Prefer established, maintained libraries over bespoke implementations when they fit.
* Do not refactor, reformat, comment, or otherwise churn unrelated code. Small unrelated defects found during the work may be fixed when they are obvious, safe, verified, and not in another agent's area; keep them in a separate commit.
* When visually testing a product, inspect the UI critically. Treat obvious UI defects, lint failures, test failures, and flakiness as real defects rather than noise. Fix them when safe and not being handled by another agent.
* Commit in logical chunks grouped by concern. Name commits for the reason or intent behind the change, not the files or mechanics changed.
* Keep project `AGENTS.md` files current when work changes conventions, architecture, constraints, or workflows future agents need to know.
* When creating or editing agent-facing instructions, use `$writing-for-agents`. Delete no-ops and duplication, keep narrow guidance at the narrowest useful scope, and state concrete completion criteria.

## Testing and bug fixes

* When fixing a bug, first reproduce it at the closest practical end-user boundary. Then add the smallest stable regression test that proves the same behavior, observe it fail for the expected reason, implement the fix, and observe it pass.
* Write tests that prove observable behavior through stable public interfaces and would fail on a plausible regression; expected results must come from an independent source of truth, and tests must not assert implementation details, mock internal collaborators, or merely restate the implementation.
* A test is not useful merely because it executes changed code or increases coverage.
* Tautological tests are considered harmful.

## Engineering

* Replace recurring or meaningful magic values with descriptive constants or enums. Keep obvious one-off values inline. Values defined by a protocol or specification should use named constants when available.
* Keep control flow shallow. Prefer early returns, guards, and `continue` over deeply nested branches.
* Avoid ambiguous boolean parameters. When `foo(true, false)` would hide meaning at the call site, use an enum, options object, or separate operation instead.
* Keep fields and functions as private as the design permits. Treat widening visibility as an API and design change; only do it when external access is actually required.
* Keep each abstraction level coherent. Encapsulate low-level mechanics such as raw I/O, parsing, sockets, storage details, or hardware access behind dedicated adapters or drivers. Higher-level code should work with domain concepts rather than reach through those boundaries.
* Respect existing architectural boundaries. Do not bypass intermediate services or abstractions for convenience. If the current boundaries are wrong, change the architecture deliberately rather than punching through it.
* Comments should explain non-obvious intent, constraints, trade-offs, or why the code exists. Do not narrate what readable code already says. Use a short example or ASCII diagram when it materially clarifies a complex protocol, state machine, data flow, or system.

## Delegation

* Use Paseo as the single system for agent delegation and worktree isolation.
* Use Paseo subagents for independent research, review, or implementation.
* When parallel agents may edit independently, give each a Paseo worktree-isolated workspace.
* Do not create agent worktrees with raw `git worktree` or another subagent system.

## Managed machines

`~/.config/home` is the source of truth for Rodrigo's machines and platforms. Compatibility expectations and repo-specific rules belong in that repo's `AGENTS.md`.

All machines use Tailscale. Prefer declarative changes to `~/.config/home` followed by the repo's `rebuild` command over persistent ad-hoc machine changes or installs. See that repo's `AGENTS.md` for rebuild targets.

When a dependency belongs to a project rather than the machine, use the project's Devenv environment when available.

## Agent harness setup

All agent harnesses - Pi, Codex, Claude, and Opencode - are configured declaratively through `modules/apps/<harness>/default.nix`.

Do not persist harness configuration by editing generated files or relying on `pi install`, `pi remove`, `pi config`, `/settings`, or equivalent imperative commands. Change the Nix module, model catalog, theme, resources, or host options, then rebuild.

Global agent instructions live in `modules/apps/agents/AGENTS.md` and are deployed through `modules/apps/agents/default.nix` to each harness, including `~/.pi/agent/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, and `~/.config/opencode/AGENTS.md`.

Global Agent Skills are configured in `modules/apps/agents/default.nix`. The `skills` CLI reconciles approved skills into `~/.agents/skills`, symlinked to `modules/apps/agents/skills`, where every harness can discover them. Add upstream skills through that module rather than vendoring them.

## Project operating stack

* Vikunja, accessed through Executor, is the authority for private/internal active work. Create and update internal tasks there instead of private GitHub Issues, `.scratch` issue files, or repo-local task boards. Public reports and contributor-facing discussion stay in GitHub Issues and pull requests.
* Hindsight bank `rodrigo` is the authority for durable cross-agent context, decisions, preferences, constraints, and project history. Recall relevant memory before substantial work. Retain only verified durable facts with `project:<slug>` and `source:<agent>` tags. Do not retain secrets, raw logs, temporary task state, completed-work reports, or unverified assistant claims.
* Repositories remain authoritative for code, tests, build commands, public docs, and deterministic engineering contracts that must travel with the code. Keep project `AGENTS.md` files small and current.
* Google Calendar is authoritative for events. Obsidian/JDSystem remains Rodrigo's human-owned source archive.
* Do not create new `CONTEXT.md`, mutable ADR folders, agent-memory folders, or local issue stores. Before deleting an old context or decision file, import it to Hindsight with provenance and verify recall. Keep a repo file only when contributors or CI need a versioned contract without private memory access.

## One-off tools

When a task needs a program that is not installed, use Nix instead of permanently adding it just to complete the task.

```bash
# Executable name known, package unknown
, ffmpeg -version

# Package known, temporarily expose its commands
nix shell nixpkgs#shellcheck -c shellcheck scripts/release.sh

# Run a one-off CLI directly
nix run nixpkgs#hyperfine -- 'rg TODO .' 'grep -R TODO .'
```

Use `, <command>` from comma/nix-index when you know the executable name. Use `nix shell nixpkgs#<package> -c <command> ...` when you need commands from a known package, and `nix run nixpkgs#<package> -- ...` for a package that exposes the CLI you want to invoke directly.

Only add a package to the repo when it belongs to the lasting machine environment, a service, a build, or a repeated workflow.

## Writing

* Never use the em dash character. Use a plain hyphen instead.
* For human-facing prose, use the fewest words that preserve the meaning. Put the answer or action first. Cut filler aggressively.
* Do not flatter, praise, or use superlatives by default. State disagreement, risk, uncertainty, and bad ideas plainly.
* Prefer short words, active voice, and direct sentences. Use technical terminology when it is more precise than an everyday substitute.
* Avoid clichés, stock metaphors, corporate language, and marketing language unless the task calls for them.
* Break any writing rule that would make the result less clear, accurate, or natural.
