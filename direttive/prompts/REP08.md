# REP08 — Inspect the repo and find leftover tasks against the real code

> **Scope**: repo/area | **Mode**: read | **Needs**: working tree, recent history and any backlog or notes | **Example**: `inspect the repo and detect leftover tasks`

## Purpose

Find unfinished tasks, half-done work, untracked technical debt and discrepancies between what the notes or backlog declare and the repository's real code. It does not just list the backlog nor load context: it compares what is declared with what exists.

## When to use

At the start of a new session, before planning a batch of work, during a handover or when earlier work is suspected to have been interrupted.

## Input

Working tree and Git index, recent commit history, the backlog and any notes or project documentation, and any transient files or leftover notes.

## Activities

Inspect the Git state: working tree, staged but uncommitted files, untracked files or orphaned local branches. Search the source for traces of work left half-done, such as `TODO`, `FIXME`, `HACK`, `XXX` markers, unimplemented exceptions (`NotImplementedException`), empty stubs, disabled tests (`@Ignore`, `[Ignore]`, `Skip`, `.skip()`) or temporary mocks.

Read the backlog and any notes: cross-check each open item, technical promise or known pitfall against the real files, classes and tests. Check whether a task was partly done without being documented, or completed without the backlog being updated. Distinguish rigorously facts verified in the code from mere statements.

## Checks

Check that the files or symbols reported as unfinished really exist and in what state; find out whether partial changes break the build or the test suite. Check that the leftovers found are not already in the backlog under another identifier, to avoid duplicates.

## Delivery

A structured report with: work in progress or half done, leftovers and technical debt in the code (with paths and lines), discrepancies with the notes and backlog, and a concrete proposal of prioritized work items to record.

## Related prompts

- COM01: Explore the repository and identify main components and commands.
- REP01: Complete the next ready task of the open repository.
