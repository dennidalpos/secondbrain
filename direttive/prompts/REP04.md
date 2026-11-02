# REP04 — Remove leftovers and unused code after verification

> **Scope**: repo/area | **Mode**: write | **Needs**: proof of no references and green tests | **Example**: `remove temporary files and orphaned build caches`

## Purpose

Remove files, code, configuration, branches or worktrees only after showing that they are superfluous and that recovery is possible.

## When to use

For requested cleanup of files, code, configuration, branches or worktrees.

## Input

Scope, real Git state, references and the data to preserve.

## Activities

Check consumers and dependencies; for branches and worktrees check changes, commits and unique work. Arrange a verifiable recovery for the data involved. Folder names and ignored status are hints, not proof that something can be deleted.

Cleaning backups, builds, caches, fixtures and captures requires an explicit request with a concrete scope. Use manifests and hashes; no automatic destructive retention. Directory names do not authorize deletions. Keep the artifacts when cleanup is not requested.

## Checks

Use the preview of the tools available, check absolute targets and back up before removals. Check the diff and the features involved; keep official artifacts.

## Delivery

Items removed, proof of non-use and of recovery, leftovers preserved with the reason.

## Related prompts

- DEV03: Refactor code preserving contracts: targeted, phased or periodic.
- REP10: Align .gitignore and .gitkeep with the real structure and files.
