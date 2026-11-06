# Getting started

[Retained Italian source; use this English page for current behavior](inizia.it.md)

Activate SecondBrain on a Windows workstation, choose the repositories it may manage, and connect an agent. Installing configuration files and proving that an IDE loaded them are separate steps.

~~~mermaid
flowchart LR
    A[Clone] --> B[Inspect]
    B --> C[Choose and activate]
    C --> D[Sync approved rules]
    D --> E[Pair an agent]
    E --> F[Verify in a new session]
~~~

## Prerequisites

Use Windows, PowerShell 7.5+ and Git 2.42+. Setup rejects missing, unrecognizable or older Git versions. Choose a checkout location you control. Dossiers and runtime files are ignored by Git; cloning or pushing this repository does not back them up.

~~~powershell
git clone https://github.com/dennidalpos/secondbrain.git C:/Projects/SecondBrain
cd C:/Projects/SecondBrain
~~~

The paths below are examples, not workstation settings.

## Inspect and activate

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive
~~~

Before activation, Check reports that the workstation is not activated and exits with code 2. Setup discovers repositories and IDEs, presents a selection and asks for confirmation before applying it. Limit discovery to known roots when scanning every drive would be slow:

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots C:/Projects -Interactive
~~~

Read [security and side effects](sicurezza.md) first. Check can process previously authorized pending dossier writes; it is not a strict no-write command. For a strictly read-only knowledge lookup, use `knowledge.ps1 -NoRecovery`.

## Sync and pair

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex -Apply
~~~

Sync applies the approved managed blocks. Pair without Apply previews the configuration; Apply changes the selected client's configuration with backup. Setup also previews user-level pairing for selected supported IDEs or explicit `-McpTargets`. Review the preview before confirming. Use `-Pair` for project scope and verify popup behavior in a new client session. See [agents and MCP](ide-e-mcp.md).

## Verify the integration

Restart the agent, open a new session and type `sb prompt`. This is a chat convention defined by the instructions, not an installed shell command.

~~~powershell
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
~~~

An aligned file, successful protocol handshake and observed loading in a live client are different forms of evidence. A successful file check alone does not qualify the client's account, permissions or loaded context.

## Troubleshooting

| Symptom | Next step |
|---|---|
| The agent does not understand `sb prompt` | Check the selected integration and test a new session |
| Check exits with 1 | Read the individual issues; do not treat reminders as passed checks |
| A tracked instructions file is modified | Preserve the changes and review the conflict; do not force Sync |
| A configuration must be restored | Use [backup and recovery](sicurezza.md) |

Continue with [daily use](uso-quotidiano.md) or the [configuration reference](riferimento/portable-brain.md).
