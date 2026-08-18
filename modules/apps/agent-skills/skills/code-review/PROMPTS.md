# Sub-agent prompts

Used at the **high** review tier. The orchestrator spawns two independent sub-agents in parallel.

Both prompts require the orchestrator to include:

- The diff command and commit list.
- The finding format from the main skill (ID, severity, axis, file, line(s), quote, description).

The smell baseline must be included in full in the Standards prompt — sub-agents have no access to skill files.

## Standards sub-agent

Include:

- The diff command and commit list.
- The list of standards-source files found in the repo.
- The smell baseline (from `SMELLS.md`) pasted in full.
- The finding format.

Brief:

> Review the diff on the Standards axis. Report every place where the diff (a) violates a documented standard — cite the standard (file and rule) — or (b) triggers a smell from the baseline — name the smell and quote the hunk. Distinguish hard violations from judgement calls. Documented-standard breaches can be hard; baseline smells are always judgement calls. A documented repo standard overrides the baseline. Skip anything tooling enforces.
>
> Use the finding format. Every finding gets an `S-` ID, a severity, the file, the line(s), a code quote, and a description of what is wrong and how to fix.

## Spec sub-agent

Include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The finding format.

Brief:

> Review the diff on the Spec axis. Report (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that was not asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding.
>
> Use the finding format. Every finding gets a `P-` ID, a severity, the file, the line(s), a code quote, and a description of what is wrong and how to fix.

If the spec is missing, skip this sub-agent entirely and note it in the final report.
