# Per-repository workflow

[Retained Italian source; use this English page for current behavior](flusso-prodotto.it.md)

Use chat conventions or the same PowerShell scripts. Run central scripts from the SecondBrain checkout and identify the product checkout explicitly when needed.

| Step | Chat | CLI or action |
|---|---|---|
| Activate once per workstation | `sb attiva` | `scripts/secondbrain.ps1 -Setup -Interactive` |
| Sync approved instructions | `sb allinea` | `scripts/secondbrain.ps1 -Sync` |
| Verify the IDE integration | `sb prompt SYS01` | `scripts/ide-map.ps1 -Verify` plus live client evidence |
| Load essential context | `sb prompt MEM06` | `scripts/knowledge.ps1 -Startup -CheckoutPath <product>` |
| Choose ready work | `sb prompt REP01` | `scripts/knowledge.ps1 -Tasks -ReadyOnly -CheckoutPath <product>` |
| Implement authorized work | Agent in the product repository | Follow repository instructions and session permissions |
| Check before any authorized push | `sb prompt SEC07` | `scripts/publication.ps1 -RepositoryPath <product>` |
| Close authorized work | `sb prompt MEM03` | Update permitted tracker/context/memory, then Sync and Check |
| Compact only when necessary | `sb compatta` | `knowledge.ps1 -Compact -CandidatePath <file>`; inspect before Apply |

Knowledge lookups never write; pending writes are integrated only by an explicit `knowledge.ps1 -FlushPending`. Audits that propose tracker changes leave the tracker unchanged; do not close a task simply because some code exists.

## Show the current next step

~~~powershell
pwsh -NoProfile -File scripts/prompts.ps1 -RepositoryPath C:/Projects/MyProduct
~~~

The MCP equivalent is `get_prompt_home` with `repositoryPath`. Without a checkout argument the menu is generic. The chat agent must supply the actual checkout rather than infer it from a dossier folder name.

## Chat and CLI boundaries

`sb` commands are conventions written in managed instructions, not shell executables. The CLI and MCP expose the same knowledge operations, but permissions and client approvals are separate. Installing an instruction file, registering an account/profile, successful stdio communication and proving live loading are separate checks.

The product agent runs builds and tests and captures screenshots. Build output, caches, temporary files, fixtures and evidence stay in Git-ignored folders of the product checkout. The SecondBrain dossier retains summaries and references to those results.

See [daily use](uso-quotidiano.md), [agents and MCP](ide-e-mcp.md), [trackers](riferimento/trackers.md) and [runtime maintenance](riferimento/runtime-maintenance.md).
