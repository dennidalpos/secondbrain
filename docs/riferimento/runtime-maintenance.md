# Manutenzione di `.runtime` e contesto iniziale

`.runtime/` contiene tutto ciò che SecondBrain produce sul tuo PC: configurazione della postazione, backup, fixture dei test, rapporti. È escluso da Git e cresce nel tempo: nel clone del maintainer ha superato 11 GB (novembre 2026), per lo più cartelle di lavoro degli agent e fixture dei test. Nulla viene cancellato in automatico; la pulizia è sempre una tua richiesta esplicita. Prima di toccare qualcosa leggi anche [sicurezza e backup](safety-backups.md) e la [mappa completa](tree.md).

## Cosa contiene, per categoria

`cleanup.ps1 -ListRuntime` classifica ogni voce di primo livello:

| Categoria | Cartelle tipiche | Si può cancellare? | Come si recupera |
|---|---|---|---|
| `protected` | `hosts/<id>/` (configurazione, `state.json`, `inventory.json`), `access/` (sessioni e lock), `backups/` della postazione corrente | **No** | Non si rigenera: è la configurazione e la prova di cosa è gestito |
| `regenerable` | `tests/` (fixture delle suite), `mcp-handshake/`, `hosts/<id>/sources/python` | Sì | `tests/`: rieseguendo le suite `test-secondbrain*.ps1`; handshake: rieseguendo il test; `sources/python`: lo ricrea `sources.ps1` |
| `evidence` | `cleanup/` (registro delle pulizie), `trace/` (turni di fine prompt, solo metadati), `captures/` (originali degli screenshot), `publication/` (policy e baseline SEC07), `directives-activation/` | Con cautela | Non si rigenerano identiche: servono come prova o provenienza |
| `backup` | `backups/` e `workstations/<id di origine>/` (host precedenti), `backup/mcp-pairing/` | Con cautela, solo con manifest | Sono i recuperi dei file che SecondBrain ha sostituito |
| `working` | `hosts/<id>/repos/<repo>/{work,fixture,tmp,temp}/` (layout annidato), `operations/`, `q201/`, `t<numero>/`, `lotto-*`, `classify-*`, `compaction*/`, file sciolti e ogni cartella creata da un agent senza prefisso | Dopo verifica | Lavoro temporaneo: controlla riferimenti e proprietà; nessun codice le legge |

Dentro `hosts/<id>/`: `workstation.json`, `state.json`, `inventory.json`, `ide-map.json`, `istruzioni-globali.md` non si cancellano; `backups/` contiene gli originali (`<guid>.bin` e `.bin.json`) e i record `.stage`; `sources/` contiene l'ambiente Python (rigenerabile) e i rapporti.

Cause tipiche di crescita: le sub-suite lanciate da sole e le esecuzioni rosse conservano la fixture (`tests/`, anche decine di migliaia di file; a esito verde `test-secondbrain.ps1` rimuove la propria), ogni scrittura gestita aggiunge un backup, gli zip di `backup.ps1` pesano centinaia di MB.

## Vedere `.runtime` a colpo d'occhio

`cleanup.ps1 -RuntimeReport` stampa un indice Markdown in sola lettura: una riga per voce, ordinata per categoria (`protected`, `evidence`, `backup`, `working`, `regenerable`) e poi per dimensione, con ultima scrittura, riferimenti, chi la scrive e come si recupera; per le voci oltre 50 MB aggiunge le sottocartelle più grandi. Con `-ReportPath .runtime/INDEX.md` lo rigenera come vista derivata (scrittura atomica, ignorata da Git, nessun dato proprio); un altro `.md` sotto `.runtime` si crea solo se non esiste. Non rimuove né sposta nulla.

```powershell
pwsh -NoProfile -File scripts/cleanup.ps1 -RuntimeReport
pwsh -NoProfile -File scripts/cleanup.ps1 -RuntimeReport -ReportPath .runtime/INDEX.md
```

**Layout delle nuove cartelle degli agent**: `hosts/<id>/repos/<repo>/<categoria>/<yyyyMMdd>-<slug>` con categoria `work` (lavoro temporaneo), `evidence` (prove), `report` (rapporti), `fixture` o `tmp`. `<repo>` è l'ultimo segmento dell'identità del repository più 8 caratteri dell'hash (leggibile e senza collisioni tra proprietari); `<slug>` usa minuscole, cifre e trattini (al più 60 caratteri). TEMP e TMP del lavoro stanno nell'area `hosts/<id>/repos/<repo>/temp`. Il percorso si ottiene con `work.ps1 -Repository <identità> -Category work -Slug <slug>` (senza `-Run` stampa il piano e non crea cartelle) o con `Get-SBRuntimeWorkPath`; senza `-Category` e `-Slug` `work.ps1` mantiene il layout precedente `hosts/<id>/repositories/<hash>/<Project>/<Runtime>`.

