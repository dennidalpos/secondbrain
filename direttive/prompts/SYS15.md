# SYS15 — Installa il server MCP SecondBrain negli IDE e verifica l'handshake

> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: radice SecondBrain, IDE di destinazione e conferma prima di scrivere | **Esempio d'uso**: `sb prompt SYS15: installa il server mcp in vscode e claude code`

## Scopo

Registrare il server MCP di SecondBrain (`scripts/mcp-server.ps1`) negli IDE e agent scelti, con anteprima, backup e verifica, senza scrivere a mano i file di configurazione degli IDE.

## Quando usarlo

Dopo SYS03 su una postazione nuova, quando si aggiunge un IDE o un agent, o quando `mcpConfigured` risulta falso nella mappa degli IDE. Per le istruzioni globali degli IDE usa SYS01.

## Input

IDE di destinazione (`claude`, `claude-code`, `codex`, `cursor`, `vscode`, `antigravity`, `windsurf`), ambito (utente o progetto), cartella del progetto per i target di progetto e radice SecondBrain.

## Attività specifiche

Anteprima, senza scrivere nulla: `pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target <ide>` (con `-WorkspacePath <progetto>` per i target di progetto). Mostra file di destinazione, frammento, comando CLI equivalente e lo stato CONFIGURATO o DA CONFIGURARE.

Target e formati (fonti ufficiali degli IDE):

- `claude` (Claude Desktop): `claude_desktop_config.json`, chiave `mcpServers`.
- `claude-code`: ambito progetto in `.mcp.json` (chiave `mcpServers`) con `-WorkspacePath`; ambito utente con `claude mcp add --transport stdio --scope user secondbrain -- pwsh -NoProfile -File <radice>/scripts/mcp-server.ps1`, che scrive `~/.claude.json`: SecondBrain non lo modifica. Il server di progetto va approvato dall'utente alla prima sessione.
- `vscode`: `mcp.json` del profilo utente (`%APPDATA%/Code/User/mcp.json`) oppure `.vscode/mcp.json` con `-WorkspacePath`; chiave `servers` e `type: stdio` (non `mcp.servers` in `settings.json`).
- `cursor`: `~/.cursor/mcp.json` oppure `.cursor/mcp.json` con `-WorkspacePath`; chiave `mcpServers`.
- `codex`: `~/.codex/config.toml`, tabella `[mcp_servers.secondbrain]`, oppure `codex mcp add`.
- `antigravity`: `~/.gemini/antigravity/mcp_config.json`, chiave `mcpServers`.
- `windsurf`: `~/.codeium/windsurf/mcp_config.json`, chiave `mcpServers`.

Applicazione dopo la conferma dell'utente: lo stesso comando con `-Apply`. La scrittura è atomica, con controllo dell'hash e backup in `.runtime/backup/mcp-pairing/` (ripristinabile con `restore-managed.ps1`); i server di terzi restano al loro posto e un file che non è JSON rigoroso (commenti, errori) non viene toccato. Un target di progetto senza `-WorkspacePath` è rifiutato. `-Target all` copre soltanto i target a livello utente.

Verifica: `scripts/test-secondbrain-mcp-handshake.ps1` esegue initialize e tools/list con il comando registrato; poi riavvia l'IDE e controlla `ide-map.ps1 -Verify` (campo `mcpConfigured`). Non scrivere mai a mano le configurazioni degli IDE e non leggere le loro credenziali.

Il setup `secondbrain.ps1 -Setup -Apply` configura MCP per gli IDE selezionati e preautorizza gli otto strumenti attuali per nome nei client supportati. Nel pairing diretto usa `-ApproveAllTools` per lo stesso perimetro oppure `-ApproveKnowledgeTools` per i sette strumenti di conoscenza. Le regole amministrative conservano la precedenza. Per VS Code usa **Chat: Manage Tool Approval** nel profilo effettivo. I passaggi manuali e i profili di cui manca un percorso verificato restano nel report. Misura i popup in una nuova sessione del client.

## Decisioni da raccogliere

- IDE e ambito di installazione (scelta multipla);
- cartella del progetto per `claude-code`, `vscode` e `cursor` a livello di progetto;
- conferma finale prima di `-Apply`.

## Verifiche

Esegui l'anteprima prima di `-Apply`; dopo l'applicazione il target risulta CONFIGURATO, esiste il backup e gli altri server del file sono intatti. Un file allineato non prova il caricamento: l'IDE va riavviato e la visibilità del server nell'elenco degli strumenti va osservata; ciò che non è osservato resta non verificato.

## Consegna

File scritti e backup per IDE, esito dell'handshake, passi manuali rimasti (riavvio dell'IDE, approvazione del server di progetto in Claude Code). Nessun commit o push implicito.

## Prompt vicini

- SYS03: Attiva SecondBrain dopo discovery e selezione degli asset.
- SYS01: Verifica gli IDE; mappa, registra account o riallinea su richiesta.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
