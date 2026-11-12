# MCP setup and verification

[Retained Italian source; use this English page for current behavior](mcp-setup.it.md)

The PowerShell server uses stdio JSON-RPC and no listening network port. It exposes knowledge/prompt/publication operations. Startup and lookups never integrate queued dossier writes; only `submit_dossier_write` writes, one reviewed request with a local receipt.

## Prerequisites and contract

Use Windows, PowerShell 7.5+ and Git 2.42+ with the actual active brain configuration. The server negotiates MCP 2025-03-26 and accepts 2024-11-05 when requested. Advertised annotations describe side effects; they do not grant user permission.

The nine read tools are get_startup_context, get_ready_tasks, get_task, search_knowledge, get_prompt_home, list_prompts, get_prompt, check_publication and list_ides. Two additional tools, preview_dossier_write and submit_dossier_write, support restricted dossier writes using reviewed local receipts. No arbitrary shell is exposed. See [reviewed MCP writes](mcp-writes.md). The server also implements prompts/list for the catalog cards, prompts/get with an optional objective, and resources/list/resources/read for secondbrain://prompts/catalog. Resource subscription and list-change notifications are not advertised. A client still needs to expose those protocol surfaces; generic MCP support does not prove its UI does so.

For a strict no-recovery session:

~~~powershell
pwsh -NoProfile -File scripts/mcp-server.ps1 -NoRecovery
~~~

A call's noRecovery=true prevents integration in that call only; it cannot undo startup integration.

## Preview and pair

~~~powershell
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target claude-code -Scope user
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target vscode -Scope project -WorkspacePath C:/Projects/MyProduct
~~~

Supported targets are codex, claude, claude-code, cursor, vscode, antigravity, windsurf and all. User is the default scope; WorkspacePath without explicit Scope preserves project scope. Project scope requires a directory and is supported for the adapters declared by the implementation.

Google documents `~/.gemini/config/mcp_config.json` for the user and `.agents/mcp_config.json` for a workspace. `-Pair` uses these paths and retains the legacy fallback to `~/.gemini/antigravity/mcp_config.json` when it is the only existing user file. The preview shows the selected destination. [Antigravity IDE MCP documentation](https://antigravity.google/docs/mcp?tab=ide#antigravity-ide)

Inspect the exact destination/snippet/native CLI command before adding Apply. Target all is not permission to change every client. Setup previews user-level pairing for selected supported IDEs or explicit `-McpTargets`. Run with `-Yes` and without `-Apply` to inspect the plan before an explicit apply. In interactive Setup, the MCP preview precedes the `APPLICA` prompt. SYS15 guides both paths.

Codex/Claude Code can use native user CLI registration. JSON/TOML adapters update the secondbrain section while preserving supported unrelated settings. Invalid input stops writing. JSON formatting/comments may not survive reserialization, so retain verified backup metadata. Inspect actual profile/configuration roots rather than assuming a path from the product name.

## Permissions and packages

ApproveKnowledgeTools (alias ApproveReadTools) prepares named knowledge permissions that include already-authorized queue integration. check_publication remains separate. ApproveAllTools retains the eight existing names and excludes the two new tools. It is a broader policy choice requiring explicit scope approval; do not use it as a routine fix for prompts.

`-ExportPackage` writes to a new directory below the checkout's `.runtime`. Use a new child directory of an initialized work folder for subsequent exports. Verify the payloads with `SHA256SUMS` and keep the launcher, message module, and configuration together. A failed export may leave an incomplete directory. Use a fresh destination for the retry.

The generated README includes a VS Code CLI command, a Cursor import link, and native pairing commands for Codex and Claude Code. It also covers the Antigravity 2.x user and project paths. The snippets and import commands contain the exporting checkout path. The separate `claude/secondbrain.mcpb` asks for the checkout directory at import time and requires PowerShell 7.5+ on PATH.

The generated installer applies the connection. To apply the supported tool permissions as well, review the permission previews and pass `-ApproveKnowledgeTools`. The plan keeps `check_publication` subject to confirmation. Verify loading and actual consent behavior in a fresh session of the target client.

## Verify in layers

1. Inspect Pair preview for target, scope, destination and brain root.
2. Run the repository MCP handshake checks to verify stdio initialization/tool behavior.
3. Inspect actual registration in the intended client/profile and restart the owned session where needed.
4. Verify instruction revision and loading in a new chat separately.
5. Record permission rules, account/profile and observed evidence separately.

For a workstation check, pass a schema 1 IDE observation receipt under `.runtime` to `secondbrain.ps1 -Check -ObservationPath <receipt>`. In the matching IDE entry, add `mcpConsent` with `tool` set to the exact SecondBrain tool name, such as `get_prompt_home`, and `outcome` set to `popup-shown` or `no-popup`. Use a fresh session and evidence that supports both loading and the popup observation. The checker validates the existing IDE receipt and evidence hash, and reports `mcp-consent-unverified` when the consent observation is incomplete or invalid. Either observed outcome is evidence for that tool and session only.

Claude Code provides /mcp; Codex CLI provides codex mcp list. These inspect the selected client's view, not another user's account.

Tool-description language follows server Language/SECONDBRAIN_LANG; per-call language controls content. Restart cached sessions after deliberate configuration/description changes; do not restart another agent's process automatically.

## Troubleshooting and limits

A successful synthetic handshake does not prove live GUI integration. Missing tools can reflect registration, scope, environment or stale client cache. Invalid paths/root should be fixed at the selected configuration, not by broadening filesystem permissions.

The server never integrates queued requests; NoRecovery additionally forbids new writes. Native memory collectors and real multi-PC SMB need separate qualification. See [adapters](adapters.md), [pending writes](pending-writes.md), [safe writes](safety-backups.md).
