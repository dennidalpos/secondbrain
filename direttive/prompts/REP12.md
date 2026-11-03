# REP12 — Consolidate branches with a --no-ff merge and delete the integrated ones

> **Scope**: repo | **Mode**: write | **Needs**: local and remote branches, the base branch and a clean working tree | **Example**: `consolidate the finished branches into master`

## Purpose

Bring finished work from side branches into the base branch with a traceable merge commit and remove the branches that are fully integrated, without losing unique work.

## When to use

When side branches, worktrees or forks of the work have accumulated and the base branch must collect them before a release or a cleanup.

## Input

`git branch -a -vv`, `git worktree list`, the base branch, the merge order requested and the branch protection or review rules of the remote.

## Activities

Before merging, record the state: working tree and index clean, current branch, `git fetch`, divergence of each branch from the base (`git rev-list --left-right --count`), commits unique to each branch and whether each is already contained (`git branch --merged`). Run the project's checks on each branch you intend to merge. Merge one branch at a time with `git merge --no-ff`, in the agreed order, stopping at the first conflict to resolve it with the user; never rebase, squash or force-push on your own. After every merge run the relevant checks and compare the result with the state recorded before. Delete a branch (`git branch -d`, remote `git push --delete`) only after confirmation and only when `git branch --merged` proves it is integrated; a branch with unique work or a worktree in use is kept and reported.

## Decisions to collect

- branches to merge and their order;
- branches to delete, local and remote, after the merge;
- how to resolve a conflict.

## Checks

Check before and after the merge that the working tree is clean, that the base branch contains every merge commit, that the project's checks pass, that no unique commit was lost (`git log` against the previous tip) and that the deleted branches were integrated. Nothing is pushed without a specific request.

## Delivery

The merge commits created, the branches deleted and kept with the reason, the checks run and anything left to the user.

## Related prompts

- OPS05: Prepare commits and pull requests with verified scope, message and checks.
- REP04: Remove leftovers and unused code after verification.
- REP10: Align .gitignore and .gitkeep with the real structure and files.
