# AUD03 — Audit architecture and technical debt not yet tracked

> **Scope**: repo/area | **Mode**: read | **Needs**: read access to the code, the backlog and architecture documentation | **Example**: `audit of architecture and technical debt of the repository`

## Purpose

Find coupling, module boundary violations and technical debt that are not in the backlog.

## When to use

Before an architectural refactoring, after rapid growth or when the cost of changes is rising.

## Input

Module structure, internal dependencies, documented architectural decisions and the backlog or notes, if any.

## Activities

Reconstruct modules, layers and dependencies from the real code, not from the documentation. Look for dependency cycles, inverted dependencies between layers, modules with too many responsibilities, duplicated responsibilities, scattered configuration, single points of failure and leftover shortcuts (TODO, FIXME, HACK markers, stubs, disabled tests). Tell real markers apart from identifiers, fixtures and test texts that contain the same word. Compare with the documented decisions and the backlog.

## Checks

Every debt item has a path, a concrete impact and a justified estimated cost (low, medium, high). Check that it is not already in the backlog under another identifier and distinguish deliberate, documented choices from defects.

## Delivery

Map of the observed boundaries, debt ordered by impact and proposed work items to record; for the remediation plan use PRG06.

## Related prompts

- AUD01: Run a full repository audit with a single report, optionally exported.
- COM04: Assess the impact, risks and dependencies of a change.
- PRG06: Plan a phased architectural refactoring with checks and rollback.
