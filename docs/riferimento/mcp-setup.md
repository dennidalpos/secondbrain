# MCP setup and verification

[Retained Italian source; use this English page for current behavior](mcp-setup.it.md)

The PowerShell server uses stdio JSON-RPC and no listening network port. It exposes knowledge/prompt/publication operations; startup and lookups may integrate already-authorized queued dossier writes. It is not a strictly read-only service.

## Prerequisites and contract

Use Windows, PowerShell 7.5+ and Git 2.42+ with the actual active brain configuration. The server negotiates MCP 2025-03-26 and accepts 2024-11-05 when requested. Advertised annotations describe side effects; they do not grant user permission.

The eight tools are get_startup_context, get_ready_tasks, get_task, search_knowledge, get_prompt_home, list_prompts, get_prompt and check_publication. No arbitrary shell or extra tracker-write tool is exposed. The server also implements prompts/list for the catalog cards, prompts/get with an optional objective, and resources/list/resources/read for secondbrain://prompts/catalog. Resource subscription and list-change notifications are not advertised. A client still needs to expose those protocol surfaces; generic MCP support does not prove its UI does so.

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

Inspect the exact destination/snippet/native CLI command before adding Apply. Target all is not permission to change every client. Setup with explicit MCP targets is another reviewed installation path; SYS15 guides it.

Codex/Claude Code can use native user CLI registration. JSON/TOML adapters update the secondbrain section while preserving supported unrelated settings. Invalid input stops writing. JSON formatting/comments may not survive reserialization, so retain verified backup metadata. Inspect actual profile/configuration roots rather than assuming a path from the product name.

## Permissions and packages

ApproveKnowledgeTools (alias ApproveReadTools) prepares named knowledge permissions that include already-authorized queue integration. check_publication remains separate. ApproveAllTools is a broader policy choice requiring explicit scope approval; do not use it as a routine fix for prompts.

ExportPackage creates a configuration package/launcher through direct file writes. Its current implementation can overwrite files in an existing OutDir without the managed writer's expected-hash checks/backups, and does not enforce runtime confinement. Always choose a new initialized runtime destination, preserve any previous package, and review the target before export. Export is not an installation preview. Keep launcher, modules/messages and configuration together; a package does not prove installation or live loading.

## Verify in layers

1. Inspect Pair preview for target, scope, destination and brain root.
2. Run the repository MCP handshake checks to verify stdio initialization/tool behavior.
3. Inspect actual registration in the intended client/profile and restart the owned session where needed.
4. Verify instruction revision and loading in a new chat separately.
5. Record permissions/account/profile and observed evidence; do not infer login from a config file.

Claude Code provides /mcp; Codex CLI provides codex mcp list. These inspect the selected client's view, not another user's account.

Tool-description language follows server Language/SECONDBRAIN_LANG; per-call language controls content. Restart cached sessions after deliberate configuration/description changes; do not restart another agent's process automatically.

## Troubleshooting and limits

A successful synthetic handshake does not prove live GUI integration. Missing tools can reflect registration, scope, environment or stale client cache. Invalid paths/root should be fixed at the selected configuration, not by broadening filesystem permissions.

Strict read-only work needs NoRecovery; client approval settings cannot undo already integrated requests. Native memory collectors and real multi-PC SMB need separate qualification. See [adapters](adapters.md), [pending writes](pending-writes.md), [safe writes](safety-backups.md).
