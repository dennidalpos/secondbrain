# SEC09 — Wipe remote GitHub history and artifacts after a data exposure

> **Scope**: repo | **Mode**: write | **Needs**: explicit request, verified backup and administrative access to the remote | **Example**: `wipe the remote history, runs and caches after the exposure`

## Purpose

Remove from the GitHub remote the history and artifacts that expose sensitive data and bring the repository back to a clean state, after the credentials have been rotated.

## When to use

Only on explicit request, after a confirmed exposure (SEC08, SEC07). The operations are destructive and irreversible for the remote.

## Input

Repository, the user's authorization for each destructive step, a verified backup, the list of secrets to rotate and the history to keep, if any.

## Activities

First rotate or revoke the exposed credentials: cleanup does not make an already published secret safe. Then, in order and with confirmation for each step: 1) a verified local backup (mirror and inventory of branches, tags, releases and issues); 2) choice of strategy: targeted rewrite with `git filter-repo`, a new history with an orphan branch and a single commit, or re-creating the repository; 3) update the remote references with `--force-with-lease` and delete leftover branches and tags; 4) delete workflow runs and logs, artifacts, Actions caches, releases and the assets involved (`gh run delete`, `gh cache delete`, the API); 5) a request to GitHub support for `refs/pull` references and objects that cannot be deleted by yourself; 6) notify owners of forks and clones so they re-clone. Check first that the tools are available (`gh`, `git filter-repo`): if one is missing, propose the alternative (orphan branch or re-creation) without installing anything without authorization. Show every command as a preview before running it. Do not perform any destructive operation without an explicit request from the user in the current message.

## Decisions to collect

- strategy: targeted rewrite, new history or re-creating the repository;
- branches, tags and releases to keep;
- explicit confirmation for every destructive step.

## Checks

Repeat SEC08 to show what is no longer reachable, compare the tree of the new state with the expected one and run SEC07 on the result. State what cannot be verified: third-party copies, caches and unreachable objects until GitHub removes them.

## Delivery

Actions performed with their outcome, state before and after, credentials rotated, residual exposures and manual steps (request to GitHub support).

## Related prompts

- SEC08: Check whether sensitive data is still reachable on the GitHub remote.
- SEC07: Check diff, repository and history for sensitive data before publishing.
- SEC04: Find exposed credentials and verify input validation.
