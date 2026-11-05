# MEM03 — Close the session: memories, tracker, handoff and commit and push request

> **Scope**: repo/area | **Mode**: write | **Needs**: state of the work done, defined next tasks and delivery destination | **Example**: `sb prompt MEM03: close the session and ask for commit and push`

## Purpose

Let a later agent resume without reconstructing the work: updated memories and tracker, a verifiable handoff, a clear Git state and an explicit request for commit and push.

## When to use

At the end of a batch, before switching session or handing over partial work.

## Input

Goal, current authorizations, Git state (branch, remote, unpublished commits), changes, evidence, blockers and the user's decisions.

## Activities

Reconcile the actual state and the acceptance criteria, then, in order:

1. **Memories.** Update `context.md` (state, constraints, open problems, next step) and `memory.md` (lasting decisions and gotchas) with the minimal-summary rule: only key operations and verified news, with no redundant chronicles and no renewed historical authorizations.
2. **Tracker.** Set the task status after verifying the criteria: close only what is complete and proven, keep partial and blocked items with status and reason, track confirmed leftovers without duplicates. Verify that done and cancelled tasks are in the archive with their full records and only remaining work is in the active tracker. A queued request stays pending until the receipt confirms it was applied.
3. **Handoff.** Save in the dossier (`history/`) a report with work done, decisions, commands and outcomes, useful files, leftovers and the first step; link the history and the TOC without duplicating chronicles in the startup package.
4. **Alignment.** Run Sync and Check with the write session; report preserved artifacts and output configuration, without unrequested cleanups.
5. **Git state.** Show `git status --ignored`, the diff, branch, remote and unpublished commits.
6. **Delivery.** If commit and push are not already authorized, ask for them explicitly; do only what the user approved, in sequence and without a further final confirmation when both were requested. Before the push verify destination, visibility, branch, scope and checks (SEC07); no force push, reset or deletions to get a clean working tree.

## Decisions to collect

- commit: yes, no, or only some files (multiple choice on the scope);
- push: yes or no, remote and target branch;
- tasks to close, keep partial or block, and new leftovers to track (multiple choice);
- information to save in memory as a decision or gotcha (multiple choice);
- artifact cleanups: never without an explicit request and a concrete scope.

## Checks

Verify paths, diff and incomplete tasks; make sure context, memory and tracker tell the same state and that the criteria of the closed tasks are proven. Distinguish current authorizations from history: a handoff neither renews permissions nor amounts to a commit or publication.

## Delivery

Handoff in the dossier, updated memories and tracker, status of the checks, outcome of commit and push (or pending request) and a reproducible first step for resuming in a new session.

## Related prompts

- MEM01: Align local instructions, context, memory and tracker.
- PRG04: Prepare a phased plan with dependencies and checks.
- SYS04: Check or align the workstation's already managed assets.
