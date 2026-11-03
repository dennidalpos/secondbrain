# SYS15 — Install the SecondBrain MCP server in the IDEs and verify the handshake

> **Scope**: central | **Mode**: write | **Needs**: SecondBrain root, target IDEs and confirmation before writing | **Example**: `sb prompt SYS15: install the mcp server in vscode and claude code`

## Purpose

Register the SecondBrain MCP server (`scripts/mcp-server.ps1`) in the chosen IDEs and agents, with preview, backup and verification, without hand-writing the IDEs' configuration files.

## When to use

After SYS03 on a new workstation, when an IDE or agent is added, or when `mcpConfigured` is false in the IDE map. For the IDEs' global instructions use SYS01.

## Input

Target IDEs (`claude`, `claude-code`, `codex`, `cursor`, `vscode`, `antigravity`, `windsurf`), scope (user or project), project folder for the project targets and the SecondBrain root.

## Activities

Preview, writing nothing: `pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target <ide>` (with `-WorkspacePath <project>` for the project targets). It shows the destination file, the snippet, the equivalent CLI command and the status CONFIGURATO or DA CONFIGURARE.

Targets and formats (official IDE sources):

- `claude` (Claude Desktop): `claude_desktop_config.json`, key `mcpServers`.
- `claude-code`: project scope in `.mcp.json` (key `mcpServers`) with `-WorkspacePath`; user scope with `claude mcp add --transport stdio --scope user secondbrain -- pwsh -NoProfile -File <root>/scripts/mcp-server.ps1`, which writes `~/.claude.json`: SecondBrain does not modify it. The project server must be approved by the user in the first session.
- `vscode`: the user-profile `mcp.json` (`%APPDATA%/Code/User/mcp.json`) or `.vscode/mcp.json` with `-WorkspacePath`; key `servers` and `type: stdio` (not `mcp.servers` in `settings.json`).
- `cursor`: `~/.cursor/mcp.json` or `.cursor/mcp.json` with `-WorkspacePath`; key `mcpServers`.
- `codex`: `~/.codex/config.toml`, table `[mcp_servers.secondbrain]`, or `codex mcp add`.
- `antigravity`: `~/.gemini/antigravity/mcp_config.json`, key `mcpServers`.
- `windsurf`: `~/.codeium/windsurf/mcp_config.json`, key `mcpServers`.

Apply after the user's confirmation: the same command with `-Apply`. The write is atomic, with hash check and backup in `.runtime/backup/mcp-pairing/` (restorable with `restore-managed.ps1`); third-party servers stay where they are and a file that is not strict JSON (comments, errors) is not touched. A project target without `-WorkspacePath` is refused. `-Target all` covers user-level targets only.

Verification: `scripts/test-secondbrain-mcp-handshake.ps1` runs initialize and tools/list with the registered command; then restart the IDE and check `ide-map.ps1 -Verify` (field `mcpConfigured`). Never hand-write the IDEs' configurations and never read their credentials.

## Decisions to collect

- IDEs and installation scope (multiple choice);
- project folder for `claude-code`, `vscode` and `cursor` at project level;
- final confirmation before `-Apply`.

## Checks

Run the preview before `-Apply`; after applying, the target reads CONFIGURATO, the backup exists and the other servers in the file are intact. An aligned file does not prove loading: the IDE must be restarted and the server's presence in the tool list observed; what is not observed stays unverified.

## Delivery

Files written and backups per IDE, handshake outcome, remaining manual steps (IDE restart, approval of the project server in Claude Code). No implicit commit or push.

## Related prompts

- SYS03: Activate SecondBrain after discovery and asset selection.
- SYS01: Check the IDEs; map, register accounts or realign on request.
- SYS04: Check or align the workstation's already managed assets.
