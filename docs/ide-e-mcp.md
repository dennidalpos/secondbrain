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
| Claude Code | `~/.claude/CLAUDE.md` | `-Target claude-code` (utente), oppure `-WorkspacePath <progetto>` |
| VS Code | (nessun file di regole) | `-Target vscode` (profilo) o `-Target vscode -WorkspacePath <progetto>` |

Le impostazioni dell'account Claude non hanno un file: incolla il testo di `.runtime/hosts/<id>/istruzioni-globali.md`.

### Istruzioni nei repository

In ogni repository gestito `AGENTS.md` è la fonte unica (standard [agents.md](https://agents.md)): lo leggono Codex, Cursor, Windsurf, GitHub Copilot, JetBrains Junie, Zed, Roo Code e altri. Claude Code e Gemini CLI non lo leggono per nome: `secondbrain.ps1 -Sync` aggiunge i puntatori `CLAUDE.md` e `GEMINI.md`, che contengono solo `@AGENTS.md` in un blocco gestito (il tuo testo nel file non viene toccato). Per Aider aggiungi `read: AGENTS.md` a `.aider.conf.yml`. Dettagli: [Prompt e direttive](riferimento/customizing-prompts-and-directives.md#2-integrazione-delle-direttive-nei-diversi-ide).

Con più account o più radici di configurazione dello stesso strumento, registra ogni integrazione con `sb prompt SYS01` (procedura e disclaimer in [IDE](riferimento/adapters.md)): SecondBrain non rileva gli account, li dichiari tu.

## Collega

```powershell
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex -Apply
```

Per installare il server in più IDE, con anteprima e verifica guidate, usa `sb prompt SYS15`.

Il primo mostra l'anteprima, il secondo applica e salva prima il file esistente. Poi riavvia l'agente.

## Cosa può fare l'agente con MCP

| Strumento | A cosa serve |
|---|---|
| `get_startup_context` | Leggere contesto e memoria del progetto |
| `get_ready_tasks` | Vedere i task pronti |
| `get_task` | Leggere un task per intero (criteri, evidenze), anche archiviato |
| `search_knowledge` | Cercare negli appunti (archivio e report inclusi, a pagine) |
| `list_prompts`, `get_prompt`, `get_prompt_home` | Consultare i prompt |
| `check_publication` | Controllare un progetto prima del push |

Il server gira solo sul tuo PC e non apre porte di rete. All'avvio e durante le letture può integrare scritture di dossier già autorizzate e accodate; gli strumenti lo dichiarano con `readOnlyHint=false`.

## Con o senza MCP

| | Con MCP | Senza MCP (riga di comando) |
|---|---|---|
| **Pro** | Strumenti già nell'elenco dell'agente, con parametri e risposte compatte e a pagine. Durante avvio e letture recupera solo scritture di dossier già autorizzate e accodate. Stesso server per Claude, Codex e Antigravity. | Nessun processo da configurare. Funziona anche dove l'IDE non supporta MCP. Nessun costo fisso nel contesto. |
| **Contro** | La risposta JSON-RPC compatta `tools/list` con `id=2` misura 9.326 caratteri in italiano e 8.758 in inglese (misurazione del 2026-11-04; il solo `result` misura 9.292/8.724). Sono caratteri, non token. I consensi dipendono dal client e dalle sue impostazioni; i titoli e le annotazioni non li sostituiscono. Va riavviato l'agente dopo il collegamento. | L'agente deve conoscere i comandi e lanciarli da shell, con un permesso per comando. La vista globale `knowledge.ps1 -Tasks -All` è paginata come in MCP (50 voci, `-Offset` e `-Limit`; `-Limit 0` le restituisce tutte). |

Il risultato è lo stesso: un test confronta i due percorsi su tutti gli strumenti. Se l'agente supporta MCP conviene collegarlo; altrimenti non perdi nulla.

### Se MCP non funziona

1. **Il collegamento è corretto?** `scripts/mcp-server.ps1 -Pair -Target <agente>` mostra l'anteprima di percorso e configurazione.
2. **Il server risponde?** `scripts/test-secondbrain-mcp-handshake.ps1` simula l'avvio e le chiamate. Se passa, il problema sta nell'agente o nella sua configurazione.
3. **L'agente lo vede?** In Claude Code apri `/mcp`; in Codex usa `codex mcp list`. Riavvia l'agente dopo ogni modifica.
4. **Troppi popup?** Aggiungi `mcp__secondbrain__<strumento>` ai permessi dell'agente per gli strumenti di conoscenza: possono integrare solo richieste pendenti già autorizzate; `check_publication` conserva il consenso separato.

Limite: la verifica nelle interfacce grafiche degli IDE non è ancora provata dal vivo.

## Senza MCP

MCP è opzionale. Senza server l'agente (o tu) ottiene gli stessi contenuti dalla riga di comando: un test confronta i due percorsi sugli stessi input per tutti gli 8 strumenti (la CLI aggiunge solo l'intestazione `CATALOGO PROMPT` in `-Show`).

| Strumento MCP | Comando CLI | Comando `sb` nell'IDE |
|---|---|---|
| `get_startup_context` | `knowledge.ps1 -Startup [-Profile Full]` | — |
| `get_ready_tasks` | `knowledge.ps1 -Tasks -ReadyOnly` (`-All` per la vista globale paginata, con `-Offset` e `-Limit`; risposta `total`, `nextOffset`, `tasks`) | — |
| `get_task` | `knowledge.ps1 -Task <id o #seq>` | — |
| `search_knowledge` | `knowledge.ps1 -Search <testo> [-Mode Relevance]` | — |
| `get_prompt_home` | `prompts.ps1` | `sb prompt` |
| `list_prompts` | `prompts.ps1 -List -Compact` | `sb prompt list` |
| `get_prompt` | `prompts.ps1 -Show -Prompt <CHIAVE>` | `sb prompt mostra CHIAVE` |
| `check_publication` | `publication.ps1 -RepositoryPath <repo>` | `sb prompt SEC07` |
| — (nessuno strumento MCP: il tracker si scrive solo da CLI) | `knowledge.ps1 -UpdateTaskId <id> -Status done`, `knowledge.ps1 -NewTask <titolo>` | `sb prompt MEM03` |
| — (compattazione) | `knowledge.ps1 -Compact -CandidatePath <file>` | `sb compatta` |

Dal checkout di un repository gestito i comandi `knowledge.ps1` risolvono da soli il dossier; altrove indica `-Repository` o `-CheckoutPath`. `sb controlla` e `sb allinea` corrispondono a `secondbrain.ps1 -Check` e `-Sync`.
## Controlla

```powershell
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
```

Un file aggiornato non basta: apri una nuova sessione e scrivi `sb prompt`.

Le descrizioni degli strumenti MCP e dei loro parametri seguono la lingua della sessione server (`SECONDBRAIN_LANG` oppure `mcp-server.ps1 -Language it|en`). Il catalogo dei prompt usa le traduzioni già registrate. Gli argomenti `language` delle singole chiamate continuano a controllare il contenuto della risposta; per aggiornare le descrizioni memorizzate dal client occorre riavviare la sessione server.

Il pacchetto generato da `-ExportPackage` include il modulo dei messaggi necessario a `install-all-ides.ps1`. Il launcher accetta `-Language it|en` e segnala una radice mancante con il codice `mcp.package.root` anche quando il clone non è disponibile. Conservare insieme i file del pacchetto. Le verifiche stdio non attestano il caricamento nelle GUI degli IDE.

## Altri strumenti

Il codice riconosce anche VS Code, Cursor, Windsurf, Continue, JetBrains e Android Studio. Sono presenti ma **non convalidati**.

Dettagli: [agenti](riferimento/adapters.md), [MCP](riferimento/mcp-setup.md).
