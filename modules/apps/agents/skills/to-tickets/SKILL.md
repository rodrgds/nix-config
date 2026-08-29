---
name: to-tickets
description: Split an approved spec into vertical implementation tasks in Vikunja with real blocking relationships.
disable-model-invocation: true
---

# To tickets

Vikunja is the authority for internal implementation work. Do not create GitHub Issues or `.scratch` task files.

## Process

1. Load the approved spec from Vikunja/current conversation and recall relevant Hindsight decisions.
2. Inspect the current code so tasks match real seams and terminology.
3. Split the work into end-to-end tracer bullets. Each task must produce observable value or reduce a concrete blocking risk; avoid horizontal layer tickets.
4. Keep each task independently executable in one agent session where practical.
5. Create tasks in the matching Vikunja project. Use a parent task or explicit relation to the spec task when available.
6. Create all tasks first, then add native blocking relations in a second pass.
7. Apply `ready-for-agent` only when a task has enough context, acceptance criteria and verification steps to run without another interview.
8. Read every created task and relation back from Vikunja. Report the ordered frontier and blocked tasks.

## Task description

```markdown
## Outcome

<observable result>

## Context

<only the context needed to execute this slice>

## Requirements

- <behavioral requirement>

## Acceptance criteria

- [ ] <externally verifiable result>

## Verification

- <targeted command or manual check>

## Useful links

- <spec/public issue/PR/design/source URL>
```

Do not put source hashes, migration metadata, private audit notes or Hindsight instructions in task descriptions. Durable cross-task decisions belong in Hindsight; current task state belongs in Vikunja.