`cleanup.ps1 -RuntimeReport` aggiunge all'indice due sezioni in sola lettura: **Livelli annidati** (le cartelle sotto `hosts/<id>/repos`, con categoria e conformità del nome) e **Cartelle legacy**, cioè le cartelle di primo livello fuori dalle voci gestite (`work-<data>-<slug>`, `t77`, `lotto-*`, …) e `hosts/<id>/repositories/…`, ciascuna con la destinazione proposta nel nuovo layout. `<id>` e `<repo>` restano da risolvere a mano: nulla viene spostato, rinominato o rimosso, e lo spostamento è una decisione tua. La proposta di pulizia (`-ProposeRuntime`) elenca le stesse legacy e valuta le cartelle annidate di lavoro oltre soglia; le prove (`evidence`, `report`) non sono mai candidate.

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
2. **Cartelle rigenerabili** (fixture di test oltre le ultime `-KeepFixtures` e `hosts/<id>/sources/python`): usa `cleanup.ps1 -Regenerable`.
   ```powershell
   # Anteprima (nessuna rimozione): target, saltati con il motivo, file e byte
   pwsh -NoProfile -File scripts/cleanup.ps1 -Regenerable -KeepFixtures 5
   # Applicazione, solo dopo una tua richiesta esplicita (da citare in -Authorization)
   pwsh -NoProfile -File scripts/cleanup.ps1 -Regenerable -KeepFixtures 5 -Apply -Authorization "richiesta utente del <data>: pulizia rigenerabili"
   ```
   Il perimetro è fisso. Si salta ciò che è stato scritto negli ultimi `-MinAgeMinutes` (predefinito 10), che contiene percorsi della configurazione o che è un reparse point; si rifiuta con transazione pendente o sessioni di accesso attive. Junction e symlink si scollegano senza seguirli e i file di sola lettura (oggetti Git) sono gestiti. Non c'è backup, perché tutto si ricrea (suite `test-secondbrain*.ps1`, `sources.ps1`); resta un registro `.runtime/cleanup/regenerable-<data>.json` con autorizzazione, elementi rimossi, dimensioni e come ricrearli. Esce con 1 se una cartella non si rimuove (esito `partial`).
3. Per file con backup e hash (`.stage`, backup, rapporti) usa `cleanup.ps1 -ManifestPath` con un manifest revisionato e `-Authorization`.
4. Per altre cartelle (rapporti handshake, lavoro di agent, zip) controlla i collegamenti (`Get-ChildItem <cartella> -Recurse -Force -Attributes ReparsePoint`; una junction si toglie con `cmd /c rmdir <link>`); per percorsi oltre 260 caratteri svuota con `robocopy <cartella-vuota> <cartella> /MIR`.
5. Dopo la pulizia esegui `secondbrain.ps1 -Check`: deve restare lo stato noto della postazione.

## Suite di test: livelli e fixture

`scripts/test-secondbrain.ps1` ha tre livelli e una sub-suite singola:

| Comando | Cosa esegue | Quando |
|---|---|---|
| `-Quick` | Controlli puri (identità dei repository, JSON deterministico, VERSION e direttive, catalogo prompt, catalogo messaggi e throw con chiave), fonti, audit esterno, ambiente Git e parser. Nessun Git né processo figlio per i controlli puri. | A ogni modifica |
| *(predefinito, Fast)* | Controlli CLI e integrazione, poi portable, workflows, tracker, audit2, traccia, concorrenza, pending, fonti, audit esterno e ambiente Git, oltre al parser. Sub-suite in parallelo (al più 4 processi `pwsh`), una riga di riepilogo con il tempo per ciascuna. | Prima del commit |
| `-Full` | Come Fast, ma in sequenza e con una riga per ogni verifica. | Prima di una pubblicazione |
| `-Only <chiave>` | Una o più sub-suite (`portable`, `workflows`, `trackers`, `audit2`, `trace`, `concurrency`, `pending`, `sources`, `external-audit`, `quick`, `git-environment`). | Per ripetere un fallimento |

