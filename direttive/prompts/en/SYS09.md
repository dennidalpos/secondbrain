# SYS09 — Run the deterministic compressed backup and verify the SHA-256 digests

> **Scope**: central | **Mode**: write | **Needs**: active configuration and backup runtime root | **Example**: `sb prompt SYS09: run a deterministic backup and validate the sha-256 manifest`

## Purpose

Run and validate the deterministic compressed backup of SecondBrain's local data.

## When to use

Before architectural changes, directive updates, migrations or at the end of significant sessions.

## Input

Local PARA tree (01-projects/, 02-areas/, 03-resources/, 04-archives/), local indices and .runtime/hosts.

## Activities

Invoke scripts/backup.ps1 to produce a deterministic compressed archive safeguarded under .runtime/backups/. Generate the manifest with the SHA-256 cryptographic digests of every included file.

Validate the archive through scripts/backup.ps1 -Verify, checking the structural integrity of the ZIP file and the exact match of every computed hash.

## Checks

Check that the archive contains all the declared dossiers and the host configurations. Make sure temporary files, build caches or sockets were not included. Check that -Verify returns a positive result.

## Delivery

Path of the generated archive, SHA-256 digest of the package and of the contents, count of protected files and integrity result.

## Related prompts

- SYS04: Check or align the workstation's already managed assets.
- MEM06: Read active memory, context and tracker of the current repository.
