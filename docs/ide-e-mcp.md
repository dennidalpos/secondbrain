# Agents and MCP

[Retained Italian source; use this English page for current behavior](ide-e-mcp.it.md)

SecondBrain distributes approved instructions and can configure a local stdio MCP connection. Configuration support does not prove that an IDE loaded those instructions or that every profile has been qualified.

## Instruction and configuration targets

| Target | Configuration scope |
|---|---|
| Claude Desktop | User-level MCP with -Target claude; this does not establish how instructions were loaded |
| Codex | User-level MCP with -Target codex; project pairing is not accepted |
| Antigravity | User-level MCP or explicit project -Scope project -WorkspacePath |
| Claude Code | User CLI registration with -Target claude-code, or project .mcp.json with -WorkspacePath |
| VS Code | User/profile MCP, or project .vscode/mcp.json with -WorkspacePath |
| Cursor | User MCP, or project .cursor/mcp.json with -Scope project -WorkspacePath |

Other adapters exist in the implementation; consult [adapter qualification](riferimento/adapters.md) for their actual scope. Do not label an adapter live-qualified from file inspection or a synthetic handshake alone.

In managed repositories, `AGENTS.md` is the common source. Sync manages `CLAUDE.md` and `GEMINI.md` pointers using `@AGENTS.md`. Existing text outside managed blocks is preserved. IDE-specific support and account-level settings require separate checks. SecondBrain does not inspect credential stores or automate login.

## Preview, pair and verify

~~~powershell
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target cursor -Scope project -WorkspacePath $project
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target cursor -Scope project -WorkspacePath $project -Apply
~~~

Run this project-scoped Cursor example from the SecondBrain checkout with $project set to the selected Git checkout. It was verified on synthetic configuration, without launching a client.

Preview user-level pairing separately for Codex or Claude Desktop; neither target accepts project scope. Review Setup's user-level MCP preview for selected supported IDEs or explicit `-McpTargets`. In interactive Setup, review the destination and named tool rules before entering `APPLICA`. For direct pairing, preview first. Apply changes the selected configuration with backup. Restart the client and inspect its MCP connection in a new session. SYS15 guides multi-client installation; SYS01 handles profile/account evidence. For workspace targets, inspect the explicit destination before applying.

## Exposed tools

| Tool | CLI equivalent |
|---|---|
| `get_startup_context` | `knowledge.ps1 -Startup [-Profile Full]` |
| `get_ready_tasks` | `knowledge.ps1 -Tasks -ReadyOnly` |
| `get_task` | `knowledge.ps1 -Task <id or sequence>` |
| `search_knowledge` | `knowledge.ps1 -Search <text> [-Mode Relevance]` |
| `get_prompt_home` | `prompts.ps1` |
| `list_prompts` | `prompts.ps1 -List -Compact` |
| `get_prompt` | `prompts.ps1 -Show -Prompt <code>` |
| `check_publication` | `publication.ps1 -RepositoryPath <checkout>` |
| `preview_dossier_write` | Reviewed plan preparation; see the [write guide](riferimento/mcp-writes.md) |
| `submit_dossier_write` | Submit one plan after local CLI approval; see the [write guide](riferimento/mcp-writes.md) |

The server exposes ten tools. Task status/new-task writes and memory/history appends are available through reviewed MCP submission as well as the CLI. Activity submission remains disabled until its activation procedure is complete. Compaction still uses reviewed CLI maintenance. Use `-CheckoutPath` or `-Repository` when the current working directory does not resolve the product. The global task view is opt-in with `-All`, paginated by `-Offset` and `-Limit` (default 50).

## Reads may have side effects

The server runs over stdio and does not listen on a network port. At startup and during lookups it can apply already-authorized queued dossier writes; the knowledge tools advertise readOnlyHint=false; preview_dossier_write advertises readOnlyHint=true, and submit_dossier_write requires a local approval receipt. Knowledge tools and the publication gate have distinct consent requirements.

For a strict no-recovery session start `mcp-server.ps1 -NoRecovery`. Per-call `noRecovery=true` only prevents recovery during that call, not startup recovery. The CLI equivalent for knowledge reads is `knowledge.ps1 -NoRecovery`.

Repository memory collection is enabled separately and requires a verified permission policy for the turn. Fixture tests do not qualify native live collectors. See [memory cycle and known 1.4.0 limits](riferimento/memory-cycle.md#known-140-limits).

## Language and packages

Use `SECONDBRAIN_LANG` or server `-Language en|it` for tool descriptions. Individual `language` arguments control content. Restart a client/server session when cached tool descriptions need updating.

`-ExportPackage` creates a launcher and required modules for importing the connection elsewhere; keep the package together and review its destination. A package or a successful handshake does not prove live client loading. See [MCP setup](riferimento/mcp-setup.md).

## Troubleshooting

1. Inspect `-Pair -Target <client>` for the intended path and scope.
2. Run the repository's MCP handshake checks to distinguish protocol failures from client configuration.
3. Inspect the connection in the real client; Claude Code provides `/mcp`, while Codex CLI provides `codex mcp list`.
4. Check named tool permissions without granting broader access than the current workflow needs.
5. Record account/profile, instruction revision, observed loading and the popup outcome for the exact tool. `secondbrain.ps1 -Check -ObservationPath` reports `mcp-consent-unverified` for a supported IDE with an incomplete or invalid consent observation.

Use the shell when MCP is unavailable. CLI access has the same data model, while shell permissions remain those of the session. Detailed procedures: [adapters](riferimento/adapters.md), [MCP setup](riferimento/mcp-setup.md), [deferred writes](riferimento/pending-writes.md).
