# Guida Operativa: Configurazione, Importazione e Pacchetto del Server MCP negli IDE

Questa guida illustra l'architettura e la procedura passo-passo per attivare, configurare ed esportare il server locale **Model Context Protocol (MCP)** di SecondBrain (`scripts/mcp-server.ps1`) per i principali ambienti di sviluppo e coding agent (**OpenAI Codex**, **Claude Desktop / Claude Code**, **Cursor**, **Visual Studio Code**, **Google Antigravity** e **Windsurf**).

---

## 1. Architettura, Protocollo e Garanzie

Il server MCP di SecondBrain è un servizio conforme allo standard di settore **Model Context Protocol (versione protocollo 2024-11-05)** progettato per fornire contesto ingegneristico continuo e sicuro agli agenti di sviluppo.

### Garanzie di Isolamento e Sicurezza
- **Nessuna porta di rete aperta**: la comunicazione avviene esclusivamente tramite flussi standard di input/output (**stdio**) via `pwsh` su processo locale.
- **Zero telemetria esterna**: nessun dato, richiesta, prompt o metadato viene trasmesso a servizi terzi o remoti.
- **Accesso in sola lettura (`read`/`verify`)**: il server espone strumenti di sola consultazione (contesto di avvio, task pronti, ricerca nella conoscenza PARA, catalogo prompt e verifica di pubblicabilità), prevenendo modifiche distruttive o accidentali al repository.

