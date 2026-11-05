# SYS02 — Check authoritative sources; acquire or update on request

> **Scope**: central | **Mode**: verify | **Needs**: PARA resource-authoritative-sources registry | **Example**: `sb prompt SYS02: check regulatory updates in the sources registry`

## Purpose

Keep central references reliable without implicitly adopting requirements.

## When to use

In central maintenance of the registry; the default check is read-only.

## Input

The resource-authoritative-sources resource, cards, versions and requested scope.

## Activities

Resolve the registry from PARA and check its metadata. Use sources.ps1 -Check for local checks and -Probe for registered endpoints. Only when collection or alignment is requested, keep candidates with -Collect and update the views with -BuildIndex, respecting rights and provenance.

No monitor or periodic check. Probes and acquisitions happen only on request; reports, caches and conversions stay under SecondBrain/.runtime and are never deleted automatically.

## Checks

Tell accessibility, transcription, applicability and implementation apart. Check dates, versions and specific requirements; flag incomplete coverage. Do not qualify or run product tasks; common rules only through proposal and approval.

## Delivery

Sources checked, changes, limits, impact and references for product agents; no conformity attestation.

## Related prompts

- COM03: Find official sources that fit the technical problem.
- SYS01: Check the IDEs; map, register accounts or realign on request.
- SYS16: Update a skill from authoritative sources and verify the diff.
