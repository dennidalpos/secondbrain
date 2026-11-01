# Istruzioni negli IDE

> Tool portabile: [procedura corrente](portable-brain.md). Nessun monitor; output operativi sotto .runtime e pulizia solo su richiesta.

## Verifica SYS01

```powershell
./scripts/ide-map.ps1 -Verify -ConfigPath .runtime/hosts/<id>/workstation.json
```

La mappa locale è `runtimeRoot/ide-map.json`; il testo approvato generato è `runtimeRoot/istruzioni-globali.md`. Il comando confronta i blocchi dei file mappati e riporta gli stati manuali registrati. Exit 0 prova l'allineamento dei file verificati, non il caricamento nelle chat o nelle impostazioni account.

La mappa è generata da `secondbrain.ps1 -Sync` e usa `schemaVersion: 2` (accettata anche la 1), `workstationId` e `ides[]`. Ogni voce ha `name` e `mode` (`file` o `manual`) e, se selezionata, `selected`; le voci file richiedono `instructions` assoluto, quelle manuali usano `accountAlias`, `profile`, `environment` e la ricevuta di osservazione. Conservare fonte e data dei riscontri manuali.

SYS01 verifica senza scrivere per impostazione predefinita. «Mappa» autorizza l'aggiornamento della mappa; «riallinea» autorizza la distribuzione del testo approvato, con backup SHA-256 e conservazione del testo personale. `ide-map.ps1` non rileva IDE e non scrive nei loro file. Non esiste uno switch di riallineamento in `ide-map.ps1`.

## Superfici distinte

| Superficie | Istruzioni / verifica |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md`; controllare `/context` o `/memory` nella sessione |
| Claude app | Impostazioni account, campo Instructions for Claude; verificare il testo salvato nell'interfaccia |
| Codex desktop / CLI | `CODEX_HOME/AGENTS.md` o `~/.codex/AGENTS.md`; controllare eventuali override e fonti caricate |
| Antigravity | `~/.gemini/GEMINI.md`; App 2.26.0+: Customizations > Installed > Skills & Rules; controllare fonte, contenuto e nuova sessione |
| Continue | Regole del progetto/pannello; icona penna per le regole caricate |
| Android Studio Gemini | `AGENTS.md` del progetto e regole IDE; Context > AGENTS.md Files |

Il file Claude Code e le istruzioni dell'account Claude sono separati. Nei repository SecondBrain mantiene il blocco in `AGENTS.md`; i precedenti collegamenti per IDE non vanno ricreati.

## Superfici manuali secondarie (Claude app, Continue, Android Studio)

Le interfacce secondarie prive di file di configurazione globale standard rilevabili in modo deterministico dal filesystem sono censite nella mappa `runtimeRoot/ide-map.json` con `mode: manual`.

### 1. Analisi delle superfici prive di file locali

- **Claude app (impostazioni account)**:
  - *Collocazione*: Impostazioni personali del profilo account Anthropic (*Settings > Personalization > Instructions for Claude*).
  - *Caratteristiche*: Le direttive sono memorizzate nel cloud del provider e applicate a tutte le sessioni web e desktop associate all'account. Non esiste alcun file locale sincronizzabile.
  - *Confini di sicurezza*: L'accesso automatizzato alle impostazioni web/browser è escluso per preservare le credenziali dell'utente e non violare le policy di autenticazione.
- **VS Code + Continue**:
  - *Collocazione*: Cartella globale `~/.continue/` (`config.json`, `config.yaml`, `prompts/`) ed estensione VS Code (`~/.vscode/extensions/continue.continue-*`).
  - *Caratteristiche*: Continue supporta molteplici provider di modelli e carica le istruzioni da regole di repository (`.continue/rules/`), dal pannello dell'estensione o inserite all'inizio della sessione. Non esiste un unico file globale Markdown standard di fallback valido per tutti i workspace.
- **Android Studio (Gemini)**:
  - *Collocazione*: Installazione IDE (`AppData\Roaming\Google\AndroidStudio*` e chiavi di registro), cassetto *Context > AGENTS.md Files* o configurazioni di progetto in `.idea/project.prompts.xml`.
  - *Caratteristiche*: A differenza di Google Antigravity (che legge `~/.gemini/GEMINI.md`), il plugin Gemini integrato in Android Studio non prevede un file utente globale di istruzioni Markdown, ma consuma il file `AGENTS.md` del progetto aperto o regole contestuali specifiche.

### 2. Procedura di verifica e qualificazione (SYS01)

L'esecuzione predefinita in sola lettura:

```powershell
pwsh -NoProfile -File scripts/ide-map.ps1 -Verify
```

segnala per ciascuna superficie manuale:
`manuale, account/profilo e caricamento non verificati o disallineati`

Questo stato indica che la superficie non dispone di un file locale autoverificante e richiede un'attestazione di osservazione della sessione recente:

1. **Allineamento manuale**:
   - *Claude app*: Copiare il testo approvato da `runtimeRoot/istruzioni-globali.md` e incollarlo nel campo *Instructions for Claude* nelle impostazioni account.
   - *Continue*: Verificare l'icona penna sopra la barra degli strumenti di Continue; inserire le direttive globali o referenziare `AGENTS.md` nel prompt di avvio o nelle regole di progetto.
   - *Android Studio*: Verificare nel cassetto *Context* la presenza del file `AGENTS.md` del repository o inserire le regole comuni nella chat iniziale.
2. **Attestazione con ricevuta di osservazione**:
   Per certificare l'allineamento nelle verifiche automatizzate senza esporre credenziali, l'utente o l'agente registra una ricevuta JSON di osservazione conforme alla funzione `Test-SBIDEObservation` contenente:
   - `ideId`: ID univoco dell'IDE registrato in `ide-map.json`.
   - `workstationId`: identificativo host della postazione.
   - `observedHash`: SHA-256 esatto del testo delle istruzioni globali osservato.
   - `loadingVerified`: boolean `true` comprovante l'effettiva applicazione.
   - `observedAt`: timestamp ISO 8601 recente (validità entro 15 minuti).
   - `evidencePath` e `evidenceSha256`: riferimento al report di verifica e relativo hash crittografico.
   Invocando `scripts/ide-map.ps1 -Verify -ObservationPath <path>` la verifica ha esito 0.

### 3. Rilevamento presenza nel modello host (`Get-SBIDEAssets`)

Il modulo host (`scripts/SecondBrain.Host.psm1`) rileva la presenza degli ambienti sulla macchina anche per le superfici manuali:
- **Continue**: scansione dell'esistenza della cartella `~/.continue` e delle estensioni VS Code con pattern `continue.continue*` in `~/.vscode/extensions/`.
- **Android Studio**: verifica degli eseguibili (`studio64.exe`, `studio.cmd`), delle voci di disinstallazione nel registro Windows e delle cartelle di configurazione Google in `%APPDATA%\Google\AndroidStudio*`.
- **Claude app**: verifica di eventuale client desktop in `%LOCALAPPDATA%\Programs\Claude\Claude.exe` o cartella dati `%APPDATA%\Claude`.
- **Cursor, Windsurf, JetBrains AI**: sola presenza delle cartelle di configurazione (`~/.cursor`, `%APPDATA%\Cursor`; `~/.windsurf`, `~/.codeium`, `%APPDATA%\Windsurf`; `%APPDATA%\JetBrains` con i nomi dei prodotti) come `installationEvidence`. Restano `mode: manual`: la presenza non prova né il login né il caricamento delle istruzioni.

### 4. Cambio di login, profilo o configurazione (`ide-context-changed`)

Ogni voce IDE registra un `environmentFingerprint` (SHA-256) calcolato da `Get-SBIDEContext` con: nome, percorso delle istruzioni, radice di configurazione e origine dell'override (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`: variabile utente, di processo o predefinita) e cartelle di configurazione presenti tra quelle note. Non legge archivi di autenticazione, token o sessioni.

