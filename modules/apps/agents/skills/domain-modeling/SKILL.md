---
name: domain-modeling
description: Build and maintain precise project language and hard-to-reverse decisions in Hindsight.
---

# Domain modeling

Use precise domain language to reduce ambiguity in code, specs and discussion. The live code remains authoritative for implemented behavior; Hindsight bank `rodrigo` stores the durable cross-agent model of why terms and decisions mean what they do.

## Start

1. Read the relevant code, public docs and the repo's `AGENTS.md`.
2. Recall Hindsight using the project name, repository URL, target symbols and the user's question.
3. Treat recalled material as historical evidence, not proof of current code. Verify claims against the repository or live system when possible.

## Model the domain

- Identify actors, entities, value objects, events, commands, states, invariants and boundaries.
- Challenge overloaded or vague terms. Prefer one term per concept and one concept per term.
- Use examples and counterexamples to test definitions.
- Separate domain facts from implementation choices.
- Identify hard-to-reverse decisions, rejected alternatives and the evidence behind them.

## Persist

Retain concise atomic memories in Hindsight:

- term definitions and aliases;
- invariants and lifecycle rules;
- boundary decisions;
- accepted/rejected alternatives with reasons;
- stable links to source commits, PRs, public issues, docs or live systems.

Use tags `project:<slug>`, `source:<agent>`, and one of `kind:domain`, `kind:decision`, or `kind:constraint`. State confidence and source type in the content or metadata. Replace/correct superseded memories instead of adding contradictory duplicates.

Do not create or update `CONTEXT.md`, ADR files, decision folders or agent-memory files. Keep a repository document only when contributors or CI need a deterministic versioned contract without private Hindsight access.
