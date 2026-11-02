# OPS05 — Prepare commits and pull requests with verified scope, message and checks

> **Scope**: repo | **Mode**: write | **Needs**: local changes to deliver and an explicit request for a commit or pull request | **Example**: `prepare the commits and the pull request description`

## Purpose

Prepare the delivery of local changes: a verified scope, messages consistent with the repository history and a pull request description grounded in evidence.

## When to use

When the user explicitly asks for a commit or a pull request. Commits and pushes are never implicit. To check whether the content is safe to publish use SEC07.

## Input

Git working tree and index, branch and target, message conventions in the recent history, results of the project's checks.

## Activities

Examine `git status` and the full diff, separating the relevant changes from unrelated work, generated files, leftovers and private data or secrets. Propose a scope for atomic commits and prepare messages in the style of the recent history. Before creating the commit run the project's relevant checks. For the pull request write the title and description with the motivation, changes, evidence and limits, without including internal data. Do not use reset, force options or history rewriting, and do not skip checks or hooks.

## Decisions to collect

- files and changes to include in the commit, also when there is unrelated work;
- branch, target and repository visibility before a push or pull request.

## Checks

Check that the index contains only the agreed scope, that the relevant checks pass and that no secrets or private data appear. After the operation check the outcome with `git status` and `git log`.

## Delivery

Commits created or proposed with message and scope, the pull request description, checks run, changes left out with the reason and any blockers.

## Related prompts

- SEC07: Check diff, repository and history for sensitive data before publishing.
- REP04: Remove leftovers and unused code after verification.
- REP01: Complete the next ready task of the open repository.
