# PRG06 — Plan a phased architectural refactoring with checks and rollback

> **Scope**: repo/area | **Mode**: read | **Needs**: module to reorganize, existing tests and invariants to preserve | **Example**: `plan the refactoring of the synchronization module`

## Purpose

Set up an architectural refactoring plan in atomic, verifiable phases that preserves public contracts and existing behavior.

## When to use

When technical debt or complexity calls for a structural reorganization. For a generic plan use PRG04, to carry out the changes DEV03, for a new module PRG05.

## Input

Code and module boundaries, current dependencies, test coverage, architectural invariants and the goal of the reorganization.

## Activities

Map responsibilities, dependencies and public contracts. Find the breaking points and split the work into atomic phases, each with executable intermediate steps, verification criteria, dependency order and rollback. Do not modify the code and do not update the backlog unless explicitly asked.

## Decisions to collect

- boundary of the refactoring and phases to include in the plan;
- compatibility to preserve for the public contracts.

## Checks

Check that each phase has a verifiable outcome, that public contracts are not broken by accident and that the test suite covers the behavior to preserve.

## Delivery

A phased plan document with dependencies, checks, rollback, agreed decision points, assumptions and limits.

## Related prompts

- PRG04: Prepare a phased plan with dependencies and checks.
- DEV03: Refactor code preserving contracts: targeted, phased or periodic.
- PRG05: Scaffold new modules with structure, configuration and tests.
- AUD03: Audit architecture and technical debt not yet tracked.
