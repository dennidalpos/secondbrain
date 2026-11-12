# Fonti autorevoli

Il registro e una Risorsa PARA con identita `resource-authoritative-sources`. Risolvere il percorso dall'indice PARA e verificare `para.json`; il percorso iniziale e `03-resources/authoritative-sources`. Schede e versioni sono autorevoli, `catalog.json` e `README.md` sono viste generate.

## Dati, versioni e applicabilita

Le schede rispettano `config/source.schema.json`. Ogni fonte ha identita, classificazione, ente, giurisdizione, lingua, diritti, endpoint HTTPS registrati, relazioni e decorrenze. Gli originali conservano i byte acquisiti e gli hash SHA-256; ciascuna versione ha manifest, trascrizione e diagnostica. Il tipo (`kind`) fissa la categoria dichiarata: `regulation` e normativa, `decision` e legale, `dependency`, `license` e `runbook` sono fonti di prodotto, gli altri tipi sono riferimenti (`category` in `catalog.json`). Per normativa e legale lo schema impone una giurisdizione diversa da `Global`, un identificativo ufficiale e almeno una data di efficacia; una data ignota si dichiara `requires-verification` con data nulla, mai stimata, e Check la segnala come `effective-date-unverified`. `acceptedVersion` richiede una versione verificata con `review.json`: revisore, data, fingerprint, hash della trascrizione e riscontri su struttura, numeri/tabelle e passaggi citati. La verifica riguarda la trascrizione, non la conformita dei prodotti o la vigenza completa del documento.

Per i PDF la conversione usa MarkItDown e una passata locale pdfplumber che conserva pagine e posizioni delle tabelle in blocchi di testo. Il PDF nativo rimane il riferimento per grafici, impaginazione e immagini. Le pagine di scansione non riconosciute vengono segnalate. HTML, DOCX, testo, CSV e JSON mantengono la propria diagnostica; i valori numerici dei dataset non vengono convertiti in floating point.

Le schede `authoritative-sources.json` dei dossier rispettano `config/source-applicability.schema.json`: applicabilita motivata e attuazione hanno stati distinti. Una citazione lessicale non prova applicabilita o comportamento. Il censimento conserva percorsi, righe, hash e copertura; esclude segreti, dipendenze, storico e snapshot. Dossier archiviati e checkout esclusi restano preservati.

I profili versionati del registro sono consultivi. Le prescrizioni comuni seguono proposta, approvazione dei testi concreti, registrazione degli hash, Sync e SYS01.

## CLI

Comandi dalla radice SecondBrain, PowerShell 7.5+:

```powershell
$cfg = '.runtime/hosts/<id>/workstation.json'
./scripts/sources.ps1 -Check -ConfigPath $cfg
./scripts/sources.ps1 -Probe -ConfigPath $cfg
./scripts/sources.ps1 -Probe -SaveReport -ConfigPath $cfg
./scripts/sources.ps1 -Collect -SourceId nist-ssdf -ConfigPath $cfg -SessionId $sessionId
./scripts/sources.ps1 -BuildIndex -ConfigPath $cfg -SessionId $sessionId
./scripts/sources.ps1 -Decide -SourceId <id> -VersionId <versione> -Decision reject -Reason <testo> -DecidedBy <chi> -SessionId $sessionId
./scripts/sources.ps1 -AddEffectiveDate -SourceId <id> -Provision <testo> [-Date yyyy-MM-dd] -DateStatus verified -Reference <testo> -SessionId $sessionId
```

Check e Probe senza SaveReport non scrivono; solo Probe accede alla rete. Collect conserva una candidata e non accetta versioni o direttive. Decide chiude una versione senza modifiche a mano: `reject` (una candidata o incompleta non e piu pendente e lo stesso contenuto non viene ricollezionato), `accept` (una versione verificata diventa accettata; una candidata richiede trascrizione estratta, `-ReviewScope` e `-ReviewedStructure -ReviewedNumbersAndTables -ReviewedCitedPassages`, e il comando scrive `review.json`) e `known-variant` (versione verificata la cui impronta puo tornare dall endpoint, per esempio un'alternanza cosmetica: Check non segnala piu `changed` per quell'impronta). Ogni decisione si aggiunge a `entries/<id>/decisions.json` (`config/source-decisions.schema.json`) con motivo, autore, data e impronta; il registro e fuori dall'hash della scheda, quindi una variante nota lascia valido il rapporto del Probe, mentre accept e reject cambiano la scheda e richiedono un nuovo Probe. AddEffectiveDate aggiunge una data di efficacia. Dopo ogni scrittura le viste generate vengono ricostruite. Una riesecuzione con gli stessi originali non crea altre versioni; una directory di versione interrotta viene preservata e richiede revisione. Riprendere una conversione candidata producendo un nuovo file e aggiornando il manifest con backup e precondizioni hash; preservare originali e precedenti trascrizioni come alternative con hash. Non aggiornare a mano hash per nascondere modifiche sconosciute.

