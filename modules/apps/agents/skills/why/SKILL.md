---
name: why
description: "Use for 'why does X work this way', 'why we picked Y', design rationale, regressions, postmortems, or data-backed thresholds. Investigates source control, tickets, docs, chat, observability, error tracking, and analytics in parallel, then returns a cited read on decisions and tradeoffs. Use how for runtime behavior."
---

# Why

Investigate the motivation and intent behind code. Why was it built this way? What edge cases were considered? What product, business, or operational constraints shaped the design? What alternatives were rejected, and why?

Companion to the `how` skill. `how` answers what the code does and how it works. `why` answers what forces led to its shape.

## How this skill works

Historical context spreads across evidence categories: Hindsight, Vikunja, source control history, public issue tracking, legacy long-form documents, real-time team chat, infrastructure observability, error or exception tracking, and product analytics. You cannot predict from the question alone which one holds the answer, so the skill queries all available categories in parallel, then synthesizes with explicit confidence calibration. Null results from searched categories are first-class evidence about how the decision was made; report them alongside positive findings. The default is coverage, not minimalism.

## Operating Posture

Operate as a careful, cautious, precise investigator. Think like a detective piecing together a historical case from fragmentary records. When the record is thin, say so.

Concretely:

- **Evidence before narrative.** Collect the pieces first, then see what story they support. Never pick a story and recruit the evidence that fits it.
- **Precision over polish.** Prefer the exact quote and citation over a smooth paraphrase. A reader should be able to follow any claim back to its source and verify it in under a minute.
- **Consider what you haven't seen.** The evidence you find is a sample, not the whole truth. Before concluding, ask what you would expect to see if an alternative explanation were true, and whether you looked for it.
- **Name the gaps.** If a thread goes cold, a source isn't searchable, or a question has no answer, document the gap. Don't paper it over with an authoritative-sounding guess.
- **Hedge on purpose.** When evidence is indirect, your language should signal it ("appears to", "likely", "suggests"). Confidence-matching phrasing is a feature of the output, not a stylistic choice the synthesizer may override.
- **No shortcut by code-reading.** The code tells you what it does, rarely why it exists. Resist inferring intent from code shape.

This posture is the working method, not a disclaimer.

## Core Epistemics

This skill builds a **patchwork understanding** from fragmented historical evidence. Tickets go stale. Chat threads get deleted. Commit messages lie. People change their minds between the PR description and the implementation. The original author may have left the company.

Be ruthlessly honest about what you know versus what you're inferring. The goal is not a satisfying story; it is to surface evidence, calibrate confidence, and let the user decide.

Principles:

- **Cite everything.** Every claim about intent should reference a specific commit hash, PR number, ticket ID, doc URL, chat permalink, or code comment. If you can't cite it, it's inference, not fact, and must be labeled as such.
- **Prefer "appears to" over "because".** Hedge when evidence is indirect. Reserve confident language for direct, explicit evidence.
- **Surface contradictions.** If two sources disagree, show both. Don't quietly pick the one that fits your narrative.
- **Acknowledge gaps.** If a question has no answer in any source you searched, say so. An honest "we couldn't find out why" beats a confident guess.
- **Multiple hypotheses are valid.** When the evidence fits several stories, present them all with the evidence for each. Let the user triangulate.
- **Beware rationalization.** Code that makes sense today may have been written for reasons that no longer apply, or for no good reason at all. Don't retrofit intent.

Read `references/epistemics.md` for the full confidence framework and phrasing guide. The synthesizer must follow it.

## Step 1. Understand the Target and the Question

Parse what the user is asking. The **target** is usually a chunk of code, a pattern, a feature, or a named design decision. The **question** is usually one of:

- "Why was X designed this way?" Design rationale.
- "Why do we do X instead of Y?" Tradeoff or alternatives.
- "What edge cases motivated this?" Defensive reasoning.
- "What business or product constraint led to this?" External forcing function.
- "Why does this code still exist?" Dead-code territory.
- "What's the history of X?" Broad archaeological sweep.

If the target is vague, make your best guess from conversation context (open files, recent edits, what was just discussed). State your interpretation briefly so the user can redirect if you're off, then proceed.

## Step 2. Establish the Code Anchor

Before spawning investigators, anchor the investigation in concrete code. You need:

