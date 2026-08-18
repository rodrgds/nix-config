# Review tiers

Risk determines review depth. The tier is selected once at the start and does not change across cycles.

## Low

One reviewer, one pass, one ledger. The reviewer applies both Standards and Spec in a single read of the diff. The ledger has both axes interleaved.

Use for: isolated bug fixes, copy changes, configuration updates, single-file refactors that do not change interfaces.

## Medium

One reviewer, one pass, one ledger with separate `## Standards` and `## Spec` sections. The reviewer reads the diff once but reports each axis in its own section.

Use for: feature work that touches one module, changes that alter behaviour but stay within a known boundary, work where the spec exists but is narrow.

## High

Two independent sub-agents run in parallel. One reviews Standards, the other reviews Spec. Each fills its own ledger. The orchestrator merges them into a single ledger for the fix and verify cycles.

Use for: authorization or access control changes, destructive operations, database migrations, external service integration, cross-module refactors, work that touches security boundaries.

The smell baseline is always part of the Standards context, regardless of tier.
