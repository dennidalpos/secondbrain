# COM04 — Assess the impact, risks and dependencies of a change

> **Scope**: repo | **Mode**: read | **Needs**: proposed change or defect to fix | **Example**: `assess the impact of isolating runtime logs`

## Purpose

Estimate the effects of a change before implementing it.

## When to use

For cross-cutting changes, shared contracts or poorly documented behavior.

## Input

The proposed change, its scope and the constraints to preserve.

## Activities

Search for consumers, dependencies, persisted data, compatibility and error paths. Distinguish code to change, integrations to verify and migration risks. Do not extend the analysis to other repositories without authorization.

## Checks

Link each risk to a concrete dependency or behavior; flag incomplete coverage. Do not modify files.

## Delivery

A concise impact matrix, risks, the checks needed and a qualitative estimate of the work.

## Related prompts

- PRG03: Design API contracts, data models and compatibility.
- PRG04: Prepare a phased plan with dependencies and checks.
- AUD03: Audit architecture and technical debt not yet tracked.
