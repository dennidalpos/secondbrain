# Agenti e MCP

Ogni agente riceve due cose: le **regole** e il **collegamento MCP**, che gli permette di leggere memoria e prompt.

```mermaid
flowchart LR
    S["SecondBrain"] -->|"regole"| F["File dell'agente"]
    S -->|"MCP, solo lettura"| A["Agente"]
    F --> A
```

## Strumenti convalidati

| Strumento | File di regole | Comando MCP |
|---|---|---|
| Claude per Windows | `~/.claude/CLAUDE.md` | `-Target claude` |
| ChatGPT Codex per Windows | `~/.codex/AGENTS.md` | `-Target codex` |
| Antigravity per Windows | `~/.gemini/GEMINI.md` | `-Target antigravity` |

Le impostazioni dell'account Claude non hanno un file: incolla il testo di `.runtime/hosts/<id>/istruzioni-globali.md`.

## Collega

```powershell
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex -Apply
```

Il primo mostra l'anteprima, il secondo applica e salva prima il file esistente. Poi riavvia l'agente.

## Cosa può fare l'agente con MCP

| Strumento | A cosa serve |
|---|---|
| `get_startup_context` | Leggere contesto e memoria del progetto |
| `get_ready_tasks` | Vedere i task pronti |
| `search_knowledge` | Cercare negli appunti |
| `list_prompts`, `get_prompt`, `get_prompt_home` | Consultare i prompt |
| `check_publication` | Controllare un progetto prima del push |

Il server gira solo sul tuo PC: nessuna porta di rete e nessuna modifica ai file.

## Controlla

```powershell
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
```

Un file aggiornato non basta: apri una nuova sessione e scrivi `sb prompt`.

## Altri strumenti

Il codice riconosce anche VS Code, Cursor, Windsurf, Continue, JetBrains e Android Studio. Sono presenti ma **non convalidati**.

Dettagli: [agenti](riferimento/adapters.md), [MCP](riferimento/mcp-setup.md).
