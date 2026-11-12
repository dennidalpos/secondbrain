# Daily use

[Retained Italian source; use this English page for current behavior](uso-quotidiano.it.md)

Work with your agent as usual. SecondBrain supplies repository context, decisions, tasks and approved instructions. The agent must still respect the permissions of the current session.

## Chat commands

The command words below remain unchanged in every documentation language.

| Type in the agent chat | Purpose |
|---|---|
| `sb prompt` | Show commands, guides and the next step |
| `sb prompt list` | Show the complete prompt list |
| `sb prompt ambito test` | List one category |
| `sb prompt mostra TST04` | Display a prompt card |
| `sb prompt TST04: check the login flow` | Compose the card with your objective |
| `sb controlla` | Inspect alignment without changing anything |
| `sb allinea` | Sync approved instructions |
| `sb attiva` | Discover and activate selected integrations |
| `sb compatta` | Preview dossier compaction; applying it requires confirmation |
| `sb runner` | Run the ready tasks of the current repository from the desktop app or the command line |
| `sb stop` | Stop the agent, save the session in the dossier and resume it from another IDE or account with `sb prompt MEM07` (MEM09) |

See the [per-repository workflow](flusso-prodotto.md) for the order of operations.

## PARA and the dossier

| Folder | Use |
|---|---|
| `01-projects/` | One folder per managed repository (specs, material, data, context, memory, tracker) and other work with an end condition |
| `02-areas/` | Continuing responsibilities that are not a repository |
| `03-resources/` | Reference material |
| `04-archives/` | Inactive material; do not reactivate it implicitly |

A repository dossier contains `index.md`, `context.md`, `memory.md`, `repository.json` and its declared tracker. Resolve it by repository identity, not the folder name. A declared dossier tracker is authoritative; a missing or invalid tracker is an error, not permission to use another file.

Durable decisions use `Decisione: … — Motivo: …` in memory. Keep only verified, useful changes in context and memory. Read the essential startup package first, then request relevant task details and historical evidence. Slim defaults to 25,000 characters for the first load; characters are not tokens. See [loading and maintenance](riferimento/runtime-maintenance.md).

## CLI lookups

Run these from the SecondBrain checkout, passing the product checkout explicitly:

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -NoRecovery -CheckoutPath C:/Projects/MyProduct
pwsh -NoProfile -File scripts/knowledge.ps1 -Tasks -ReadyOnly -NoRecovery -CheckoutPath C:/Projects/MyProduct
pwsh -NoProfile -File scripts/knowledge.ps1 -Task TASK-ID -NoRecovery -CheckoutPath C:/Projects/MyProduct
~~~

The global task view requires `-All` and is paginated. Task edits belong to the repository being worked on. An audit that only proposes tracker changes must leave the tracker untouched.

## Before publication

~~~powershell
pwsh -NoProfile -File scripts/publication.ps1 -RepositoryPath C:/Projects/MyProduct
~~~

The gate scans working tree, index and relevant history, subject to its reported coverage. Review findings, binary limitations and any accepted fingerprints. A clean pattern scan is not proof that every secret or private detail has been found. Commit and push each require the user's authorization.

## Running tracker tasks

To work through the ready autonomous tasks, one fresh agent session per task and one repository at a time, use `scripts/run-ready-tasks.ps1`. It previews by default and prints progress on the console while it runs. `-Run` also needs `-Model` and `-Effort`, or `-UseCliDefault`; without a choice it exits 2 and lists the options the installed CLI exposes. See [running tracker tasks](riferimento/operations.md#running-tracker-tasks-in-fresh-sessions) for options, safety limits and results.

## Versions and closure

A documentation correction does not automatically require a new version. Propose a version only when justified; change it and the changelog only after acceptance.

At an authorized task closure, verify acceptance criteria, preserve task IDs and history, update the permitted dossier records and run Sync and Check. Repository memory collection is enabled only explicitly and requires a verified permission policy for the current turn.

## Terms

A dossier is a repository's knowledge folder; a tracker stores tasks; a managed block is the delimited text Sync maintains; MCP connects the client to the local server. See [trackers](riferimento/trackers.md), [PARA](riferimento/tree.md) and [operations](riferimento/operations.md).
