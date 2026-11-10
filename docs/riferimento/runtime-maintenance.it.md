# Manutenzione di `.runtime` e contesto iniziale

`.runtime/` contiene tutto ciò che SecondBrain produce sul tuo PC: configurazione della postazione, backup, fixture dei test, rapporti. È escluso da Git e cresce nel tempo: nel clone del maintainer ha superato 11 GB (novembre 2026), per lo più cartelle di lavoro degli agent e fixture dei test. Nulla viene cancellato in automatico; la pulizia è sempre una tua richiesta esplicita. Prima di toccare qualcosa leggi anche [sicurezza e backup](safety-backups.md) e la [mappa completa](tree.md).

## Cosa contiene, per categoria

`SECONDBRAIN_STATE_ROOT` consente di usare un percorso assoluto su disco fisso locale, fuori dal clone. La sottocartella è distinta per clone e postazione e contiene configurazione, discovery, selezione, esito di Setup, mappa IDE, istruzioni globali generate e il percorso predefinito `sources/python`. Sessioni e lock restano in `.runtime/access` sulla radice SecondBrain.

`cleanup.ps1 -Migrate -LocalState` confronta in anteprima i file di stato e gli hash a destinazione. Le cartelle `hosts/<id>/repos` restano nella posizione corrente e Python si ricrea dal lock. `cleanup.ps1 -ListInstallBackups` presenta alla revisione le copie verificate dei file IDE personali non versionati dopo sette giorni, con soglia impostabile tramite `-InstallBackupDays`.

`cleanup.ps1 -ListRuntime` classifica ogni voce di primo livello:

| Categoria | Cartelle tipiche | Si può cancellare? | Come si recupera |
|---|---|---|---|
| `protected` | `hosts/<id>/` (configurazione, `state.json`, `inventory.json`), `access/` (sessioni e lock), `backups/` della postazione corrente | **No** | Non si rigenera: è la configurazione e la prova di cosa è gestito |
| `regenerable` | Contenuti ricreabili descritti dall'inventario; il selettore ammette solo fixture/tmp annidate, proprie, chiuse e scadute | Solo con richiesta esplicita, verifiche e perimetro concreto | Suite o comando identificato dal task nel manifest; la classificazione non autorizza la rimozione |
| `evidence` | `cleanup/` (registro delle pulizie), `trace/` (turni di fine prompt, solo metadati), `captures/` (originali degli screenshot), `publication/` (policy e baseline SEC07), `directives-activation/` | Con cautela | Non si rigenerano identiche: servono come prova o provenienza |
| `backup` | `backups/` (con `mcp-pairing/`, `trace/`) e `workstations/<id di origine>/` (host precedenti), `install-backups/` | Con cautela, solo con manifest | Sono i recuperi dei file che SecondBrain ha sostituito; un solo nome, `backups` |
| `working` | `hosts/<id>/repos/<repo>/{work,evidence,report,fixture,tmp,temp}/<yyyyMMdd>-<slug>/` (layout annidato), `operations/`, `q201/`, `t<numero>/`, `lotto-*`, `classify-*`, `compaction*/`, file sciolti e ogni cartella creata da un agent senza prefisso | Dopo verifica | Lavoro temporaneo: controlla riferimenti e proprietà; nessun codice le legge |

Dentro `hosts/<id>/`: `workstation.json`, `state.json`, `inventory.json`, `ide-map.json`, `istruzioni-globali.md` non si cancellano; `backups/` contiene gli originali (`<guid>.bin` e `.bin.json`) e i record `.stage`; `sources/` contiene l'ambiente Python (rigenerabile) e i rapporti.

Cause tipiche di crescita: tutte le esecuzioni conservano fixture e prove (`tests/` o la radice runtime scelta, anche decine di migliaia di file), ogni scrittura gestita aggiunge un backup, gli zip di `backup.ps1` pesano centinaia di MB. La pulizia richiede sempre una richiesta esplicita con perimetro e verifiche dei riferimenti.

## Vedere `.runtime` a colpo d'occhio

