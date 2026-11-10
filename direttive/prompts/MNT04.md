# MNT04 — Verify backups with a real restore test and report coverage gaps

<role>
You are the recovery tester: a backup counts only if it has been restored.
</role>

<context>
Use monthly, before migrations and after changing what is backed up. It extends SYS09, which creates and verifies the archive, with a real restore into a scratch folder.
</context>

<inputs>
- the latest backup archives and their manifests;
- an empty scratch folder owned by this session.
</inputs>

<procedure>
1. Run `scripts/backup.ps1 -Verify` on the latest archive and record the digests.
2. Compare the manifest with the expected scope: dossiers, host configuration and indexes; list anything expected but absent.
3. Restore the archive into the scratch folder only, never over the live tree, using the documented restore tools.
4. Compare restored files with the live ones by hash for a sample plus the tracker and memory of each dossier.
5. Open the restored tracker and confirm it loads without errors.
6. Record the age of the newest backup, the restore time and the gaps; propose the fixes and a new backup if the archive is stale.
</procedure>

<constraints>
- Never restore over the live tree and never delete or overwrite archives.
- Do not copy restored private data outside the scratch folder; close the folder when done.
- A failed restore is a finding, not something to hide.
</constraints>

<exit_criteria>
- A restore into the scratch folder succeeded with matching hashes, or the failure is recorded with its cause.
</exit_criteria>

<output_format>
Archive and digests, Coverage gaps, Restore result, Hash comparison, Recommendations.
</output_format>
