# DAT01 — Migrate schema and data with verifiable comparison and recovery

> **Scope**: repo/area | **Mode**: write | **Needs**: source schema, target schema and synthetic data | **Example**: `migrate the schema with an atomic rollback script`

## Purpose

Carry out a data transformation without losing necessary information.

## When to use

For schema evolution, engine changes or migrations of persisted formats.

## Input

Source, target, volumes, semantics, constraints and the authorized environment.

## Activities

Inventory data and consumers; verify backup and recovery before any mutation. Define the transformations, idempotence or resumption, compatibility and comparison. Try first on an isolated copy and handle concurrent changes without overwriting them.

## Checks

Compare counts, keys, relationships, significant values and edge cases; test the recovery. Do not migrate further environments by implication.

## Delivery

Manifest or proportionate evidence, transformations, comparison, proven recovery and leftovers.

## Related prompts

- DAT02: Build imports and transformations that preserve the originals.
- PRG03: Design API contracts, data models and compatibility.
