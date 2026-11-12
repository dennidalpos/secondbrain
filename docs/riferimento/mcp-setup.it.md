# Guida Operativa: Configurazione, Importazione e Pacchetto del Server MCP negli IDE

Questa guida illustra l'architettura e la procedura passo-passo per attivare, configurare ed esportare il server locale **Model Context Protocol (MCP)** di SecondBrain (`scripts/mcp-server.ps1`) per i principali ambienti di sviluppo e coding agent (**OpenAI Codex**, **Claude Desktop / Claude Code**, **Cursor**, **Visual Studio Code**, **Google Antigravity** e **Windsurf**).

---

## 1. Architettura, Protocollo e Garanzie

Il server MCP di SecondBrain usa JSON-RPC su stdio e negozia **2025-03-26**, mantenendo **2024-11-05** se richiesto dal client. Le prove coprono handshake, strumenti, prompt e risorse; non dimostrano conformita generale al protocollo o caricamento nelle GUI.

Una versione sconosciuta riceve `2025-03-26` come alternativa supportata; il client deve verificare di supportarla prima di proseguire. L'handshake attende la risposta a `initialize`, invia `notifications/initialized` e controlla che stdout contenga solo risposte JSON-RPC valide. Per provare un'altra versione usare `test-secondbrain-mcp-handshake.ps1 -ProtocolVersion <versione>`; il rapporto distingue versione richiesta e negoziata. Riferimento: [negoziazione MCP 2025-03-26](https://modelcontextprotocol.io/specification/2025-03-26/basic/lifecycle).

I dodici strumenti espongono un titolo localizzato in `annotations.title`, secondo lo [schema MCP 2025-03-26](https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-03-26/schema.ts). Tutti gli strumenti tranne `submit_dossier_write` dichiarano `readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true` e `openWorldHint=false`: le letture non recuperano mai scritture pendenti (lo fa solo `knowledge.ps1 -FlushPending`). `submit_dossier_write` dichiara `readOnlyHint=false` e `destructiveHint=true`. Il client interpreta le annotazioni indipendentemente dalle regole di approvazione configurate dal setup. I titoli seguono la lingua della sessione server, come le descrizioni. La misura dei popup e dei consensi negli IDE reali resta distinta dalle prove stdio.

### Garanzie di Isolamento e Sicurezza
- **Nessuna porta di rete aperta**: la comunicazione avviene esclusivamente tramite flussi standard di input/output (**stdio**) via `pwsh` su processo locale.
- **Zero telemetria esterna**: nessun dato, richiesta, prompt o metadato viene trasmesso a servizi terzi o remoti.
- **Consultazione con recupero delle scritture autorizzate**: all'avvio e nelle richieste il server tenta di integrare i [pendenti dei dossier](pending-writes.md), senza attendere il lock. I tool dichiarano `readOnlyHint=false`; le relative regole nominative includono questo effetto. Non si eseguono comandi arbitrari o nuove scritture richieste via MCP.

### Prerequisiti di Sistema
- **PowerShell 7.5+** (`pwsh`) installato su Windows.
- Percorso assoluto del clone SecondBrain (es. `C:\Progetti\SecondBrain` o `$env:SECONDBRAIN_HOME`).
- Il pairing (`-Pair`) non richiede la postazione attivata: legge solo il percorso del clone. Per usare il server con il contesto dei tuoi repository attiva prima la postazione (`secondbrain.ps1 -Setup`, vedi [setup](portable-brain.it.md#configurazione-e-prerequisiti)).
- Prima di `-Apply` leggi [cosa modifica SecondBrain e dove sono i backup](safety-backups.md).

---

## 2. Strumenti, Prompt e Risorse Esposti

### Strumenti Informativi (`tools/list` e `tools/call`)
| Tool MCP | Modalità | Parametri principali | Descrizione |
| :--- | :---: | :--- | :--- |
| `get_startup_context` | `read` | `repository`, `checkoutPath`, `dossier`, `readyOnly`, `profile`, `budget`, `taskIds` | Restituisce il pacchetto di avvio del repository in lavoro. Profilo `slim` (predefinito, 25.000 caratteri, solo primo caricamento): indice, sezioni essenziali di `context.md` e `memory.md`, task pronti in una riga ed elenco dei livelli non caricati. Profilo `full`: tutto, senza tetto. Senza `repository` né `dossier` il repository si risolve dal checkout (`checkoutPath` o directory corrente); non esiste più un default sul dossier di SecondBrain. |
| `get_ready_tasks` | `read` | `repository`, `checkoutPath`, `all`, `includeAcceptance`, `offset`, `limit` *(solo con `all=true`: 50 task per pagina, `nextOffset` per la successiva)* | Restituisce la proiezione dei soli task eseguibili (con dipendenze soddisfatte) del repository in lavoro: `repository` esplicito oppure quello del checkout (`checkoutPath` o directory corrente del server). La vista globale richiede `all=true`, ogni voce ha `scope: global`, ed è incompatibile con `repository`. Senza repository risolvibile risponde con errore. |
| `get_task` | `read` | `task` *(obbligatorio: ID o `#seq`)*, `repository`, `checkoutPath`, `dossier` | Restituisce il record integro di un task (descrizione, criteri di accettazione, evidenze, provenienza) dal tracker o da `history/tracker-archive.json`. Alias `secondbrain_get_task`. |
| `search_knowledge` | `read` | `query` *(obbligatorio)*, `budget`, `limit`, `offset`, `dossier`, `repository`, `allDossiers`, `includeOriginals`, `category` *(array: `memoria`, `informazioni`, `normative`, `policy`, `prompt`; senza `prompt` per impostazione predefinita)*, `previousRevision` *(revisione di una ricerca identica precedente: se nulla è cambiato la risposta è `unchanged=true` senza riscontri; solo con `offset` 0)*, `mode` *(`literal` predefinito, `relevance` per termini multipli ordinati per pertinenza)* | Ricerca deterministica nei file di conoscenza del dossier in lavoro (`context.md`, `memory.md`, `tracker.json`, archivio tracker, rapporti). Tetto predefinito: 20 riscontri e 10.000 caratteri; con `hasMore=true` si richiama con `offset=nextOffset`. `limit=0` e `budget=0` tolgono il tetto; `allDossiers=true` cerca in tutte le aree; `includeOriginals=true` include `history/compaction/`. |
| `get_runner_status` | `read` | `repository`, `checkoutPath`, `tail` *(righe di eventi, predefinito 20)* | Stato del runner del repository in lavoro letto da `status.json` e `events.jsonl` del run attivo o dell'ultimo: verdetto `working`, `stalled`, `finished`, `orphaned` o `none`, fase, task corrente, età dell'ultimo segnale dell'agente e ultimi eventi. Sola lettura: non avvia né ferma run (per fermare: `runner-status.ps1 -Stop`). |
| `list_prompts` | `read` | `category` *(opzionale: id o prefisso come `TST`)*, `compact` *(opzionale)*, `language` *(`en`\|`it`)* | Elenca la lista unica dei 120 prompt. Con `compact` una riga per prompt (codice, modalità, sommario). |
| `get_prompt` | `read` | `prompt` *(obbligatorio: ID `pmt-…` o codice come `TST04`)*, `objective` *(opzionale)*, `language` | Restituisce il prompt composto (compito, contesto, ruolo, procedura, vincoli, criteri di uscita, formato) in XML; `objective` ne imposta il compito. Senza contesto di repository. |
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

`-Target all` comprende sette target a livello utente, incluso `claude-code`. `-Scope user|project` rende esplicito l'ambito: senza opzioni vale `user`; `-WorkspacePath` senza `-Scope` conserva l'ambito `project`. L'ambito progetto richiede una cartella ed è disponibile per Claude Code, Cursor, VS Code e Antigravity. Da chat: `sb prompt SYS15`.

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
3. **Scrittura atomica con backup verificato**: se il file esiste, l'originale è copiato prima in `.runtime/backups/mcp-pairing/<guid>.bin` con metadati `<guid>.bin.json` (percorso, hash), la scrittura controlla che il file non sia cambiato nel frattempo e rilegge il risultato. Trova e ripristina il backup con `scripts/restore-managed.ps1 -List -Path <file>` (vedi [sicurezza e backup](safety-backups.md)).
4. **Codifica UTF-8 pulita**: scrive file senza BOM.

---

## 4. Metodo 2: Esportazione di un Pacchetto Distribuibile (`-ExportPackage`)

Esporta in una sottocartella nuova di `.runtime`. Per ripetere l'export, scegli una nuova destinazione. Il file `SHA256SUMS` contiene le impronte dei file generati.

```powershell
# Genera il pacchetto nella cartella predefinita (.runtime/mcp-package)
pwsh -NoProfile -File scripts/mcp-server.ps1 -ExportPackage

# Oppure specifica una directory di destinazione personalizzata
pwsh -NoProfile -File scripts/mcp-server.ps1 -ExportPackage -OutDir ".runtime/mcp-package-fixture"
```

Il README generato include il link per Cursor, il comando per VS Code, i comandi di pairing per Codex e Claude Code e i percorsi utente e progetto di Antigravity 2.x. I frammenti e i link usano il percorso del clone da cui sono stati esportati. Il bundle `claude/secondbrain.mcpb` chiede di selezionare il clone locale all'importazione e richiede PowerShell 7.5+ sul PATH.

L'installer applica il collegamento. Per applicare anche i consensi supportati, riesamina le anteprime e passa `-ApproveKnowledgeTools`. Il piano conserva la conferma per `check_publication`. Verifica caricamento e consensi in una nuova sessione del client.

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

Claude Code usa la CLI nativa: `-Pair -Target claude-code -Apply` registra il server in ambito utente; con `-WorkspacePath <progetto>` lo registra nel `.mcp.json` del progetto. Claude Desktop usa invece `claude_desktop_config.json`: non ripiega sul file di Claude Code.

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
- Google documenta `~/.gemini/config/mcp_config.json` per l’utente e `.agents/mcp_config.json` per il progetto. `-Pair` usa questi percorsi e conserva il ripiego sul file storico `~/.gemini/antigravity/mcp_config.json` quando è l’unico file utente esistente. L’anteprima mostra la destinazione selezionata. [Documentazione MCP dell’IDE Antigravity](https://antigravity.google/docs/mcp?tab=ide#antigravity-ide)

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
*Esito atteso*: una risposta JSON valida contenente la lista dei 12 tool con schemi e proprietà.

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
Per ciascun IDE avvia come processo il comando che `-Pair` registra e invia `initialize`, `tools/list`, un `tools/call` per ognuno dei 12 strumenti, `prompts/list`, `resources/list` e `resources/read`. Verifica 12 strumenti esatti, risposte senza errore e uscita 0 alla chiusura di stdin; scrive un rapporto JSON in `.runtime/mcp-handshake/` (`guiVerified: false`). `get_startup_context` richiede un dossier con `context.md` e `check_publication` un checkout Git: se mancano, lo strumento è dichiarato in `skippedTools`. Il test non dimostra che l'IDE mostri gli strumenti nell'interfaccia: serve ancora il riavvio dell'IDE e il controllo visivo.

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

## Installazione utente e consensi nominativi

La registrazione di Codex e Claude Code usa rispettivamente `codex mcp add` e `claude mcp add --transport stdio --scope user` (o `project`). Una CLI assente, un errore, un timeout o una registrazione diversa da quella attesa sono esiti espliciti: non vengono sostituiti da scritture dirette. Un server omonimo con comando o argomenti diversi produce `conflict`. Il comando nativo ha un timeout di 30 secondi; il suo output non viene riversato nel rapporto.

Prima di modificare un file esistente viene conservata una copia dei byte con hash e metadati in `.runtime/backups/mcp-pairing`. La CLI nativa mantiene le proprie modalità di scrittura: il backup e la verifica successiva non rendono atomica l'intera installazione. In caso di errore consultare gli esiti e il backup, senza cancellare i materiali di recupero.

L'anteprima mostra registrazione, ambito e regole opzionali. `-Apply` applica la registrazione; `-ApproveKnowledgeTools` (alias storico `-ApproveReadTools`) autorizza le regole nominative per i sette strumenti di conoscenza, che possono integrare solo richieste pendenti già autorizzate. `check_publication` resta soggetto a consenso.

```powershell
# Anteprima, senza scritture
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex -Scope user
# Applicare soltanto dopo aver esaminato l'anteprima
pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex -Apply -ApproveKnowledgeTools
# Setup: target MCP esplicito e approvazione dei tool separata
pwsh -NoProfile -File scripts/secondbrain.ps1 -Setup -Roots C:/Progetti -Select mio-progetto -McpTargets cursor -ApproveMcpReadTools -Yes
```

L'ultimo comando prepara l'anteprima del setup. Aggiungere `-Apply` per applicare la selezione. Senza `-McpTargets`, Setup ricava i client MCP dagli IDE selezionati. Preautorizza per nome gli otto strumenti attuali, incluso `check_publication`, in Codex, Claude Code e Cursor. `-ApproveMcpReadTools` mantiene il profilo di sola consultazione, che può recuperare scritture pendenti già autorizzate.

In VS Code, usare **Chat: Manage Tool Approval** nel profilo effettivo e selezionare gli strumenti SecondBrain. Per Claude Desktop, Windsurf e Antigravity IDE il report segnala il passaggio manuale o il supporto da verificare. La registrazione del server, la scrittura delle regole e la verifica dei popup nella nuova sessione sono esiti distinti. [Approvazioni VS Code](https://code.visualstudio.com/docs/agents/run/approvals)

| Target | Registrazione | Regole automatiche dei tool |
|---|---|---|
| Codex | CLI nativa, utente | `tools.<nome>.approval_mode = "approve"`; default e `check_publication` su `prompt` |
| Claude Code | CLI nativa, utente/progetto | `permissions.allow` nominative e `permissions.ask` per `check_publication` |
| Cursor | JSON utente/progetto | `permissions.json`, sette voci `mcpAllowlist` `secondbrain:<nome>`; richiede una modalità che rispetti la allowlist |
| Claude Desktop | JSON utente dedicato | Manuali |
| VS Code | `mcp.json`, chiave `servers` | Manuali; eligibility non equivale ad approvazione |
| Antigravity | JSON utente/progetto; legacy esistente riconosciuto | Non verificate per l'IDE; i percorsi e le regole della CLI non vengono trasferiti all'IDE |
| Windsurf | JSON utente | Non verificate: fonte ufficiale corrente non acquisita |

Le regole restrittive esistenti vengono conservate e possono continuare a richiedere consenso. Per Cursor, una allowlist che autorizza anche `check_publication` ferma l'operazione prima di scrivere: occorre una decisione esplicita sul conflitto. Nessun preset generale di approvazione viene attivato. JSON con commenti e TOML ambiguo vengono rifiutati intatti quando la modifica non può preservarli; i commenti e le sezioni TOML estranee rimangono conservati nei formati gestiti.

Formati verificati sulle fonti ufficiali: [Codex MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli), [Claude Code MCP](https://code.claude.com/docs/en/mcp), [Claude Code permissions](https://code.claude.com/docs/en/permissions), [Cursor permissions](https://prod.cursor.com/docs/reference/permissions), [VS Code approvals](https://code.visualstudio.com/docs/agents/run/approvals), [Antigravity MCP](https://antigravity.google/docs/mcp/) e [permissions](https://antigravity.google/docs/permissions/). Le fixture verificano i file generati e le invocazioni simulate; non certificano il caricamento o l'effetto sui popup in sessioni IDE reali.

Il report di setup è salvato per postazione in `setup-result.json` e appare in `-Setup -Status`. I profili Codex e Claude Code con percorso di istruzioni esplicito hanno la propria configurazione MCP. Profili o ambienti di cui non è determinabile il percorso effettivo restano segnalati come `profile-unverified` o `environment-unverified`.