- The relevant file path(s) and line range(s)
- The key symbols (function names, class names, constants)
- An initial commit list. The last few commits touching the target.
- PR numbers from merge commits (pattern `(#1234)` in the subject line)

Build this inline. It's cheap, and every investigator needs it.

```bash
# Blame target lines for last-touch commits
git blame -L <start>,<end> <file>

# Full file history, with patches, through renames
git log --follow -p -- <file>

# Last N commits touching the file, PR numbers visible
git log --oneline -20 -- <file>

# Extract PR numbers from a commit message
git log -1 --format=%B <commit>
```

Pull PR bodies and discussion via `gh` for any substantive commits:

```bash
gh pr view <number> --json title,body,author,createdAt,mergedAt,labels,closingIssuesReferences,comments,reviews
```

Capture this as seed context (file paths, symbols, commits, PR numbers, linked ticket IDs). Pass it to the investigators so they don't rediscover it.

## Step 3. Spawn Parallel Investigators (default posture)

**Default to the full parallel investigation.** Each evidence category lives in a different kind of system, and you cannot tell from the question alone which one holds the answer without looking. So look across every available category, in parallel, by default.

### Evidence categories

Source control is always available through git and `gh`. For the other categories, use whatever tools, MCPs, or integrations are available in your environment. Map what you have access to:

1. **Hindsight durable context** - project decisions, constraints, domain language and source-linked history
2. **Vikunja internal work** - accepted specs, tasks, comments and execution history
3. **Source control history** - always available via git and `gh`
4. **Public issue / contributor tracking** - GitHub Issues and PR discussion
5. **Legacy long-form documents** - historical ADRs, design docs, specs, READMEs and wikis
6. **Real-time team chat** - Slack, Discord, etc. if accessible
7. **Infrastructure observability** - Datadog, Grafana, etc. if accessible
8. **Error / exception tracking** - Sentry, Bugsnag, etc. if accessible
9. **Product analytics** - warehouses, dashboards, etc. if accessible

Aim for a complete **coverage map**, not a minimal one. A null result from an issue tracker is evidence the decision was not ticketed, a useful fact in itself. Document the null, don't skip the search.

Launch all matching investigators in a single message so they run concurrently. One investigator per category lets each specialize in one tool's query vocabulary and result shape. Don't ask one agent to cover multiple categories.

Each investigator gets:
1. The base prompt from `references/investigator-prompt.md`
2. The category playbook from `references/sources/<source>.md` if available
3. The cross-cutting `references/sources/incident-postmortem.md` **if the target code looks defensive** (null checks, retry logic, timeout handling, rate limiting, feature flags, egress guards, OOM handlers)
4. The code anchor from Step 2 (file paths, symbols, commits, PR numbers, ticket IDs)
5. The user's original question

### Investigator roster

Spawn one investigator per available category. Each owns exactly one source.

1. **Source control investigator**. Git history, `gh` for PRs, code comments, tests. Always spawn; the only guaranteed source. Best at surfacing *implementation-time rationale captured during review*. PR descriptions stating the problem, review threads debating alternatives, inline comments encoding non-obvious constraints, test names that encode motivating edge cases, and commit messages linking tickets or incidents.

2. **Issue / ticket tracker investigator**. Tickets, project docs, status updates. Best at surfacing *the product or business forcing function*. Customer requests, compliance deadlines, parent-initiative framing, ticket-level scope changes.

3. **Long-form documents investigator**. PRDs, specs, RFCs, design docs, ADRs, postmortems, meeting notes. Best at surfacing *long-form design rationale*. Problem statements, explicit "alternatives considered" sections, strategy documents, ADRs with finalized decisions.

4. **Real-time team chat investigator**. Feature-name and symbol searches, PR URL mentions, incident channels. Best at surfacing *real-time deliberation that never reached a doc*. Fire-drill decisions during incidents, Q&A between PR author and reviewers, rationale for small changes that didn't warrant a PRD.

5. **Infrastructure observability investigator**. Metrics, monitors, dashboards, logs, traces, incidents. Best at surfacing *infrastructure and runtime reality that motivated the code*. Monitor thresholds matching code constants, metric spikes before a PR merge, dashboards created as postmortem action items.

6. **Error / exception tracking investigator**. Issues, events, stack traces, releases. Best at surfacing *the specific exceptions and error trajectories that motivated defensive code*. Stack traces through the target function, issues whose first-seen windows bracket the PR ship date.

