---
name: code-review
description: Review changes since a fixed point. Track every finding in a ledger, select a risk-based review tier, and verify closures on an incremental delta. Max two cycles. Use when asked to "review since X", review a branch, review a PR, or inspect work-in-progress changes.
---

Two-axis review — **Standards** and **Spec** — of the diff between a stable HEAD and a fixed point the user supplies. Every finding gets a stable ID, a severity, and a disposition. The same reviewers verify closures on the incremental delta between review rounds.

The issue tracker should have been provided to you. If `docs/agents/issue-tracker.md` is missing, tell the user to run `/setup-matt-pocock-skills`.

## Finding format

Every finding in the ledger carries:

- **ID** — stable per cycle. First cycle: `S-1`, `S-2`, ... (standards) and `P-1`, `P-2`, ... (spec). Second cycle spillover: `N-S-1`, `N-P-1`, etc.
- **Severity** — `critical` (auth bypass, data loss, security hole — must fix before merge), `major` (correctness or standards violation — blocks merge), `minor` (suggestion, smell, style).
- **Axis** — `standards` or `spec`.
- **File** and **Line(s)**.
- **Quote** — the relevant code.
- **Description** — what is wrong and how to fix.

Dispositions during fix: `fixed` (with commit ref), `wontfix` (with reason), `deferred` (ticket created), `false-positive` (reviewer error).

## Process

### 1. Pin the stable SHA

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. If they did not specify one, ask.

Confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty (`git diff <fixed-point>...HEAD`). Capture the diff command and the commit list (`git log <fixed-point>..HEAD --oneline`). **Done when:** the SHA resolves and the diff is non-empty.

### 2. Assess risk

Classify the change as **low**, **medium**, or **high** risk.

Escalate to **high** when the diff touches authorization or access control, destructive or irreversible operations, database migrations, external service integration, authentication boundaries, encryption, or data retention.

Escalate to **medium** when the diff changes shared state, async flows, error handling, or cross-module interfaces.

Default to **low**.

### 3. Identify the spec source

Look for the originating spec:

1. Issue references in commit messages (`#123`, `Closes #45`, GitLab `!67`) — fetch via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user. If they say there is no spec, skip the Spec axis and note this in the final report.

**Done when:** the spec path is resolved or the user confirms there is none.

### 4. Select the review tier

Choose based on risk:

- **Low** — one reviewer reads the diff, applies both Standards and Spec in a single pass, fills one ledger.
- **Medium** — one reviewer reads the diff, produces a ledger with separate `## Standards` and `## Spec` sections.
- **High** — two independent sub-agents run in parallel: one Standards, one Spec. Each fills its own ledger. See [`PROMPTS.md`](PROMPTS.md) for the sub-agent prompts.

The smell baseline is always part of the Standards context. Read [`SMELLS.md`](SMELLS.md) and include it in the review context — sub-agents have no access to skill files. See [`TIERS.md`](TIERS.md) for full tier definitions.

### 5. Review

Read the diff against the spec (if present) and the standards. Fill the ledger with every finding — per file, per hunk, per axis. Include the smell baseline on the first pass.

**Done when:** every finding is numbered, classified by severity, and in the ledger.

### 6. Fix

The implementer addresses every finding in one batch. Mark each:

- `fixed` — with the commit reference.
- `wontfix` — with a reason.
- `deferred` — a ticket has been created.
- `false-positive` — the reviewer got it wrong.

**Done when:** every finding has a disposition. The review cannot proceed until this is true.

### 7. Verify the delta (incremental pass)

Same reviewers, new context. Reviewers receive:

- The existing ledger.
- The incremental diff: `git diff <old-HEAD>...<new-HEAD>`.
- The old and new SHAs.

For each finding:

- Verify the closure. Check the commit that claims to fix it. Confirm `fixed` findings are actually resolved. Confirm `wontfix` and `deferred` dispositions are sound.
- If a `wontfix` or `deferred` is disputed, escalate to the human.
- Inspect the new diff for spillover — new issues introduced by the fixes. Number spillover findings with the cycle prefix (e.g., `N-S-1`).

**Done when:** every closure is verified and all spillover is in the ledger.

### 8. Cycle cap

Maximum two review-fix cycles. After the second incremental pass:

- **All clear** — the ticket is ready to merge.
- **Spillover growing** — the ticket needs splitting.
- **Disputed dispositions** — escalate to the human.

A third cycle means the ticket is too large or the changes are too entangled. Split or escalate.

## Final report

- **Summary** — total findings per axis, worst issue per axis.
- **Ledger** — every finding with its final disposition.
- **Manual verification** — anything that cannot be verified from the diff (browser behaviour, deployed state, provider interaction).
- **Cycle count** — how many review-fix cycles were used.

## Rules

- When the spec is missing, skip the Spec axis entirely. Note this in the final report.
- Exclude tooling-enforced checks from the review. Linters, type checkers, and formatters own their domains. The review covers what tooling cannot catch.
