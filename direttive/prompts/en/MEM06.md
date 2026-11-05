# MEM06 — Read active memory, context and tracker of the current repository

> **Scope**: repo | **Mode**: read | **Needs**: checkout of the open repository | **Example**: `sb prompt MEM06: load the repository context and memory within budget`

## Purpose

Load the repository's active memory, summary context and tracker within the context budget. This is the initial load: to list the tasks in detail use MEM04, to cross-check them with the real code REP08.

## When to use

At the start of a session or before planning and making changes in the current repository; also to measure the initial package against the cap or to consult the central PARA by identity and path.

## Input

Local repository, AGENTS.md file, repository dossier with context.md, memory.md and tracker.json.

## Activities

Resolve the associated dossier by checking para.json and repository.json. Read index.md and load the summary context, essential memory and the open projection of the tasks in the lean profile (30,000 characters, first load only); the rest is requested with `knowledge.ps1 -Startup -Profile Full` or `-Search`, with no cap. Consult the authoritative tracker source with no fallback. Do not create stubs or redundant memories.

To measure the initial package use `knowledge.ps1 -Startup -Report`: characters per part (not tokens), saturation against the 30,000 of the lean profile and the weight of the directives; the full context (`-Profile Full`) has no cap. If the package exceeds the cap, reorganize the levels or plan the conservative compaction SYS05.

To find other dossiers, areas or resources of the central PARA, resolve identities and paths from `para-index.json` or `scripts/para.ps1 -Check`, read `para.json` and `brief.md` without inferring from the file system, tell active entities from retired or archived ones, and do not reactivate archives or create undocumented links between independent areas.

Load deep dives and history only when actually needed. Keep distributable code separate from internal memories; preserve personal files and local differences that are not authorized for modification.

## Checks

Check that the dossier paths are valid and do not come from archives. Make sure the essential information has not been truncated and that the declared tracker is valid. Check the consistency between `para-index.json` and the `para.json` files on disk and that the character count excludes deep dives, logs and historical archives.

## Delivery

A summary picture of the repository's state, relevant open tasks, observed constraints and the plan for the agreed batch; if requested, character count per part with saturation percentage and the PARA entities found with path and status.

## Related prompts

- MEM01: Align local instructions, context, memory and tracker.
- MEM04: List and describe the tracker tasks and the problems they solve.
- REP08: Inspect the repo and find leftover tasks against the real code.
