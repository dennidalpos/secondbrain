# TST03 — Find and fix flaky or non-deterministic tests

> **Scope**: repo/area | **Mode**: write | **Needs**: logs of the intermittent failures and the test suite | **Example**: `fix the instability in the async tests of the suite`

## Purpose

Make reliable a check whose outcome changes without functional changes.

## When to use

For intermittent failures, order dependencies or timing differences.

## Input

Test, observed frequency, logs, seeds, environment and reproduction commands.

## Activities

Repeat in a limited and justified way; look for races, time, randomness, shared state and external services. Fix isolation or synchronization while keeping the behavior protected.

## Checks

Repeat the reproduction under the causal conditions identified. Avoid arbitrary sleeps, indiscriminate retries, disabling tests and reducing assertions.

## Delivery

Cause of the instability, the fix and the number and conditions of the repetitions; no absolute guarantee.

## Related prompts

- DEV02: Reproduce a defect and fix its cause.
- TST04: Diagnose and fix build and test failures in CI.
