# Rodrigo's agent instructions

## Core

- Choose technical solutions for correctness, simplicity, robustness, maintainability, and scalability. Implementation effort is not a reason to accept a weaker design.
- For one-off or infrequent operational work, take the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation until a concrete blocker or repeated need justifies them.
- Prefer a maintained library to custom code when it fits.
- Keep changes focused on the task. Do not refactor, reformat, or comment unrelated code. Fix an unrelated defect only when it is obvious, safe, verified, and not owned by another agent, then commit it separately.
- During visual tests, inspect the UI for defects. Treat visible problems, lint failures, test failures, and flaky tests as bugs. Fix them when safe and not owned by another agent.
- Group commits by concern. Name each commit for why the change exists, not which files changed.
- Update the project's `AGENTS.md` when a change introduces a convention, architectural boundary, constraint, or workflow that future agents must follow.

## Initiative and scope

- Treat requests to do work as authorization to implement and verify it. Make routine choices from the current code and stated intent. Ask only when missing information materially changes scope, correctness, compatibility, or an irreversible action; continue independent work while waiting.
- Apply corrections and answer side questions without dropping the original task. Finish authorized work before presenting any remaining decision for approval.
- User instructions take precedence over skill guidelines, subject to system and developer constraints. Load only relevant skills. If a skill blocks progress, cite its exact file and instruction and explain why existing authorization does not cover the action.
- A request to release or deploy authorizes its normal commits, pushes, tags, artifact publication, and deployment. State the revision and effect, verify the result, and finish without another approval prompt. Ask separately for destructive actions outside the requested workflow.

## Testing and bug fixes

- When fixing a bug, first reproduce it at the closest practical end-user boundary. Then add the smallest stable regression test that proves the same behavior, observe it fail for the expected reason, implement the fix, and observe it pass.
- Test observable behavior through stable public interfaces, with expected results derived independently from the implementation. Choose the closest useful boundary from the acceptance criteria and existing tests; routine test placement needs no separate approval.
- Run the closest existing checks first. Add only the smallest coverage needed for changed behavior that existing checks cannot prove, and tie each new test to an acceptance criterion.
- Executing changed code or increasing coverage does not make a test useful. Delete tautological tests.
- Complete the required checks for the changed surfaces. Once they pass, repeat or broaden verification only after further edits, failures, or unresolved risks. Documentation and low-impact edits need relevant validation, not tests that repeat their contents.

## Engineering

- Name recurring or meaningful values with constants or enums. Keep obvious one-off values inline. Use named constants supplied by protocols and specifications when available.
- Keep control flow shallow. Prefer early returns, guards, and `continue` over deeply nested branches.
- Replace ambiguous boolean parameters with an enum, options object, or separate operation. Calls such as `foo(true, false)` hide their meaning.
- Keep fields and functions private unless callers need access. Treat wider visibility as an API and design change.
- Put raw I/O, parsing, sockets, storage, and hardware access behind dedicated adapters or drivers. Higher-level code should use domain concepts instead of reaching through those boundaries.
- Respect architectural boundaries. If a boundary is wrong, redesign it instead of bypassing its service or abstraction.
- Comments should explain intent, constraints, trade-offs, or other facts the code cannot express. Do not narrate readable code. Use a short example or ASCII diagram when it clarifies a complex protocol, state machine, or data flow.

## Delegation

- When delegation is allowed, use subagents for bounded, independent work that improves quality or shortens the critical path. Keep tightly coupled changes local. Give each agent its scope, evidence required, and completion criterion; inspect its results before integrating.
- Use Worktrunk (`wt`) for all worktree operations. Do not use raw `git worktree` or another worktree manager.
- Give each parallel editing agent its own branch and Worktrunk-managed worktree. Tell the agent its absolute worktree path and require all edits to stay there.

## Managed machines

`~/.config/home` is the Nix config source of truth for Rodrigo's machines.

All machines use Tailscale.

When a dependency belongs to a project rather than the machine, use the project's Devenv environment.

All agent harnesses and skills are configured through the Nix source. Edit their owning module and use the repository's rebuild workflow to apply changes.

## Project operating stack

- Use Vikunja through Executor for private active work. Create and update internal tasks there, not in private GitHub Issues nor repo-local task boards. Keep public reports and contributor discussions in GitHub Issues and pull requests.
- Use Hindsight bank `rodrigo` for durable cross-agent context, decisions, preferences, constraints, and project history. Recall relevant memory before substantial work. Retain only verified durable facts tagged `project:<slug>` and `source:<agent>`. Never retain secrets, raw logs, temporary task state, completed-work reports, or unverified assistant claims.
- Repositories own code, tests, build commands, public docs, and engineering contracts that must travel with the code. Keep project `AGENTS.md` files small and current.

## One-off tools

Use Nix when a task needs an uninstalled program. Do not install a program permanently for one job.

Use `, <command>` from comma/nix-index when you know the executable name but not the package. Use `nix shell nixpkgs#<package> -c <command> ...` for commands from a known package. Use `nix run nixpkgs#<package> -- ...` to invoke a package's CLI directly.

Add a package to the repo only when a machine, service, build, or repeated workflow needs it.

## Writing

- Never use em dashes. Separate clauses with commas or periods.
- For human-facing prose, use the fewest words that preserve the meaning. Put the answer or action first. Cut filler aggressively.
- Do not flatter, praise, or use superlatives by default. State disagreement, risk, uncertainty, and bad ideas plainly.
- Prefer short words, active voice, and direct sentences. Use technical terminology when it is more precise than an everyday substitute.
- Avoid clichés, stock metaphors, corporate language, and marketing language unless the task calls for them.
- Break any writing rule that would make the result less clear, accurate, or natural.
