# PRG02 — Compare architectural options and justify a decision

> **Scope**: repo/area | **Mode**: read | **Needs**: alternatives to evaluate and project constraints | **Example**: `compare SQLite and JSON for local persistence`

## Purpose

Choose an approach compatible with the real architecture and constraints.

## When to use

When there are alternatives with substantial differences in cost, risk or maintenance.

## Input

Problem, success criteria, constraints and the components involved.

## Activities

Describe the practicable alternatives, including reuse of what exists. Compare trade-offs, dependencies, reversibility and operational consequences. Consult official sources when the choice depends on the capabilities of a technology. Present the choices and collect the final decision as defined options.

## Decisions to collect

- architectural alternative to adopt among those compared;
- trade-offs accepted (multiple choice) and final confirmation of the decision.

## Checks

Check assumptions against the code and versions; distinguish facts, estimates and preferences. Do not introduce a new architecture out of convention.

## Delivery

Proposed decision with its rationale, discarded alternatives and the conditions that would make it be revisited; no implicit writing of decision records.

## Related prompts

- COM04: Assess the impact, risks and dependencies of a change.
- PRG03: Design API contracts, data models and compatibility.
- PRG05: Scaffold new modules with structure, configuration and tests.
