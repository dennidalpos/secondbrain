# DEV02 — Reproduce a defect and fix its cause

> **Scope**: repo/area/file | **Mode**: write | **Needs**: report or expected and actual behavior | **Example**: `fix the parsing error for paths containing spaces`

## Purpose

Remove the cause of incorrect behavior and prevent it from coming back.

## When to use

For an application defect with an identifiable symptom or expected result.

## Input

Reproduction, errors, logs, environment and the difference between expected and observed.

## Activities

Reconstruct the flow and look for a minimal reproduction. Formulate and verify hypotheses; fix the cause and check for recurrences from the same origin. If it cannot be reproduced, separate static diagnosis from evidence.

## Checks

Show before and after when possible and add a meaningful regression test. Do not change test expectations to hide the defect.

## Delivery

Cause, fix, reproduction and checks, with the remaining limits.

## Related prompts

- TST03: Find and fix flaky or non-deterministic tests.
- TST04: Diagnose and fix build and test failures in CI.
- COM05: Analyze logs and incidents to find the root cause, without changing code.
- OPS06: Prepare a release hotfix and rollback with verification and communication.
