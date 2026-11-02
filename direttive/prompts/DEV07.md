# DEV07 — Triage and reproduce an issue before fixing it, without changing code

> **Scope**: repo/area | **Mode**: read | **Needs**: issue text, environment and read access to the code | **Example**: `triage and reproduce the path parsing issue`

## Purpose

Assess a report before acting on it: type, severity, completeness, duplicates and reproducibility, to decide whether and how to work on it.

## When to use

When a new issue or an unverified error report arrives. To fix a defect that is already reproducible use DEV02; to find the root cause from logs COM05.

## Input

Issue text, declared reproduction steps, versions and environment, logs or attachments, issues and tasks already tracked.

## Activities

Classify the report (defect, request, question, out of scope) and estimate its severity and impact. Look for duplicates among issues and the backlog and use REP08 to check whether the leftover is already known. Attempt a minimal reproduction in the stated environment without modifying code, configuration or real data; if it cannot be reproduced, separate static diagnosis from evidence and say what information is missing. Do not close or comment on issues in external systems without an explicit request.

## Decisions to collect

- proposed classification and priority;
- outcome: fix now (DEV02), track in the backlog, ask for information or discard.

## Checks

Make sure the reproduction is shown with commands and output or declared unsuccessful with the reasons. Distinguish observed facts, hypotheses and preferences.

## Delivery

Triage note with classification, severity, duplicates, reproduction outcome, missing information and recommended action; no changes to the code.

## Related prompts

- DEV02: Reproduce a defect and fix its cause.
- REP08: Inspect the repo and find leftover tasks against the real code.
- PRG01: Turn a request into requirements and acceptance criteria.
- COM05: Analyze logs and incidents to find the root cause, without changing code.
