# DEV06 — Configure and run linters, formatters and static analysis

> **Scope**: repo/area/file | **Mode**: write | **Needs**: linter configuration and analysis scope | **Example**: `configure the linter and run static analysis`

## Purpose

Configure and apply linters, formatters and static analysis tools to ensure stylistic consistency, quality and the absence of risky patterns in the code.

## When to use

Before opening a pull request, during code modernization or to standardize the project's linting rules.

## Input

Project manifests, the current linter configuration (for example ESLint, Ruff, PSScriptAnalyzer), source code and the test suite.

## Activities

Configure the linter settings files in line with the project's standards. Run the scan and distinguish critical errors, warnings and stylistic preferences. Apply safe automatic fixes only where there is no risk of altering semantics; for complex findings propose targeted changes.

## Checks

Run the static analysis again to confirm zero violations or fewer findings; run the project's test suite to make sure there are no functional regressions.

## Delivery

Formatted and cleaned code, updated linter configuration and a concise report of the rules verified.

## Related prompts

- DEV01: Implement a feature with relevant checks.
- TST04: Diagnose and fix build and test failures in CI.
