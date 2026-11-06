# Security, backups and side effects

[Retained Italian source; use this English page for current behavior](sicurezza.it.md)

SecondBrain manages instructions, configuration and local knowledge. Its core workflow does not edit product source code. It can write outside its checkout when syncing managed instructions or configuring an explicitly selected IDE.

## What commands can change

| Command | Effects to review |
|---|---|
| `knowledge.ps1 -Startup/-Tasks -NoRecovery` | Knowledge lookup without pending-write recovery |
| `knowledge.ps1` lookups without NoRecovery | May integrate already-authorized pending dossier writes |
| `prompts.ps1`, `secondbrain.ps1 -Check`, default MCP startup/lookups | May process already-authorized pending dossier writes |
| `-Setup -Interactive` | Selected workstation configuration and integrations after confirmation; optional user environment registration |
| `-Sync` | Approved managed blocks, generated local views and configured instruction files |
| `mcp-server.ps1 -Pair -Apply` | Selected MCP client configuration, with backup |
| `backup.ps1` / restore commands | Backup or restore operations; inspect the target and options first |
| `mcp-server.ps1 -ExportPackage` | Managed writes into a new directory below `.runtime`; existing destinations are refused |

Sync writes immediately. Inspect alignment first, preserve existing changes, and never treat a successful file write as proof that a live IDE loaded it. The MCP tools advertise `readOnlyHint=false` because knowledge reads may process queued writes. Start the server with `-NoRecovery` for a strict no-recovery session; a single call's `noRecovery=true` cannot undo recovery that already happened at startup.

SecondBrain does not inspect authentication stores to discover credentials. Account and profile identities are declared and separately verified through SYS01.

<a id="ripristina-un-file"></a>

## Backups and recovery

Workstation backups are under `.runtime/hosts/<id>/backups/`; MCP pairing also uses `.runtime/backups/mcp-pairing/`. For clean tracked files, the write record identifies the Git commit and blob instead of duplicating the content. Dirty tracked files are protected from automatic overwrite. Untracked/local files use verified binary backups.

~~~powershell
pwsh -NoProfile -File scripts/backup.ps1
pwsh -NoProfile -File scripts/restore-managed.ps1 -List -Path "$HOME/.claude/CLAUDE.md"
~~~

Review the selected metadata before restoring:

~~~powershell
pwsh -NoProfile -File scripts/restore-managed.ps1 -MetadataPath .runtime/hosts/<id>/backups/<guid>.bin.json
~~~

Replace the placeholders with an actual verified record. Restore checks for intervening changes. Preserve recovery markers, journals and original evidence; do not delete them to clear a warning.

Dossiers and runtime files are ignored by Git. A Git push does not back them up. Backups and official evidence are protected; documented retention for eligible closed work or fixture folders is a separate operation with its own safeguards.

## Network and privacy boundary

The stdio MCP server does not open a listening network port. Some explicit operations, including GitHub audit and source collection, access external services. Agents and IDE providers have their own data handling policies. Do not put private dossier content, real credentials, raw captures or operational logs into product repositories or public issues.

## Removing an integration

Preview `secondbrain.ps1 -Setup -Unbind <selection>` first; applying it requires explicit confirmation and `-Apply`. Review remaining managed blocks and MCP entries before removing them. Back up knowledge and recovery records before any separately authorized removal of the clone or environment registration. Unbinding does not authorize deleting dossiers or backups.

Detailed procedures: [safe writes](riferimento/safety-backups.md), [recovery](riferimento/recovery.md), [access coordination](riferimento/access.md).
