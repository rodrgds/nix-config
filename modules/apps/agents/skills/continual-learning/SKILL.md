---
name: continual-learning
description: "Mine high-signal deltas from prior conversations and update AGENTS.md with durable learnings. Use when the user asks to mine chats, maintain AGENTS.md, or run the continual-learning loop."
---

# Continual Learning

Keep `AGENTS.md` current by mining prior conversations for durable learnings.

## Trigger

Use when the user asks to mine prior chats, maintain `AGENTS.md`, or run the continual-learning loop.

## Workflow

1. Read existing `AGENTS.md` first. If it does not exist, create it with only:
   - `## Learned User Preferences`
   - `## Learned Workspace Facts`
2. Load the incremental index if present (`.continual-learning-index.json` in the repo root).
3. Look for transcript or conversation logs. Check common locations:
   - `agent-transcripts/` directories
   - `.pi/` or `.paseo/` directories
   - Any `.jsonl` or `.md` conversation exports
   - Files newer than the index timestamp
4. Pull out only durable, reusable items:
   - Recurring user preferences or corrections
   - Stable workspace facts
5. Update `AGENTS.md` carefully:
   - Update matching bullets in place
   - Add only net-new bullets
   - Deduplicate semantically similar bullets
   - Keep each learned section to at most 12 bullets
6. Refresh the incremental index for processed transcripts.
7. If the merge produces no `AGENTS.md` changes, leave it unchanged but still refresh the index.
8. If no meaningful updates exist, respond exactly: `No high-signal memory updates.`

## Guardrails

- Use plain bullet points only.
- Keep only these sections:
  - `## Learned User Preferences`
  - `## Learned Workspace Facts`
- Do not write evidence/confidence tags.
- Do not write process instructions, rationale, or metadata blocks.
- Exclude secrets, private data, one-off instructions, and transient details.

## Output

- Updated `AGENTS.md` and `.continual-learning-index.json` when needed.
- Otherwise exactly `No high-signal memory updates.`
