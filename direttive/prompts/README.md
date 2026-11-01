# Catalogo prompt v2

Indice generato da catalog.json e schede Markdown con scripts/build-prompts.ps1. Non modificare questo indice a mano.

Nella chat: `sb prompt`, `sb prompt tutti`, `sb prompt ambito test`, `sb prompt mostra TST04`, `sb prompt TST04: descrizione`. Ogni prompt ha un ID immutabile (`pmt-` e 8 esadecimali) e uno o più alias (codice incluso): ID e alias risolvono allo stesso prompt.

La CLI compone testo; il task viene svolto dall'agente nei permessi e nella modalità della sessione. [Uso, attivazione e migrazione dei codici](../../docs/directives-prompts.md).

```text
Catalogo prompt v2

COMPRENSIONE E RICERCA
COM01 | Esplora il repository e individua componenti e comandi principali.
  • ID: pmt-a709a792
  • Scope: repo | Modalità: read
  • Serve: accesso in lettura al repository e shell
  • Esempio: sb prompt COM01: esplora struttura e moduli principali

COM02 | Ricostruisci un flusso e le sue dipendenze nel codice.
  • ID: pmt-e0fd59da
  • Scope: repo/area | Modalità: read
  • Serve: punto di ingresso o scenario da tracciare
  • Esempio: sb prompt COM02: ricostruisci il flusso di autenticazione e sessioni

COM03 | Ricerca fonti ufficiali compatibili con il problema tecnico.
  • ID: pmt-25c97d58
  • Scope: repo/area | Modalità: read
  • Serve: problema tecnico o libreria con versione
  • Esempio: sb prompt COM03: cerca documentazione ufficiale PowerShell 7.5

COM04 | Valuta impatto, rischi e dipendenze di una modifica.
  • ID: pmt-179b9acc
  • Scope: repo | Modalità: read
  • Serve: proposta di modifica o difetto da correggere
  • Esempio: sb prompt COM04: valuta impatto dell isolamento dei log runtime


REQUISITI E PROGETTAZIONE
PRG01 | Trasforma una richiesta in requisiti e criteri di accettazione.
  • ID: pmt-98071f85
  • Scope: repo | Modalità: read
  • Serve: richiesta utente e documentazione esistente
  • Esempio: sb prompt PRG01: definisci criteri di accettazione per la ricerca full-text

PRG02 | Confronta soluzioni architetturali e motiva una decisione.
  • ID: pmt-3e0ad55e
  • Scope: repo/area | Modalità: read
  • Serve: alternative da valutare e vincoli di progetto
  • Esempio: sb prompt PRG02: confronta sqlite vs json per la persistenza locale

PRG03 | Progetta contratti API, modelli dati e compatibilità.
  • ID: pmt-83764c0d
  • Scope: repo/area | Modalità: read
  • Serve: requisiti o schema attuale con versione
  • Esempio: sb prompt PRG03: progetta schema json e contratti api per il tracker v2

PRG04 | Prepara un piano per fasi con dipendenze e verifiche.
  • ID: pmt-8541aed1
  • Scope: repo/area | Modalità: read
  • Serve: requisiti concordati e perimetro del lavoro
  • Esempio: sb prompt PRG04: pianifica la migrazione in tre rilasci atomici

PRG05 | Crea lo scaffolding di nuovi moduli con struttura, configurazione e test.
  • ID: pmt-884419a5
  • Scope: repo/area | Modalità: write
  • Serve: perimetro architetturale e dipendenze concordate
  • Esempio: sb prompt PRG05: definisci scaffolding del nuovo modulo

PRG06 | Pianifica un refactoring architetturale a fasi con verifiche e rollback.
  • ID: pmt-3731bb7d
  • Scope: repo/area | Modalità: read
  • Serve: modulo da riorganizzare, test esistenti e invarianti da preservare
  • Esempio: sb prompt PRG06: pianifica il refactoring del modulo di sincronizzazione


SVILUPPO E MODERNIZZAZIONE
DEV01 | Implementa una funzionalità con verifiche pertinenti.
  • ID: pmt-83df1685
  • Scope: repo/area/file | Modalità: write
  • Serve: requisiti o criteri di accettazione verificati
  • Esempio: sb prompt DEV01: implementa il comando di export con validazione hash

DEV02 | Riproduci un difetto e correggine la causa.
  • ID: pmt-25ac264e
  • Scope: repo/area/file | Modalità: write
  • Serve: segnalazione o comportamento atteso ed effettivo
  • Esempio: sb prompt DEV02: correggi errore di parsing per percorsi con spazi

DEV03 | Esegui un refactoring preservando contratti e comportamento.
  • ID: pmt-2b07a693
  • Scope: repo/area | Modalità: write
  • Serve: codice da migliorare e test esistenti
  • Esempio: sb prompt DEV03: estrai modulo per la gestione transazioni para

DEV04 | Aggiorna dipendenze verificando compatibilità e regressioni.
  • ID: pmt-e2405036
  • Scope: repo/area/file | Modalità: write
  • Serve: manifest delle dipendenze e lock file
  • Esempio: sb prompt DEV04: aggiorna pacchetto System.Text.Json

DEV05 | Migra codice o framework verso una destinazione definita.
  • ID: pmt-22863973
  • Scope: repo/area | Modalità: write
  • Serve: versione sorgente e destinazione con note di rilascio
  • Esempio: sb prompt DEV05: migra script da Windows PowerShell 5.1 a PowerShell 7.5

DEV06 | Configura ed esegui linter, formattatori e analisi statica del codice.
  • ID: pmt-f3082c1b
  • Scope: repo/area/file | Modalità: write
  • Serve: configurazione linter e perimetro di analisi
  • Esempio: sb prompt DEV06: configura linter ed esegui analisi statica

DEV07 | Classifica e riproduci un'issue prima di correggerla, senza modificare codice.
  • ID: pmt-9bd26aad
  • Scope: repo/area | Modalità: read
  • Serve: testo dell'issue, ambiente e accesso in lettura al codice
  • Esempio: sb prompt DEV07: classifica e riproduci l'issue sul parsing dei percorsi

DEV08 | Rivedi leggibilità, coerenza e manutenibilità del codice senza modificarlo.
  • ID: pmt-b16674bd
  • Scope: repo/area/file | Modalità: read
  • Serve: codice da rivedere, convenzioni del repository e test esistenti
  • Esempio: sb prompt DEV08: rivedi leggibilità e manutenibilità del modulo di sync


TEST E VERIFICA
TST01 | Aggiungi test unitari e di integrazione sui rischi rilevanti.
  • ID: pmt-08bff671
  • Scope: repo/area | Modalità: write
  • Serve: harness di test e comportamento da verificare
  • Esempio: sb prompt TST01: aggiungi test di boundary per il calcolo budget caratteri

TST02 | Copri percorsi utente con test end-to-end.
  • ID: pmt-286c3225
  • Scope: repo/area | Modalità: write
  • Serve: ambiente di test e flussi utente concordati
  • Esempio: sb prompt TST02: crea test end-to-end per il ciclo di backup e ripristino

TST03 | Individua e correggi test instabili o non deterministici.
  • ID: pmt-91021b67
  • Scope: repo/area | Modalità: write
  • Serve: log dei fallimenti intermittenti e suite di test
  • Esempio: sb prompt TST03: risolvi instabilita nei test asincroni della suite

TST04 | Diagnostica e correggi errori di build e test nella CI.
  • ID: pmt-bd98736f
  • Scope: repo/area/file | Modalità: write
  • Serve: log della CI e configurazione della pipeline
  • Esempio: sb prompt TST04: correggi fallimento del runner GitHub Actions su Windows

TST05 | Verifica il comportamento reale rispetto ai requisiti.
  • ID: pmt-ef96dea5
  • Scope: repo | Modalità: read
  • Serve: criteri di accettazione e ambiente funzionante
  • Esempio: sb prompt TST05: verifica conformita output rispetto alle specifiche 4.0

TST06 | Misura e migliora prestazioni e consumo di risorse.
  • ID: pmt-9de57e24
  • Scope: repo/area | Modalità: write
  • Serve: benchmark o scenario di carico riproducibile
  • Esempio: sb prompt TST06: riduci tempo di discovery host e memoria occupata

TST07 | Configura harness di test con fixture isolate e pulizia sicura.
  • ID: pmt-37c695fe
  • Scope: repo | Modalità: write
  • Serve: framework di test, script di test e radice di fixture isolata assegnata
  • Esempio: sb prompt TST07: crea fixture isolate su disco e valida cleanup automatico


REVIEW E SICUREZZA
SEC01 | Revisiona modifiche o codice con rilievi concreti e riferimenti.
  • ID: pmt-27896824
  • Scope: repo | Modalità: read
  • Serve: diff, commit o file da analizzare
  • Esempio: sb prompt SEC01: revisiona pull request per rilevamento leak dati

SEC02 | Analizza minacce, confini di fiducia e scenari di abuso.
  • ID: pmt-deb7d01a
  • Scope: repo | Modalità: read
  • Serve: architettura e flussi di dati verso l'esterno
  • Esempio: sb prompt SEC02: threat modeling dei flussi mcp stdio e file system locale

SEC03 | Correggi vulnerabilità e rafforza le difese interessate.
  • ID: pmt-b4cb6659
  • Scope: repo/area/file | Modalità: write
  • Serve: vulnerabilita confermata e contesto del codice
  • Esempio: sb prompt SEC03: bonifica path traversal nella risoluzione dei percorsi

SEC04 | Scansione credenziali, analisi dipendenze e hardening del codice.
  • ID: pmt-73fb4547
  • Scope: repo | Modalità: verify
  • Serve: albero di lavoro e strumenti di scansione
  • Esempio: sb prompt SEC04: esegui audit sicurezza credenziali

SEC05 | Verifica isolamento dati personali e conformità a GDPR e policy.
  • ID: pmt-24189cb6
  • Scope: repo | Modalità: verify
  • Serve: mappatura dei dati e policy di conformita
  • Esempio: sb prompt SEC05: controlla assenza dati personali e conformita privacy gdpr


INTERFACCIA ED ESPERIENZA UTENTE
INT01 | Valuta usabilità, coerenza e stati dei percorsi utente.
  • ID: pmt-33216f62
  • Scope: repo/area | Modalità: read
  • Serve: applicazione avviabile e percorsi da esaminare
  • Esempio: sb prompt INT01: valuta usabilita del wizard di configurazione terminale

INT02 | Implementa un’interfaccia seguendo requisiti e riferimenti.
  • ID: pmt-db55c30d
  • Scope: repo/area | Modalità: write
  • Serve: linee guida o mockup e componenti esistenti
  • Esempio: sb prompt INT02: realizza schermata di sincronizzazione

INT03 | Verifica accessibilità e utilizzo con tastiera e ausili.
  • ID: pmt-2ea0c993
  • Scope: repo/area | Modalità: read
  • Serve: interfaccia funzionante e standard di riferimento
  • Esempio: sb prompt INT03: verifica conformita aria e accessibilita

INT04 | Verifica internazionalizzazione di stringhe, formati e traduzioni.
  • ID: pmt-805ca095
  • Scope: repo/area | Modalità: verify
  • Serve: interfaccia o messaggi con lingue e formati supportati
  • Esempio: sb prompt INT04: verifica stringhe, formati e traduzioni della CLI


DATI E INTEGRAZIONI
DAT01 | Migra schema e dati con confronto e recupero verificabili.
  • ID: pmt-32e3cf59
  • Scope: repo/area | Modalità: write
  • Serve: schema sorgente, destinazione e dati sintetici
  • Esempio: sb prompt DAT01: migra schema del tracker con script di rollback atomico

DAT02 | Realizza importazioni e trasformazioni preservando gli originali.
  • ID: pmt-3ddd1df9
  • Scope: repo/area | Modalità: write
  • Serve: file sorgente, modello destinazione e validazione
  • Esempio: sb prompt DAT02: importa catalogo da csv a json preservando originali

DAT03 | Integra servizi API gestendo errori e ripetizione delle richieste.
  • ID: pmt-6b7b0e8d
  • Scope: repo/area | Modalità: write
  • Serve: documentazione API, credenziali di test e schema
  • Esempio: sb prompt DAT03: implementa client rest con retry esponenziale e backoff


BUILD E OPERATIVITÀ
OPS01 | Prepara e verifica pacchetti e artefatti distribuibili.
  • ID: pmt-a5c78cc6
  • Scope: repo | Modalità: write
  • Serve: istruzioni di build e requisiti del pacchetto
  • Esempio: sb prompt OPS01: prepara archivio zip deterministico e calcola sha-256

OPS02 | Configura pipeline, container e infrastruttura come codice.
  • ID: pmt-ce00f261
  • Scope: repo | Modalità: write
  • Serve: requisiti di deployment e ambiente di destinazione
  • Esempio: sb prompt OPS02: configura Dockerfile multi-stage per build riproducibile

OPS03 | Aggiungi log, metriche e diagnostica utili al problema.
  • ID: pmt-c2785b9c
  • Scope: repo/area/file | Modalità: write
  • Serve: scenario da monitorare e standard di logging
  • Esempio: sb prompt OPS03: aggiungi logging strutturato json

OPS04 | Prepara note di rilascio e verifiche di consegna.
  • ID: pmt-0618969e
  • Scope: repo | Modalità: write
  • Serve: commit, issue o task completati dalla release precedente
  • Esempio: sb prompt OPS04: compila note di rilascio v4.0 da commit e tracker


REPOSITORY E DOCUMENTAZIONE
REP01 | Completa il prossimo task eseguibile del repository aperto.
  • ID: pmt-4cc383ba
  • Scope: repo | Modalità: write
  • Serve: task pianificato e criteri di accettazione
  • Esempio: sb prompt REP01: esegui il prossimo task autonomo prioritario

REP02 | Scrivi guide e README coerenti con il prodotto reale.
  • ID: pmt-07430e8c
  • Scope: repo | Modalità: write
  • Serve: funzionalita implementate e comandi verificati
  • Esempio: sb prompt REP02: aggiorna guide e genera flussi mermaid

REP03 | Documenta API e contratti a partire dall’implementazione.
  • ID: pmt-6e82e3a9
  • Scope: repo/area | Modalità: write
  • Serve: codice sorgente di contratti ed endpoint
  • Esempio: sb prompt REP03: documenta parametri e schema risposte degli endpoint

REP04 | Rimuovi residui e codice inutilizzato dopo le verifiche.
  • ID: pmt-40772e6e
  • Scope: repo/area | Modalità: write
  • Serve: verifiche di assenza di riferimenti e test verdi
  • Esempio: sb prompt REP04: rimuovi file temporanei e build cache orfane

REP05 | Verifica contenuti e cronologia prima della pubblicazione.
  • ID: pmt-6055dd39
  • Scope: repo | Modalità: read
  • Serve: stato Git, cronologia e albero di lavoro
  • Esempio: sb prompt REP05: verifica pubblicabilita per prevenire leak di segreti

REP06 | Prepara il README GitHub con informazioni e asset verificati.
  • ID: pmt-60dba781
  • Scope: repo | Modalità: write
  • Serve: documentazione del repository e screenshot approvati
  • Esempio: sb prompt REP06: genera readme github con flussi mermaid

REP07 | Acquisisci screenshot reali e prepara gli asset pubblici.
  • ID: pmt-75786fd6
  • Scope: repo | Modalità: write
  • Serve: interfaccia funzionante con dati sintetici
  • Esempio: sb prompt REP07: acquisisci screenshot autentici dall interfaccia reale

REP08 | Ispeziona il repo, individua task residui e incrocia memorie e codice reale.
  • ID: pmt-cc2c5f5a
  • Scope: repo/area | Modalità: read
  • Serve: albero di lavoro, dossier di memoria e tracker
  • Esempio: sb prompt REP08: ispeziona il repo e rileva task residui

REP09 | Prepara commit e pull request con perimetro, messaggio e controlli verificati.
  • ID: pmt-3e3728b6
  • Scope: repo | Modalità: write
  • Serve: modifiche locali da consegnare e richiesta esplicita di commit o pull request
  • Esempio: sb prompt REP09: prepara commit e descrizione della pull request


MEMORIA E CONTINUITÀ
MEM01 | Allinea istruzioni locali, contesto, memoria e tracker.
  • ID: pmt-f02db9d0
  • Scope: repo/area | Modalità: write
  • Serve: decisioni o modifiche recenti non registrate
  • Esempio: sb prompt MEM01: allinea context.md e memory.md dopo completamento task

MEM02 | Migra progettazione e attività nel dossier SecondBrain.
  • ID: pmt-64dfa49f
  • Scope: repo/area | Modalità: write
  • Serve: documentazione storica o issue esterne da migrare
  • Esempio: sb prompt MEM02: migra todo sparsi nel tracker centralizzato del dossier

MEM03 | Chiudi la sessione: memorie, tracker, handoff e richiesta di commit e push.
  • ID: pmt-76604e4a
  • Scope: repo/area | Modalità: write
  • Serve: stato del lavoro svolto, task successivi definiti e destinazione di consegna
  • Esempio: sb prompt MEM03: chiudi la sessione e chiedi commit e push

MEM04 | Elenca e descrivi le attività del tracker e i problemi che risolvono.
  • ID: pmt-23c3d2be
  • Scope: repo/area | Modalità: read
  • Serve: tracker del dossier di repository
  • Esempio: sb prompt MEM04: elenca attivita e problemi del tracker

SYS06 | Leggi memoria attiva, contesto e tracker del repository corrente.
  • ID: pmt-821f7dec
  • Scope: repo | Modalità: read
  • Serve: checkout del repository aperto
  • Esempio: sb prompt SYS06: carica contesto e memoria del repository nel budget


SISTEMA E MANUTENZIONE CENTRALE
SYS01 | Verifica gli IDE; mappa o riallinea su richiesta.
  • ID: pmt-26817a61
  • Scope: central | Modalità: verify
  • Serve: installazioni IDE e autorizzazioni locali
  • Esempio: sb prompt SYS01: mappa lo stato di allineamento delle direttive negli ide

SYS02 | Verifica le fonti autorevoli; acquisisci o aggiorna su richiesta.
  • ID: pmt-5b593404
  • Scope: central | Modalità: verify
  • Serve: registro PARA resource-authoritative-sources
  • Esempio: sb prompt SYS02: verifica aggiornamenti normativi nel registro fonti

SYS03 | Attiva SecondBrain dopo discovery e selezione degli asset.
  • ID: pmt-5f9f93e0
  • Scope: central | Modalità: write
  • Serve: volume SecondBrain e consenso utente sugli asset
  • Esempio: sb prompt SYS03: attiva secondbrain selezionando repository e ide locali

SYS04 | Controlla o allinea gli asset già gestiti della postazione.
  • ID: pmt-677a10ab
  • Scope: central | Modalità: verify
  • Serve: configurazione postazione e direttive approvate
  • Esempio: sb prompt SYS04: verifica allineamento direttive nei repository gestiti

SYS05 | Compatta il dossier preservando originali, fatti e TOC.
  • ID: pmt-77d7bf7a
  • Scope: central | Modalità: write
  • Serve: dossier da compattare e storico verificabile
  • Esempio: sb prompt SYS05: compatta cronologia del dossier preservando fatti e toc

SYS07 | Consulta entità e risorse del PARA centrale per identità e percorso.
  • ID: pmt-f0cb4572
  • Scope: central | Modalità: read
  • Serve: archivio PARA centrale e para-index.json
  • Esempio: sb prompt SYS07: consulta entita del para centrale per percorso e id

SYS08 | Misura i caratteri di contesto, memoria e tracker rispetto al budget.
  • ID: pmt-9a32f4e4
  • Scope: central | Modalità: verify
  • Serve: dossier target e vincolo di 50.000 caratteri
  • Esempio: sb prompt SYS08: verifica conteggio caratteri rispetto a 20000

SYS09 | Esegui il backup compresso deterministico e verifica i digest SHA-256.
  • ID: pmt-e498353a
  • Scope: central | Modalità: write
  • Serve: configurazione attiva e root runtime di backup
  • Esempio: sb prompt SYS09: esegui backup deterministico e valida il manifest sha-256

SYS10 | Esegui rollback e dismissione repository restituendo i dati per privacy.
  • ID: pmt-b98acaaa
  • Scope: central | Modalità: write
  • Serve: dossier del repository, checkout di destinazione e consenso utente
  • Esempio: sb prompt SYS10: esegui rollback del repository dismesso e pulisci i dati

SYS11 | Aggiungi, modifica o rimuovi un prompt del catalogo centralizzato.
  • ID: pmt-364616bb
  • Scope: central | Modalità: write
  • Serve: catalogo v2 valido, area di destinazione e sessione di scrittura
  • Esempio: sb prompt SYS11: aggiungi un prompt al catalogo nell'area test


GOVERNANCE, LICENZE E CONFORMITÀ
GOV01 | Verifica licenze open source, conformità dei file e header SPDX.
  • ID: pmt-313da996
  • Scope: repo | Modalità: verify
  • Serve: albero sorgenti e file di licenza
  • Esempio: sb prompt GOV01: verifica licenza mit e corrispondenza intestazioni spdx

GOV02 | Scansiona dipendenze esterne e compila il registro CREDITS con licenze terze.
  • ID: pmt-adb9bfc0
  • Scope: repo | Modalità: write
  • Serve: lockfile dipendenze e licenze di terze parti
  • Esempio: sb prompt GOV02: scansiona dipendenze terze e compila file CREDITS.md

```
