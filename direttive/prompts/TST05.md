# TST05 — Verify real behavior against the requirements

> **Scope**: repo | **Mode**: verify | **Needs**: acceptance criteria and a working environment | **Example**: `verify that the output conforms to the specifications`

## Purpose

Establish what really works within the scope indicated.

## When to use

For acceptance testing, confirming a fix or verifying a delivery.

## Input

Acceptance criteria, the build or application to test, environment and test data.

## Activities

Map the criteria to observable paths. Run the relevant positive, negative and boundary tests; collect outcomes and references. Use copies or isolated fixtures so as not to change real data.

## Checks

Distinguish static inspection, automated tests and real interaction. Do not fix code or update notes for a verification-only request.

## Delivery

Matrix of criterion, outcome and evidence, reproducible defects and the parts that could not be reached.

## Related prompts

- SEC01: Review changes or code with concrete findings and references.
- TST02: Cover user journeys with end-to-end tests.