Scritture con sessione Write e operation lock, senza forzature; Start/End nello stesso script con try/finally. Backup nel backupRoot. Il Probe rilascia il lock durante la rete e vincola il rapporto agli hash delle schede lette. Una scheda cambiata invalida la freschezza del relativo rapporto.

Exit code: 0 regolare; 1 variazioni o revisioni pendenti; 2 errore o copertura incompleta; 3 contesa. Il Check generale comprende i riscontri locali quando la Risorsa e presente. Gli impedimenti dichiarati restano segnalazioni: non vengono trasformati in controlli superati.

## Convertitore locale

Python 3.13; ambiente dedicato nel runtime della postazione, sottocartella `sources/python`. Installare dal lock `scripts/source-requirements.lock.txt` con il controllo degli hash: `python -m pip install --require-hashes -r scripts/source-requirements.lock.txt`. Il lock fissa 30 pacchetti, ciascuno con lo sha256 di tutti i file PyPI della versione; se cambia una versione, rigenerare tutti i suoi hash prima dell'installazione. `source-requirements.txt` documenta la dipendenza diretta `markitdown[pdf,docx]==0.1.9`. Nessuna dipendenza viene introdotta nelle build dei prodotti.

Il convertitore riceve file locali tramite stream, con plugin e servizi cloud disabilitati. Limite download 50 MiB, timeout 30 secondi, massimo cinque redirect con host registrati e indirizzi pubblici. Nessuna autenticazione o aggiramento di blocchi; endpoint non verificabili e file incompatibili richiedono un esito esplicito.

## Pianificazione

Non esiste alcun task pianificato: il Probe (rete) e la raccolta sono comandi espliciti, da lanciare su richiesta con `sources.ps1 -Probe -SaveReport`. L'esecuzione non modifica corpus, direttive, tracker o schede dei prodotti.

Rapporti in `runtimeRoot/sources/reports`; ultimo esito in `runtimeRoot/sources/latest.json`. Conservazione 90 giorni; Check segnala rapporti assenti, incompatibili con le schede o piu vecchi di 14 giorni, variazioni e copertura incompleta. La consultazione dell'archivio funziona offline. Le segnalazioni si consultano nel rapporto e nel Check, senza invii esterni.

## Verifiche

`test-secondbrain-sources.ps1` e incluso nella suite principale; con `-PythonPath` esegue anche le prove reali del convertitore. Nessuna prova di pianificazione: lo scheduler è stato ritirato.

Fonti tecniche: [MarkItDown](https://github.com/microsoft/markitdown), [PyPI](https://pypi.org/project/markitdown/), [HttpClient](https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpclient), [Task Scheduler](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasksettingsset?view=windowsserver2025-ps).

## Automazione, file di controllo e alberatura standard (03-resources)

Ogni cartella di `03-resources/` ha la stessa alberatura: `para.json` (kind `resource`, id `resource-<cartella>`), `brief.md`, il contenuto e due viste generate, `CONTROL.json` (percorso, SHA-256 e dimensione di ogni file, senza date) e `INDEX.md`. Il registro aggiunge `entries/<id>/metadata.json`, `entries/<id>/versions/<yyyyMMdd>-<fp16>/`, `domains.json`, `catalog.json` e `normative-queue.json`. Le risorse restano ignorate da Git; la storia sono versioni e manifest, e lo ZIP di backup include gia la cartella.

`scripts/resources.ps1`: `-Check` (sola lettura: alberatura, scostamento di CONTROL.json e INDEX.md), `-BuildIndex` (riscrive le viste), `-Sync [-IfStale] [-MaxDepth 3] [-MaxSources 50]`. Sync controlla ogni endpoint, raccoglie una nuova versione `candidate` solo se il contenuto e cambiato (le versioni accettate e precedenti non si toccano mai), segue `relatedSources` e i numeri ufficiali trovati nelle trascrizioni entro i limiti, e scrive in `normative-queue.json` cio che non risolve; non scarica mai una fonte non registrata. L accettazione resta manuale. Check segnala anche `mapping-outdated` quando una mappatura di prodotto punta a una versione precedente a quella accettata di un regolamento o una decisione.

`scripts/resources-hook.ps1` e un ponte non bloccante all avvio della sessione: lancia `-Sync -IfStale` (report di probe piu vecchio di 14 giorni) in un processo separato. `-ShowConfiguration` stampa la voce SessionStart di Claude Code; lo script non modifica alcun file di impostazioni.
