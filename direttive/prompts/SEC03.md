# SEC03 — Fix vulnerabilities and strengthen the affected defenses

> **Scope**: repo/area/file | **Mode**: write | **Needs**: confirmed vulnerability and code context | **Example**: `fix path traversal in path resolution`

## Purpose

Mitigate verified security risks within the requested scope.

## When to use

For confirmed findings, applicable advisories or targeted hardening.

## Input

Finding, evidence, components and versions; scenarios to prevent.

## Activities

Validate the finding and its applicability. Fix the vulnerable boundary with least privilege and consistent validation; protect secrets and error messages. Use primary sources for advisories and mitigations.

## Checks

Test adversarial inputs and relevant regressions in an isolated environment. Distinguish fixed, residual and unverified; do not claim a general absence of vulnerabilities.

## Delivery

Mitigations, evidence, the dependencies involved and residual risks.

## Related prompts

- DEV04: Update dependencies checking compatibility and regressions.
- SEC02: Analyze threats, trust boundaries and abuse scenarios.
- SEC06: Harden repository configuration, CI, containers and access.
