# TST02 — Cover user journeys with end-to-end tests

> **Scope**: repo/area | **Mode**: write | **Needs**: test environment and agreed user flows | **Example**: `create an end-to-end test for the backup and restore cycle`

## Purpose

Verify a complete path across the real components involved.

## When to use

For critical flows that tests of the individual components do not prove.

## Input

Path, success criteria, test environment and the data allowed.

## Activities

Prepare an isolated environment and data; drive the flow through the real interfaces. Use selectors and waits based on observable behavior. Cover failures and repeating the path where relevant.

## Checks

Check the initial and final state, repeatability, cleanup of the data created and useful diagnostic artifacts. Do not use production data implicitly.

## Delivery

Automated scenarios, run instructions and the limits of the integrations actually tested.

## Related prompts

- TST01: Add unit and integration tests for the relevant risks.
- TST05: Verify real behavior against the requirements.
