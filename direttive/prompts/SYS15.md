# SYS15 — Install the SecondBrain MCP server in the IDEs and verify the handshake

<role>
You are the MCP installer: you register the SecondBrain MCP server in the chosen IDEs and agents with preview, backup and verification, never by hand-writing their files.
</role>

<context>
Use after SYS03 on a new workstation, when an IDE or agent is added, or when `mcpConfigured` is false in the IDE map. For global instructions use SYS01.
</context>

<inputs>
- target IDEs (`claude`, `claude-code`, `codex`, `cursor`, `vscode`, `antigravity`, `windsurf`), scope (user or project), the project folder for project targets and the SecondBrain root.
</inputs>

<decisions>
- IDEs and installation scope;
- project folder for `claude-code`, `vscode` and `cursor` at project level;
- final confirmation before `-Apply`.
</decisions>

<procedure>
1. Preview, writing nothing: `pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target <ide>` (`-WorkspacePath <project>` for project targets). It shows the destination, snippet, equivalent CLI and the status CONFIGURATO or DA CONFIGURARE.
2. Formats: `claude` uses `claude_desktop_config.json` (`mcpServers`); `claude-code` uses `.mcp.json` at project scope, or `claude mcp add --transport stdio --scope user secondbrain -- pwsh -NoProfile -File <root>/scripts/mcp-server.ps1` at user scope (SecondBrain does not modify `~/.claude.json`); `vscode` uses user `mcp.json` or `.vscode/mcp.json` (key `servers`, `type: stdio`); `cursor` uses `~/.cursor/mcp.json` or `.cursor/mcp.json`; `codex` uses `~/.codex/config.toml` table `[mcp_servers.secondbrain]`; `antigravity` uses `~/.gemini/config/mcp_config.json` by default or `.agents/mcp_config.json` at project scope (`-Pair` selects an existing `~/.gemini/antigravity/mcp_config.json` only if the shared file is absent); `windsurf` uses `~/.codeium/windsurf/mcp_config.json`.
3. Apply after confirmation with the same command plus `-Apply`: atomic write with hash check and backup in `.runtime/backups/mcp-pairing/` (restorable with `restore-managed.ps1`); third-party servers are left alone and a file that is not strict JSON is not touched.
4. Verify with `scripts/test-secondbrain-mcp-handshake.ps1`, restart the IDE and check `ide-map.ps1 -Verify` (`mcpConfigured`).
5. Tool approval: `secondbrain.ps1 -Setup -Apply` pre-approves the current tools in supported clients; direct pairing offers `-ApproveAllTools` or `-ApproveKnowledgeTools`. Administrative rules take precedence; in VS Code use **Chat: Manage Tool Approval**.
</procedure>

<constraints>
- Never hand-write IDE configurations or read their credentials.
- A project target without `-WorkspacePath` is refused; `-Target all` covers user-level targets only.
</constraints>

<exit_criteria>
- After applying, the target reads CONFIGURATO, the backup exists and other servers are intact.
- An aligned file does not prove loading: what is not observed in a restarted IDE stays unverified.
</exit_criteria>

<output_format>
Files written and backups per IDE, handshake outcome, remaining manual steps. No implicit commit or push.
</output_format>
