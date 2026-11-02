# AUD04 — Audit dependencies: outdated, vulnerable, unused and licenses

> **Scope**: repo/area | **Mode**: read | **Needs**: manifests, lock files and access to package registries or dependency advisories | **Example**: `dependency audit before the upgrade`

## Purpose

Take stock of direct and transitive dependencies to decide what to update, replace or remove.

## When to use

Before updating (DEV04), before a release or periodically.

## Input

Manifests and lock files, reachable package registries, known advisories and the project's license policy.

## Activities

List direct and transitive dependencies with the version in use and the latest compatible one. Flag those that are unmaintained or deprecated, with recorded advisories (check official sources such as the OSV database and GitHub advisories), not referenced by the code, or with incompatible or undeclared licenses. Rank by urgency: exploitable vulnerability, end of support, major versions behind.

## Checks

Do not infer a vulnerability from the version number alone: check that it applies to the code path actually used. Check apparently unused dependencies by hand (dynamic use, plugins, build scripts). Do not modify manifests or lock files.

## Delivery

Inventory with status per dependency, update priority, risks and proposed work items for DEV04; licenses to examine further with GOV01.

## Related prompts

- AUD01: Run a full repository audit with a single report, optionally exported.
- DEV04: Update dependencies checking compatibility and regressions.
- GOV01: Check open source licenses, file compliance and SPDX headers.
