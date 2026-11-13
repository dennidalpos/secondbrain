# Trackers and import

[Retained Italian source; use this English page for current behavior](trackers.it.md)

Resolve the active dossier by repository identity and PARA metadata. A `repository.json` declaration of `location=dossier`, `path=tracker.json` and `schemaVersion=1` makes that file authoritative. The bootstrap for a new checkout without a source tracker creates this declaration and an empty schema 1 tracker directly.

Ordinary reads of a greenfield dossier require the declaration. A missing declaration reports `tracker.greenfield.declaration.required`, a missing declared file reports `tracker.declared.missing`, and an incompatible payload version reports `tracker.schema.version`. These reads leave the files intact. An undeclared original source is discoverable for a greenfield dossier only through the explicit import workflow.

## Validation and reads

Schema 1 plus application checks validate identity/date, unique IDs, statuses, priority, dependencies and graph cycles across managed repositories. Acceptance criteria and imported statuses are data, not proof of completed work.

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -Tasks -ReadyOnly -NoRecovery -CheckoutPath C:/Projects/MyProduct
pwsh -NoProfile -File scripts/knowledge.ps1 -Task TASK-ID -NoRecovery -CheckoutPath C:/Projects/MyProduct
~~~

The working repository resolves through explicit Repository or checkout/bindings/origin. Outside a resolvable checkout the CLI errors rather than listing unrelated work. All is an explicit paginated global read, incompatible with Repository. Task lookup includes archived IDs/sequences.

ReadyOnly resolves dependencies in active and historical trackers. Only completed outcomes satisfy dependencies. Fields include status, execution, priority, acceptance, evidence, provenance and optional sequence. The allowed statuses are todo, in_progress, blocked, done, cancelled and unknown.

## Changes and history

UpdateTaskId accepts Status, StateReason, Priority, Execution, DependsOn, Stream, Awaiting, Requires, Description, Acceptance (`;`-separated), Evidence (`reference|outcome`, outcome passed, failed, partial or unverified; appended) and DecisionsFile (a JSON file of owner decisions `{question, answer}` stored in `extensions.decisions[]`). Omitted fields stay unchanged; at least one supplied field is required. DependsOn takes task IDs, `<repository>#<id>` for another managed repository, or `#<seq>` for a task of the same tracker by number, active or archived; `#<seq>` is stored as that task's ID and an unknown number is refused. Empty DependsOn clears dependencies and empty Stream removes it. Unknown tasks/repositories, invalid references, cycles and writes to another working repository are refused.

NewTask requires acceptance/provenance and a numbered tracker. Sequence is lastSeq+1; IDs/numbers are not reused. RenumberTasks previews the migration and preserves original records by hash. With pwsh File, list arguments use semicolon separation as documented by the CLI.

Every change of status, execution or evidence also appends a record to the dossier ledger `history/task-runs.jsonl` in the same transaction, with the executor. `knowledge.ps1 -Registry` lists every task of the working repository, archived ones included, with the ledger and this workstation's runner reports (filters `-Tool`, `-TaskStatus`, `-Archived include|exclude|only`, `-Filter`; pages `-Page`/`-PageSize`, default 50). `-BackfillTaskRuns` copies older runner reports into the ledger, preview unless `-Apply`.

After verified acceptance, terminal done/cancelled records move into history/tracker-archive.json with IDs, numbers, evidence and provenance intact. Tracker/archive/queued receipt share one transaction. Reopening uses the same ID explicitly. Audit-only task proposals never apply these operations.

## Import workflow

Activation (SYS03) never seeds an empty tracker over a repository's own. For a new dossier it looks in the checkout, in the resolver's order, for `tracker.json`, `tracker.md`, `tasks.json` and `legacy-tasks.json`; `tracker.md` counts by existing, a JSON file only if it parses as an object. When one is found the dossier is created without `tracker.json` or a tracker declaration, the binding gets status `tracker-import-required`, and the activation report shows `trackerSource` with the relative `path` and `compatible` (true when the file passes the schema 1 checks once its `repository` is realigned to the target identity). The import below then makes the dossier tracker authoritative.

A source that is already schema 1 passes through the conversion unchanged: IDs, `seq`, statuses, evidence, provenance, dependencies, history and its own extensions (for example `lastSeq`) stay as they are. Only `repository` is realigned to the target identity; dependencies that named the original identity become same-repository ones, and the whole original document, original `repository` included, stays in `extensions.original`.

`import-tracker.ps1 -Repository <identity> -SourcePath <path>` previews source conversion. The supplied path must match the original source identified for the dossier. Supported collections preserve values and provenance. Ambiguous statuses or dependencies become unknown and block activation. Unsupported Markdown task rows raise an error.

Preparation Apply records manifest, verified exact original, candidate and recovery payload under backupRoot. A verified candidate is not yet authoritative. Activation needs separately approved concrete migration and Activate/Apply. Source changes after preparation block resume; do not edit hashes or candidate bytes to bypass it.

Manifest phases are pending/prepared/copied/verified/references_updated/originals_removed/completed. Rollback ends in rolled_back. `-ResumeManifest` reads the recorded state and `-RollbackManifest` previews recovery before Apply. These explicit commands also accept validated pre-1.0 `tracker-migration` journals. Check and PARA safety checks still detect their registered state.

Optional ReviewPath binds repository/sourceSha256 and explicit task status/dependency decisions with reasons. Its exact bytes/hash remain in manifest/history. It classifies imported data; it does not qualify application acceptance.

<a id="spostamenti-para"></a>

## PARA moves and diagnostics

Archive/Restore update registered operational references in the same transaction while preserving original payload hashes. Pending import phases prevent moves. Completed/rolled-back imports may move; a later tracker edit can still prevent rollback. A move is never implicit authorization to archive/restore.

Diagnostics separate stable code and localized message. Historical source text/provenance remain original. HistoryMessages is a derived language view; MigrateHistoryMessages previews then preserves originals on authorized Apply. This is not compaction.

Check validates declared sources, project references and registered migration state; it does not check all remote URLs/anchors or resolve GitHub exposure. A prepared import remains incomplete work.

Use bounded Write sessions and hash preconditions. See [deferred requests](pending-writes.md), [access](access.md), [recovery](recovery.md) and [runtime loading](runtime-maintenance.md).
