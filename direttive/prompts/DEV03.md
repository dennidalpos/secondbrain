# DEV03 — Refactor code preserving contracts: targeted, phased or periodic

> **Scope**: repo/area | **Mode**: write | **Needs**: code to improve, existing tests and scope (targeted, phased or periodic) | **Example**: `extract transaction handling into its own module`

## Purpose

Reduce complexity, duplication and dead code and make the code readable to a new developer, without changing the required behavior or the public contracts.

## When to use

For duplication, confused responsibilities, an undeclared public surface or hard-to-read code: targeted on one component, phased across the whole scope (after DEV08, AUD02 or AUD03, or for a handover) or as periodic maintenance after a batch of changes across several modules. To review without changing use DEV08; to plan an architectural restructuring PRG06; for performance TST06; to migrate to a new version DEV05.

## Input

Scope (component, module or repository), mode (targeted, phased or periodic), repository conventions, green build and tests, public contracts and observable invariants, recent changes (Git).

## Activities

Start from a green build and tests; if they are missing, first write characterization tests (TST01). Find callers, dependencies and coverage. Work in small, independent batches, one module and one change at a time: names that express intent, short functions with a single responsibility, duplication removed, conditions simplified, consistent error handling, comments that explain why.

In periodic maintenance also look for functions with the same purpose in different modules (compare their behavior before merging them), functions never called from production code or used only by tests, a public surface exposed without an explicit list, dead parameters and branches, flows with nested branching or hidden effects. Unify on the correct version, move test-only code into the tests, make the exported surface explicit and remove dead code only after checking references (REP04).

Follow the existing conventions without introducing new ones, add no abstraction without a concrete use and change no public contract without an explicit decision. One batch corresponds to one proposed logical commit, never mixed with functional changes.

## Decisions to collect

- mode, scope and order of the modules;
- readability thresholds (for example maximum function length) and commit granularity per batch;
- which version to keep when duplicated functions diverge;
- which functions belong to the public surface and must be exported;
- removal or retention of code that looks dead but has dynamic references.

## Checks

After each batch run the build, tests and linter; compare public contracts and output before and after and search for leftover references to renamed or removed names (code, tests, documentation, examples). Stop and revert the batch if behavior changes; flag invariants not covered by tests.

## Delivery

Changes made with their rationale, duplicates unified, exported surface, code removed or moved, contracts preserved and evidence of equivalence, metrics before and after (AUD02) if available, and leftovers that need a decision.

## Related prompts

- DEV05: Migrate code or a framework to a defined target.
- REP04: Remove leftovers and unused code after verification.
- TST06: Measure and optimize performance and resources: one bottleneck or many modules.
- DEV08: Review readability, consistency and maintainability without changing code.
- PRG06: Plan a phased architectural refactoring with checks and rollback.
