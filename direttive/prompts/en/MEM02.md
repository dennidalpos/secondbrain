# MEM02 — Migrate design and tasks into the SecondBrain dossier

> **Scope**: repo/area | **Mode**: write | **Needs**: historical documentation or external issues to migrate | **Example**: `sb prompt MEM02: migrate scattered todos into the dossier's central tracker`

## Purpose

Centralize knowledge and tasks of the selected repository only.

## When to use

For an explicitly requested transfer of design, plans and trackers.

## Input

Identity, current dossier, sources to transfer and the applicable tracker contract.

## Activities

Inventory contents and consumers; keep in the product the sources, tests and documentation needed by build and CI. Use the central resolver and migrators with backup, manifest and resume; if prerequisites are missing, stop the transfer. Preserve IDs, provenance, statuses and references.

## Checks

Compare originals and copies, reconcile links and verify recovery before removing originals. Handle concurrent changes by keeping both versions. Do not modify Issues, PRs, the Wiki or the Git past.

## Delivery

Transferred, kept, ambiguous and unverified; manifest, evidence, tracker and relevant Sync.

## Related prompts

- DAT01: Migrate schema and data with verifiable comparison and recovery.
- MEM01: Align local instructions, context, memory and tracker.