### Prerequisiti di Sistema
- **PowerShell 7.5+** (`pwsh`) installato su Windows.
- Percorso assoluto del clone SecondBrain (es. `C:\Progetti\SecondBrain` o `$env:SECONDBRAIN_HOME`).
- Il pairing (`-Pair`) non richiede la postazione attivata: legge solo il percorso del clone. Per usare il server con il contesto dei tuoi repository attiva prima la postazione (`secondbrain.ps1 -Setup`, vedi [setup](portable-brain.md#configurazione-e-prerequisiti)).
- Prima di `-Apply` leggi [cosa modifica SecondBrain e dove sono i backup](safety-backups.md).

---

## 2. Strumenti, Prompt e Risorse Esposti

### Strumenti Informativi (`tools/list` e `tools/call`)
| Tool MCP | Modalità | Parametri principali | Descrizione |
| :--- | :---: | :--- | :--- |
| `get_startup_context` | `read` | `repository`, `checkoutPath`, `dossier`, `readyOnly`, `profile`, `budget` | Restituisce il pacchetto di avvio del repository in lavoro. Profilo `slim` (predefinito, 20.000 caratteri, solo primo caricamento): indice, sezioni essenziali di `context.md` e `memory.md`, task pronti in una riga ed elenco dei livelli non caricati. Profilo `full`: tutto, senza tetto. Senza `repository` né `dossier` il repository si risolve dal checkout (`checkoutPath` o directory corrente); non esiste più un default sul dossier di SecondBrain. |
| `get_ready_tasks` | `read` | `repository`, `checkoutPath`, `all`, `includeAcceptance`, `offset`, `limit` *(solo con `all=true`: 50 task per pagina, `nextOffset` per la successiva)* | Restituisce la proiezione dei soli task eseguibili (con dipendenze soddisfatte) del repository in lavoro: `repository` esplicito oppure quello del checkout (`checkoutPath` o directory corrente del server). La vista globale richiede `all=true`, è in sola lettura, ogni voce ha `scope: global`, ed è incompatibile con `repository`. Senza repository risolvibile risponde con errore. |
| `get_task` | `read` | `task` *(obbligatorio: ID o `#seq`)*, `repository`, `checkoutPath`, `dossier` | Restituisce il record integro di un task (descrizione, criteri di accettazione, evidenze, provenienza) dal tracker o da `history/tracker-archive.json`. Alias `secondbrain_get_task`. |
| `search_knowledge` | `read` | `query` *(obbligatorio)*, `budget`, `limit`, `offset`, `dossier`, `repository`, `allDossiers`, `includeOriginals`, `mode` *(`literal` predefinito, `relevance` per termini multipli ordinati per pertinenza)* | Ricerca deterministica nei file di conoscenza del dossier in lavoro (`context.md`, `memory.md`, `tracker.json`, archivio tracker, rapporti). Tetto predefinito: 20 riscontri e 10.000 caratteri; con `hasMore=true` si richiama con `offset=nextOffset`. `limit=0` e `budget=0` tolgono il tetto; `allDossiers=true` cerca in tutte le aree; `includeOriginals=true` include `history/compaction/`. |
| `list_prompts` | `read` | `category` *(opzionale: id o prefisso come `TST`)*, `compact` *(opzionale)*, `pack` *(opzionale: `core`, `maintenance`, `all`)* | Elenca il catalogo dei 62 workflow generici (pacchetto core; `pack` = `maintenance` per i 16 di manutenzione SecondBrain). Con `compact` una riga per prompt (codice, modalità, sommario). |
| `get_prompt` | `read` | `prompt` *(obbligatorio: ID `pmt-…`, codice come `TST04` o alias)* | Restituisce il testo integrale della scheda ingegneristica con scopo, attività, verifiche e consegna. |
| `get_prompt_home` | `read` | *(nessuno)* | Schermata iniziale di `sb prompt`: percorso del file Markdown del catalogo completo e tabella dei comandi `sb` con descrizione. |
| `check_publication` | `verify` | `repositoryPath` *(obbligatorio)*, `detail` | Esegue la verifica di pubblicabilità (SEC07) del working tree, indice e storia del repository specificato prima di push o rilascio. Risposta in riepilogo (conteggi per regola, primi 20 riscontri, `findingsTotal`); `detail=true` il rapporto integro. |

### Prompt Standard MCP (`prompts/list` e `prompts/get`)
Il server implementa il protocollo standard MCP Prompts: tutti i workflow attivi sono esposti nativamente come template richiamabili direttamente dall'interfaccia dell'IDE (es. selezionando `SYS03`, `DEV01`, `SEC07`).

### Risorse Standard MCP (`resources/list` e `resources/read`)
- URI: `secondbrain://prompts/catalog`
- Descrizione: catalogo strutturato in formato JSON dei workflow attivi con metadati completi.

---

## 3. Metodo 1: Accoppiamento e Importazione Automatica (`-Pair` e `-Apply`)

SecondBrain fornisce il comando CLI `scripts/mcp-server.ps1` per rilevare, visualizzare e iniettare automaticamente la configurazione corretta in tutti gli IDE.

### A. Anteprima della configurazione (Sola lettura)
Per verificare percorsi, stato e frammenti di configurazione senza scrivere su disco:

```powershell
# Anteprima per tutti gli IDE supportati
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target all

# Oppure per un singolo IDE specifico
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target claude
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target claude-code -WorkspacePath C:/Progetti/mio-progetto
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target cursor
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target vscode
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target antigravity
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target windsurf

# Target di progetto: -WorkspacePath scrive nella cartella del progetto (vscode: .vscode/mcp.json, cursor: .cursor/mcp.json, claude-code: .mcp.json)
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target vscode -WorkspacePath C:/Progetti/mio-progetto
```

`-Target all` copre i sei target a livello utente; `claude-code` va indicato esplicitamente e richiede `-WorkspacePath` per `-Apply` (senza, rifiuta e non scrive). Da chat: `sb prompt SYS15`.

### B. Applicazione automatica sicura (`-Apply`)
Per applicare automaticamente la configurazione al file di configurazione dell'IDE:

```powershell
# Applica la configurazione a tutti i target (il file viene creato anche se l'IDE non è installato)
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target all -Apply

# Oppure applica solo a un IDE specifico (es. Claude)
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target claude -Apply
```

#### Garanzie dell'Applicazione Automatica:
1. **Le altre voci restano**: i server MCP già configurati nel JSON non vengono toccati; nel TOML di Codex viene sostituita solo la sezione `[mcp_servers.secondbrain]`. Il JSON è riscritto con formattazione standard (commenti e ordine delle chiavi non si conservano: per questo c'è il backup).
2. **File illeggibile = nessuna scrittura**: se il file esistente non è JSON rigoroso (errori o commenti, per esempio JSONC) o non ha un oggetto come radice, l'operazione si ferma con errore e il file resta com'è.
3. **Scrittura atomica con backup verificato**: se il file esiste, l'originale è copiato prima in `.runtime/backup/mcp-pairing/<guid>.bin` con metadati `<guid>.bin.json` (percorso, hash), la scrittura controlla che il file non sia cambiato nel frattempo e rilegge il risultato. Trova e ripristina il backup con `scripts/restore-managed.ps1 -List -Path <file>` (vedi [sicurezza e backup](safety-backups.md)).
4. **Codifica UTF-8 pulita**: scrive file senza BOM.

---

## 4. Metodo 2: Esportazione di un Pacchetto Distribuibile (`-ExportPackage`)

Se desideri creare un pacchetto portabile con tutte le configurazioni già pronte, script one-click e guida per distribuirlo ad altri workspace o postazioni:

```powershell
# Genera il pacchetto nella cartella predefinita (.runtime/mcp-package)
pwsh -NoProfile -File scripts/mcp-server.ps1 -ExportPackage

# Oppure specifica una directory di destinazione personalizzata
pwsh -NoProfile -File scripts/mcp-server.ps1 -ExportPackage -OutDir "C:\Condivisa\SecondBrain-MCP-Package"
```

### Contenuto del Pacchetto Generato:
```text
mcp-package/
├── README.md                      # Guida autonoma di consultazione rapida
├── install-all-ides.ps1           # Script PowerShell one-click per applicare a tutti gli IDE
├── codex/
│   ├── config.toml                # File completo per ~/.codex/config.toml
│   └── snippet.toml               # Solo la sezione [mcp_servers.secondbrain]
├── claude/
│   └── claude_desktop_config.json # Configurazione JSON per Claude Desktop
├── cursor/
│   └── mcp.json                   # Configurazione JSON per Cursor
├── vscode/
│   └── mcp.json                   # Frammento mcp.json con servers (type stdio)
├── antigravity/
│   └── mcp_config.json            # Configurazione JSON per Google Antigravity
└── windsurf/
    └── mcp_config.json            # Configurazione JSON per Windsurf
```

---

## 5. Metodo 3: Configurazione Manuale per Singolo IDE

Se preferisci configurare manualmente ciascun ambiente, individua la sezione seguente:

### A. OpenAI Codex (CLI e config.toml)
- Percorso file: `%USERPROFILE%\.codex\config.toml` (o `$env:CODEX_HOME\config.toml`)

**Tramite comando CLI:**
```bash
codex mcp add secondbrain -- pwsh -NoProfile -File "C:\Progetti\SecondBrain\scripts\mcp-server.ps1"
```

**Tramite modifica manuale di `config.toml`:**
```toml
[mcp_servers.secondbrain]
command = "pwsh"
args = ["-NoProfile", "-File", "C:\\Progetti\\SecondBrain\\scripts\\mcp-server.ps1"]
```

---

### B. Claude Desktop e Claude Code
- Percorso file: `%APPDATA%\Claude\claude_desktop_config.json`
- In Claude Desktop: **Settings** > **Developer** > **Edit Config**.

Aggiungi o integra la voce `secondbrain` sotto `mcpServers`:
```json
{
  "mcpServers": {
    "secondbrain": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-File",
        "C:/Progetti/SecondBrain/scripts/mcp-server.ps1"
      ]
    }
  }
}
```
*Salva e riavvia Claude Desktop. L'icona del martello (🔨) mostrerà i tool SecondBrain attivi.*

**Claude Code** registra il server altrove: in `.claude.json` (profilo utente, o la cartella `CLAUDE_CONFIG_DIR` se impostata), con `claude mcp add secondbrain -- pwsh -NoProfile -File "<percorso>/scripts/mcp-server.ps1"`. `-Pair -Target claude` mostra lo stato dei due file separatamente (`Desktop: CONFIGURATO | Code: DA CONFIGURARE`); `-Apply` scrive solo `claude_desktop_config.json`, la registrazione di Claude Code resta un comando da eseguire a mano e `.claude.json` viene soltanto letto.

Per il solo Claude Code: `-Pair -Target claude-code -WorkspacePath <progetto> -Apply` scrive `.mcp.json` nella cartella del progetto (chiave `mcpServers`; Claude Code chiede l'approvazione alla prima sessione). L'ambito utente resta alla CLI: `claude mcp add --transport stdio --scope user secondbrain -- pwsh -NoProfile -File "<percorso>/scripts/mcp-server.ps1"`, che scrive `~/.claude.json` (SecondBrain non lo modifica).

---

### C. Cursor IDE
- Percorso file globale: `%USERPROFILE%\.cursor\mcp.json` (oppure `.cursor/mcp.json` nel workspace)
- Tramite UI: **Settings** (`Ctrl + ,`) > **Features** > **MCP Servers** > **Add New MCP Server**.

Compila i campi:
- **Name**: `secondbrain`
- **Type**: `command`
- **Command**: `pwsh -NoProfile -File C:/Progetti/SecondBrain/scripts/mcp-server.ps1`

Oppure incolla nel file `mcp.json`:
```json
{
  "mcpServers": {
    "secondbrain": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-File",
        "C:/Progetti/SecondBrain/scripts/mcp-server.ps1"
      ]
    }
  }
}
```

---

### D. Visual Studio Code
- Percorso file: `%APPDATA%\Code\User\mcp.json` (profilo utente) oppure `.vscode/mcp.json` nel progetto (`-WorkspacePath`)

Aggiungi la configurazione sotto la chiave `"servers"`, con `"type": "stdio"` ([formato ufficiale](https://code.visualstudio.com/docs/agents/reference/mcp-configuration)); `mcp.servers` in `settings.json` non è più il formato:
```json
{
  "servers": {
    "secondbrain": {
      "type": "stdio",
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-File",
        "C:/Progetti/SecondBrain/scripts/mcp-server.ps1"
      ]
    }
  }
}
```

---

### E. Google Antigravity
- Percorso file: `%USERPROFILE%\.gemini\config\mcp_config.json` (Antigravity 2.0, condiviso tra IDE e CLI) se esiste, altrimenti `%USERPROFILE%\.gemini\antigravity\mcp_config.json` (versioni precedenti). `-Pair` sceglie il file da solo; verifica quale esiste sulla tua postazione.

Inserisci o integra la sezione `mcpServers`:
```json
{
  "mcpServers": {
    "secondbrain": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-File",
        "C:/Progetti/SecondBrain/scripts/mcp-server.ps1"
      ]
    }
  }
}
```

---

### F. Windsurf
- Percorso file: `%USERPROFILE%\.codeium\windsurf\mcp_config.json`

Inserisci o integra la sezione `mcpServers`:
```json
{
  "mcpServers": {
    "secondbrain": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-File",
        "C:/Progetti/SecondBrain/scripts/mcp-server.ps1"
      ]
    }
  }
}
```

---

## 6. Verifica della Connessione e Test Diagnostici

Puoi testare il server direttamente dal terminale PowerShell inviando messaggi JSON-RPC standard prima o dopo l'integrazione nell'IDE.

### Test 1: Handshake `tools/list`
```powershell
'{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | pwsh -NoProfile -File scripts/mcp-server.ps1
```
*Esito atteso*: una risposta JSON valida contenente la lista degli 8 tool con schemi e proprietà.

### Test 2: Ping rapido
```powershell
'{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}' | pwsh -NoProfile -File scripts/mcp-server.ps1
```
*Esito atteso*: `{"jsonrpc":"2.0","id":2,"result":{}}`

### Test 3: Esecuzione di uno strumento (`tools/call`)
```powershell
'{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_prompt","arguments":{"prompt":"SYS03"}}}' | pwsh -NoProfile -File scripts/mcp-server.ps1
```
*Esito atteso*: contenuto Markdown completo della scheda `SYS03`.

### Test 4: Handshake completo per ogni IDE
```powershell
pwsh -NoProfile -File scripts/test-secondbrain-mcp-handshake.ps1 [-Target codex,vscode|all] [-PublicationPath <repository Git>] [-ReportPath <file>]
```
Per ciascun IDE avvia come processo il comando che `-Pair` registra e invia `initialize`, `tools/list`, un `tools/call` per ognuno degli 8 strumenti, `prompts/list`, `resources/list` e `resources/read`. Verifica 8 strumenti esatti, risposte senza errore e uscita 0 alla chiusura di stdin; scrive un rapporto JSON in `.runtime/mcp-handshake/` (`guiVerified: false`). `get_startup_context` richiede un dossier con `context.md` e `check_publication` un checkout Git: se mancano, lo strumento è dichiarato in `skippedTools`. Il test non dimostra che l'IDE mostri gli strumenti nell'interfaccia: serve ancora il riavvio dell'IDE e il controllo visivo.

---

## 7. Risoluzione dei Problemi Comuni (FAQ)

### I tool non compaiono nell'IDE dopo l'installazione
- Assicurati di aver riavviato completamente l'IDE (o eseguito il comando di reload della finestra, es. `Developer: Reload Window` in VS Code / Cursor).
- Verifica che `pwsh` (PowerShell 7) sia accessibile dal `PATH` di sistema eseguendo `pwsh --version` nel prompt comandi.

### Errore di parsing percorsi su Windows (backslash vs slash)
- Nei file **JSON** è preferibile utilizzare lo slash convenzionale (`/`, es. `C:/Progetti/SecondBrain/scripts/mcp-server.ps1`) oppure il doppio backslash (`\\\\`).
- Nei file **TOML** (Codex) il backslash va raddoppiato (`"C:\\Progetti\\SecondBrain\\scripts\\mcp-server.ps1"`).
- L'utilizzo dei comandi automatici (`-Pair -Apply` o `-ExportPackage`) applica automaticamente l'escape corretto per ciascun formato.

### Permessi di esecuzione script PowerShell
Se l'IDE restituisce un errore relativo all'ExecutionPolicy di PowerShell:
- Gli switch preimpostati includono `-NoProfile`.
- Verifica la policy utente con `Get-ExecutionPolicy -Scope CurrentUser`. Se necessario, abilita l'esecuzione degli script locali:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
  ```
