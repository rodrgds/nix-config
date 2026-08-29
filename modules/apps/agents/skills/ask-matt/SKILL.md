---
name: ask-matt
description: Route engineering work through the Matt-derived skills using Vikunja and Hindsight as shared state.
disable-model-invocation: true
---

# Ask Matt

Use this router when the next workflow is unclear.

## Main flow

1. Sharpen a feature with `/grill-with-docs`, but persist durable context/decisions to Hindsight rather than `CONTEXT.md` or ADR files.
2. Use `/prototype` when a runnable artifact is needed to settle a question. Use `/handoff` to move the result through Hindsight.
3. For a multi-session build: `/to-spec` creates the spec task in Vikunja, `/to-tickets` creates vertical implementation tasks and blocking relations, then `/implement` works one ready task at a time.
4. For a small build: `/implement` directly, still using Vikunja for any active internal task and Hindsight for durable decisions.

## On-ramps

- Public bugs and requests: `/triage`. Keep the public conversation on GitHub; accepted internal execution lives in Vikunja.
- Hard bug or regression: `/diagnosing-bugs`.
- Huge foggy effort: `/wayfinder` for a Vikunja decision map backed by Hindsight decisions.
- Historical rationale: `/why`, searching Hindsight, Vikunja, git/PR history and public sources.
- Domain language or hard-to-reverse decisions: `/domain-modeling`, persisted in Hindsight.

## Boundaries

- Continue when the current context is still sharp.
- Use a subagent for independent bounded work.
- Use `/handoff` for a new harness/session that can access Hindsight.
- Use a portable file only when the next harness cannot access Hindsight.
- Use `/clear` only when the previous phase's context is now represented in authoritative systems.

Run `/setup-matt-pocock-skills` once to verify the fixed Vikunja/Hindsight operating stack. Never create local issue stores, mutable context files or ADR-memory folders as a fallback.
