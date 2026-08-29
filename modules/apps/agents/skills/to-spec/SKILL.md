---
name: to-spec
description: Turn the current conversation into an implementation-ready spec in Vikunja and retain durable decisions in Hindsight.
disable-model-invocation: true
---

# To spec

Synthesize what is already known. Do not restart the interview.

## Process

1. Inspect the repo and recall Hindsight for the project, feature and relevant decisions.
2. Verify recalled claims against current code. Respect deterministic contracts in `AGENTS.md` and public docs.
3. Identify the highest useful testing seam and confirm it with the user only when the choice is genuinely ambiguous.
4. Write the spec using the template below.
5. Create or update one task in the matching Vikunja project. Apply `ready-for-agent` when the spec is complete. Read the task back and verify its description and links.
6. Retain only the durable implementation/testing decisions in Hindsight with `project:<slug>`, `source:<agent>` and `kind:decision`. Do not retain task status or copy the full spec as undifferentiated memory.

Never create an internal GitHub Issue or repo-local spec/context file. A public GitHub report may be linked as evidence; it remains the public conversation while Vikunja owns internal execution.

## Vikunja description

```markdown
## Problem

<user-visible problem>

## Solution

<user-visible result>

## User stories

1. As <actor>, I want <capability>, so that <benefit>.

## Implementation decisions

- <decision and why>

## Testing decisions

- <external behavior and seam>

## Out of scope

- <explicit boundary>

## Useful links

- <public issue, PR, design, source or evidence URL>
```

Descriptions must remain actionable and user-facing. Do not include migration keys, source paths, hashes or audit boilerplate.
