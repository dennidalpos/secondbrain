# SecondBrain for Coding Agents

![Version 1.17.1](https://img.shields.io/badge/version-1.17.1-blue) ![Windows](https://img.shields.io/badge/Windows-0078D6) ![PowerShell 7.5+](https://img.shields.io/badge/PowerShell-7.5%2B-5391FE)

English · [Italiano](#italiano)

**Project context, decisions, tasks and shared rules for coding agents on Windows.**

SecondBrain stores private project dossiers outside the public Git content. An agent loads the relevant dossier through PowerShell or the optional local MCP server. Approved instruction blocks can be distributed to selected repositories and agent configurations.

Use it when you want Claude Code, Codex or Antigravity to work from the same project notes and rules. A Git clone contains the scripts and public guides; it does not contain your ignored dossiers or their backups.

~~~mermaid
flowchart LR
    U[You] --> A[Coding agent]
    A --> L[Explicit context lookup]
    L --> D[Selected project dossier]
    D --> C[Context, decisions and tasks]
    C --> A
    R[Approved rules] --> P[Selected repository instructions]
~~~

## Quick start: load one project's context

You need Windows, PowerShell 7.5+ and Git 2.42+. Choose an existing local Git repository for MyProject. Read [what Setup changes](docs/sicurezza.md) first.

Run in PowerShell; replace the two example paths:

~~~powershell
$brain = 'C:/Projects/SecondBrain'
$project = 'C:/Projects/MyProject'
git clone https://github.com/dennidalpos/secondbrain.git $brain
Set-Location $brain
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -PreviewOnly -Roots $project -Select $project
~~~

The preview discovers the selected checkout without activating it. Review the plan. To authorize activation for that repository:

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots $project -Select $project -Yes -Apply -NoRegisterEnvironment
~~~

Setup creates the dossier and workstation configuration and synchronizes approved repository instructions. This example selects no IDE and leaves the user-level environment variable unchanged. Existing conflicting instructions are preserved and reported.

Load the dossier and open the next-task prompt:

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -Profile Slim -NoRecovery -CheckoutPath $project
pwsh -NoProfile -File scripts/prompts.ps1 -Show -Prompt REP01 -Language en
~~~

Check the returned repository identity, profile and withinBudget value. A budget failure is a result to resolve, not a successful context load. The sequence was exercised from a clean Windows clone with one synthetic Git repository; no agent login was needed.

For interactive selection, team setup and a new agent session, continue with [Getting started](docs/inizia.md).

## Common tasks

Run from the SecondBrain checkout. Keep $project set to the selected project path.

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -Tasks -ReadyOnly -NoRecovery -CheckoutPath $project
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
~~~

- **Read project knowledge:** use Startup, task lookup or search; [daily use](docs/uso-quotidiano.md) explains the CLI and chat conventions.
- **Change a task or memory:** review the operation and its approval requirements. The [MCP write guide](docs/riferimento/mcp-writes.md) covers the local receipt for each submitted operation.
- **Use prompt cards:** 113 English cards with Italian counterparts cover development, review, documentation and maintenance. [Prompt guide](docs/prompt.md).
- **Back up private knowledge:** preserve the dossier and recovery records separately from Git. [Backup and recovery](docs/sicurezza.md).

A new dossier has no recorded tasks, so an empty ready-task list is expected.

Check and default knowledge reads can integrate already-authorized queued writes. NoRecovery disables that recovery for the knowledge commands above.

## Configuration and agent connections

Setup can select repositories and supported IDE integrations interactively. MCP is optional: the CLI exposes the same project knowledge.

| Integration | What is implemented | What to verify separately |
|---|---|---|
| Repository instructions | Managed AGENTS.md blocks and CLAUDE.md/GEMINI.md pointers | Loading in a new agent session |
| MCP configuration | Client-specific preview and pairing | Actual tool exposure, profile and popup behavior |
| MCP server | Ten tools, including reviewed dossier-write preview and submission | Client consent and the local receipt for each write |
| Memory collection | Guided envelopes, per-turn Permit CLI and a native bridge | Current implementation limits and live qualification |

See [Agents and MCP](docs/ide-e-mcp.md) for client scopes. An updated file or a successful synthetic handshake does not prove that a client loaded the configuration.

SECONDBRAIN_HOME can identify the checkout on your workstation; scripts can also bootstrap from their own checkout. SECONDBRAIN_STATE_ROOT selects local workstation state, including when dossiers use an explicitly configured shared root. Keep machine paths and receipts out of public repositories. [Configuration reference](docs/riferimento/portable-brain.md).

PARA organizes the dossier; startup loads an essential layer before deeper history. [Architecture](docs/riferimento/architecture.md) describes the data boundaries and modules.

## Limits of the current version

- Windows only; PowerShell and Git are required.
- Context loading must be requested through the CLI, MCP or an agent workflow. Setup does not make every client remember or capture every chat automatically.
- Native memory capture remains partial. Version 1.6.0 accepts only a native Stop event and binds Permit Apply to the reviewed preview hash, on synthetic fixtures only. Use the guided workflow and read the [known memory-cycle limits](docs/riferimento/memory-cycle.md#known-limits-141) before enabling a native bridge.
- Synthetic fixtures do not qualify real IDE sessions, account permissions, crashes or multiple physical hosts on SMB.
- Ignored dossier files are private local/shared data, not a backup supplied by Git.

## Help and contributor checks

Start with [Getting started](docs/inizia.md), [daily use](docs/uso-quotidiano.md), the [single guide](docs/guida.md) or the [technical reference](docs/riferimento/operations.md).

Report defects through the [bug form](https://github.com/dennidalpos/secondbrain/issues/new/choose). Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md). Contributions follow [CONTRIBUTING.md](CONTRIBUTING.md).

For documentation and code changes, run Quick and the checks relevant to the change:

~~~powershell
pwsh -NoProfile -File scripts/test-secondbrain.ps1 -Quick
pwsh -NoProfile -File scripts/build-prompts.ps1 -Check
pwsh -NoProfile -File scripts/check-distribution.ps1
~~~

[Verification levels](docs/riferimento/runtime-maintenance.md#verification-levels) distinguish Quick, Fast, Full and live qualification. [SEC07](docs/riferimento/operations.md#publication) separately checks text and Git inventory before publication. Passing one level does not imply the others passed.

MIT License. [Sources and acknowledgements](CREDITS.md).

---

## Italiano

**Contesto, decisioni, task e regole condivise per gli agenti di sviluppo su Windows.**

SecondBrain conserva dossier privati che l'agente consulta tramite PowerShell o il server MCP locale facoltativo. Distribuisce i blocchi di istruzioni approvati nei repository selezionati. Il clone Git non contiene né salva i dossier ignorati.

### Inizia con un progetto

Servono Windows, PowerShell 7.5+ e Git 2.42+. I comandi copiabili sono nella sezione [Quick start](#quick-start-load-one-projects-context): scegli un repository Git locale, leggi l'anteprima, autorizza Setup e carica il contesto con Startup. L'esempio non seleziona IDE né registra la variabile utente. [Guida di avvio](docs/inizia.md).

### Compiti comuni e configurazione

Consulta i task pronti, carica il dossier e usa una delle 113 schede prompt. Le scritture MCP richiedono un piano e una ricevuta CLI locale per operazione. [Uso quotidiano](docs/uso-quotidiano.md) · [Scritture approvate](docs/riferimento/mcp-writes.md) · [Agenti e MCP](docs/ide-e-mcp.md).

### Limiti e aiuto

Il contesto va richiesto: Setup non rende automatica la memoria di ogni chat. La cattura nativa è parziale; in 1.6.0 il bridge accetta solo l evento Stop e Permit Apply è vincolato all hash dell anteprima, verificati solo su fixture sintetiche. [Limiti osservati](docs/riferimento/memory-cycle.md#known-limits-141).

Le fixture non qualificano sessioni IDE reali, account o share fra PC fisici. I controlli per contributori sono nella sezione [Help and contributor checks](#help-and-contributor-checks). Problemi di sicurezza: [SECURITY.md](SECURITY.md). Licenza MIT.
