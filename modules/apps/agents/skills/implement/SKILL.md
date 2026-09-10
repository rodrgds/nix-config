---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the authorized spec or tickets through the owning code and public interfaces. Resolve routine details from current code; ask only about decisions that change the requested outcome or compatibility.

Use `tdd` for changed behavior that needs regression coverage. Select the test boundary from the acceptance criteria and existing tests.

Run focused checks during implementation and the repository's required gates for the changed surfaces before delivery. Broaden or repeat them only when edits, failures, or unresolved risks justify it.

Review the final diff against the request and repository standards. Use `code-review` for substantial changes or when explicitly requested; a small change can be reviewed locally.

Follow the repository's branch and commit policy. Report the result, verification, and any remaining blocker. Push or deploy only with the required authorization.
