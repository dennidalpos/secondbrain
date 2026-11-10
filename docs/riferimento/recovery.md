# Cleanup and recovery

[Retained Italian source; use this English page for current behavior](recovery.it.md)

Preserve backups, reports, builds, caches, captures and fixtures after success or failure. The current test runner retains unique runs and run.json; older descriptions of automatic successful-fixture deletion are superseded.

## Inspect before cleanup

~~~powershell
pwsh -NoProfile -File scripts/cleanup.ps1 -ListRuntime -OlderThanDays 90
pwsh -NoProfile -File scripts/cleanup.ps1 -ListStageRecords -OlderThanDays 90
pwsh -NoProfile -File scripts/access.ps1 -Status
~~~

ListRuntime reports age, size, references and protection without following reparse points. Reviewable means investigate, not remove. ListStageRecords selects readable completed records older than the threshold; interrupted staging and binary backups are not automatic candidates.

A reviewed cleanup manifest identifies schemaVersion, reviewed/referencesChecked, reason and exact absolute file paths/SHA-256. It describes selection; user authorization remains separate. Preview with ManifestPath; Apply additionally requires Authorization and rechecks bytes, paths, protected data and pending transactions.

Cleanup does not decide from age alone or delete checkouts. Partial failure reports removed/failed entries; preserve recovery records. No cleanup belongs to an ordinary documentation task.

## Restore a file

~~~powershell
pwsh -NoProfile -File scripts/restore-managed.ps1 -List -Path "$HOME/.claude/CLAUDE.md"
~~~

Select the verified metadata record, then pass MetadataPath to restore-managed. Previous/deployed hashes and payload are checked. Later target edits are refused. Clean tracked originals are recoverable from recorded commit/blob; local originals use binary backups. Do not reset current work to make a restore succeed.

## Interrupted transactions

.runtime/access/para-transaction.json identifies an unfinished transaction and blocks central writes. Status reports owner, time and manifest. Another host can recover only when it reaches the validated manifest through a verified brain alias.

~~~powershell
pwsh -NoProfile -File scripts/recover.ps1 -ManifestPath $manifestPath
~~~

Apply only after reviewing the preview under the relevant authorization. Recovery validates every destination before writes, reverses recorded operations and preserves originals. Later edits are not overwritten. It does not rewrite SECONDBRAIN_HOME.

Tracker imports have a separate import-tracker RollbackManifest procedure. A verified preparation is not yet the authoritative committed tracker.

## Repository retirement

rollback-repo previews by default. Apply exports the dossier to the product's .secondbrain area, or central backup when explicitly forced without checkout; it updates associations/state/instructions before removing central data. The brain's own checkout/dossier and ambiguous identities are rejected.

This is a separate destructive workflow. Check that private exports cannot be published. Unbind, which preserves dossiers, is different.

## Errors and qualification limits

core.write.denied returns CLI exit 4 preserving the original exception. A destination write may precede a failed final receipt: inspect target, hashes and journal before retrying. Restore access and follow normal recovery; do not delete markers/staging.

Windows protected removal normalizes ordinary local/UNC paths before native extended-path access. Existing writers, lost sessions and unsupported filesystems may prevent it. Local Unicode/long-path/loopback fixtures do not certify two-PC SMB or another host's long-path policy.

Verified backup does not authorize deletion. See [safe writes](safety-backups.md), [runtime](runtime-maintenance.md), [shared brain](shared-brain.md).

Older root-level transaction markers remain detectable and recoverable; see [sandbox roots](sandbox-roots.md).
