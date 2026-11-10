# Optional writable roots

scripts/sandbox-roots.ps1 previews and exports configuration for one managed checkout. It does not change user settings, launch an agent, alter approvals, or install a global policy. The exported configuration is private workstation data and stays in a repository-owned work folder created by work.ps1.

The supported operation scope is dossier reads and writes through knowledge.ps1, including pending requests, receipts and transaction journals. Setup, Sync, PARA moves, global indexes, source acquisition and memory-cycle collectors need their own write scopes. Do not use this configuration as proof that those operations are supported.

## Roots and exposure

| Root | Purpose | Exposure |
|---|---|---|
| Active repository dossier | Tracker, memory, context and history | One dossier |
| .runtime/access | Locks, sessions, pending requests, receipts and recovery markers | Shared across repositories and hosts |
| Configured backupRoot | Verified file backups and transaction journals | May contain other repositories' data |
| runtimeRoot/repos/<repository-segment> | This repository's work and retained outputs | One repository on this workstation |

The whole brain, .runtime and the host's runtime directory are never emitted as writable roots. A configured backup directory that includes one of those boundaries is refused. Existing permissions from other configuration layers, the primary workspace and the client's default temporary directories may add access beyond this list. This export adds capabilities; it is not a proof of isolation.

Claude additional directories also extend read access. Edit rules allow built-in edits under those roots; they do not constrain arbitrary subprocesses at OS level, and no Bash or PowerShell command is preapproved. Higher-priority managed settings and restrictive rules can still deny operations.

## Preview and export

Run from the managed product checkout and resolve the SecondBrain script path on the workstation. $brain below is the resolved root, not a path to commit into the product.

~~~powershell
$identity = 'github.com/example/product'
$session = & "$brain/scripts/access.ps1" -Start -Mode Write -Client Codex -Repository $identity | ConvertFrom-Json
try {
    $slug = 'sandbox-' + [guid]::NewGuid().ToString('N').Substring(0, 12)
    $work = & "$brain/scripts/work.ps1" -Repository $identity -Category work -Slug $slug -Init -Task 'Optional sandbox configuration' -SessionId $session.sessionId | ConvertFrom-Json
    $options = @{
        Repository = $identity
        CheckoutPath = (Get-Location).Path
        Target = 'codex' # or claude-code
        OutputDirectory = $work.root
        SessionId = $session.sessionId
    }
    $plan = & "$brain/scripts/sandbox-roots.ps1" @options | ConvertFrom-Json
    $plan | ConvertTo-Json -Depth 12

    # After reviewing roots, warnings, destination contents and planHash:
    # & "$brain/scripts/sandbox-roots.ps1" @options -Apply -ExpectedPlanHash $plan.planHash
} finally {
    & "$brain/scripts/access.ps1" -End -SessionId $session.sessionId
}
~~~

Preview itself creates no files, leases or pending-write recovery. The example explicitly initializes a work folder before preview. Apply requires that folder to be open and owned by the current workstation, user and session. A new session needs a new work folder; existing folders are not claimed automatically.

Apply regenerates the plan and checks its hash, including destination hashes and the work manifest. Changes require another preview. Replacing an exported file preserves its previous bytes in the configured verified backup store. The two Codex exports are individually safe writes; a failed export may leave only one file, so retry from a fresh preview. No partially exported bundle is activated automatically.

## Use the exported configuration

For Codex CLI, codex-config.toml is an inspectable fragment using sandbox_mode and sandbox_workspace_write.writable_roots. It is not installed in .codex. The companion JSON contains the equivalent native arguments:

~~~powershell
$config = Get-Content -LiteralPath "$exportDirectory/codex-arguments.json" -Raw | ConvertFrom-Json
$nativeArguments = [string[]]$config.arguments
& codex @nativeArguments
~~~

The arguments select the recorded checkout, workspace-write and this root list for that invocation. Other existing client settings remain active. Do not copy a path-bearing fragment into a public repository.

For Claude Code, start in the recorded checkout:

~~~powershell
Set-Location -LiteralPath $checkout
claude --settings "$exportDirectory/claude-settings.json"
~~~

The settings contain permissions.additionalDirectories and absolute Edit allow rules. Windows drive paths use Claude's documented POSIX normalization (for example, D:\data becomes /d/data, expressed as Edit(//d/data/**)). Paths with rule metacharacters are refused. UNC additional directories are unsupported; the exporter neither maps drives nor guesses aliases.

Recompute the plan after moving a checkout, changing a binding or changing the brain/state location. Exported files are not refreshed automatically. Close the work folder with work.ps1 -Close after use; the files remain subject to work-folder retention, so export again when needed.

## Clients and verification limits

| Client | Export behavior | Verification |
|---|---|---|
| Codex CLI | Native workspace-write arguments and TOML fragment | Synthetic fixture configuration and transaction paths |
| Claude Code | Per-invocation settings file, directories and Edit rules | Synthetic fixture configuration; UNC explicitly refused |
| Cursor, VS Code, Windsurf, Antigravity, Claude Desktop and other targets | status=unsupported, reason, no files | Adapter absence is explicit and covered by a fixture |

No GUI client configuration is inferred from CLI support. Export always reports clientSessionVerified=false. Restart in a new client session and record actual permitted roots, write outcomes or denials separately using the adapter qualification workflow. Do not treat a passing fixture as live sandbox qualification.

New transactions place their marker at .runtime/access/para-transaction.json. Readers, recovery and cleanup also detect an existing .runtime/para-transaction.json from older clients. An old marker blocks minimal-root export until recovery; two markers fail closed and preserve both. Recovery of an old marker may need PowerShell outside the narrow sandbox. Align team clients to the same release before shared writes: an older client does not discover the new marker location.

## Official format references

Verified on 7 November 2026:

- [Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference): sandbox_mode and sandbox_workspace_write.writable_roots.
- [Codex command reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli): native configuration overrides and checkout selection.
- [Claude settings](https://code.claude.com/docs/en/settings): per-invocation settings and configuration precedence.
- [Claude permissions](https://code.claude.com/docs/en/permissions): additional directories, Edit rules, Windows path normalization, UNC limits and subprocess caveats.