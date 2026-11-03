# SYS10 — Roll back and decommission a repository, returning its data for privacy

> **Scope**: central | **Mode**: write | **Needs**: repository dossier, target checkout and user consent | **Example**: `sb prompt SYS10: roll back the decommissioned repository and clean up the data`

## Purpose

Return all the knowledge and data archived in SecondBrain to the repository they belong to, removing every central residue for maximum privacy protection and tracking the repository as forbidden.

## When to use

On explicit user request to decommission, forbid or revoke a repository from SecondBrain's perimeter without any loss of information.

## Input

Identifier or path of the repository, associated PARA dossier, path of the target checkout and the user's explicit confirmation.

## Activities

Check that the repository's checkout is reachable. Create the protected `.secondbrain/` folder inside the target repository and transfer into it `brief.md`, `context.md`, `memory.md`, `tracker.json`, `history/` and metadata. If present, remove the SecondBrain managed block from the repository's `AGENTS.md` to eliminate any coupling.

Fully remove the dossier folder from `02-areas/products/`. Clean up the transient and environment data in `.runtime`. Update the workstation configuration (`workstation.json`): remove the repository from the active bindings and register it in `forbiddenRepositories` to prevent its future automatic inclusion. Finally, invoke `Update-SBParaIndex` to regenerate `para-index.json` and `PARA.md`.

## Checks

Make sure all the knowledge files were moved into the owning repository under `.secondbrain/`. Check that `AGENTS.md` is clean and contains no managed markers. Verify that the dossier folder in SecondBrain no longer exists and that the PARA index contains no orphan references. Verify that `secondbrain.ps1 -Check` does not flag the repository.

## Delivery

Decommissioning report with the paths involved, list of transferred files, confirmation of the central dossier's removal and the entry in the forbidden-repositories list.

## Related prompts

- SYS03: Activate SecondBrain after discovery and asset selection.
- SYS04: Check or align the workstation's already managed assets.
- SYS05: Compact the dossier preserving originals, facts and TOC.
