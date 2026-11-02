# DEV04 — Update dependencies checking compatibility and regressions

> **Scope**: repo/area/file | **Mode**: write | **Needs**: dependency manifests and lock files | **Example**: `update the JSON serialization package`

## Purpose

Update selected dependencies to justified, compatible versions, with compatibility, build and tests verified. For the preliminary analysis of dependency status use AUD04.

## When to use

For package maintenance or updates driven by advisories or incompatibilities.

## Input

Packages, current versions, target and the reason for the update.

## Activities

Read the real manifests and lock files, release notes and official migration guides. Assess transitive dependencies, runtime, peer dependencies and breaking changes. Update with the project's package manager.

## Checks

Verify the lock, resolution, build and the behaviors affected. Do not declare a vulnerability fixed on the version number alone.

## Delivery

Versions changed, incompatibilities handled, checks and residual risks.

## Related prompts

- DEV05: Migrate code or a framework to a defined target.
- SEC03: Fix vulnerabilities and strengthen the affected defenses.
- AUD04: Audit dependencies: outdated, vulnerable, unused and licenses.
