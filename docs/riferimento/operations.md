# Operations reference

[Retained Italian source; use this English page for current behavior](operations.it.md)

Run scripts from the SecondBrain checkout with PowerShell 7.5+ and Git 2.42+. ConfigPath is optional after activation; the current host configuration resolves under .runtime/hosts/<id>.

## Workflow

~~~mermaid
flowchart LR
    A[Discover and activate] --> B[Sync approved instructions]
    B --> C[Verify selected IDE]
    C --> D[Load essential context and ready work]
    D --> E[Authorized repository work]
    E --> F[Evidence and permitted closure]
    F --> G[Publication check before authorized push]
~~~

prompts Context resolves paths; knowledge Startup loads the actual packet. A resolved path is not loaded knowledge.

### Review workstation setup

Run `scripts/secondbrain.ps1 -Setup -PreviewOnly -Roots <folder>` to list discovered repositories and IDEs. Add `-Interactive` to select several assets, or pass `-Select` and `-Ides` to review an explicit selection. The resulting plan lists dossier metadata paths and MCP destinations. The preview skips the runtime write probe and leaves discovery, selection, activation and MCP files untouched.

Run `-Setup -Interactive -Roots <folder>` to review the activation and MCP plans and apply them in the same run. Type `APPLICA` to confirm. Press Enter to finish with the preview and leave workstation files untouched.

For team setup, pass `-TeamRoot '\\server\share'` for an existing authoritative SecondBrain root. Discovery still targets the local checkout by default. Use `-PreviewOnly` to review the plan, or set `SECONDBRAIN_STATE_ROOT` to a directory on a fixed local drive and use `-Interactive` to review and activate in one run. Automation can use `-Yes -Apply` for an already approved selection. Team access uses the share's existing ACLs.

If a selected repository has an active dossier in both roots, `dossierConflicts` lists the identity, checkout and both dossier paths. Setup stops before writing. Review the dossiers against that checkout before agreeing on consolidation.

Setup keeps the workstation configuration, inventory, discovery, selection, receipts and IDE state in the local state directory. The share receives dossier changes, generated PARA views and coordination records, including recovery journals under `.runtime/access/recovery`. Run subsequent commands from the authoritative root with the same local state setting.

<a id="controllo-e-sincronizzazione-su-richiesta"></a>

## Check and Sync

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
~~~

Check first attempts already-authorized deferred writes with zero lock wait. Asset checks do not apply their corrections. concurrent-writer/pending-transaction warnings mean the observed state may be intermediate.

Sync writes immediately through coordination, backups and hashes. It generates approved managed blocks/local views, preserves unrelated text and reports conflicts. New assets require explicit Setup selection; unapproved source text is not distributed. Neither command schedules monitoring.

Use NoRecovery-capable knowledge lookup/server startup when the session forbids all writes. A filtered Check/Sync with Repository limits coverage to that managed identity; it does not certify other products, IDEs or global instructions.

## Knowledge and closure

Slim selects whole Markdown blocks deterministically, with a first-load default of 30,000 characters. Without explicit TaskIds it includes no task detail. Full and deeper lookups remain available; essential content is not silently discarded.

A permitted transition to done records closure advice/lastClosure. The closure-memory-pending timestamp warning is advisory and does not certify content quality. Do not invent closure dates for historic tasks. An audit that proposes tracker corrections leaves the tracker untouched.

## Publication

~~~powershell
pwsh -NoProfile -File scripts/check-distribution.ps1
pwsh -NoProfile -File scripts/publication.ps1 -RepositoryPath C:/Projects/MyProduct
~~~

Distribution checks the Git public boundary, not general working-tree cleanliness. SEC07 separately examines working tree, index and relevant history, with findings/incomplete coverage. Commit, push, tags and releases remain separately authorized.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Requested operation completed without its reported blocking findings |
| 1 | Attention, conflicts, missing qualification or bounded incomplete result |
| 2 | Operational/configuration error or incomplete discovery |
| 3 | Writer coordination timeout |
| 4 | Access denied during a write; core.write.denied |

Inspect command-specific JSON. A destination write can precede failed result recording; check hashes/journal before retry.

Trace stop events are fail-open and require current-turn persistence permission. trace.event.lost means no event was saved. Missing turns are not reconstructed.

## Reference map

| Topic | Guide |
|---|---|
| Installation/bindings | [Portable brain](portable-brain.md) |
| Shared-host limits | [Shared brain](shared-brain.md) |
| Workspaces, retained runs, loading | [Runtime](runtime-maintenance.md) |
| Side effects/backups | [Safe writes](safety-backups.md) |
| Cleanup/interrupted writes | [Recovery](recovery.md) |
| Dossier and runtime layout | [Tree](tree.md) |
| Task authority/import/history | [Trackers](trackers.md) |
| Optional dossier write roots | [Sandbox roots](sandbox-roots.md) |
| IDE/account qualification | [Adapters](adapters.md) |
| Reviewed dossier writes | [MCP writes](mcp-writes.md) |
| Pairing/local stdio | [MCP](mcp-setup.md) |
| Catalog/common instructions | [Customization](customizing-prompts-and-directives.md) |
| Source applicability | [Sources](authoritative-sources.md) |
| Explicit remote acquisition | [GitHub audit](external-audit.md) |
| Sessions/deferred writes | [Access](access.md), [queue](pending-writes.md) |
| Per-turn collection | [Memory cycle](memory-cycle.md) |

Fixture success, file alignment and observed live loading are different evidence. Product checks belong to product agents.
