# SYS13 — Set or remove the greenfield lock (versions, changelog, migrations, aliases)

> **Scope**: repo/area | **Mode**: write | **Needs**: managed repository, active dossier and user confirmation | **Example**: `sb prompt SYS13: set or remove the greenfield lock on this repository`

## Purpose

Set or remove the greenfield lock of a repository. With the lock active, agents and scripts do not introduce version numbers, CHANGELOG entries, migrations or schema imports, compatibility aliases and `deprecations` (flag `lifecycle: greenfield` in the dossier's `repository.json`). Without the lock the normal version, CHANGELOG and migration cycle provided by the directives applies again.

## When to use

Set the lock for a new or rewritten project, with no existing users to protect and where backward compatibility is not a constraint. Remove it when the project has users to protect or is about to be released. Not needed for already released products, where the directives' version rule applies (number proposed as multiple choice).

## Input

Managed repository with an active dossier (SYS03), requested operation (set or remove), the user's explicit confirmation of what the lock forbids and any files already present (`VERSION`, `CHANGELOG.md`, aliases) to evaluate. Removal is not retroactive: it creates no versions, CHANGELOG entries or migrations.

## Activities

From the repository's checkout set the flag with the script, under lock and only for the repository being worked on: `pwsh -NoProfile -File scripts/knowledge.ps1 -SetLifecycle greenfield` to set, `-SetLifecycle none` to remove. Do not edit `repository.json` by hand.

With the lock active, prompt composition and `secondbrain.ps1 -Check` flag the violations: uncommitted changes to `VERSION`, new entries in `CHANGELOG.md`, registered schema imports or migrations, compatibility aliases in `repository.json` and `deprecations` in the catalog (SecondBrain only). The comparison is against HEAD: an already committed change is not flagged. The lock deletes nothing existing and does not authorize commit or push.

On removal the directives' version rule applies again: when the changes justify it, propose the number and ask with multiple choice whether to change it. The violations flagged before removal remain to be evaluated with the user.

## Decisions to collect

- operation: set or remove the lock;
- repository to apply it to, if it is not the one being worked on;
- confirmation of what the lock forbids, or that compatibility, versions and migrations are managed again;
- how to treat the already present `VERSION`, `CHANGELOG.md` and aliases and whether to start the proposal of a first version right away.

## Checks

The script's outcome reports `lifecycle: greenfield` (set) or an empty `lifecycle` (removed); `prompts.ps1 -Compose` shows or no longer shows the block in the local references; `secondbrain.ps1 -Check -Repository <identity>` contains no `greenfield-violation` or lists them as known residues.

## Delivery

Flag state, violations already present or remaining, list of what is now forbidden or allowed again and decisions on the version. No implicit commit or push.

## Related prompts

- MEM01: Align local instructions, context, memory and tracker.
- SYS04: Check or align the workstation's already managed assets.