`cleanup.ps1 -RuntimeReport` stampa un indice Markdown in sola lettura: una riga per voce, ordinata per categoria (`protected`, `evidence`, `backup`, `working`, `regenerable`) e poi per dimensione, con ultima scrittura, riferimenti, chi la scrive e come si recupera; per le voci oltre 50 MB aggiunge le sottocartelle più grandi. Con `-ReportPath .runtime/INDEX.md` lo rigenera come vista derivata (scrittura atomica, ignorata da Git, nessun dato proprio); un altro `.md` sotto `.runtime` si crea solo se non esiste. Non rimuove né sposta nulla.

```powershell
pwsh -NoProfile -File scripts/cleanup.ps1 -RuntimeReport
pwsh -NoProfile -File scripts/cleanup.ps1 -RuntimeReport -ReportPath .runtime/INDEX.md
```

**Layout delle cartelle di lavoro di SecondBrain**: `hosts/<id>/repos/<repo>/<categoria>/<yyyyMMdd>-<slug>` con categoria `work` (lavoro temporaneo), `evidence` (prove), `report` (rapporti), `fixture` o `tmp`. `<repo>` è l'ultimo segmento dell'identità del repository più 8 caratteri dell'hash (leggibile e senza collisioni tra proprietari); `<slug>` usa minuscole, cifre e trattini (al più 60 caratteri). TEMP e TMP del lavoro stanno nell'area `hosts/<id>/repos/<repo>/temp`. Il percorso si ottiene con `work.ps1 -Repository <identità> -Category work -Slug <slug>` (senza `-Init` e `-Run` stampa il piano e non crea cartelle) o con `Get-SBRuntimeWorkPath`; con `-Init -Task <testo> -SessionId <id>` crea la cartella e il suo `MANIFEST.json`, con `-Close` la marca chiusa. Senza `-Category` e `-Slug` `work.ps1` mantiene l'ambiente di build `hosts/<id>/repositories/<hash>/<Project>/<Runtime>`.

### Manifest, sessioni e retention

Ogni cartella nuova ha un `MANIFEST.json`: schema, categoria, nome, data, host, repository, proprietario (utente, computer, client), `sessionId` dell'accesso, task, stato (`open`/`closed`) e scadenza. Lega la cartella alla sessione `access.ps1` che la usa, così si sa chi la possiede e quando può essere valutata. Scadenze predefinite: `fixture` e `tmp` 7 giorni (e comunque solo oltre le ultime 5 per repository), `work` 30 giorni dalla chiusura; `evidence` e `report` non scadono mai da sole. Una cartella appartiene a una postazione, un utente e una sessione: sulla radice condivisa di squadra si condividono solo dossier e `access/`, e ogni postazione pulisce solo il proprio `hosts/<id>/`.

`cleanup.ps1 -RuntimeReport` aggiunge all'indice due sezioni in sola lettura: **Livelli annidati** (le cartelle sotto `hosts/<id>/repos`, con categoria e conformità del nome) e **Cartelle legacy**, cioè le cartelle di primo livello fuori dalle voci gestite (`work-<data>-<slug>`, `t77`, `lotto-*`, …) e `hosts/<id>/repositories/…`, ciascuna con la destinazione proposta nel nuovo layout. ``cleanup.ps1 -Migrate` ne prepara lo spostamento: in anteprima elenca ogni mossa (origine, destinazione, byte), con `-Apply -Authorization "<richiesta>"` sposta solo con rinomina nello stesso volume, scrive il `MANIFEST.json` per work/evidence/report e un registro in `.runtime/cleanup/migrate-*.json`; salta cartelle recenti, reparse point e destinazioni già esistenti. La proposta di pulizia (`-ProposeRuntime`) elenca le stesse legacy e valuta le cartelle annidate di lavoro oltre soglia; le prove (`evidence`, `report`) non sono mai candidate.

## Routine di manutenzione (una volta al mese)

```powershell
# 1. Rapporto per categoria, in sola lettura (dimensione, età, riferimenti, come si recupera)
pwsh -NoProfile -File scripts/cleanup.ps1 -ListRuntime

# 2. Proposta di pulizia, in sola lettura: nessuna cartella viene rimossa
pwsh -NoProfile -File scripts/cleanup.ps1 -ProposeRuntime -KeepFixtures 5
pwsh -NoProfile -File scripts/cleanup.ps1 -ProposeRuntime -ProposalPath .runtime/cleanup/proposals/2026-11.json   # salva la proposta in un nuovo file

# 3. Backup .stage oltre 90 giorni (elenco), da rimuovere solo con un manifest revisionato
pwsh -NoProfile -File scripts/cleanup.ps1 -ListStageRecords -OlderThanDays 90
```

