# MEM04 — List and describe the tracker tasks and the problems they solve

> **Scope**: repo/area | **Mode**: read | **Needs**: repository dossier tracker | **Example**: `sb prompt MEM04: list the tracker tasks and problems`

## Purpose

Present in a structured and understandable way the tasks tracked in the repository's tracker, highlighting the real problem each one solves, its dependencies and status. It describes the tracker as it is: to compare it with the real code use REP08, to run a task REP01.

## When to use

At the start of a batch of work, during a status review with the user or before picking the next task to tackle.

## Input

Dossier of the current repository with a verified tracker.json, context.md and a brief or task description.

## Activities

Read the tracker declared by repository.json with no fallback. Group the tasks by status (open, in progress, blocked, done). For each task summarize the goal, the practical problem solved, the acceptance criteria and the blocking dependencies. Do not duplicate tasks or treat hypotheses as facts.

## Checks

Make sure the identifiers match the tracker schema, that the dependencies cited exist and that blocked tasks give the real reason.

## Delivery

A clear overview ordered by priority, immediately showing which tasks are ready to execute and which wait to be unblocked.

## Related prompts

- MEM01: Align local instructions, context, memory and tracker.
- MEM06: Read active memory, context and tracker of the current repository.
- REP08: Inspect the repo and find leftover tasks against the real code.
- REP01: Complete the next ready task of the open repository.
