# Rodrigo's agent instructions

## Working style

- Choose the simplest design that fully meets the requirements. Do not trade correctness or maintainability for less implementation work. Use a direct workflow for one-off operations.
- Complete requested work and relevant verification. Make routine choices yourself; ask when missing information changes scope, compatibility, correctness, or a destructive action.
- Keep changes focused and preserve unrelated work. Group commits by concern.
- Inspect the UI during visual checks and fix defects you find when they are within scope and not owned by another agent.
- A release or deployment request authorizes its normal commits, pushes, tags, publication, rollout, and verification. Report the revision and distinguish local, pushed, deployed, and live-verified state.
- Use the workspace provided by the harness. Keep parallel editing isolated, and preserve work before removing a workspace.
- Update project instructions when you establish a durable convention or constraint that future agents cannot infer from the code.

## Verification

- For bugs, reproduce the failure at the closest useful user boundary. Add a small regression test, observe it fail for the expected reason, then fix it and observe it pass.
- Test observable behavior with independently derived expectations. Run the relevant existing checks; add coverage only for a meaningful gap. Documentation and low-impact changes need relevant validation, not tests that repeat their contents.
- Once required checks pass, broaden or repeat them only after further changes, failures, or unresolved risks.

## Tools and context

- Use GitHub Issues for work that needs durable tracking, unless the project specifies another tracker. Small tasks can stay in the conversation. Keep issues current and close them when their acceptance criteria are met.
- Use Hindsight bank `rodrigo` when prior decisions or project history matter. Retain verified durable facts tagged `project:<slug>` and `source:<agent>`, excluding secrets, logs, temporary state, and unverified claims.
- Keep upstream skills managed by their installer and unmodified. Put local conventions in project instructions or a local skill.

## Execution

- Run commands directly. Agent shells load the project's Devenv environment automatically. Do not wrap commands in `devenv shell`, `nix develop`, or `direnv exec`; if a tool is missing, name it and stop.
- Give every command a deadline with `timeout <seconds>`: 120s by default, 600s for installs, builds, and test suites, 1800s only for releases. On timeout, report the tail of the log.
- Never run a server, watcher, or dev process in the foreground. Start it detached, write to a log, and poll the log or port with a bounded command.
- Keep output small: `cmd > /tmp/<name>.log 2>&1; tail -50 /tmp/<name>.log`. Never dump full logs, lockfiles, or generated files into context.
- After two failed attempts at the same approach, stop and report what failed and what you need.

## Delegation and cost

- Delegate implementation, not only audits. Every subagent brief names the files it may edit, the acceptance check, and a wall-clock budget.
- At most 3 concurrent subagents and 6 per task, 15 minutes each. Subagents do not spawn subagents.
- Use the cheapest model that can pass. Reserve the most expensive model for design decisions and hard conflicts.
- Do not create a review subagent for a change under 200 lines. Review the diff yourself. One review round only, unless the change touches security, data, or protocol.
- Work in the repository or the workspace the harness provides. Never copy the tree to `/tmp` and edit there; unmerged scratch work does not count.

## Skills and instructions

- Read a skill only when its trigger matches the task. Read `SKILL.md` once; open reference files only for the section you need, and never re-read the same skill in a session.
- Project `AGENTS.md` overrides this file. Do not restate instructions in plans or reports.

## Pruning and deletion work

- When asked to remove or prune code, optimize for removal. Do not add tests, coverage gates, or evidence ledgers that were not requested.
- Land in batches: one package or subsystem, committed, with the relevant suite run once. Report measured removals and runtime change, not audit prose.
- Keep security, storage, protocol, migration, payment, permission, and core user-flow coverage. Delete copy-only, markup-detail, exact-source, duplicate-contract, and test-only-seam tests.

## Managed machines

- `~/.config/home` is the Nix source of truth for all machines, agent configuration, and local skills. Edit the owning module and use its rebuild workflow.
- All machines use Tailscale. Project dependencies belong in the project's Devenv environment, which agent shells load automatically.
- Use `, <command>`, `nix shell nixpkgs#<package> -c <command>`, or `nix run nixpkgs#<package> -- ...` for one-off tools. Add a machine package only for ongoing use.

## Writing

- Be concise and direct. State disagreement and uncertainty plainly; avoid flattery and filler.
- Never use em dashes. Use commas or periods.
