# SYS05 — Compact the dossier preserving originals, facts and TOC

> **Scope**: central | **Mode**: write | **Needs**: dossier to compact and verifiable history | **Example**: `sb prompt SYS05: compact the dossier history preserving facts and toc`

## Purpose

Reduce the initial context without losing originals, decisions and the possibility of deeper reading.

## When to use

On explicit request sb compatta, or during sb allinea for dossiers over budget.

## Input

Dossier identified by PARA, current sources, open tasks and the 30,000-character cap for the lean startup.

## Activities

Read index.md and the necessary sources. Apply the minimal-summary rule recording only key operations, active decisions, constraints, open problems and the next step; do not renew historical authorizations. Move details to knowledge or history and update the links. If the environment supports Function Calling or Tool Use (e.g. `ask_question`), use it to submit to the user the confirmation of the scope and of the compaction options. Prepare in .runtime a JSON candidate schema 1 with repository, sources (context.md and memory.md: SHA-256), summaries (full text for both), openTaskIds, reviewed=true and a reasoned reviewNote. The context must have the sections Stato corrente, Vincoli, Problemi aperti, Prossimo passo. Use knowledge.ps1 -Compact -Dossier -CandidatePath first as a preview and then -Apply. The originals are kept by hash. Do not truncate to meet the budget and do not delete archives.

## Decisions to collect

- dossier to compact (multiple choice) and budget to reach;
- information to keep in the summary and confirmation of the candidate before `-Apply`.

## Checks

Compare essential facts before/after; verify originals byte for byte, open tasks, schema, links and TOC. Measure characters, do not present an estimate as an exact token count. Details on request must remain reachable.

## Delivery

Summary and TOC, manifest of the originals, size before/after and any budget not reached.

## Related prompts

- MEM01: Align local instructions, context, memory and tracker.
- MEM03: Close the session: memories, tracker, handoff and commit and push request.
- SYS04: Check or align the workstation's already managed assets.
