# Getting started

[Retained Italian source; use this English page for current behavior](inizia.it.md)

Load one local Git project's context through the CLI, then optionally connect an agent. Use Windows, PowerShell 7.5+ and Git 2.42+. Dossiers and runtime files are ignored by Git and need their own backups.

## Clone and choose a project

Follow the [README quick start](../README.md#quick-start-load-one-projects-context). It provides the complete clone, read-only preview, explicit activation and Startup commands. The example chooses one existing Git checkout, selects no IDE and uses NoRegisterEnvironment.

Setup creates workstation configuration, the selected dossier and approved repository instructions. It does not copy the example paths into account instructions. A new clone's Check exits with 2 before activation; a valid read-only Setup preview exits with 0 without activating anything.

## Inspect the result

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -Profile Slim -NoRecovery -CheckoutPath $project
~~~

Run from the SecondBrain checkout; $project is the path selected in the quick start. In the isolated one-project run, Check exited with 0 and Startup returned profile=Slim and withinBudget=true. Your existing dossier can exceed the budget or have pending conflicts: read the actual issues before proceeding.

Check may process previously authorized pending writes. Knowledge with NoRecovery does not perform that recovery. File alignment and actual loading in an agent session are different evidence.

## Optional interactive setup

For interactive confirmation of the selected project, run:

~~~powershell
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Interactive -Roots $project -Select $project -NoRegisterEnvironment
~~~

Review the activation and MCP plans. Enter APPLICA only for the displayed scope; any other reply leaves activation unapplied. The documented confirmation/refusal paths can be exercised on synthetic profiles, but this is not a live IDE loading test.

Setup performs Sync for the approved selection. Do not immediately repeat a global Sync merely because an example used it in the past. Use targeted checks and preserve dirty-file conflicts. See [security and side effects](sicurezza.md).

## Optional MCP pairing

Client scopes differ: Codex and Claude Desktop use user-level pairing; Cursor, VS Code, Claude Code and Antigravity support explicit project scopes in the implementation. See the [target and scope table](ide-e-mcp.md#instruction-and-configuration-targets).

This project-scoped example writes only the selected project's Cursor configuration:

~~~powershell
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target cursor -Scope project -WorkspacePath $project
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target cursor -Scope project -WorkspacePath $project -Apply
~~~

Preview first. Apply writes configuration with backup; it does not prove that Cursor is installed, connected or displaying the tools. The example was checked against a synthetic project configuration, not a real client session. Other clients follow their own [MCP setup instructions](riferimento/mcp-setup.md).

## Use an agent and get help

Open a new session in the selected agent and request sb prompt. This is a chat convention from the managed instructions, not an installed shell command. The agent must actually load those instructions. Use the CLI if the client cannot expose MCP.

| Symptom | Next step |
|---|---|
| Check exits with 1 | Read the individual issues; do not treat them as passed checks |
| Startup reports withinBudget=false | Preserve essentials and prepare reviewed dossier maintenance |
| The agent does not understand sb prompt | Check the selected integration and start a new session |
| A tracked instructions file is modified | Preserve the change and review the conflict |
| Automatic memory capture is expected | Read the [current limits](riferimento/memory-cycle.md#known-limits-141); explicit loading remains available |

Continue with [daily use](uso-quotidiano.md). Use the [bug form](https://github.com/dennidalpos/secondbrain/issues/new/choose) for defects and [SECURITY.md](../SECURITY.md) for private vulnerability reporting.

## Guided first-run setup

On a clean machine, after cloning, ask your agent for `sb setup` (prompt SYS17). It runs `scripts/setup-status.ps1` (read-only: preflight, detected IDEs, and which optional features are enabled, available or unsupported, with the reason and a preview command for each), then walks activation (SYS03), MCP (SYS15) and directives (SYS01) with a confirmation before every write, and finally offers the optional features one at a time. Recommendations come from the current state of the workstation, not from your command history; nothing is enabled without your confirmation.
