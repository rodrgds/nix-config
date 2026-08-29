---
name: wayfinder
description: Map a multi-session effort as decision tasks in Vikunja and durable resolved decisions in Hindsight.
disable-model-invocation: true
---

# Wayfinder

Use this only when the path to a destination is too unclear for one session. It maps decisions, not implementation slices.

## Storage

- One **map task** in the matching Vikunja project owns the destination, scope and links to decision tasks.
- Each open question is a related Vikunja decision task with one type label: `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`.
- Native Vikunja blocking relations define the frontier. Open, unblocked and unclaimed tasks are takeable.
- Resolved decisions are retained atomically in Hindsight with `project:<slug>`, `source:<agent>`, `kind:decision`, and a link to the closed Vikunja task.
- GitHub Issues are not used for the private map. Public reports may be linked as evidence.

## Map task description

```markdown
## Destination

<what must be clear when the map is done>

## Notes

<standing constraints and useful links>

## Decisions so far

- <linked closed decision task>: <one-line gist>

## Not yet specified

- <in-scope fog that cannot yet be phrased as a precise question>

## Out of scope

- <explicit boundary and reason>
```

The map is an index. The full decision lives in Hindsight and its linked closed task; do not duplicate long answers in the map.

## Chart the map

1. Name the destination and scope.
2. Explore breadth-first until the first precise questions and remaining fog are visible.
3. Create the map task.
4. Create every currently precise decision task, then add blocking relations in a second pass.
5. Leave imprecise in-scope questions under `Not yet specified`; do not invent premature tasks.
6. Launch independent research where useful. Stop after charting; do not resolve several human decisions in the same session.

## Work the map

1. Load the map task and recall project decisions from Hindsight.
2. Pick one open, unblocked decision task and claim it before work.
3. Resolve it with evidence. Human decisions remain human-in-the-loop.
4. Comment the concise result on the Vikunja task, close it, retain the durable decision in Hindsight, then append only a linked gist to the map.
5. Create newly visible decision tasks and relations; move newly sharp fog out of `Not yet specified`.
6. Read back the map, task and Hindsight decision to verify all three surfaces agree.

When no decisions remain, hand off to `/to-spec`; do not jump from a large decision map straight into implementation.
