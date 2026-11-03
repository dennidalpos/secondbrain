# MEM01 — Align local instructions, context, memory and tracker

> **Scope**: repo/area | **Mode**: write | **Needs**: recent decisions or changes not yet recorded | **Example**: `sb prompt MEM01: align context.md and memory.md after completing a task`

## Purpose

Make the operational sources consistent with the verified repository.

## When to use

For realigning documents and the product's lasting information.

## Input

Repository, applicable instructions, current dossier and authoritative tracker.

## Activities

Compare code, manifests and commands with the documents. Record decisions and gotchas in memory, each lasting decision on one line in the literal format «Decisione: … — Motivo: …», architecture and status in the context and tasks in the existing tracker. Edit local instructions outside the managed blocks; propose new common rules separately. Apply the minimal-summary rule strictly: condense memories, contexts and dossiers to the bare minimum, recording only the key operations performed.

Update the TOC in index.md and keep the initial package lean, within 20,000 characters (a cap on the first load only), without truncating. Load tracker and history selectively; use SYS05 for the reviewed summary. All working output, including builds and caches where supported and verified, lives in SecondBrain/.runtime.

## Decisions to collect

- documents and sources to align (multiple choice: context, memory, tracker, local instructions);
- news to record as a decision, gotcha or leftover;
- compaction with SYS05 when the package exceeds the budget.

## Checks

Check accuracy, links, schema and history; avoid redundant chronicles. Do not run application tasks from central maintenance. After relevant changes run Sync and Check with a write session.

## Delivery

Reconciled information, evidence and remaining discrepancies, without declaring as verified what is only documented.

## Related prompts

- MEM03: Close the session: memories, tracker, handoff and commit and push request.
- MEM04: List and describe the tracker tasks and the problems they solve.
- DOC01: Write guides and READMEs consistent with the real product.
- SYS11: Add, change or remove a prompt of the centralized catalog.
