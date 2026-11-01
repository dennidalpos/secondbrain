# Fonti autorevoli

Il registro e una Risorsa PARA con identita `resource-authoritative-sources`. Risolvere il percorso dall'indice PARA e verificare `para.json`; il percorso iniziale e `03-resources/authoritative-sources`. Schede e versioni sono autorevoli, `catalog.json` e `README.md` sono viste generate.

## Dati, versioni e applicabilita

Le schede rispettano `config/source.schema.json`. Ogni fonte ha identita, classificazione, ente, giurisdizione, lingua, diritti, endpoint HTTPS registrati, relazioni e decorrenze. Gli originali conservano i byte acquisiti e gli hash SHA-256; ciascuna versione ha manifest, trascrizione e diagnostica. `acceptedVersion` richiede una versione verificata con `review.json`: revisore, data, fingerprint, hash della trascrizione e riscontri su struttura, numeri/tabelle e passaggi citati. La verifica riguarda la trascrizione, non la conformita dei prodotti o la vigenza completa del documento.

Per i PDF la conversione usa MarkItDown e una passata locale pdfplumber che conserva pagine e posizioni delle tabelle in blocchi di testo. Il PDF nativo rimane il riferimento per grafici, impaginazione e immagini. Le pagine di scansione non riconosciute vengono segnalate. HTML, DOCX, testo, CSV e JSON mantengono la propria diagnostica; i valori numerici dei dataset non vengono convertiti in floating point.

Le schede `authoritative-sources.json` dei dossier rispettano `config/source-applicability.schema.json`: applicabilita motivata e attuazione hanno stati distinti. Una citazione lessicale non prova applicabilita o comportamento. Il censimento conserva percorsi, righe, hash e copertura; esclude segreti, dipendenze, storico e snapshot. Dossier archiviati e checkout esclusi restano preservati.

I profili versionati del registro sono consultivi. Le prescrizioni comuni seguono proposta, approvazione dei testi concreti, registrazione degli hash, Sync e SYS01. Il generatore inserisce il riferimento alle nuove schede solo con revisione comune approvata 3.2 o successiva; la comune 3.2 e stata approvata e distribuita il 27 ottobre 2026, inclusa la separazione tra manutenzione centrale e lavoro degli agenti prodotto.

## CLI

Comandi dalla radice SecondBrain, PowerShell 7.5+:

```powershell
$cfg = '.runtime/hosts/<id>/workstation.json'
./scripts/sources.ps1 -Check -ConfigPath $cfg
./scripts/sources.ps1 -Probe -ConfigPath $cfg
./scripts/sources.ps1 -Probe -SaveReport -ConfigPath $cfg
./scripts/sources.ps1 -Collect -SourceId nist-ssdf -ConfigPath $cfg -SessionId $sessionId
./scripts/sources.ps1 -BuildIndex -ConfigPath $cfg -SessionId $sessionId
```

Check e Probe senza SaveReport non scrivono; solo Probe accede alla rete. Collect conserva una candidata e non accetta versioni o direttive. Una riesecuzione con gli stessi originali non crea altre versioni; una directory di versione interrotta viene preservata e richiede revisione. Riprendere una conversione candidata producendo un nuovo file e aggiornando il manifest con backup e precondizioni hash; preservare originali e precedenti trascrizioni come alternative con hash. Non aggiornare a mano hash per nascondere modifiche sconosciute.

Scritture con sessione Write e operation lock, senza forzature; Start/End nello stesso script con try/finally. Backup nel backupRoot. Il Probe rilascia il lock durante la rete e vincola il rapporto agli hash delle schede lette. Una scheda cambiata invalida la freschezza del relativo rapporto.

Exit code: 0 regolare; 1 variazioni o revisioni pendenti; 2 errore o copertura incompleta; 3 contesa. Il Check generale comprende i riscontri locali quando la Risorsa e presente. Gli impedimenti dichiarati restano segnalazioni: non vengono trasformati in controlli superati.

## Convertitore locale

Python 3.13; ambiente dedicato nel runtime della postazione, sottocartella `sources/python`. Installare dal lock `scripts/source-requirements.lock.txt`; `source-requirements.txt` documenta la dipendenza diretta `markitdown[pdf,docx]==0.1.9`. Nessuna dipendenza viene introdotta nelle build dei prodotti.

Il convertitore riceve file locali tramite stream, con plugin e servizi cloud disabilitati. Limite download 50 MiB, timeout 30 secondi, massimo cinque redirect con host registrati e indirizzi pubblici. Nessuna autenticazione o aggiramento di blocchi; endpoint non verificabili e file incompatibili richiedono un esito esplicito.

## Pianificazione

Non esiste alcun task pianificato: il Probe (rete) e la raccolta sono comandi espliciti, da lanciare su richiesta con `sources.ps1 -Probe -SaveReport`. L'esecuzione non modifica corpus, direttive, tracker o schede dei prodotti.

Rapporti in `runtimeRoot/sources/reports`; ultimo esito in `runtimeRoot/sources/latest.json`. Conservazione 90 giorni; Check segnala rapporti assenti, incompatibili con le schede o piu vecchi di 14 giorni, variazioni e copertura incompleta. La consultazione dell'archivio funziona offline. Le segnalazioni si consultano nel rapporto e nel Check, senza invii esterni.

## Verifiche

`test-secondbrain-sources.ps1` e incluso nella suite principale; con `-PythonPath` esegue anche le prove reali del convertitore. Nessuna prova di pianificazione: lo scheduler è stato ritirato.

Fonti tecniche: [MarkItDown](https://github.com/microsoft/markitdown), [PyPI](https://pypi.org/project/markitdown/), [HttpClient](https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpclient), [Task Scheduler](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasksettingsset?view=windowsserver2025-ps).
