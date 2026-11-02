# PRG05 — Scaffold new modules with structure, configuration and tests

> **Scope**: repo/area | **Mode**: write | **Needs**: agreed architectural scope and dependencies | **Example**: `define the scaffolding of the new module`

## Purpose

Define the initial skeleton of a new module, component or service following the repository's conventions.

## When to use

When starting a new component or service. To reorganize existing code use PRG06 (refactoring plan) and DEV03 (execution).

## Input

Folder tree, project manifests, architectural invariants and the requirements of the new module.

## Activities

Analyze the module boundaries and current dependencies. Create the folder structure, configuration files, manifests and skeleton tests following the repository's conventions, without introducing dependencies that were not agreed and without overwriting existing files.

## Checks

Check that the separation of responsibilities is respected, that the skeleton builds and that the skeleton tests run.

## Delivery

Project structure created, files generated and checks run, with the limits that remain.

## Related prompts

- PRG02: Compare architectural options and justify a decision.
- PRG04: Prepare a phased plan with dependencies and checks.
- PRG06: Plan a phased architectural refactoring with checks and rollback.
