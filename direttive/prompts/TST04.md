# TST04 — Diagnose and fix build and test failures in CI

> **Scope**: repo/area/file | **Mode**: write | **Needs**: CI logs and pipeline configuration | **Example**: `fix the GitHub Actions runner failure on Windows`

## Purpose

Restore the failing check by understanding the difference between CI and the local environment.

## When to use

When a pipeline fails or the failure depends on the runner.

## Input

Job, commit, the relevant full logs, runner, versions, commands and artifacts.

## Activities

Find the first causal error and compare checkout, toolchain, caches, permissions and non-secret variables with the local environment. Reproduce the command on a fixture or a compatible environment; fix the code or the pipeline according to the evidence.

## Checks

Run the relevant check again. Do not remove gates, widen permissions or mark success to get around the failure. Distinguish local verification from a new remote run.

## Delivery

Cause, environmental difference, fix and the verified status of the job.

## Related prompts

- DEV06: Configure and run linters, formatters and static analysis.
- OPS02: Configure pipelines, containers and infrastructure as code.
- TST03: Find and fix flaky or non-deterministic tests.
