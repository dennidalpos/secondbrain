# SYS04 — Check or align the workstation's already managed assets

> **Scope**: central | **Mode**: verify | **Needs**: workstation configuration and approved directives | **Example**: `sb prompt SYS04: check directive alignment in the managed repositories`

## Purpose

Check and align the brain and the integrations without implicitly widening the scope.

## When to use

sb controlla for verification only; sb allinea to correct the already approved assets.

## Input

Locally resolved host configuration, dossiers and approved directives.

## Activities

Rerun the host discovery and compare the assets with the approved associations. Run -Check. For sb allinea use -Sync, applying only approved texts and preserving conflicts. Where there are divergences, propose the corrective options through Function Calling or Tool Use (e.g. `ask_question`). Propose new assets through SYS03. For every dossier over budget, prepare a reviewed summary with SYS05, apply it and repeat the check. The CLI does not invent summaries automatically. Do not run application tasks, builds or tests of the products from central maintenance. Check the sources with SYS02 on request, with no scheduling. No deletion of artifacts.

## Decisions to collect

- correction to apply for each divergence (align, keep the conflict, defer);
- new assets to propose with SYS03 and dossiers to compact with SYS05 (multiple choice);
- IDEs or accounts whose loading must be rechecked after a login change.

## Checks

Check TOC, task projections, references, hosts, accounts and loading. Do not equate aligned files with verified sessions. Do not declare the scan complete if areas remain unread.

## Delivery

Distinct outcomes per asset and coverage; actual changes, conflicts and activities still needed.

## Related prompts

- SYS01: Check the IDEs; map, register accounts or realign on request.
- SYS03: Activate SecondBrain after discovery and asset selection.
- SYS05: Compact the dossier preserving originals, facts and TOC.
- SYS11: Add, change or remove a prompt of the centralized catalog.
