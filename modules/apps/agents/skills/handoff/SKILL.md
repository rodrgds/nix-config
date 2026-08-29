---
name: handoff
description: Save a concise source-linked handoff to Hindsight for another agent or session.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

# Handoff

Default to Hindsight, not a temporary Markdown file.

1. Identify the project and the next session's purpose.
2. Summarize only unresolved context: current objective, verified state, key decisions, blockers, exact source links and the next useful action.
3. Link to Vikunja tasks, commits, PRs, public issues and deterministic repo docs instead of duplicating them.
4. Redact secrets and omit raw logs, temporary chatter and completed-work narration.
5. Retain the handoff in bank `rodrigo` with `project:<slug>`, `source:<agent>`, `kind:handoff`, and a stable document ID when updating an existing handoff.
6. Recall it once and verify the next agent can recover the objective, blockers and source links.

Write a temporary portable Markdown handoff only when the target harness cannot access Hindsight or the user explicitly asks for a file. Never create a repo-local handoff/context store by default.
