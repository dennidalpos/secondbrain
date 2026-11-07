# Portable workstation setup

[Retained Italian source; use this English page for current behavior](portable-brain.it.md)

SecondBrain resolves its root from the running checkout and optional user-local SECONDBRAIN_HOME. It does not require a hard-coded personal path, silently install prerequisites or install a background monitor.

<a id="configurazione-e-prerequisiti"></a>

## Prerequisites and discovery

Use Windows, PowerShell 7.5+ and Git 2.42+. Inspect the actual version with pwsh and git before activation. Source approval hashes in direttive/approved.json must match the approved text before distribution.

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots C:/Projects -Interactive
~~~

Interactive Setup performs preflight, discovery and preview before confirmation and application. Without explicit roots discovery may visit accessible fixed volumes, so bounded roots are preferable. Known system and build trees are excluded and coverage and errors are reported. Metadata discovery leaves authentication stores alone. For team activation and workstation storage, see the [shared-root procedure](shared-brain.md).

Discover can save a runtime report; MaxDirectories/ResumePath support bounded resumable discovery. New checkouts are not managed until selected. Raw discovery contains host paths and must not be published.

## Selection and activation

| Option | Purpose |
|---|---|
| Roots / MaxDirectories | Bound discovery |
| Select / All | Select confirmed repository candidates |
| Ides / AllIdes | Select confirmed client integrations |
| ApproveExistingBlocks | Record review of differing existing managed blocks |
| Yes | Record noninteractive confirmation already obtained from the user |
| Apply | Perform the confirmed selection instead of preview |
| RegisterEnvironment / NoRegisterEnvironment | Explicitly control user-root registration |
| AndSync | Synchronize on applied setup; disable only deliberately |

Preview the current command and selection; do not treat flags as authorization. Activate SelectionPath is the lower-level path for a confirmed selection with matching report/fingerprint hashes. Outdated selections are refused. Setup Status reads current bindings/integrations/receipt.

New dossiers start with an English context template. Slim startup, compaction and memory-cycle promotion recognize the four required context headings in English or Italian. New dossiers can start with an empty tracker only if no existing authoritative tracker source needs explicit import. Conversion/import and adoption of old memories remain separate reviewed actions. RegisterEnvironment behavior is explicit; restart IDEs to pick up user-environment changes.

## Configuration and identity

Workstation state, inventory, backups and selection receipts live under .runtime/hosts/<id>. repository.json and PARA establish dossier identity; configuration binds actual checkouts. Use ConfigPath for an explicit configuration override, not an example file as authority to manage assets.

Spaces are supported when paths are quoted. Missing SECONDBRAIN_HOME does not prevent direct checkout bootstrap, but the pre-push hook needs a resolvable brain/runtime. Moving a real workstation configuration requires reviewed setup/reconciliation; aliases are not automatically relocation.

A Git push does not synchronize ignored dossiers/runtime. Shared-root access is a separate [deployment/qualification model](shared-brain.md), not a private-Git synchronization mechanism.

## Operations, output and recovery

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
~~~

Check may integrate already-authorized pending dossier writes. Sync writes approved blocks and generated views, reporting dirty/conflicting files rather than forcing them. File alignment, profile/account observation and live loading are separate outcomes.

SecondBrain work folders use work Init with category, slug, manifest and session. Product agents keep build output, caches, temporary files, fixtures and evidence in Git-ignored local folders of the product checkout. The product agent verifies any tool-specific paths. Preserve test runs and recovery records.

Slim defaults to 30,000 characters for first load and explicitly selected tasks; Full has no default budget. Search defaults to 20 matches/10,000 characters unless overridden. Compact previews a candidate; Apply needs review/confirmation and preserves originals by hash.

MCP is optional and exposes eight tools through stdio. Use Pair preview before Apply; default startup/reads may process pending writes. For strict read-only knowledge use NoRecovery. Publication, source collection, task import and memory-cycle permission each retain their own contracts.

See [safe writes](safety-backups.md), [MCP](mcp-setup.md), [trackers](trackers.md), [runtime](runtime-maintenance.md).
