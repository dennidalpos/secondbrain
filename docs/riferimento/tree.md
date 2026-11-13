# Repository and runtime layout

[Retained Italian source; use this English page for current behavior](tree.it.md)

This map describes ownership and recovery boundaries. Regenerable does not mean authorized for deletion. Preserve artifacts until a concrete cleanup scope, references, hashes and recoverability have been reviewed.

## Public checkout

| Path | Responsibility |
|---|---|
| scripts/ | PowerShell modules (MCP server, IDE configuration and package in separate modules), CLI, tests and source-converter dependencies |
| config/ | Local schemas, shared policy and configuration example |
| direttive/ | Approved common instructions, original proposals and approval hashes |
| direttive/prompts/ | English cards, Italian counterparts and generated indexes |
| docs/ | English guides and retained Italian sources |
| .github/ | Community forms and workflow configuration |
| README, VERSION, CHANGELOG, CREDITS, LICENSE | Public product information and attribution |
| AGENTS.md | Repository instructions; managed blocks come from generators |

Git tracks the PARA skeleton using .gitkeep. PARA contents, generated PARA.md/para-index.json, local configuration and .runtime are ignored. Ignore rules do not remove tracked files or erase history.

<a id="para-gestione-dei-progetti"></a>

## PARA and dossiers

| Root | Purpose |
|---|---|
| 01-projects/ | One dossier per managed repository (isolated from each other: specs, material, data, context, memory, tracker) and finite initiatives |
| 02-areas/ | Continuing responsibilities not tied to a repository; legacy `02-areas/products/` dossiers migrate with `para.ps1 -MigrateToProjects` |
| 03-resources/ | Reusable references |
| 04-archives/projects, areas, resources | Explicitly archived entities |

Entities retain stable IDs in para.json and a brief.md. Resolve paths through para-index.json and verify metadata; repository.json establishes repository identity and tracker location. Duplicate names and missing checkouts do not establish retirement.

A dossier contains index.md, context.md, memory.md, repository.json, its declared tracker, derived memory.agent.md and history/. Optional authoritative-sources.json records applicability. Original knowledge/history are not regenerable; indexes and agent views are.

Projects (including repository dossiers) use active/completed/cancelled; Areas and Resources use active/retired. Repository dossiers are archived under 04-archives/projects. A time-bound project may link repository dossiers (or areas) by id, and may link none. Archiving changes location, preserving identity and references. Sync does not reactivate archives.

Use MEM05 and para.ps1 for entity creation/state changes. Check and SuggestArchive inspect; NewProject/NewResource/SetStatus/Archive/Restore are writing workflows with separate authorization. Tracker import manifests must be reconciled before a move. PARA.md and para-index.json are generated, never manually edited.

## Runtime

| Path under .runtime/ | Contents |
|---|---|
| hosts/<id>/workstation.json | Active bindings, integrations and output receipts |
| hosts/<id>/inventory.json, ide-map.json, state.json | Generated observations and deployment state |
| hosts/<id>/backups/ | Verified originals, Git recovery records and staging/journals |
| hosts/<id>/sources/ | Dedicated converter environment and source reports |
| hosts/<id>/repos/<repo>/<category>/<date>-<slug>/ | Manifest-owned work/fixture/tmp/evidence/report folders |
| hosts/<id>/repos/<repo>/temp/ | Repository-scoped temporary environment |
| access/ | Sessions, leases, FIFO tickets, locks, requests and receipts |
| access/para-transaction.json | Incomplete transaction marker; recover instead of deleting (older root-level markers also detected) |
| backups/mcp-pairing/ | MCP configuration recovery |
| publication/ | Baselines and reports; the policy (allowances, binary reviews) is the tracked `config/publication-policy.json`, and a legacy `policy.json` here is no longer read (`publication.ps1 -MigratePolicy` copies it once) |
| trace/, cleanup/, INDEX.md | Turn metadata, cleanup receipts and generated inventory |

Initialize agent folders with work.ps1 Category/Slug/Init, pass SessionId, and close the manifest. Do not write into another host/user/session's folder. Evidence/reports are protected; closed work/fixture/tmp retention is a separate guarded workflow.

Tests preserve unique run directories, run.json, logs and fixtures after success and failure; esito.json links the latest run. Old flat directories and hosts/<id>/repositories layouts are retained until explicitly authorized migration.

## Inspection and maintenance

~~~powershell
pwsh -NoProfile -File scripts/access.ps1 -Status
pwsh -NoProfile -File scripts/cleanup.ps1 -ListRuntime
~~~

Check ownership, references, hashes, active sessions, markers and reparse points before proposing maintenance. Do not recursively delete unresolved paths or use an empty mirrored directory as a shortcut.

Products are separate checkouts. Products keep their operational outputs in Git-ignored checkout folders. Central maintenance keeps dossiers with summaries and references. Product agents handle product qualification. See [runtime](runtime-maintenance.md), [trackers](trackers.md), [recovery](recovery.md) and [shared brain](shared-brain.md).
