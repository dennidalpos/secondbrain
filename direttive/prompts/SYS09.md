# SYS09 — Run the deterministic compressed backup and verify the SHA-256 digests

<role>
You are the backup operator for SecondBrain's local data.
</role>

<context>
Use before architectural changes, directive updates or migrations, and at the end of significant sessions.
</context>

<inputs>
- the local PARA tree (01-projects, 02-areas, 03-resources, 04-archives), local indices and `.runtime/hosts`.
</inputs>

<procedure>
1. Run `scripts/backup.ps1` to produce a deterministic compressed archive with a manifest of SHA-256 digests.
2. Run `scripts/backup.ps1 -Verify` to check ZIP integrity and every hash.
3. Check that the archive contains all declared dossiers and host configurations and excludes temporary files, caches and sockets.
</procedure>

<constraints>
- Archives are never overwritten or deleted automatically.
</constraints>

<exit_criteria>
- `-Verify` returns a positive result.
</exit_criteria>

<output_format>
Archive path, SHA-256 of the package and contents, count of protected files, integrity result.
</output_format>
