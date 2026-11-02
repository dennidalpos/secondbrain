# PRG03 — Design API contracts, data models and compatibility

> **Scope**: repo/area | **Mode**: read | **Needs**: requirements or current schema with its version | **Example**: `design the JSON schema and API contracts for the task list`

## Purpose

Define consistent interfaces and models before implementing them.

## When to use

When a boundary between modules, services or persisted formats changes.

## Input

Consumers, use cases, existing contracts and the compatibility required.

## Activities

Specify inputs, outputs, errors, invariants, versioning and responsibilities. Distinguish the public model from the internal representation. Consider data evolution and compatibility with the known consumers.

## Checks

Walk through valid, invalid and evolution examples; check the project's real conventions. Avoid unnecessary wire-format details.

## Delivery

Proposed contract, examples, impact on consumers and a minimal verification plan.

## Related prompts

- DAT01: Migrate schema and data with verifiable comparison and recovery.
- DOC02: Document APIs and contracts from the implementation.
