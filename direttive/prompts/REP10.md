# REP10 — Align .gitignore and .gitkeep with the real structure and files

> **Scope**: repo | **Mode**: write | **Needs**: Git state, exclusion rules and folders to preserve in the repository | **Example**: `align gitignore and gitkeep before publishing`

## Purpose

Make the exclusion rules and folder placeholders consistent with the structure the repository should have.

## When to use

After adding tools, builds, caches or local folders and before SEC07 or a publication.

## Input

`.gitignore` (root and nested), `.gitkeep`, tracked and ignored files, folders to preserve and the publication rules.

## Activities

Compare `git ls-files`, `git ls-files -ci --exclude-standard` (tracked but ignored), `git status --ignored` and `git check-ignore -v`. Find generated or private files that are not ignored, obsolete, duplicate or overly broad rules that hide legitimate files, `!` exceptions that have no effect on ignored directories, folders to preserve without `.gitkeep` and unnecessary `.gitkeep` files in folders that already have content. Show the difference before changing anything. Do not remove already tracked files from the index without confirmation: `git rm --cached` only on request and after checking that the local file stays.

## Decisions to collect

- files tracked but ignored: keep or remove from the index;
- folders to preserve with `.gitkeep`.

## Checks

Verify each new rule with `git check-ignore -v` on positive and negative examples, check that `git status` shows no private files and that no wanted file ends up ignored, and run the project's distribution checks.

## Delivery

A justified diff of `.gitignore` and `.gitkeep`, decisions on tracked-but-ignored files and leftovers.

## Related prompts

- REP04: Remove leftovers and unused code after verification.
- SEC07: Check diff, repository and history for sensitive data before publishing.
- SEC05: Verify personal data isolation and compliance with GDPR and policies.
