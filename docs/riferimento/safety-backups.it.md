# Cosa modifica SecondBrain e dove sono i backup

Leggi questa pagina prima di lanciare gli script. SecondBrain non installa software e non tocca il codice dei tuoi repository, ma alcuni comandi scrivono file fuori dal clone (direttive degli IDE, configurazione MCP, `AGENTS.md`). Ogni sostituzione di un file esistente conserva l'originale in un backup ripristinabile; le eccezioni sono elencate sotto.

## Regole di base

1. **Parti sempre da un comando che non scrive**: `pwsh -NoProfile -File scripts/prompts.ps1` (è ciò che mostra `sb prompt`) e `scripts/secondbrain.ps1 -Check` non modificano nulla. Prima dell'attivazione `-Check` termina con «Postazione non attivata» (codice 2); dopo, il codice 1 significa «ancora da allineare».
2. **Anteprima prima, applicazione dopo**: `-Setup` (senza `-Apply`), `mcp-server.ps1 -Pair` (senza `-Apply`), `rollback-repo.ps1` (senza `-Apply`), `cleanup.ps1`, `recover.ps1` e `publication.ps1 -InstallHook` mostrano solo cosa farebbero.
3. **`-Sync` scrive subito**, ma solo il blocco gestito SecondBrain, delimitato dai marcatori `<!-- secondbrain:repository:begin -->…end -->` e `<!-- secondbrain:global:begin -->…end -->`. Il testo che hai scritto fuori dal blocco non viene toccato. Esegui `-Check` prima per vedere le divergenze.
4. **File tuoi già esistenti non vengono adottati di nascosto**: un file IDE che esiste senza blocco SecondBrain non viene scritto (vedi «Conflitti»).

## Cosa tocca ogni comando

