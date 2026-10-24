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

## Managed machines

- `~/.config/home` is the Nix source of truth for all machines, agent configuration, and local skills. Edit the owning module and use its rebuild workflow.
- All machines use Tailscale. Project dependencies belong in the project's Devenv environment.
- Use `, <command>`, `nix shell nixpkgs#<package> -c <command>`, or `nix run nixpkgs#<package> -- ...` for one-off tools. Add a machine package only for ongoing use.

## Writing

- Be concise and direct. State disagreement and uncertainty plainly; avoid flattery and filler.
- Never use em dashes. Use commas or periods.
