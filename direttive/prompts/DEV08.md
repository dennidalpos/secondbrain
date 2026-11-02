# DEV08 — Review readability, consistency and maintainability without changing code

> **Scope**: repo/area/file | **Mode**: read | **Needs**: code to review, repository conventions and existing tests | **Example**: `review readability and maintainability of the sync module`

## Purpose

Assess the quality, consistency and maintainability of the indicated code, with concrete findings and proposals, without modifying it.

## When to use

Before a refactoring or a quality review. For security and correctness findings on a change use SEC01, for automatic rules DEV06, to apply the fixes DEV03.

## Input

Files or modules to review, conventions and instructions of the repository, linter and test results, recent change history.

## Activities

Read the code in the context of the repository's conventions for names, comments and structure. Find duplication, excessive complexity, confused responsibilities, coupling, inconsistent error handling and dead code. Order the findings by impact on maintenance and give for each the path and line, the reason and a proposal. Do not modify files and do not introduce new conventions: follow the existing ones.

## Checks

Verify each finding on the real code and check that it is not already covered by a linter or a backlog item. Distinguish proven defects from style preferences.

## Delivery

A prioritized list of findings with path, reason and proposal, plus any work items to record; no changes to the code.

## Related prompts

- DEV03: Refactor code preserving contracts: targeted, phased or periodic.
- DEV06: Configure and run linters, formatters and static analysis.
- SEC01: Review changes or code with concrete findings and references.
- AUD02: Measure the repository with reproducible metrics and find hotspots.