7. **Product analytics investigator**. Usage events, experiment data, feature flags, billing events. Best at surfacing *product and data reality that shaped the code*. Feature-usage trajectories, experiment exposure data, pre-ship distributions that reveal threshold constants.

### When to skip an investigator

Only skip with an **explicit, written justification** that goes in the final "Sources Consulted" section. Two valid reasons:

- **No tool is available for that category** in this environment. Flag this as a gap, not a choice.
- **The source is provably irrelevant**, not just "probably irrelevant." A high bar. Example: "Error / exception tracking skipped. Target is a build-time script with no runtime code path."

Run the search; let the null result speak. The cost of an investigator returning empty is one agent. The cost of missing a design doc that actually exists is a wrong answer.

## Step 4. Synthesize

Synthesize all investigator findings into one confidence-weighted, evidence-cited narrative. Use `references/synthesizer-prompt.md` as the template.

The synthesizer gets:
1. The investigator findings, including any null results and any categories skipped with justification
2. The code anchor from Step 2
3. The user's original question
4. The epistemics framework from `references/epistemics.md`

## Step 5. Present

Take the synthesizer's output and present it to the user. You may lightly edit for clarity or add context from the conversation, but **do not rewrite the confidence language**. The epistemic framing is the product. Dropping the hedges to sound more authoritative is the exact failure mode this skill exists to prevent.

## Output Format

The final output uses this structure. Adapt as needed, but keep the confidence separation intact.

**The Question**. Restate what the user asked, concisely.

**The Code in Question**. File paths, line ranges, and key symbols. One or two lines so the reader is anchored.

**What We Found (direct evidence)**. Claims with explicit citations (PR #, ticket ID, doc URL, chat permalink, commit hash, code comment with file:line). Each bullet is a thing we have textual evidence for. Use present tense and quote or paraphrase the source.

**What We Can Reasonably Infer**. Claims well-supported by indirect evidence or combinations of signals, but not explicitly stated anywhere. Each bullet must explain the inference chain: "Given A and B, it's likely that C." Use hedged language ("appears to", "likely", "suggests").

**Competing Hypotheses**. If the evidence fits multiple stories, list them. For each, give the hypothesis, the evidence for it, and the evidence against it. Don't force a winner when the record doesn't support one. (Skip this section if there's a clear answer.)

**What We Don't Know**. Explicit gaps. Questions the user asked that the evidence didn't answer. Sources we searched and came up empty. Be specific. "We searched the issue tracker for 'rate limit' and found no ticket discussing this specific threshold" is more useful than "we don't know why."

**Sources Consulted**. One line per investigator, including the ones that returned nothing. The reader should see at a glance which sources were queried, which came back empty, and which were skipped and why.

After the Sources Consulted block, if the user's `why` question is a precursor to actually changing this code, convert the lineage findings into a Preserve / Change / Avoid / Risk constraint set suitable for planning the change.

## Common Failure Modes to Avoid

- **Confident storytelling**. A plausible narrative built from thin evidence. A bullet with no citation goes in "inferred" or "hypotheses," not "what we found."
- **Citing the code as evidence for its own intent**. "Handles the null case because it checks for null" is mechanics, not motivation. Motivation comes from an external source (PR discussion, ticket, comment, conversation) or is labeled as inference.
- **Recency bias**. Assuming the most recent commit is authoritative. The current shape is often the accretion of many earlier decisions. Trace back.
- **Sycophantic agreement**. If the user suggests a reason ("I assume this is for performance?"), treat it as a hypothesis and check the evidence independently, don't just confirm it.
- **Skipping the gaps section**. An honest accounting of what you couldn't find out is part of the value.
- **Skipping investigators by anticipation**. Deciding up front that "long-form docs probably don't have this" without searching. The default-to-all-categories posture prevents this. A null result is a data point; a skipped search is a blind spot.

## Reference Files

- `references/epistemics.md`. Confidence tiers and phrasing guide. The synthesizer must follow it.
- `references/investigator-prompt.md`. Base prompt template for investigator subagents.
- `references/source-playbook.md`. Index pointing at the category playbooks.
- `references/sources/*.md`. One self-contained example playbook per category. Give an investigator the single file that matches its category and adapt it to the available tools.
- `references/synthesizer-prompt.md`. Prompt template for the synthesizer, including the output format.
