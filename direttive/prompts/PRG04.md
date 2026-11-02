# PRG04 — Prepare a phased plan with dependencies and checks

> **Scope**: repo/area | **Mode**: read | **Needs**: agreed requirements and scope of the work | **Example**: `plan the migration in three atomic releases`

## Purpose

Prepare a workable plan without leaving substantial decisions implicit.

## When to use

For complex work, multiple changes or a planned resumption.

## Input

Goal, authorized scope, current state and completion criteria.

## Activities

Explore the code before planning. Define ordered phases, prerequisites, interfaces, risks, checks and proportionate recovery conditions. Clarify substantial choices that cannot be deduced from the files.

## Checks

Check that every phase contributes to the goal and has a verifiable outcome. Do not implement and do not update the backlog unless explicitly asked.

## Delivery

Complete plan with dependencies, acceptance criteria, assumptions and limits.

## Related prompts

- PRG01: Turn a request into requirements and acceptance criteria.
- PRG05: Scaffold new modules with structure, configuration and tests.
- REP01: Complete the next ready task of the open repository.
- PRG06: Plan a phased architectural refactoring with checks and rollback.
