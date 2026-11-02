# DEV05 — Migrate code or a framework to a defined target

> **Scope**: repo/area | **Mode**: write | **Needs**: source and target versions with release notes | **Example**: `migrate the scripts from the old runtime version to the current one`

## Purpose

Move an area of code to an agreed technology or version.

## When to use

For structural modernization that goes beyond an ordinary package update.

## Input

Source, target, motivation, compatibility and release constraints.

## Activities

Inventory deprecated APIs, integrations and semantic differences. Use the target's official guides, migrate in verifiable units and remove the replaced path after checking consumers. Keep a proportionate recovery option.

## Checks

Compare features and contracts against a baseline; run the relevant build and tests, declaring platforms not tested.

## Delivery

Units migrated, intentional differences, evidence and steps still needed.

## Related prompts

- DAT01: Migrate schema and data with verifiable comparison and recovery.
- DEV04: Update dependencies checking compatibility and regressions.
