# TST01 — Add unit and integration tests for the relevant risks

> **Scope**: repo/area | **Mode**: write | **Needs**: test harness and the behavior to verify | **Example**: `add boundary tests for the budget calculation`

## Purpose

Protect important behaviors with reliable tests.

## When to use

When there is no evidence for behaviors or for the boundaries between components.

## Input

Behavior to protect, the risk and the framework actually in use.

## Activities

Find uncovered scenarios, edge cases and errors. Choose the level of the test according to the boundary to verify; use isolated fixtures and controlled dependencies. Avoid assertions that restate the implementation.

## Checks

Check that the tests tell correct results from wrong ones and do not depend on order, network or unexpected user state.

## Delivery

Tests added, behaviors covered, command and result; no arbitrary coverage percentage.

## Related prompts

- TST02: Cover user journeys with end-to-end tests.
- TST03: Find and fix flaky or non-deterministic tests.
