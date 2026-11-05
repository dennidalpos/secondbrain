# Catalogo dei prompt

Indice generato da catalog.json e dalle schede Markdown con scripts/build-prompts.ps1. Non modificarlo a mano.

In chat: `sb prompt`, `sb prompt list`, `sb prompt ambito test`, `sb prompt mostra TST04`, `sb prompt TST04: descrizione`. Ogni prompt ha un ID immutabile (`pmt-` e 8 cifre esadecimali) e un codice stabile mai riutilizzato: ID e codice risolvono allo stesso prompt.

La CLI compone il testo; il task è svolto dall'agente nei permessi e nella modalità della sessione. [Come usare e modificare i prompt](../../docs/prompt.md). Lingua: [English](README.md) · [Italiano](README.it.md).

```text
Catalogo prompt
Legenda: 🔭 legge · ✅ verifica · 🔥 scrive · ⛔ distruttivo/irreversibile

COMPRENSIONE E RICERCA
🔭 COM01 | Esplora il repository e individua componenti principali e comandi.
  • ID: pmt-a709a792
  • Ambito: repo | Modalità: read
  • Cosa serve: accesso in lettura al repository e una shell
  • Esempio d'uso: esplora la struttura e i moduli principali

🔭 COM02 | Segui un flusso e le sue dipendenze attraverso il codice.
  • ID: pmt-e0fd59da
  • Ambito: repo/area | Modalità: read
  • Cosa serve: punto di ingresso o scenario da seguire
  • Esempio d'uso: segui il flusso di autenticazione e sessione

🔭 COM03 | Trova le fonti ufficiali adatte al problema tecnico.
  • ID: pmt-25c97d58
  • Ambito: repo/area | Modalità: read
  • Cosa serve: problema tecnico o libreria con la sua versione
  • Esempio d'uso: trova la documentazione ufficiale per la versione di runtime in uso

🔭 COM04 | Valuta impatto, rischi e dipendenze di una modifica.
  • ID: pmt-179b9acc
  • Ambito: repo | Modalità: read
  • Cosa serve: modifica proposta o difetto da correggere
  • Esempio d'uso: valuta l'impatto dell'isolamento dei log di runtime

🔭 COM05 | Analizza log e incidenti per trovare la causa radice, senza toccare il codice.
  • ID: pmt-1839927a
  • Ambito: repo/area | Modalità: read
  • Cosa serve: log, errori o sintomi, finestra temporale e accesso in lettura
  • Esempio d'uso: trova la causa radice degli errori di ieri nei log

🔭 COM06 | Spiega codice o concetti a chi è nuovo del progetto
  • ID: pmt-fe04425a
  • Ambito: repo/file | Modalità: read
  • Cosa serve: Codice, modulo o concetto da spiegare e il livello di partenza del lettore
  • Esempio d'uso: COM06: spiega il flusso dei retry dei pagamenti a un nuovo collega


REQUISITI E PROGETTAZIONE
🔭 PRG01 | Trasforma una richiesta in requisiti e criteri di accettazione.
  • ID: pmt-98071f85
  • Ambito: repo | Modalità: read
  • Cosa serve: richiesta dell'utente e documentazione esistente
  • Esempio d'uso: definisci i criteri di accettazione per la ricerca full-text

🔭 PRG02 | Confronta le opzioni architetturali e motiva una decisione.
  • ID: pmt-3e0ad55e
  • Ambito: repo/area | Modalità: read
  • Cosa serve: alternative da valutare e vincoli del progetto
  • Esempio d'uso: confronta SQLite e JSON per la persistenza locale

🔭 PRG03 | Progetta contratti API, modelli di dati e compatibilità.
  • ID: pmt-83764c0d
  • Ambito: repo/area | Modalità: read
  • Cosa serve: requisiti o schema attuale con la sua versione
  • Esempio d'uso: progetta lo schema JSON e i contratti API per l'elenco dei task

🔭 PRG04 | Prepara un piano a fasi con dipendenze e controlli.
  • ID: pmt-8541aed1
  • Ambito: repo/area | Modalità: read
  • Cosa serve: requisiti concordati e perimetro del lavoro
  • Esempio d'uso: pianifica la migrazione in tre rilasci atomici

🔥 PRG05 | Crea l'impalcatura di nuovi moduli con struttura, configurazione e test.
  • ID: pmt-884419a5
  • Ambito: repo/area | Modalità: write
  • Cosa serve: perimetro architetturale concordato e dipendenze
  • Esempio d'uso: definisci l'impalcatura del nuovo modulo

🔭 PRG06 | Pianifica un refactoring architetturale a fasi con controlli e rollback.
  • ID: pmt-3731bb7d
  • Ambito: repo/area | Modalità: read
  • Cosa serve: modulo da riorganizzare, test esistenti e invarianti da preservare
  • Esempio d'uso: pianifica il refactoring del modulo di sincronizzazione

🔥 PRG07 | Registra una decisione architetturale (ADR)
  • ID: pmt-c61c598b
  • Ambito: repo | Modalità: write
  • Cosa serve: La decisione presa o da prendere, il contesto, i vincoli, le opzioni considerate e chi decide
  • Esempio d'uso: PRG07: registra perché abbiamo scelto PostgreSQL al posto di MongoDB


SVILUPPO E MODERNIZZAZIONE
🔥 DEV01 | Implementa una funzionalità con i controlli pertinenti.
  • ID: pmt-83df1685
  • Ambito: repo/area/file | Modalità: write
  • Cosa serve: requisiti o criteri di accettazione verificati
  • Esempio d'uso: implementa il comando di esportazione con validazione dell'hash

🔥 DEV02 | Riproduci un difetto e correggine la causa.
  • ID: pmt-25ac264e
  • Ambito: repo/area/file | Modalità: write
  • Cosa serve: segnalazione o comportamento atteso e osservato
  • Esempio d'uso: correggi l'errore di parsing per i percorsi contenenti spazi

🔥 DEV03 | Rifattorizza il codice preservando i contratti: mirato, a fasi o periodico.
  • ID: pmt-2b07a693
  • Ambito: repo/area | Modalità: write
  • Cosa serve: codice da migliorare, test esistenti e perimetro dell'intervento
  • Esempio d'uso: estrai la gestione delle transazioni in un modulo dedicato

🔥 DEV04 | Aggiorna le dipendenze verificando compatibilità e regressioni.
  • ID: pmt-e2405036
  • Ambito: repo/area/file | Modalità: write
  • Cosa serve: manifest delle dipendenze e lock file
  • Esempio d'uso: aggiorna il pacchetto di serializzazione JSON

🔥 DEV05 | Migra codice o un framework verso un obiettivo definito.
  • ID: pmt-22863973
  • Ambito: repo/area | Modalità: write
  • Cosa serve: versioni di origine e di destinazione con note di rilascio
  • Esempio d'uso: migra gli script dalla vecchia versione del runtime a quella corrente

🔥 DEV06 | Configura ed esegui linter, formattatori e analisi statica.
  • ID: pmt-f3082c1b
  • Ambito: repo/area/file | Modalità: write
  • Cosa serve: configurazione del linter e perimetro dell'analisi
  • Esempio d'uso: configura il linter ed esegui l'analisi statica

🔭 DEV07 | Fai il triage di una segnalazione e riproducila, senza modificare il codice.
  • ID: pmt-9bd26aad
  • Ambito: repo/area | Modalità: read
  • Cosa serve: testo della segnalazione, ambiente e accesso in lettura al codice
  • Esempio d'uso: fai il triage e riproduci la segnalazione sul parsing dei percorsi

🔭 DEV08 | Rivedi leggibilità, coerenza e manutenibilità senza modificare il codice.
  • ID: pmt-b16674bd
  • Ambito: repo/area/file | Modalità: read
  • Cosa serve: codice da rivedere, convenzioni del repository e test esistenti
  • Esempio d'uso: rivedi leggibilità e manutenibilità del modulo di sincronizzazione

🔥 DEV12 | Sviluppa o rivedi una funzione LLM con valutazioni
  • ID: pmt-0715c64b
  • Ambito: repo | Modalità: write
  • Cosa serve: La funzione LLM o agente, modello e provider, comportamento atteso, casi di errore e input di esempio
  • Esempio d'uso: DEV12: aggiungi un set di valutazione al bot di supporto prima di cambiarne il prompt


TEST E VERIFICA
🔥 TST01 | Aggiungi test unitari e di integrazione per i rischi pertinenti.
  • ID: pmt-08bff671
  • Ambito: repo/area | Modalità: write
  • Cosa serve: infrastruttura di test e comportamento da verificare
  • Esempio d'uso: aggiungi test dei casi limite per il calcolo del budget

🔥 TST02 | Copri i percorsi utente con test end-to-end.
  • ID: pmt-286c3225
  • Ambito: repo/area | Modalità: write
  • Cosa serve: ambiente di test e flussi utente concordati
  • Esempio d'uso: crea un test end-to-end per il ciclo di backup e ripristino

🔥 TST03 | Trova e correggi i test instabili o non deterministici.
  • ID: pmt-91021b67
  • Ambito: repo/area | Modalità: write
  • Cosa serve: log dei fallimenti intermittenti e suite di test
  • Esempio d'uso: correggi l'instabilità dei test asincroni della suite

🔥 TST04 | Diagnostica e correggi i fallimenti di build e test in CI.
  • ID: pmt-bd98736f
  • Ambito: repo/area/file | Modalità: write
  • Cosa serve: log della CI e configurazione della pipeline
  • Esempio d'uso: correggi il fallimento del runner GitHub Actions su Windows

✅ TST05 | Verifica il comportamento reale rispetto ai requisiti.
  • ID: pmt-ef96dea5
  • Ambito: repo | Modalità: verify
  • Cosa serve: criteri di accettazione e un ambiente funzionante
  • Esempio d'uso: verifica che l'output sia conforme alle specifiche

🔥 TST06 | Misura e ottimizza prestazioni e risorse: un collo di bottiglia o molti moduli.
  • ID: pmt-9de57e24
  • Ambito: repo/area | Modalità: write
  • Cosa serve: flusso, carico rappresentativo, ambiente, metrica e soglia
  • Esempio d'uso: riduci i tempi di discovery degli host e l'uso di memoria

🔥 TST07 | Prepara un'infrastruttura di test con fixture isolate e pulizia sicura.
  • ID: pmt-37c695fe
  • Ambito: repo | Modalità: write
  • Cosa serve: framework di test, script di test e una radice di fixture isolata assegnata
  • Esempio d'uso: crea fixture isolate su disco e convalida la pulizia automatica

🔭 TST08 | Valuta la qualità dei test e individua le lacune
  • ID: pmt-de5f1d8d
  • Ambito: repo | Modalità: read
  • Cosa serve: Suite di test, report di copertura se esistono, percorsi critici e difetti recenti
  • Esempio d'uso: TST08: valuta i test del modulo fatturazione: lacune e asserzioni deboli


REVISIONE E SICUREZZA
🔭 SEC01 | Rivedi modifiche o codice con rilievi concreti e riferimenti.
  • ID: pmt-27896824
  • Ambito: repo | Modalità: read
  • Cosa serve: diff, commit o file da analizzare
  • Esempio d'uso: rivedi la pull request alla ricerca di fughe di dati

🔭 SEC02 | Analizza minacce, confini di fiducia e scenari di abuso.
  • ID: pmt-deb7d01a
  • Ambito: repo | Modalità: read
  • Cosa serve: architettura e flussi di dati verso l'esterno
  • Esempio d'uso: modello delle minacce dei flussi stdio e del file system locale

🔥 SEC03 | Correggi le vulnerabilità e rafforza le difese interessate.
  • ID: pmt-b4cb6659
  • Ambito: repo/area/file | Modalità: write
  • Cosa serve: vulnerabilità confermata e contesto del codice
  • Esempio d'uso: correggi il path traversal nella risoluzione dei percorsi

✅ SEC04 | Trova le credenziali esposte e verifica la validazione degli input.
  • ID: pmt-73fb4547
  • Ambito: repo | Modalità: verify
  • Cosa serve: working tree e strumenti di scansione
  • Esempio d'uso: esegui un audit di sicurezza delle credenziali

✅ SEC05 | Verifica l'isolamento dei dati personali e la conformità a GDPR e policy.
  • ID: pmt-24189cb6
  • Ambito: repo | Modalità: verify
  • Cosa serve: mappatura dei dati e policy di conformità
  • Esempio d'uso: verifica i dati personali e la conformità privacy GDPR

🔥 SEC06 | Rafforza configurazione del repository, CI, container e accessi.
  • ID: pmt-c356eede
  • Ambito: repo/area | Modalità: write
  • Cosa serve: configurazione, workflow CI, container e impostazioni del repository
  • Esempio d'uso: rafforza i workflow GitHub Actions e i container

✅ SEC07 | Verifica dati sensibili prima della pubblicazione, in locale e sul remoto
  • ID: pmt-058c474f
  • Ambito: repo | Modalità: verify
  • Cosa serve: Commit, indice, working tree e storia da pubblicare; destinazione e visibilità del remoto; strumenti di scansione disponibili
  • Esempio d'uso: SEC07: verifica i commit in uscita, e il remoto, alla ricerca di dati sensibili

⛔ SEC09 | Cancella cronologia e artefatti del remoto GitHub dopo un'esposizione di dati.
  • ID: pmt-7fc91f08
  • Ambito: repo | Modalità: write
  • Cosa serve: richiesta esplicita, backup verificato e accesso amministrativo al remoto
  • Esempio d'uso: cancella cronologia, run e cache del remoto dopo l'esposizione


AUDIT E METRICHE
🔭 AUD01 | Esegui un audit completo del repository con un unico rapporto, anche esportato.
  • ID: pmt-ccbf18b8
  • Ambito: repo/area | Modalità: read
  • Cosa serve: accesso in lettura a repository, documentazione e strumenti di misura
  • Esempio d'uso: audit completo del repository prima del rilascio

🔭 AUD02 | Misura il repository con metriche riproducibili e individua gli hotspot.
  • ID: pmt-4a9a4b4f
  • Ambito: repo/area | Modalità: read
  • Cosa serve: accesso in lettura a repository, cronologia Git e strumenti di misura
  • Esempio d'uso: metriche e hotspot del repository

🔭 AUD03 | Verifica architettura e debito tecnico non ancora tracciati.
  • ID: pmt-c692cc23
  • Ambito: repo/area | Modalità: read
  • Cosa serve: accesso in lettura a codice, backlog e documentazione di architettura
  • Esempio d'uso: audit di architettura e debito tecnico del repository

🔭 AUD04 | Verifica le dipendenze: obsolete, vulnerabili, inutilizzate e licenze.
  • ID: pmt-7dc63766
  • Ambito: repo/area | Modalità: read
  • Cosa serve: manifest, lock file e accesso ai registri dei pacchetti o agli avvisi
  • Esempio d'uso: audit delle dipendenze prima dell'aggiornamento

🔭 AUD05 | Verifica le prestazioni e trova i percorsi critici senza modificare il codice.
  • ID: pmt-4efbc54f
  • Ambito: repo/area | Modalità: read
  • Cosa serve: scenario di carico rappresentativo e strumenti di profilazione o misura
  • Esempio d'uso: trova i percorsi critici per tempo e memoria

🔭 AUD07 | Audit della pipeline CI/CD e della catena di fornitura
  • ID: pmt-6b494996
  • Ambito: repo | Modalità: read
  • Cosa serve: Definizioni della pipeline, permessi dei workflow, gestione dei segreti, azioni di terzi e processo di rilascio
  • Esempio d'uso: AUD07: verifica i workflow GitHub Actions: azioni non fissate e permessi eccessivi


INTERFACCIA ED ESPERIENZA UTENTE
🔭 INT01 | Valuta usabilità, coerenza e stati dei flussi utente.
  • ID: pmt-33216f62
  • Ambito: repo/area | Modalità: read
  • Cosa serve: applicazione eseguibile e flussi da esaminare
  • Esempio d'uso: valuta l'usabilità della procedura guidata di configurazione

🔥 INT02 | Implementa un'interfaccia seguendo requisiti e riferimenti.
  • ID: pmt-db55c30d
  • Ambito: repo/area | Modalità: write
  • Cosa serve: linee guida o mockup e componenti esistenti
  • Esempio d'uso: realizza la schermata di sincronizzazione

✅ INT03 | Verifica l'accessibilità e l'uso con tastiera e tecnologie assistive.
  • ID: pmt-2ea0c993
  • Ambito: repo/area | Modalità: verify
  • Cosa serve: interfaccia funzionante e standard di riferimento
  • Esempio d'uso: verifica la conformità ARIA e l'accessibilità

✅ INT04 | Verifica l'internazionalizzazione di stringhe, formati e traduzioni.
  • ID: pmt-805ca095
  • Ambito: repo/area | Modalità: verify
  • Cosa serve: interfaccia o messaggi con lingue e formati supportati
  • Esempio d'uso: verifica stringhe, formati e traduzioni della CLI

🔥 INT05 | Scrivi o rivedi testi dell'interfaccia e messaggi d'errore
  • ID: pmt-f3614e6a
  • Ambito: repo/file | Modalità: write
  • Cosa serve: Schermate o flussi, destinatari, tono, terminologia esistente e lingue supportate
  • Esempio d'uso: INT05: riscrivi gli errori del checkout in modo che ognuno dica cosa fare dopo


DATI E INTEGRAZIONI
🔥 DAT01 | Migra schema e dati con confronto verificabile e recupero.
  • ID: pmt-32e3cf59
  • Ambito: repo/area | Modalità: write
  • Cosa serve: schema di origine, schema di destinazione e dati sintetici
  • Esempio d'uso: migra lo schema con uno script di rollback atomico

🔥 DAT02 | Costruisci importazioni e trasformazioni che preservano gli originali.
  • ID: pmt-3ddd1df9
  • Ambito: repo/area | Modalità: write
  • Cosa serve: file di origine, modello di destinazione e regole di validazione
  • Esempio d'uso: importa il catalogo da CSV a JSON preservando gli originali

🔥 DAT03 | Integra servizi API con gestione degli errori e nuovi tentativi delle richieste.
  • ID: pmt-6b7b0e8d
  • Ambito: repo/area | Modalità: write
  • Cosa serve: documentazione dell'API, credenziali di prova e schema
  • Esempio d'uso: implementa un client REST con backoff esponenziale e nuovi tentativi

🔥 DAT04 | Ottimizza query e indici del database
  • ID: pmt-6b6c2ade
  • Ambito: repo | Modalità: write
  • Cosa serve: Query o endpoint lenti, schema, indici, piani di esecuzione e un database di prova sicuro
  • Esempio d'uso: DAT04: velocizza la query dell'elenco ordini senza cambiare i risultati


RILASCIO E OPERATIVITÀ
🔥 OPS01 | Prepara e verifica pacchetti e artefatti distribuibili.
  • ID: pmt-a5c78cc6
  • Ambito: repo | Modalità: write
  • Cosa serve: istruzioni di build e requisiti del pacchetto
  • Esempio d'uso: costruisci un archivio zip deterministico e calcola il suo SHA-256

🔥 OPS02 | Configura pipeline, container e infrastruttura come codice.
  • ID: pmt-ce00f261
  • Ambito: repo | Modalità: write
  • Cosa serve: requisiti di distribuzione e ambiente di destinazione
  • Esempio d'uso: configura un Dockerfile multi-stage per una build riproducibile

🔥 OPS03 | Aggiungi log, metriche e diagnostica utili al problema.
  • ID: pmt-c2785b9c
  • Ambito: repo/area/file | Modalità: write
  • Cosa serve: scenario da monitorare e standard di logging
  • Esempio d'uso: aggiungi il logging JSON strutturato

🔥 OPS04 | Prepara note di rilascio e controlli di consegna.
  • ID: pmt-0618969e
  • Ambito: repo | Modalità: write
  • Cosa serve: commit, segnalazioni o task completati dal rilascio precedente
  • Esempio d'uso: compila le note di rilascio della v1.1 da commit e segnalazioni

🔥 OPS05 | Prepara commit e pull request con perimetro, messaggio e controlli verificati.
  • ID: pmt-3e3728b6
  • Ambito: repo | Modalità: write
  • Cosa serve: modifiche locali da consegnare e richiesta esplicita di commit o PR
  • Esempio d'uso: prepara i commit e la descrizione della pull request

🔥 OPS06 | Prepara hotfix e rollback di un rilascio con verifica e comunicazione.
  • ID: pmt-b377d5f0
  • Ambito: repo | Modalità: write
  • Cosa serve: rilascio difettoso, versione precedente nota e criteri per tornare indietro
  • Esempio d'uso: prepara l'hotfix e il rollback per il rilascio 2.3.1

🔥 OPS07 | Scrivi un postmortem dell'incidente senza attribuire colpe
  • ID: pmt-28f4fbf5
  • Ambito: repo | Modalità: write
  • Cosa serve: Cronologia dell'incidente, impatto, log o allarmi, correzione applicata e persone coinvolte
  • Esempio d'uso: OPS07: scrivi il postmortem del blocco del checkout di ieri notte


DOCUMENTAZIONE
🔥 DOC01 | Scrivi guide e README coerenti con il prodotto reale.
  • ID: pmt-07430e8c
  • Ambito: repo | Modalità: write
  • Cosa serve: funzionalità implementate, comandi verificati e screenshot approvati
  • Esempio d'uso: aggiorna le guide e aggiungi diagrammi di flusso Mermaid

🔥 DOC02 | Documenta API e contratti a partire dall'implementazione.
  • ID: pmt-6e82e3a9
  • Ambito: repo/area | Modalità: write
  • Cosa serve: codice sorgente dei contratti e degli endpoint
  • Esempio d'uso: documenta i parametri e gli schemi di risposta degli endpoint

🔥 DOC03 | Cattura screenshot reali e prepara asset pubblici.
  • ID: pmt-75786fd6
  • Ambito: repo | Modalità: write
  • Cosa serve: interfaccia funzionante con dati sintetici
  • Esempio d'uso: cattura screenshot autentici dall'interfaccia reale

🔥 DOC04 | Scrivi o aggiorna un runbook operativo
  • ID: pmt-4b88488d
  • Ambito: repo | Modalità: write
  • Cosa serve: La procedura, i sistemi coinvolti, gli accessi necessari, i guasti possibili e un operatore che la validi
  • Esempio d'uso: DOC04: scrivi un runbook per ripristinare il database da backup


IGIENE DEL REPOSITORY
🔥 REP01 | Completa il prossimo task pronto del repository aperto.
  • ID: pmt-4cc383ba
  • Ambito: repo | Modalità: write
  • Cosa serve: task pianificato e criteri di accettazione
  • Esempio d'uso: esegui il prossimo task prioritario che si può fare in autonomia

⛔ REP04 | Rimuovi residui e codice inutilizzato dopo la verifica.
  • ID: pmt-40772e6e
  • Ambito: repo/area | Modalità: write
  • Cosa serve: prova dell'assenza di riferimenti e test verdi
  • Esempio d'uso: rimuovi i file temporanei e le cache di build orfane

🔭 REP08 | Ispeziona il repo e trova i task residui rispetto al codice reale.
  • ID: pmt-cc2c5f5a
  • Ambito: repo/area | Modalità: read
  • Cosa serve: working tree, cronologia recente ed eventuale backlog o note
  • Esempio d'uso: ispeziona il repo e rileva i task residui

🔥 REP10 | Allinea .gitignore e .gitkeep alla struttura e ai file reali.
  • ID: pmt-f1df8757
  • Ambito: repo | Modalità: write
  • Cosa serve: stato Git, regole di esclusione e cartelle da preservare nel repository
  • Esempio d'uso: allinea gitignore e gitkeep prima di pubblicare

🔥 REP11 | Segnala un errore come issue GitHub nel formato del form, dopo conferma.
  • ID: pmt-fe68329a
  • Ambito: repo | Modalità: write
  • Cosa serve: errore osservato, passi di riproduzione, versione e `gh` autenticato
  • Esempio d'uso: segnala questo errore di build come issue GitHub

🔥 REP12 | Consolida i branch con merge --no-ff ed elimina quelli integrati.
  • ID: pmt-fabd3439
  • Ambito: repo | Modalità: write
  • Cosa serve: branch locali e remoti, ramo base e working tree pulito
  • Esempio d'uso: consolida i branch conclusi in master

🔥 REP13 | Allinea pagina GitHub, file della community e sicurezza, dopo conferma.
  • ID: pmt-3e2e75f6
  • Ambito: repo | Modalità: write
  • Cosa serve: `gh` con diritti di amministratore ed esito di SEC07
  • Esempio d'uso: rendi trovabile questo repository e applica la sicurezza standard

🔭 REP14 | Smista le issue e le pull request aperte
  • ID: pmt-f8dd6843
  • Ambito: repo | Modalità: read
  • Cosa serve: Repository GitHub con gh autenticato, etichette, regole del progetto, età e attività di issue e PR
  • Esempio d'uso: REP14: smista issue e PR aperte e proponi etichette e chiusure


GOVERNANCE, LICENZE E CONFORMITÀ
✅ GOV01 | Verifica le licenze open source, la conformità dei file e le intestazioni SPDX.
  • ID: pmt-313da996
  • Ambito: repo | Modalità: verify
  • Cosa serve: albero dei sorgenti e file di licenza
  • Esempio d'uso: verifica la licenza MIT e che le intestazioni SPDX corrispondano

🔥 GOV02 | Analizza le dipendenze di terze parti e compila il registro CREDITS.
  • ID: pmt-adb9bfc0
  • Ambito: repo | Modalità: write
  • Cosa serve: lock file delle dipendenze e licenze di terze parti
  • Esempio d'uso: analizza le dipendenze di terze parti e compila CREDITS.md


MEMORIA E CONTINUITÀ
🔥 MEM01 | Allinea istruzioni locali, contesto, memoria e tracker.
  • ID: pmt-f02db9d0
  • Ambito: repo/area | Modalità: write
  • Cosa serve: decisioni o modifiche recenti non registrate
  • Esempio d'uso: sb prompt MEM01: allinea context.md e memory.md dopo completamento task

🔥 MEM02 | Migra progettazione e attività nel dossier SecondBrain.
  • ID: pmt-64dfa49f
  • Ambito: repo/area | Modalità: write
  • Cosa serve: documentazione storica o issue esterne da migrare
  • Esempio d'uso: sb prompt MEM02: migra todo sparsi nel tracker centralizzato del dossier

🔥 MEM03 | Chiudi la sessione: memorie, tracker, handoff e richiesta di commit e push.
  • ID: pmt-76604e4a
  • Ambito: repo/area | Modalità: write
  • Cosa serve: stato del lavoro svolto, task successivi definiti e destinazione di consegna
  • Esempio d'uso: sb prompt MEM03: chiudi la sessione e chiedi commit e push

🔭 MEM04 | Elenca e descrivi le attività del tracker e i problemi che risolvono.
  • ID: pmt-23c3d2be
  • Ambito: repo/area | Modalità: read
  • Cosa serve: tracker del dossier di repository
  • Esempio d'uso: sb prompt MEM04: elenca attivita e problemi del tracker

🔥 MEM05 | Crea, aggiorna e archivia progetti, aree e risorse del PARA centrale.
  • ID: pmt-4e1b7c52
  • Ambito: central | Modalità: write
  • Cosa serve: obiettivo dell'entità PARA e sessione di scrittura sul clone SecondBrain
  • Esempio d'uso: sb prompt MEM05: archivia la risorsa conclusa res-guida

🔭 MEM06 | Leggi memoria attiva, contesto e tracker del repository corrente.
  • ID: pmt-821f7dec
  • Ambito: repo | Modalità: read
  • Cosa serve: checkout del repository aperto
  • Esempio d'uso: sb prompt MEM06: carica contesto e memoria del repository nel budget


SISTEMA E MANUTENZIONE CENTRALE
✅ SYS01 | Verifica gli IDE; mappa, registra account o riallinea su richiesta.
  • ID: pmt-26817a61
  • Ambito: central | Modalità: verify
  • Cosa serve: installazioni IDE e autorizzazioni locali; per registrare account anche postazione attivata e consenso
  • Esempio d'uso: sb prompt SYS01: registra un ide con due account o due radici

✅ SYS02 | Verifica le fonti autorevoli; acquisisci o aggiorna su richiesta.
  • ID: pmt-5b593404
  • Ambito: central | Modalità: verify
  • Cosa serve: registro PARA resource-authoritative-sources
  • Esempio d'uso: sb prompt SYS02: verifica aggiornamenti normativi nel registro fonti

🔥 SYS03 | Attiva SecondBrain dopo discovery e selezione degli asset.
  • ID: pmt-5f9f93e0
  • Ambito: central | Modalità: write
  • Cosa serve: volume SecondBrain e consenso utente sugli asset
  • Esempio d'uso: sb prompt SYS03: attiva secondbrain selezionando repository e ide locali

✅ SYS04 | Controlla o allinea gli asset già gestiti della postazione.
  • ID: pmt-677a10ab
  • Ambito: central | Modalità: verify
  • Cosa serve: configurazione postazione e direttive approvate
  • Esempio d'uso: sb prompt SYS04: verifica allineamento direttive nei repository gestiti

🔥 SYS05 | Compatta il dossier preservando originali, fatti e TOC.
  • ID: pmt-77d7bf7a
  • Ambito: central | Modalità: write
  • Cosa serve: dossier da compattare e storico verificabile
  • Esempio d'uso: sb prompt SYS05: compatta cronologia del dossier preservando fatti e toc

🔥 SYS09 | Esegui il backup compresso deterministico e verifica i digest SHA-256.
  • ID: pmt-e498353a
  • Ambito: central | Modalità: write
  • Cosa serve: configurazione attiva e root runtime di backup
  • Esempio d'uso: sb prompt SYS09: esegui backup deterministico e valida il manifest sha-256

⛔ SYS10 | Esegui rollback e dismissione repository restituendo i dati per privacy.
  • ID: pmt-b98acaaa
  • Ambito: central | Modalità: write
  • Cosa serve: dossier del repository, checkout di destinazione e consenso utente
  • Esempio d'uso: sb prompt SYS10: esegui rollback del repository dismesso e pulisci i dati

🔥 SYS11 | Aggiungi, modifica o rimuovi un prompt del catalogo centralizzato.
  • ID: pmt-364616bb
  • Ambito: central | Modalità: write
  • Cosa serve: catalogo valido, area di destinazione e sessione di scrittura
  • Esempio d'uso: sb prompt SYS11: aggiungi un prompt al catalogo nell'area test

🔥 SYS13 | Fissa o rimuovi il blocco greenfield (versioni, changelog, migrazioni, alias).
  • ID: pmt-29b3278f
  • Ambito: repo/area | Modalità: write
  • Cosa serve: repository gestito, dossier attivo e conferma dell'utente
  • Esempio d'uso: sb prompt SYS13: fissa o rimuovi il blocco greenfield su questo repository

🔥 SYS15 | Installa il server MCP SecondBrain negli IDE e verifica l'handshake.
  • ID: pmt-2d3c1d51
  • Ambito: central | Modalità: write
  • Cosa serve: radice SecondBrain, IDE di destinazione e conferma prima di scrivere
  • Esempio d'uso: sb prompt SYS15: installa il server mcp in vscode e claude code

🔥 SYS16 | Aggiorna una skill da fonti autorevoli e verifica il diff.
  • ID: pmt-9ef61b3d
  • Ambito: central | Modalità: write
  • Cosa serve: skill identificata, agente e versione di destinazione, fonti ufficiali
  • Esempio d'uso: sb prompt SYS16: aggiorna la skill locale dalle fonti ufficiali

```