La proposta indica cartelle candidate (fixture di test oltre le ultime `-KeepFixtures`, rapporti handshake oltre soglia, ambiente Python delle fonti, zip di backup oltre i due più recenti, backup `.bin` duplicati di Git (file ora tracciato e pulito, copia con SHA-256 pari a `previousHash` e contenuto presente come blob: senza blob il `.bin` è l'unica copia e non è candidato), lavoro di agent senza riferimenti), con dimensione, età, riferimenti e come si ricreano. **Non è un manifest eseguibile.** Rimuovere le cartelle è un passo separato:

1. Chiudi le sessioni di scrittura (`access.ps1 -Status`) e verifica che non esista `.runtime/para-transaction.json`.
2. **Cartelle rigenerabili ammesse**: solo `hosts/<host-corrente>/repos/<repo>/fixture|tmp/<yyyyMMdd>-<slug>`, oltre le ultime `-KeepFixtures` per repository e categoria, con `MANIFEST.json` schema 1 leggibile e coerente con percorso, host, repository, categoria, nome e proprietario Windows corrente (utente e computer). Lo stato deve essere `closed` e la scadenza valida `yyyy-MM-dd` deve precedere la data locale corrente: il giorno di scadenza si conserva. Usa `cleanup.ps1 -Regenerable`.
   ```powershell
   # Anteprima (nessuna rimozione): target, saltati con il motivo, file e byte
   pwsh -NoProfile -File scripts/cleanup.ps1 -Regenerable -KeepFixtures 5
   # Applicazione, solo dopo una tua richiesta esplicita (da citare in -Authorization)
   pwsh -NoProfile -File scripts/cleanup.ps1 -Regenerable -KeepFixtures 5 -Apply -Authorization "richiesta utente del <data>: pulizia rigenerabili"
   ```
   Le ultime N cartelle sono ordinate per ultima scrittura della directory decrescente, poi percorso crescente a parità di data; si conservano anche quando hanno manifest invalidi. Cartelle legacy, `tests/`, fixture/tmp piatte, Python, handshake e cartelle vuote di primo livello sono escluse. Nessun manifest viene aggiunto retroattivamente: `run.json` non lo sostituisce. Manifest assenti, invalidi, aperti, migrati, non scaduti o di altri proprietari producono motivi di esclusione stabili con messaggi it/en; identità corrente non verificabile significa nessun target.

   Si salta ciò che è stato scritto negli ultimi `-MinAgeMinutes` (predefinito 10), che contiene percorsi della configurazione/accessi o reparse point anche interni; si rifiuta con transazione pendente o sessioni di accesso attive. Prima di ogni rimozione si ricontrollano idoneità e impronta di manifest, hash dei file e metadati delle directory. Target cambiati o non più idonei si conservano, si registrano tra gli esclusi ed escono con esito `partial` (codice 1). Un'ispezione incompleta non autorizza rimozioni. I lock cooperativi e la verifica non garantiscono atomicità contro scrittori esterni durante la cancellazione: chiudi i processi produttori prima di applicare. Non c'è backup; prima dell'autorizzazione verifica riferimenti, hash e recuperabilità tramite il comando del task nel manifest. Resta un registro `.runtime/cleanup/regenerable-<data>.json` con autorizzazione, esiti e recupero. I test di rimozione usano solo cartelle sintetiche isolate.
3. Per file con backup e hash (`.stage`, backup, rapporti) usa `cleanup.ps1 -ManifestPath` con un manifest revisionato e `-Authorization`.
4. Per altre cartelle (rapporti handshake, lavoro di agent, zip) controlla i collegamenti (`Get-ChildItem <cartella> -Recurse -Force -Attributes ReparsePoint`; una junction si toglie con `cmd /c rmdir <link>`); per percorsi oltre 260 caratteri svuota con `robocopy <cartella-vuota> <cartella> /MIR`.
5. Dopo la pulizia esegui `secondbrain.ps1 -Check`: deve restare lo stato noto della postazione.

## Suite di test: livelli e fixture

`scripts/test-secondbrain.ps1` usa tre profili minimi. Scegli un solo selettore tra `-Quick`, `-Full` e `-Only`. Senza selettore parte Fast. Il runner rifiuta una selezione vuota. I budget della postazione di riferimento includono preparazione, verifiche, ripristino dell'ambiente e scritture del rapporto e del riepilogo. Il runner fallisce se il tempo supera il budget. Il collaudo dei budget misura anche il comando completo dall'esterno, compreso l'avvio di PowerShell.

| Comando | Copertura | Budget |
|---|---|---:|
| `-Quick` | Parser, identità, JSON/schema, versione/badge, direttive, catalogo e messaggi; nessun Git o processo figlio | 15 s |
| *(predefinito, Fast)* | Quick e flussi essenziali: attivazione/idempotenza, aggiornamento task, coda differita, Slim/compattazione e handshake MCP stdio | 90 s |
| `-Full` | Fast e confini critici: hash/backup/recovery, isolamento, percorsi/junction, accesso negato, concorrenza, fonti, pubblicabilità sintetica, runtime, prompt e audit dei tracker; le suite extra girano in parallelo come processi separati | 300 s |
| `-Only <chiave>` | Gruppi pertinenti: `portable`, `workflows`, `trackers`, `audit2`, `trace`, `concurrency`, `pending`, `sources`, `external-audit`, `quick`, `git-environment`, `runtime`, `prompts`, `tracker-audit` (~150-180 s, incluso in `-Full` in parallelo) | Misurato, senza budget di profilo |

Misure del lotto sulla postazione Windows di riferimento, con PowerShell 7.6.9 e Git 2.56.0.windows.4: Quick 9,00 s, Fast 49,17 s e Full 66,13 s. I rapporti locali registrano durata e impronte per ogni esecuzione.

La suite essenziale condivide una sola fixture e verifica la logica tramite API; i processi figli coprono soltanto CLI e stdio. I cinque ingressi storici portable/workflows/trackers/audit2/git-environment invocano gli stessi gruppi consolidati, senza mantenere copie degli scenari. In `-Full` le suite extra (trace, concurrency, sources, external-audit, runtime, prompts, tracker-audit) partono insieme come processi separati mentre l'essenziale è in corso; ognuna scrive il proprio `suite-<chiave>.log` e la durata per gruppo resta in `results` di `run.json`. `-Sequential` le esegue una alla volta; `SECONDBRAIN_TEST_TIMING` resta accettato. Non ci sono suite ricorsive nella verifica ordinaria.

Rimossi dal percorso mantenuto: combinazioni equivalenti dei provider Git/IDE, asserzioni letterali su guide e prompt, ripetizioni CLI/MCP della stessa logica, copie di controlli puri e attivazioni ripetute per ogni variante. Restano casi positivi e negativi dei confini di protezione dati. Le prove sintetiche non qualificano account, GUI reali, SMB tra PC fisici o percorsi di qualsiasi profondità; i task relativi restano aperti. I benchmark estesi sono comandi separati e non fanno parte della suite ordinaria.

Ogni esecuzione lavora in `.runtime/hosts/<id>/repos/tests-<hash>/fixture/<yyyyMMdd>-minimal/run-<id>` (con `MANIFEST.json`: `open` durante i run, `closed` quando termina l'ultimo run attivo del contenitore, anche dopo un errore, scadenza a 7 giorni; i contenitori storici `fixture-<data>-minimal` e le radici personalizzate restano senza manifest) oppure sotto `SECONDBRAIN_TEST_ROOT`, che deve appartenere al runtime centrale. Le sub-suite ordinarie condividono la directory del run. Un runner annidato usa invece una directory sorella: il contesto interno `SECONDBRAIN_TEST_RUN_CONTEXT` identifica il rapporto del padre, viene verificato contro la radice richiesta e ripristinato in `finally`. Non modificarlo per spostare le fixture. Il rapporto del figlio cita il padre e quello del padre elenca i figli. I payload intenzionalmente oltre MAX_PATH restano lunghi.

Fixture e log restano conservati dopo successo ed errore, anche per la suite di concorrenza. `-KeepFixtures` e `SECONDBRAIN_TEST_KEEP=1` restano accettati per compatibilità; non sono più necessari nel runner, che trasmette la conservazione ai figli e ripristina il valore precedente. Nessun artefatto esistente viene spostato o cancellato. Per le sub-suite lanciate direttamente impostare `SECONDBRAIN_TEST_KEEP=1`: alcune mantengono la pulizia locale preesistente. Per la tracciabilità completa avviarle attraverso `test-secondbrain.ps1 -Only <chiave>`.

Ogni directory `run-<id>` contiene un rapporto permanente `run.json`, `runner.log` e i log delle sub-suite. Il rapporto registra comando e parametri, esito, verifiche, durata, radice fixture, parentela, ambiente selezionato e hash degli input prima/dopo. `esito.json` accanto ai run conserva i campi precedenti e collega l'ultimo rapporto: è una vista aggiornata, non lo storico. Le esecuzioni concorrenti hanno rapporti distinti; un lock breve serializza soltanto l'aggiornamento della vista. `esito-concurrency.json` resta nel run (o nella fixture autonoma di concorrenza) e contiene durata, verifiche, file e byte per caso.

La copertura degli hash è conservativa: tutti i file nell'indice Git e i nuovi file non ignorati, nei byte del working tree. Non è una traccia dei file effettivamente consumati e non comprende dossier/runtime ignorati o input esterni. Se gli snapshot differiscono, il rapporto diventa `invalidated`, `eligibleForClosure=false` e il runner fallisce. Errori di preparazione producono una prova fallita quando la directory del run è già disponibile. Cambiamenti transitori ripristinati tra gli snapshot non sono rilevati. L'ambiente registra versioni di PowerShell/Git/OS, architettura, cultura e una lista esplicita di variabili pertinenti; le coppie `GIT_CONFIG*` sono rappresentate da hash, senza copiarne valori potenzialmente riservati. I file globali Git diretti sono identificati per hash; include, tool e stato esterno non sono rilevati esaustivamente.

Una prova verde con input stabili è utilizzabile per la chiusura solo entro questi limiti e dopo il confronto dell'ambiente e dei dati pertinenti; nessun riuso automatico o cache dei risultati. Per un lotto senza commit/push eseguire Quick finale e suite pertinenti. Ripetere verifiche già verdi per nuove modifiche ai loro input, errori o dubbi nuovi, motivando la ripetizione. Fast prima del commit e Full prima della pubblicazione restano obbligatori. Distinguere verifiche funzionali, allineamento Sync/Check e audit privacy.

I tempi per gruppo sono nel rapporto run.json; il runner minimo è già sequenziale. I `git init` usano il template minimo di test-helpers.ps1 (solo info/exclude), senza hook di esempio.

### Git e percorsi lunghi nelle fixture Windows

Il runner imposta `core.longpaths=true` solo nell'ambiente del processo e dei figli. Aggiunge una coppia a `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n` / `GIT_CONFIG_VALUE_n` e usa un file temporaneo tramite `GIT_CONFIG_GLOBAL`: include i file globali ereditati nell'ordine di lettura Git e aggiunge `core.longpaths=true`. Questo serve al livello Windows che può leggere la configurazione da file prima degli override di comando. Le configurazioni persistenti restano intatte. Le coppie ereditate sono preservate e ogni variabile modificata (anche quelle prima assenti, `GIT_CONFIG_GLOBAL` e `GIT_TEMPLATE_DIR`) viene ripristinata in `finally`, inclusi errori di preparazione.

I wrapper restano in `.runtime/hosts/<host>/repos/tests-<hash-checkout>/tmp/tmp-<data>-git-env-<id>/global.config`; la radice delle fixture resta quella richiesta. Lo helper richiede Git 2.42+ e `git var GIT_CONFIG_GLOBAL` e percorsi globali assoluti su una sola riga, senza fallback per versioni non supportate; il wrapper deve essere leggibile sotto MAX_PATH. Comportamento verificato con Git `2.56.0.windows.4`. Riferimenti: [variabili Git](https://git-scm.com/docs/git-config), [percorsi restituiti da git var](https://git-scm.com/docs/git-var), [ordine dei file nel sorgente della versione verificata](https://github.com/git-for-windows/git/blob/v2.56.0.windows.4/builtin/var.c). Ogni sub-suite che usa `test-helpers.ps1` verifica sia il valore effettivo sia quello globale da file prima di creare la fixture; una configurazione incompleta o un override di solo comando con valore globale disabilitato vengono rifiutati. Il gruppo `git-environment`, incluso in Full, verifica ereditarietà e ripristino; i controlli puri `quick` restano senza Git né processi figli.

Per una sub-suite avviata direttamente, usare lo stesso ambiente temporaneo:

```powershell
. ./scripts/test-git-environment.ps1
$fixtureGitEnvironment = Enter-SBTestGitEnvironment
try {
    $env:SECONDBRAIN_TEST_KEEP = '1'
    pwsh -NoProfile -File scripts/test-secondbrain-portable.ps1
} finally {
    Exit-SBTestGitEnvironment $fixtureGitEnvironment
}
```

Impostare `SECONDBRAIN_TEST_ROOT` su una directory del runtime centrale per verificare il percorso annidato effettivo; non sostituirlo con una radice corta per aggirare un errore. Tutte le fixture restano conservate. `core.longpaths` riguarda Git for Windows: non qualifica un host con `LongPathsEnabled=0` né una share SMB fisica.

Limiti osservati con Git `2.56.0.windows.4`: inizializzazione e discovery dei metadati possono fallire quando il percorso del nuovo `.git/config` raggiunge 260 caratteri, anche con `core.longpaths=true` verificato nell'ambiente e con `-c core.longpaths=true`; i processi dei worktree rifiutano inoltre `GIT_DIR` oltre `PATH_MAX-40` ([sorgente Git della versione verificata](https://github.com/git-for-windows/git/blob/v2.56.0.windows.4/setup.c)). Il caso audit `references_updated` usa il nome sintetico `source-refs-updated` e le fixture workflow `wf-<id>`, mantenendo la radice runtime annidata e gli scenari originali. La regressione dell'ambiente verifica separatamente che la fixture riconosca il proprio repository e che un file tracciato oltre 260 caratteri sia aggiunto, committato e riletto esattamente. Non vengono qualificati metadati Git a profondità arbitrarie. Conservare la fixture e l'errore iniziale di Git: un'inizializzazione fallita può far risalire la ricerca del repository al checkout padre.

### Benchmark esplicito della coda pendente

`test-pending-benchmark.ps1 -OutputRoot <directory-nuova-in-.runtime>` esegue separatamente dalle suite ordinarie i profili con 1, 2, 4 e 8 produttori, tre ripetizioni, cinque richieste di riscaldamento e 100 richieste misurate per produttore. Ogni append contiene 1024 byte e un identificatore unico. Il writer resta occupato durante la produzione; due nuovi processi importano poi le richieste durevoli e una ripetizione verifica l'assenza di duplicati. Tutte le fixture, i log e i campioni restano conservati; una directory di output esistente viene rifiutata.

Il rapporto contiene hash del codice, ambiente, profondità osservata della coda e distribuzioni p50/p95/p99/massimo. La diagnostica opzionale `-Diagnostics <hashtable>` di `New-SBPendingWrite`, `Invoke-SBPendingWrites` e `Complete-SBPendingSubmission` separa preparazione, scrittura/flush, rilettura, scansione e tentativi non bloccanti di acquisizione del lock; non cambia richieste, ricevute o output ordinario CLI/MCP. CPU del processo e tempo trascorso sono misurati separatamente: la differenza non dimostra da sola latenza del disco.

La scansione riusa le verifiche degli antenati nello stesso ciclo tramite l'API batch del Core; coda, directory delle ricevute e file sono ricontrollati a ogni elemento. Non conserva una cache delle richieste o delle ricevute tra le chiamate: hash, conflitti e ordinamento restano letti dai file correnti.

I percentili usano il metodo nearest-rank (rango arrotondato per eccesso) sui soli campioni misurati, escluso il riscaldamento. Il limite operativo è la massima concorrenza che passa tutte le ripetizioni con p95 entro 2 secondi e p99 entro 5 secondi, nel carico e nella postazione riportati. I parametri `-Producers`, `-Repetitions`, `-Samples` e `-Warmup` consentono smoke ridotti, che non sostituiscono il profilo completo. Nessuna misura locale dimostra prestazioni SMB o di altre postazioni.

## Contesto iniziale: cosa viene caricato e come ridurlo

Dopo `sb prompt` l'agente carica il pacchetto di avvio del dossier. Il profilo predefinito è **snello** (tetto 30.000 caratteri, **solo per il primo caricamento**): indice, sezioni essenziali di `context.md` e `memory.md`, task pronti in una riga ciascuno e un elenco dei livelli non caricati. Il resto non è eliminato e si richiede quando serve: dopo il primo caricamento **non c'è nessun altro tetto**. `-Profile Full` e la ricerca (`-Search`, `search_knowledge`) restituiscono tutto ciò che è pertinente alla richiesta; `-Budget` è un limite facoltativo che imposti tu.

```powershell
# Pacchetto snello (predefinito) e rapporto: caratteri per parte, stima token, peso delle direttive
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -Report

# Contesto completo (senza tetto) o ricerca mirata nei livelli non caricati
pwsh -NoProfile -File scripts/knowledge.ps1 -Startup -Profile Full
pwsh -NoProfile -File scripts/knowledge.ps1 -Search "termine"   # dossier in lavoro, 20 riscontri / 10.000 caratteri; -AllDossiers, -IncludeOriginals, -Limit 0 -Budget 0
pwsh -NoProfile -File scripts/knowledge.ps1 -Search "più termini della richiesta" -Mode Relevance -Limit 10 -Offset 0

# Recupero a strati: task integro (anche archiviato) o sezione intera
pwsh -NoProfile -File scripts/knowledge.ps1 -Task SB-SIMP-QUEUE-20261101
pwsh -NoProfile -File scripts/knowledge.ps1 -Section "Stato" -Source context
```

Dal server MCP: `get_startup_context` con `profile` = `slim` (predefinito) o `full`; i task completi con `get_ready_tasks` (`includeAcceptance`) o `get_task` (ID o `#seq`, anche archiviati).

**Caricamento a strati**: il profilo snello applica la Progressive Summarization (metodo di Tiago Forte, autore di PARA): ogni livello è un riassunto più breve dell'originale, e i livelli più profondi si leggono solo su richiesta. Qui il riassunto è sempre una scelta di sezioni, mai una riscrittura che perde informazioni: gli originali restano per hash.

**Decisioni in `memory.md`**: ogni scelta durevole va in una riga `Decisione: … — Motivo: …`, senza file dedicati (ADR leggera). Il motivo permette di riesaminarla senza rileggere la cronaca.

**Voci tipizzate (formato consigliato per le nuove voci)**: una riga per voce, `- [D|G|A|C] AAAA-MM-GG · scope · testo`, con D decisione, G gotcha, A architettura, C vincolo; per le decisioni il testo resta `Decisione: … — Motivo: …`. Le voci in forma libera già presenti restano valide e non vanno riscritte: la vista le classifica dal titolo di sezione o dal prefisso (`Decisione:`, `Gotcha:`).

**Vista per agenti `memory.agent.md`**: file derivato da `memory.md` (non modificare), generato da `secondbrain.ps1 -Sync` e dalla compattazione; `-Check` segnala `agent-view-pending` se manca o è obsoleto. Contiene le sole parti essenziali, una voce per riga con tipo e id stabile (`[D#a1b2c3] …`), senza grassetti, righe vuote né note di archivio, con l'hash della fonte in intestazione. Il profilo snello la carica al posto delle parti essenziali di `memory.md` solo se l'hash coincide; altrimenti ricade su `memory.md`. Dà struttura uniforme, non una riduzione di dimensione: la riduzione viene dalla compattazione (SYS05). Il formato è Markdown puro, leggibile allo stesso modo da Claude, Codex e Antigravity.

**Livelli in `memory.md` e `context.md`**: una sezione `##` è storica, e quindi non caricata nel profilo snello, se il titolo finisce con `(storico)` oppure se la prima riga sotto il titolo è `<!-- sb:tier=history -->`. Le decisioni durevoli e i gotcha restano nelle sezioni essenziali; la cronaca di sessioni e lotti va in quelle storiche. Un file senza marcatori si carica per intero. Per riorganizzare un dossier senza perdere nulla usa la compattazione conservativa (SYS05, `knowledge.ps1 -Compact -CandidatePath`): il candidato è revisionato, l'anteprima precede `-Apply` e gli originali restano per hash in `history/compaction/`.

Senza `-Dossier`, `-Compact` risolve il dossier del repository in lavoro (checkout corrente o `-CheckoutPath`/`-Repository`), come `-Startup`; un `-Dossier` relativo è inteso rispetto alla radice SecondBrain. Il tetto di `-Compact` (`-Budget`, predefinito 30.000) misura in memoria il pacchetto Slim che verrà caricato dopo la transazione, con la stessa composizione di `-Startup -Profile Slim`: indice, contesto essenziale con collegamento all'originale, vista agente rigenerata dalla memoria finale e descrizione dei livelli omessi. Slim include i soli task esplicitamente selezionati con `-TaskIds`; gli altri restano disponibili tramite `-Tasks` e `-Task`, mentre Full conserva la proiezione completa. Non conta il corpo delle sezioni storiche. L'anteprima non scrive il candidato nel dossier. Il pacchetto essenziale realmente oltre il tetto viene rifiutato senza omissioni silenziose.

Il [ciclo memorie](memory-cycle.md) aggiunge registro separato, allegati originali, promozione verificata e indici tematici ricostruibili. La consultazione con `-NoRecovery` non integra scritture pendenti. La manutenzione SYS05 dello storico rimane a lotti con anteprima e conferma.

**Baseline di pubblicazione.** `publication.ps1 -Initial` scrive `.runtime/publication/baseline-<id>.json` solo dopo una verifica completa senza rilievi irrisolti. Le baseline legacy sono ignorate. La baseline corrente riusa la copertura della sola storia quando repository, riferimenti e OID, policy effettiva, scanner e limiti coincidono. Working tree e indice vengono esaminati a ogni verifica.

**Riferimenti scansionati da SEC07.** La storia parte da rami, tag, riferimenti remoti locali e `HEAD`. Il rapporto elenca in `excludedRefs` gli altri riferimenti locali esclusi dal controllo. L'hook pre-push include anche gli OID effettivamente inviati, compresi quelli indicati da SHA o riferimenti non standard. La storia di un clone shallow o con graft è dichiarata incompleta.

Una revisione storica vale per il singolo percorso. SEC07 legge ogni blob una volta, ma verifica separatamente tutti i suoi percorsi storici. Se la mappa dei percorsi non è verificabile, la copertura risulta incompleta. Un blob inviato direttamente tramite OID o tag, senza un percorso, viene verificato anche come oggetto autonomo e non eredita le revisioni dei percorsi.

Cosa il rapporto **non** misura: prompt di sistema, definizioni degli strumenti MCP e skill dell'IDE. Se il contesto iniziale resta alto, guarda il riepilogo del contesto dell'IDE per vedere quali server MCP e skill pesano di più. Le misure sono in caratteri, non in token (la stima è caratteri/4).

## Uso stabile di `.runtime` su una postazione di prova

Questo profilo vale per una postazione locale usata per provare SecondBrain, dove i repository stanno su GitHub e la perdita dei dati dei dossier è accettabile.

- `.runtime` contiene solo `hosts/<id>/` (workstation.json, selezione, stato e ricevute IDE; la discovery salvata conserva soltanto i repository scelti), `access/` (lock, coda, sessioni, registro delle postazioni) e le fixture temporanee dei test in `hosts/<id>/repos/tests-*`.
- Tutto il resto è ricreabile e si può cancellare in qualsiasi momento: fixture, tmp, cartelle work chiuse, cache, rapporti. Build, cache e file temporanei dei prodotti stanno nelle cartelle del sistema operativo, non in `.runtime`.
- Nessun backup. Ogni repository conserva il proprio contesto minimo originale in `AGENTS.md`; i dossier (contesto, memoria, tracker) si possono ricostruire o scartare.
- Reset: senza transazione PARA pendente né sessioni attive, cancella tutto sotto `.runtime`, poi esegui `secondbrain.ps1 -Setup -Roots <cartelle> -Select <repository> -Ides <ide> -ApproveExistingBlocks -Yes -Apply`. I dossier in `01-projects` si riconoscono dall'identità del repository: non si sposta nulla. Il 2026-11-10 `.runtime` è passata da circa 56 GB a meno di 200 KB e i 22 repository sono stati ricollegati con `filesAligned: true`.