Ogni esecuzione lavora in `.runtime/tests/run-<id>`, sub-suite comprese. A esito **verde** quella directory (e solo quella) viene rimossa; a esito rosso resta, con le sue fixture, per l'analisi. `-KeepFixtures` o `SECONDBRAIN_TEST_KEEP=1` la conservano anche in caso di successo. Le sub-suite lanciate da sole (`pwsh -File scripts/test-secondbrain-<nome>.ps1`) conservano la propria fixture, come prima; fa eccezione `test-secondbrain-concurrency.ps1`, che la rimuove da sé a esito verde (e la conserva a esito rosso o con `SECONDBRAIN_TEST_KEEP=1`). A fine esecuzione `test-secondbrain.ps1` scrive `esito.json` accanto alle cartelle `run-<id>` (livello, verifiche, durata, suite con tempi, fixture rimosse o conservate) e la sub-suite di concorrenza `esito-concurrency.json` (per ogni caso durata, verifiche, file e byte della fixture): restano dopo la rimozione di `run-<id>`. `SECONDBRAIN_TEST_TIMING=1` esegue in sequenza e stampa le 15 sezioni più lente. I `git init` delle fixture usano un template minimo (`GIT_TEMPLATE_DIR` impostato da `test-helpers.ps1`, solo `info/exclude`): niente hook di esempio, circa 250 file in meno per fixture.

### Git e percorsi lunghi nelle fixture Windows

Il runner imposta `core.longpaths=true` solo nell'ambiente del processo e dei figli. Aggiunge una coppia a `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n` / `GIT_CONFIG_VALUE_n` e usa un file temporaneo tramite `GIT_CONFIG_GLOBAL`: include i file globali ereditati nell'ordine di lettura Git e aggiunge `core.longpaths=true`. Questo serve al livello Windows che può leggere la configurazione da file prima degli override di comando. Le configurazioni persistenti restano intatte. Le coppie ereditate sono preservate e ogni variabile modificata (anche quelle prima assenti, `GIT_CONFIG_GLOBAL` e `GIT_TEMPLATE_DIR`) viene ripristinata in `finally`, inclusi errori di preparazione.

