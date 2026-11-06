# Installation and operations guide

[Retained Italian source; use this English page for current behavior](guida.it.md)

This guide connects installation, everyday commands, environment settings and recovery. Start with [getting started](inizia.md); use the [technical reference](riferimento/operations.md) for detailed procedures.

## Install and activate

Use Windows, PowerShell 7.5+ and Git 2.42+.

~~~powershell
git clone https://github.com/dennidalpos/secondbrain.git C:/Projects/SecondBrain
cd C:/Projects/SecondBrain
pwsh -NoProfile -File scripts/secondbrain.ps1 -Check
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots C:/Projects -Interactive
pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync
~~~

Before activation, Check exits with 2. Setup presents choices and confirmation before applying workstation configuration. Sync distributes approved managed instructions immediately; preserve conflicts rather than forcing them. Check and prompt lookups may process already-authorized pending dossier writes.

## Connect an agent or use the CLI

~~~powershell
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex -Apply
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
~~~

MCP is optional. Preview before Apply, then test a new client session. File alignment, account/profile declaration, stdio handshake and live loading are distinct evidence. See [agents and MCP](ide-e-mcp.md).

From the SecondBrain checkout:

~~~powershell
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -NoRecovery -CheckoutPath C:/Projects/MyProduct
pwsh -NoProfile -File scripts/knowledge.ps1 -Tasks -ReadyOnly -NoRecovery -CheckoutPath C:/Projects/MyProduct
pwsh -NoProfile -File scripts/knowledge.ps1 -Search "search terms" -NoRecovery -CheckoutPath C:/Projects/MyProduct
pwsh -NoProfile -File scripts/publication.ps1 -RepositoryPath C:/Projects/MyProduct
~~~

The product path is explicit so the scripts resolve the correct identity and dossier. `-All` opts into the read-only global task projection. Task writes require the working repository and its declared tracker; never use another tracker as fallback.

Chat commands such as `sb prompt`, `sb controlla`, `sb allinea` and `sb compatta` are conventions, not installed executables. The [per-repository flow](flusso-prodotto.md) maps them to scripts.

## Environment

| Variable | Purpose |
|---|---|
| `SECONDBRAIN_HOME` | User-local clone location. Confirmed Setup application registers it unless `-NoRegisterEnvironment` is used; lower-level Activate uses explicit `-RegisterEnvironment`. Restart open IDEs afterward. |
| `SECONDBRAIN_LANG` | Message language; explicit `-Language` takes precedence, then environment/configuration/system fallback. Some legacy diagnostics remain untranslated. |
| `SECONDBRAIN_LOCK_WAIT_SECONDS` | Writer-lock wait, default 60 seconds, also controlled by `-WaitSeconds` where supported. |
| `SECONDBRAIN_SKIP_PRE_PUSH` | Explicit one-push hook bypass; it does not qualify the publication or resolve findings. |

Scripts can bootstrap from the checkout without the environment variable. A configured pre-push hook fails closed if its runtime or brain root cannot be resolved. Do not copy workstation paths into public instructions.

## Coordination and backups

~~~powershell
pwsh -NoProfile -File scripts/access.ps1 -Status
pwsh -NoProfile -File scripts/access.ps1 -Queue
~~~

Knowledge reads avoid blocking locks, but default reads may process queued writes. Writers serialize through a FIFO queue and return exit 3 when the wait limit expires. Do not remove lock files or incomplete-transaction markers.

Longer writes use Start/End in the same script with try/finally and pass SessionId to the invoked CLIs. Initialize work folders for SecondBrain activities with `work.ps1 -Category <category> -Slug <slug> -Init` and a manifest. Product agents verify tool-specific output paths in Git-ignored folders of their own checkout.

Clean tracked files are recoverable by recorded Git commit/blob; local files use verified backups. Dirty tracked files are protected from overwrite. See [safe writes](riferimento/safety-backups.md) and [recovery](riferimento/recovery.md).

## Lifecycle and limits

Greenfield state is declared in dossier `repository.json`; Check reports incompatible version/changelog/schema changes. Changing lifecycle is a separate SYS13 decision.

Dossiers, backups and evidence are not covered by a Git push. Account login is manual. Product builds/tests belong to product agents. Shared-brain and SMB behavior requires its own real-host qualification. See [portable configuration](riferimento/portable-brain.md), [shared brain](riferimento/shared-brain.md) and [runtime maintenance](riferimento/runtime-maintenance.md).
