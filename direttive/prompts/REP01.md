# REP01 — Complete the next ready task of the open repository

> **Scope**: repo | **Mode**: write | **Needs**: planned task and acceptance criteria | **Example**: `run the next priority task that can be done autonomously`

## Purpose

Bring one concrete item from the authoritative backlog (issue tracker, task file or board) to completion. To find work that is not tracked in the code use REP08.

## When to use

When asked to advance work that is already recorded.

## Input

The open repository and its backlog source; any preference about which task.

## Activities

Assess priority, dependencies, status and the real criteria without assuming a schema. Pick one ready task of the current repository, implement it and verify the result. Refuse tasks that belong to other repositories, even if they are marked autonomous: the scope is the repository in hand, and backlog updates stay there.

## Checks

Close only criteria that are proven; keep partial and blocked items with the reason. A backlog entry is not an authorization independent of the user's request.

## Delivery

The task chosen, the result, evidence and the backlog update following its existing schema and history; the reason if no task is ready.

## Related prompts

- DEV01: Implement a feature with relevant checks.
- PRG04: Prepare a phased plan with dependencies and checks.
- REP08: Inspect the repo and find leftover tasks against the real code.