I wrapper restano in `.runtime/hosts/<host>/repos/tests-<hash-checkout>/tmp/tmp-<data>-git-env-<id>/global.config`; la radice delle fixture resta quella richiesta. Lo helper richiede `git var GIT_CONFIG_GLOBAL` e percorsi globali assoluti su una sola riga, senza fallback per versioni non supportate; il wrapper deve essere leggibile sotto MAX_PATH. Comportamento verificato con Git `2.56.0.windows.4`. Riferimenti: [variabili Git](https://git-scm.com/docs/git-config), [percorsi restituiti da git var](https://git-scm.com/docs/git-var), [ordine dei file nel sorgente della versione verificata](https://github.com/git-for-windows/git/blob/v2.56.0.windows.4/builtin/var.c). Ogni sub-suite che usa `test-helpers.ps1` verifica sia il valore effettivo sia quello globale da file prima di creare la fixture; una configurazione incompleta o un override di solo comando con valore globale disabilitato vengono rifiutati. La sub-suite `git-environment`, inclusa anche in Quick, verifica ereditarietà e ripristino; i controlli puri `quick` restano senza Git né processi figli.

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

Impostare `SECONDBRAIN_TEST_ROOT` su una directory del runtime centrale per verificare il percorso annidato effettivo; non sostituirlo con una radice corta per aggirare un errore. Per conservare tutte le fixture usare `-KeepFixtures` e `SECONDBRAIN_TEST_KEEP=1`. `core.longpaths` riguarda Git for Windows: non qualifica un host con `LongPathsEnabled=0` né una share SMB fisica.

Limiti osservati con Git `2.56.0.windows.4`: inizializzazione e discovery dei metadati possono fallire quando il percorso del nuovo `.git/config` raggiunge 260 caratteri, anche con `core.longpaths=true` verificato nell'ambiente e con `-c core.longpaths=true`; i processi dei worktree rifiutano inoltre `GIT_DIR` oltre `PATH_MAX-40` ([sorgente Git della versione verificata](https://github.com/git-for-windows/git/blob/v2.56.0.windows.4/setup.c)). Il caso audit `references_updated` usa il nome sintetico `source-refs-updated` e le fixture workflow `wf-<id>`, mantenendo la radice runtime annidata e gli scenari originali. La regressione dell'ambiente verifica separatamente che la fixture riconosca il proprio repository e che un file tracciato oltre 260 caratteri sia aggiunto, committato e riletto esattamente. Non vengono qualificati metadati Git a profondità arbitrarie. Conservare la fixture e l'errore iniziale di Git: un'inizializzazione fallita può far risalire la ricerca del repository al checkout padre.

### Benchmark esplicito della coda pendente

`test-pending-benchmark.ps1 -OutputRoot <directory-nuova-in-.runtime>` esegue separatamente dalle suite ordinarie i profili con 1, 2, 4 e 8 produttori, tre ripetizioni, cinque richieste di riscaldamento e 100 richieste misurate per produttore. Ogni append contiene 1024 byte e un identificatore unico. Il writer resta occupato durante la produzione; due nuovi processi importano poi le richieste durevoli e una ripetizione verifica l'assenza di duplicati. Tutte le fixture, i log e i campioni restano conservati; una directory di output esistente viene rifiutata.

Il rapporto contiene hash del codice, ambiente, profondità osservata della coda e distribuzioni p50/p95/p99/massimo. La diagnostica opzionale `-Diagnostics <hashtable>` di `New-SBPendingWrite`, `Invoke-SBPendingWrites` e `Complete-SBPendingSubmission` separa preparazione, scrittura/flush, rilettura, scansione e tentativi non bloccanti di acquisizione del lock; non cambia richieste, ricevute o output ordinario CLI/MCP. CPU del processo e tempo trascorso sono misurati separatamente: la differenza non dimostra da sola latenza del disco.

La scansione riusa le verifiche degli antenati nello stesso ciclo tramite l'API batch del Core; coda, directory delle ricevute e file sono ricontrollati a ogni elemento. Non conserva una cache delle richieste o delle ricevute tra le chiamate: hash, conflitti e ordinamento restano letti dai file correnti.

I percentili usano il metodo nearest-rank (rango arrotondato per eccesso) sui soli campioni misurati, escluso il riscaldamento. Il limite operativo è la massima concorrenza che passa tutte le ripetizioni con p95 entro 2 secondi e p99 entro 5 secondi, nel carico e nella postazione riportati. I parametri `-Producers`, `-Repetitions`, `-Samples` e `-Warmup` consentono smoke ridotti, che non sostituiscono il profilo completo. Nessuna misura locale dimostra prestazioni SMB o di altre postazioni.

## Contesto iniziale: cosa viene caricato e come ridurlo

Dopo `sb prompt` l'agente carica il pacchetto di avvio del dossier. Il profilo predefinito è **snello** (tetto 20.000 caratteri, **solo per il primo caricamento**): indice, sezioni essenziali di `context.md` e `memory.md`, task pronti in una riga ciascuno e un elenco dei livelli non caricati. Il resto non è eliminato e si richiede quando serve: dopo il primo caricamento **non c'è nessun altro tetto**. `-Profile Full` e la ricerca (`-Search`, `search_knowledge`) restituiscono tutto ciò che è pertinente alla richiesta; `-Budget` è un limite facoltativo che imposti tu.

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

Senza `-Dossier`, `-Compact` risolve il dossier del repository in lavoro (checkout corrente o `-CheckoutPath`/`-Repository`), come `-Startup`; un `-Dossier` relativo è inteso rispetto alla radice SecondBrain. Il tetto di `-Compact` (`-Budget`, predefinito 50.000) misura in memoria il pacchetto Slim che verrà caricato dopo la transazione, con la stessa composizione di `-Startup -Profile Slim`: indice, contesto essenziale con collegamento all'originale, vista agente rigenerata dalla memoria finale, righe dei task pronti (incluse le dipendenze dei tracker correlati) e descrizione dei livelli omessi. Non conta la proiezione JSON completa dei task né il corpo delle sezioni storiche; anche i task non pronti restano integralmente conservati nel tracker. L'anteprima non scrive il candidato nel dossier. Una riorganizzazione per livelli che sposta la cronaca in sezioni `(storico)` non richiede quindi un `-Budget` esplicito; il pacchetto Slim realmente oltre il tetto viene rifiutato senza troncamenti.

**Baseline di pubblicazione**: `publication.ps1 -Initial` scrive il baseline SEC07 in `publication/baseline-<id>.json`, un file per repository (l'id deriva dal percorso del checkout). Un `-Initial` su un repository non altera il baseline degli altri. Il file unico `publication/baseline.json` delle versioni precedenti è letto solo se registrato per lo stesso repository e non viene riscritto.

**Riferimenti scansionati da SEC07**: la storia esaminata (primo controllo e `-Initial`) parte da rami, tag, remoti e `HEAD`. I riferimenti locali che non lasciano il clone (per esempio `refs/codex/*` creati dagli strumenti, stash, notes) non sono scansionati e il rapporto li elenca in `excludedRefs`; se uno di essi va pubblicato, trasformalo in ramo o tag prima del controllo. La scansione incrementale (`baseline..HEAD`) non cambia.

Cosa il rapporto **non** misura: prompt di sistema, definizioni degli strumenti MCP e skill dell'IDE. Se il contesto iniziale resta alto, guarda il riepilogo del contesto dell'IDE per vedere quali server MCP e skill pesano di più. Le misure sono in caratteri, non in token (la stima è caratteri/4).