`secondbrain.ps1 -Check` confronta il contesto corrente con quello registrato (nella configurazione o, per le attivazioni precedenti, nella base che `-Sync` salva in `state.json` alla prima esecuzione) e segnala `ide-context-changed`. Il rilievo abbassa `liveLoadingVerified` e non cambia `filesAligned`. `-Setup -Status` espone `contextStatus` (`unchanged`, `changed`, `unrecorded` o `unknown`), `sha256`, `installationEvidence` e il fingerprint senza scrivere.

Limite: un cambio di account nella stessa radice di configurazione non è rilevabile senza credenziali. Resta coperto da `accountAlias` e dalla ricevuta di osservazione (valida 15 minuti, vincolata a profilo, account, ambiente e hash).

Procedura per un nuovo accesso (nuovo account, profilo o radice):

1. Verifica lo stato: `scripts/secondbrain.ps1 -Setup -Status` (cerca `contextStatus: changed`).
2. Riattiva l'IDE con una nuova selezione: `-Discover` e `-Activate -SelectionPath` con `accountAlias`, `profile` ed `environment` nella voce IDE (`-Setup -Ides` registra l'IDE con il profilo predefinito e senza alias). L'id è derivato da profilo, alias e ambiente, quindi un nuovo accesso crea una nuova integrazione e registra il fingerprint corrente; riattivare con gli stessi valori sostituisce la voce e aggiorna il fingerprint.
3. Ritira l'accesso precedente: `scripts/secondbrain.ps1 -Setup -Unbind <id-precedente> -Yes -Apply`. I file dell'IDE non vengono modificati.
4. In una sessione nuova dell'IDE registra la ricevuta di osservazione e rilancia `scripts/ide-map.ps1 -Verify -ObservationPath <path>`: l'allineamento dei file non dimostra il caricamento.

## Integrazione Server MCP con OpenAI Codex

Per OpenAI Codex (CLI e Desktop), SecondBrain offre il server MCP stdio locale (`scripts/mcp-server.ps1`).

- **Configurazione TOML** in `~/.codex/config.toml` (o `%CODEX_HOME%\config.toml`):
  ```toml
  [mcp_servers.secondbrain]
  command = "pwsh"
  args = ["-NoProfile", "-File", "C:\\Progetti\\SecondBrain\\scripts\\mcp-server.ps1"]
  ```
- **Comando CLI equivalente**:
  ```bash
  codex mcp add secondbrain -- pwsh -NoProfile -File "C:\Progetti\SecondBrain\scripts\mcp-server.ps1"
  ```
- **Accoppiamento guidato**:
  ```powershell
  pwsh -NoProfile -File scripts/mcp-server.ps1 -Pair -Target codex
  ```

L'inventario della postazione (`scripts/SecondBrain.Host.psm1`) rileva automaticamente la presenza di `config.toml` e lo stato configurato del server MCP.

Fonti ufficiali: [Claude Code](https://code.claude.com/docs/en/memory), [account Claude](https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features), [Codex AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md), [Antigravity](https://www.antigravity.google/docs/rules/), [Continue](https://docs.continue.dev/customize/deep-dives/rules), [Android Studio](https://developer.android.com/studio/gemini/agent-files). Contratto del comando: [ide-map.ps1](../../scripts/ide-map.ps1).