| Comando | Scrive fuori dal clone | Scrive nel clone (`.runtime`, dossier) | Anteprima |
|---|---|---|---|
| `prompts.ps1`, `secondbrain.ps1 -Check`, `ide-map.ps1`, `restore-managed.ps1 -List` | No | No | È già sola lettura |
| `secondbrain.ps1 -Discover` | No | Rapporto di discovery per host | È già sola lettura sui tuoi file |
| `secondbrain.ps1 -Setup` / `-Activate` senza `-Apply` | No | Proposta e selezione in `.runtime/hosts/<id>/` | Sì |
| `secondbrain.ps1 -Setup -Apply` | Variabile utente `SECONDBRAIN_HOME` (solo con `-RegisterEnvironment` o risposta `SI`; mai con `-NoRegisterEnvironment`) | `workstation.json`, dossier **nuovi**, `para-index.json`, `PARA.md` | Dopo `-Yes`: anteprima senza `-Apply` |
| `secondbrain.ps1 -Sync` | Blocco `repository` in `AGENTS.md` dei repository gestiti; blocco `global` in `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md` | Indici dei dossier, `state.json`, `inventory.json`, `ide-map.json`, `istruzioni-globali.md` | No: usa `-Check` |
| `secondbrain.ps1 -Setup -Unbind …` | No | Solo `workstation.json` | Sì, senza `-Apply` |
| `mcp-server.ps1 -Pair` | No | No | È l'anteprima |
| `mcp-server.ps1 -Pair -Apply` | File MCP degli IDE scelti (tabella sotto) | Backup in `.runtime/backups/mcp-pairing/` | Senza `-Apply` |
| `approve-revision.ps1` | No | `direttive/approved.json` e, con `-ProposalPath`, `direttive/*.md` | No |
| `rollback-repo.ps1 … -Apply` | `AGENTS.md` del repository dismesso (rimuove il blocco); copia del dossier in `<repo>/.secondbrain/` | Elimina il dossier, aggiorna `workstation.json` | Senza `-Apply` |
| `publication.ps1 -InstallHook -Apply` / `-UninstallHook -Apply` | `.git/hooks/pre-push` (o `core.hooksPath`); la rimozione rifiuta hook non creati da SecondBrain | No | Senza `-Apply` |
| `cleanup.ps1`, `recover.ps1` | No | Solo dentro `.runtime` | Senza `-Apply` |
| `backup.ps1` | Solo con `-OutputPath` | Zip in `backupRoot`; esclusi i dati rigenerabili (#396): cartelle `fixture`, `tmp`/`temp` e `fixture-*`, `tmp-*`, `tests-*` sotto `.runtime/hosts/<host>/repos/`, `sources/python`, ogni `cache` e le `work` con MANIFEST.json `closed`; evidenze, rapporti, work aperti, configurazione e dossier restano | No |
| `work.ps1 -Run` | Esegue il programma che indichi | Cartelle sotto `.runtime` (con `-Category` e `-Slug`: `hosts/<id>/repos/<repo>/<categoria>/<data>-<slug>`; TEMP e cache restano nel sistema operativo) | Senza `-Run` stampa il piano |

File MCP scritti da `-Pair -Apply` (solo per i target scelti; con `-Target all` sono tutti):

| Target | File |
|---|---|
| `codex` | `~/.codex/config.toml` |
| `claude` | `claude_desktop_config.json` in `%APPDATA%\Claude` (o `$CLAUDE_CONFIG_DIR`); se la cartella non esiste, `~/.claude.json` |
| `cursor` | `~/.cursor/mcp.json` |
| `vscode` | `%APPDATA%\Code\User\mcp.json` (con `-WorkspacePath`: `.vscode/mcp.json` del progetto) |
| `claude-code` | `.mcp.json` nella cartella di `-WorkspacePath` (obbligatorio; non incluso in `-Target all`) |
| `antigravity` | A livello utente `~/.gemini/config/mcp_config.json` (ripiego su `~/.gemini/antigravity/mcp_config.json` se è il solo file utente esistente). A livello di progetto `.agents/mcp_config.json` |
| `windsurf` | `~/.codeium/windsurf/mcp_config.json` |

Il file e la cartella vengono creati anche se l'IDE non è installato. Le altre voci del file restano; se il file non è JSON rigoroso (errori o commenti, come in un `mcp.json` di VS Code con JSONC) o la radice non è un oggetto, **l'operazione si ferma e non scrive**. Il JSON viene riscritto con la formattazione standard: commenti e ordine delle chiavi non si conservano, per questo il backup è importante. Nel TOML di Codex viene sostituita l'intera sezione `[mcp_servers.secondbrain]`.

Non vengono mai scritti: il codice dei repository (solo `AGENTS.md`), gli IDE «manuali» (VS Code + Continue, Android Studio, impostazioni account web), credenziali e archivi di autenticazione.

## Dove sono i backup

Le scritture protette conservano una copia dei file esistenti che richiedono un originale per il recupero, come dossier, configurazioni MCP e istruzioni IDE personali.

| Percorso | Contenuto |
|---|---|
| `.runtime/hosts/<id>/backups/<guid>.bin` | Copia esatta del file com'era prima |
| `.runtime/hosts/<id>/backups/<guid>.bin.json` | Metadati: `path` originale, `previousHash`, `deployedHash`, `backup` |
| `.runtime/hosts/<id>/backups/<guid>.stage` | Destinazione, utente Windows, ora UTC, SHA-256 precedente e previsto, staging e stato della scrittura |
| `.runtime/hosts/<id>/backups/<guid>.git.json` | Originale tracciato e verificato byte per byte rispetto al checkout Git, con percorso, hash, commit e blob |
| `.runtime/backups/mcp-pairing/` | Come sopra, per i file MCP |
| `.runtime/hosts/<id>/backups/para-<guid>/manifest.json` | Transazioni sui dossier |
| `.runtime/hosts/<id>/backups/rollback-<guid>/` | Dossier salvato da `rollback-repo.ps1 -Force` senza checkout |

`<id>` è l'identificativo della postazione (`ws-` più 16 cifre esadecimali). `.runtime/` è escluso da Git: i backup restano solo sul tuo PC e non vengono mai pubblicati. Non c'è cancellazione automatica; la pulizia è esplicita (`cleanup.ps1`, vedi [recovery](recovery.md)). Se un file non esisteva, la scrittura lo crea e non c'è nulla da salvare.

Gli indici PARA e del runtime, le viste del dossier, le istruzioni globali generate e i file IDE composti interamente dal puntatore gestito usano il journal senza copia binaria separata. Se il file del puntatore contiene testo personale, segue la normale politica di backup. Le scritture delle transazioni PARA e di importazione tracker riusano le rispettive copie di ripristino verificate. Una sostituzione interrotta può lasciare accanto alla destinazione un file `.recovery`.

Per un file tracciato e pulito, SecondBrain verifica che `git cat-file --filters <gitCommit>:<percorso>` riproduca l'hash precedente. Se coincide, registra commit e blob. Se la verifica fallisce, applica la politica di backup ordinaria. Le scritture ordinarie si fermano sui file tracciati con modifiche non committate. Le operazioni che ammettono esplicitamente un file sporco mantengono il backup delle modifiche locali. `cleanup.ps1 -ProposeRuntime` può elencare i backup precedenti candidati alla revisione.

`backup.ps1` crea invece uno zip deterministico dei dati locali con manifest SHA-256 (`-Verify` lo controlla). Con il nome predefinito `secondbrain-backup-<data>-<ora>.zip` un archivio esistente non viene mai sovrascritto: due backup nello stesso secondo ricevono il suffisso `-2`, `-3`, … (con `-OutputPath` esplicito il file indicato viene rimpiazzato). Non copre i file degli IDE, la configurazione MCP né `AGENTS.md` dei repository, e non esiste un comando di ripristino dello zip. Esempi: `backup.ps1` (archivio di `01-projects`, `02-areas`, `03-resources`, `04-archives`, `PARA.md`, `para-index.json` e `.runtime/hosts`), `backup.ps1 -OutputPath D:/Backups/SecondBrain/backup.zip` per un percorso scelto, `backup.ps1 -Verify` (ultimo archivio in `.runtime/backups/`) e `backup.ps1 -Verify -BackupPath <zip>` per uno specifico.

## Ripristinare un file

I backup hanno nomi casuali: trova quello giusto per percorso originale.

```powershell
# Elenco dei backup di un file, dal più recente (sola lettura)
pwsh -NoProfile -File scripts/restore-managed.ps1 -List -Path "$HOME/.claude/CLAUDE.md"

# Ripristino dal file di metadati scelto
pwsh -NoProfile -File scripts/restore-managed.ps1 -MetadataPath .runtime/hosts/<id>/backups/<guid>.bin.json
```

Il ripristino rifiuta di procedere se il backup è stato alterato o se il file attuale non è più quello distribuito da SecondBrain (lo hai modificato dopo): in quel caso confronta a mano il file con `<guid>.bin`. Dopo un ripristino esegui `secondbrain.ps1 -Check`; se segnala `conflict`, il blocco ripristinato non coincide con quello registrato in `state.json` ed è la protezione che evita di sovrascriverti.

Transazioni interrotte sui dossier: `recover.ps1 -ManifestPath <manifest>` (anteprima) e poi `-Apply`. Dettagli in [recovery](recovery.md).

## Conflitti

`-Check` e `-Sync` segnalano senza scrivere:

| Segnalazione | Significato | Cosa fare |
|---|---|---|
| `ide-adoption-required` | Esiste un file IDE tuo senza blocco SecondBrain | Se vuoi le direttive in quel file, incolla il testo da `.runtime/hosts/<id>/istruzioni-globali.md` tra i marcatori `<!-- secondbrain:global:begin -->` e `<!-- secondbrain:global:end -->`, poi `-Sync` |
| `ide-conflict` | Il file IDE è cambiato rispetto a quello visto dalla discovery | Rivedi il file, poi rilancia la discovery |
| `conflict` (blocco) | Il blocco gestito è stato modificato a mano o non è registrato | Confronta con il backup; per riscriverlo rimuovi il blocco e rilancia `-Sync` |

## Disinstallare

SecondBrain non ha un disinstallatore automatico. Per rimuovere ciò che ha scritto:

1. **Postazione**: `secondbrain.ps1 -Setup -Unbind <identità|percorso|id IDE|nome IDE> -Yes -Apply`. Disassocia repository e IDE ma non cancella dossier né file degli IDE.
2. **Blocchi nei file**: elimina a mano il testo tra i marcatori `secondbrain:global` in `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, e `secondbrain:repository` in `AGENTS.md` di ogni repository. Per un repository che vuoi dismettere con restituzione dei dati: `rollback-repo.ps1 -RepositoryIdentity <identità> -Apply` (prima senza `-Apply`).
3. **MCP**: rimuovi la voce `secondbrain` dai file della tabella sopra (o ripristina il backup).
4. **Variabile utente**: `[Environment]::SetEnvironmentVariable('SECONDBRAIN_HOME', $null, 'User')`.
5. **Hook Git**: `publication.ps1 -RepositoryPath <repo> -UninstallHook -Apply`.
6. **Clone**: cancellalo per ultimo; contiene `.runtime` con tutti i backup, quindi copia prima ciò che vuoi conservare.

Altre guide: [manutenzione di .runtime](runtime-maintenance.md), [setup iniziale](portable-brain.it.md#configurazione-e-prerequisiti), [server MCP](mcp-setup.md), [alberatura e cartelle cancellabili](tree.md).
