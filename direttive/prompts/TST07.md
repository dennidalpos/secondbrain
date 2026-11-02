# TST07 — Set up a test harness with isolated fixtures and safe cleanup

> **Scope**: repo | **Mode**: write | **Needs**: test framework, test scripts and an assigned isolated fixture root | **Example**: `create isolated on-disk fixtures and validate the automatic cleanup`

## Purpose

Set up controlled test harnesses, isolated fixtures and safe execution of the suites.

## When to use

When developing new test suites, validating migration scenarios or testing CLI scripts. For flaky tests that already exist use TST03.

## Input

Test scripts, paths for temporary fixtures (a dedicated directory outside the tracked tree) and synthetic data.

## Activities

Set up dedicated, isolated directories for the test fixtures, avoiding overlap with the real environment. Use try/finally blocks to ensure fixtures are kept or cleaned up in a controlled way according to the project's policy.

Simulate boundary conditions, concurrent conflicts, corrupted data and recovery after a crash. Do not call network resources or remote endpoints during unit or local integration tests.

## Checks

Check that fixtures do not write outside the assigned test root. Make sure the tests exercise both nominal paths and error cases. Confirm that no real or personal data is present in the fixtures.

## Delivery

Updated test scripts, a validated harness, verified isolated fixtures and an execution report of the suite.

## Related prompts

- TST01: Add unit and integration tests for the relevant risks.
- TST02: Cover user journeys with end-to-end tests.
- TST03: Find and fix flaky or non-deterministic tests.
