# Trackers and import

[Retained Italian source; use this English page for current behavior](trackers.it.md)

Resolve the active dossier by repository identity and PARA metadata. A repository.json declaration of tracker location=dossier, path=tracker.json, schemaVersion=1 makes that file authoritative. Missing/invalid declarations or payloads are errors without fallback. An undeclared original Markdown source is not automatically a valid JSON tracker.

## Validation and reads

Schema 1 plus application checks validate identity/date, unique IDs, statuses, priority, dependencies and graph cycles across managed repositories. Acceptance criteria and imported statuses are data, not proof of completed work.

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -Tasks -ReadyOnly -NoRecovery -CheckoutPath C:/Projects/MyProduct
pwsh -NoProfile -File scripts/knowledge.ps1 -Task TASK-ID -NoRecovery -CheckoutPath C:/Projects/MyProduct
~~~

The working repository resolves through explicit Repository or checkout/bindings/origin. Outside a resolvable checkout the CLI errors rather than listing unrelated work. All is an explicit paginated global read, incompatible with Repository. Task lookup includes archived IDs/sequences.

ReadyOnly resolves dependencies in active and historical trackers. Only completed outcomes satisfy dependencies. Fields include status, execution, priority, acceptance, evidence, provenance and optional sequence. The allowed statuses are todo, in_progress, blocked, done, cancelled and unknown.

## Changes and history

UpdateTaskId accepts Status, StateReason, Priority, Execution, DependsOn and Stream. Omitted fields stay unchanged; at least one supplied field is required. Empty DependsOn clears dependencies and empty Stream removes it. Unknown tasks/repositories, invalid references, cycles and writes to another working repository are refused.

NewTask requires acceptance/provenance and a numbered tracker. Sequence is lastSeq+1; IDs/numbers are not reused. RenumberTasks previews the migration and preserves original records by hash. With pwsh File, list arguments use semicolon separation as documented by the CLI.

After verified acceptance, terminal done/cancelled records move into history/tracker-archive.json with IDs, numbers, evidence and provenance intact. Tracker/archive/queued receipt share one transaction. Reopening uses the same ID explicitly. Audit-only task proposals never apply these operations.

## Import workflow

import-tracker previews source conversion. Supported original collections preserve raw values/provenance; notes do not become tasks. Ambiguous statuses/dependencies become unknown and block activation. Unsupported Markdown table/checkbox rows cause explicit errors, not a silently partial tracker. This is not a generic Markdown importer.

Preparation Apply records manifest, verified exact original, candidate and recovery payload under backupRoot. A verified candidate is not yet authoritative. Activation needs separately approved concrete migration and Activate/Apply. Source changes after preparation block resume; do not edit hashes or candidate bytes to bypass it.

Manifest phases are pending/prepared/copied/verified/references_updated/originals_removed/completed; rollback ends rolled_back. ResumeManifest reads recorded state. RollbackManifest previews recovery before Apply. Validate all payloads/destinations first and preserve later user edits.

Optional ReviewPath binds repository/sourceSha256 and explicit task status/dependency decisions with reasons. Its exact bytes/hash remain in manifest/history. It classifies imported data; it does not qualify application acceptance.

<a id="spostamenti-para"></a>

## PARA moves and diagnostics

Archive/Restore update registered operational references in the same transaction while preserving original payload hashes. Pending import phases prevent moves. Completed/rolled-back imports may move; a later tracker edit can still prevent rollback. A move is never implicit authorization to archive/restore.

Diagnostics separate stable code and localized message. Historical source text/provenance remain original. HistoryMessages is a derived language view; MigrateHistoryMessages previews then preserves originals on authorized Apply. This is not compaction.

Check validates declared sources, project references and registered migration state; it does not check all remote URLs/anchors or resolve GitHub exposure. A prepared import remains incomplete work.

Use bounded Write sessions and hash preconditions. See [deferred requests](pending-writes.md), [access](access.md), [recovery](recovery.md) and [runtime loading](runtime-maintenance.md).
