---
name: setup-matt-pocock-skills
description: Configure the fixed Vikunja + Hindsight project workflow used by the Matt-derived engineering skills.
disable-model-invocation: true
---

# Set up the project operating stack

The storage choices are fixed globally. Do not ask the user to choose an issue tracker or create repo-local context/ADR stores.

## Sources of truth

- **Vikunja through Executor**: private/internal active work, specs, implementation tasks, wayfinder maps and decision tasks.
- **Hindsight bank `rodrigo`**: durable cross-agent context, domain language, decisions, constraints, preferences and project history.
- **GitHub Issues**: public bug reports, feature requests and contributor-facing discussion only. Never create private/internal planning issues there.
- **Repository**: code, tests, build commands, public docs and deterministic engineering contracts that must travel with the code.
- **Google Calendar**: events.
- **Obsidian/JDSystem**: Rodrigo's human-owned source archive.

## Setup

1. Read the repo's `AGENTS.md` and identify its project slug and matching Vikunja project.
2. Verify Executor can list that Vikunja project without mutating tasks.
3. Recall Hindsight with the project name and repository URL. Confirm the shared bank is `rodrigo`.
4. Ensure the repo `AGENTS.md` contains a short source-of-truth note. Do not generate `CONTEXT.md`, ADR folders, `.scratch` issue stores, or issue-tracker docs.
5. If old mutable context exists, inventory and hash it, import it to Hindsight with `project:<slug>` and source tags, verify recall, then remove only redundant files. Keep deterministic contracts.
6. Report any missing Vikunja project or unavailable Hindsight access instead of silently falling back to GitHub/local files.

## Writing rules

- Vikunja descriptions contain actionable user-facing context and useful links only. Keep migration provenance, source hashes and audit metadata outside task descriptions.
- Hindsight retains verified durable facts only. Never retain secrets, raw logs, temporary task state, completed-work reports or unverified assistant claims.
- Every Hindsight write gets `source:<agent>` and, for project material, `project:<slug>`.
