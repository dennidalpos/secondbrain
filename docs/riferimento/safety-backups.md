# Safe writes and backups

[Retained Italian source; use this English page for current behavior](safety-backups.it.md)

Review command effects first. Ordinary synchronization does not edit product source, but instructions and selected MCP configurations may be written outside the clone.

## Operation boundaries

| Operation | Behavior |
|---|---|
| knowledge lookup with NoRecovery | No deferred-write integration |
| Default knowledge/prompt/Check/MCP read | May integrate already-authorized dossier requests |
| Discover / Setup preview | May save runtime discovery/selection reports |
| Setup/Activate Apply | Selected host configuration/new dossiers; optional environment registration |
| Sync | Immediate approved-block/local-view updates |
| Unbind | Preview, then confirmed association changes; dossiers preserved |
| Pair | Preview, then selected client changes with Apply |
| Revision approval | Source/approval writes after concrete-text approval |
| Hook install/remove | Selected Git hook after separate authorization |
| Cleanup/recovery/rollback | Preview first; respective Apply authorization required |
| Backup | Local knowledge/runtime archive, not an IDE-wide backup |
| ExportPackage | Managed writes into a new directory below `.runtime`; existing destinations are refused |
| work Run | Executes the explicitly supplied program |

Preview does not always mean zero runtime writes. Use strict NoRecovery knowledge/server entrypoints when all writes are prohibited.

## Configuration targets

Inspect Pair output for the actual client/profile path. Codex uses its selected config.toml; Claude Desktop uses desktop/profile configuration; Claude Code supports native user registration or explicit workspace .mcp.json. VS Code supports user/profile or workspace .vscode/mcp.json. Other supported adapters have their own paths.

Unrelated configuration is preserved where the supported format allows it. Invalid/unsupported input stops a write; Codex replaces the secondbrain server section. JSON comments/formatting limitations and native CLI registration are detailed in [MCP setup](mcp-setup.md). File creation does not prove a client is installed or loaded.

## Recovery records

| Record | Meaning |
|---|---|
| <guid>.stage | Target, Windows user, UTC start time, previous and intended SHA-256, staging path and write state |
| <guid>.bin / .bin.json | Exact local original and previous/deployed hashes |
| <guid>.git.json | Clean tracked original verified byte for byte against Git checkout output, with commit and blob IDs |
| Transaction manifest | Coordinated file changes and rollback journal |

Workstation backupRoot normally resides under .runtime/hosts/<id>/backups; MCP pairing also has .runtime/backups/mcp-pairing. New files have no original to back up. Dirty tracked files are refused by ordinary Sync; preserve the diff instead of bypassing the guard. Package export is an implementation exception: it does not use these protected writes or enforce a new/runtime-confined OutDir. Choose a new initialized runtime target and retain previous packages.

Generated PARA and runtime indexes, dossier views, the generated global instructions and IDE files that consist entirely of the managed pointer use the journal without a separate binary copy. A pointer file with personal text retains the normal backup policy. PARA and tracker import transactions reuse their verified rollback payloads when writing a file. An interrupted replacement can retain an adjacent `.recovery` file.

~~~powershell
pwsh -NoProfile -File scripts/restore-managed.ps1 -List -Path "$HOME/.claude/CLAUDE.md"
~~~

Choose verified MetadataPath before restore. It rejects altered backups or targets changed since deployment. Preserve payloads and metadata together.

## Whole-brain backup

backup.ps1 archives local PARA knowledge/indexes and host runtime data with a SHA-256 manifest; Verify checks an archive. Default names avoid same-second overwrites through suffixes. Explicit OutputPath can replace its named archive.

It does not include external IDE configuration/product instructions and has no automatic archive-wide restore. Git pushes do not back up ignored dossiers/runtime.

## Conflicts and removal

ide-adoption-required needs deliberate adoption review; ide-conflict needs rediscovery/profile verification; managed-block conflict needs comparison with deployment state and backup. Do not delete blocks or reset files merely to force Sync.

No blanket uninstaller exists. Preview selected Unbind, then separately review managed-block/MCP/hook/environment removal. Back up knowledge before an explicitly authorized clone removal. Unbinding and destructive repository rollback are different workflows.

Backups, journals, fixtures, builds, captures and other agents' work are not disposable because they appear regenerable. Cleanup requires scope, references, hashes and recoverability. See [recovery](recovery.md) and [runtime](runtime-maintenance.md).
