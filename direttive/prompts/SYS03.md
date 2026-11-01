# SYS03 — Attiva SecondBrain dopo discovery e selezione degli asset

> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: discovery completata e conferma esplicita utente | **Esempio d'uso**: `sb prompt SYS03: attiva secondbrain selezionando repository e ide locali`

## Scopo

Preparare una postazione Windows nuova o riconciliare i suoi asset senza percorsi preimpostati.

## Quando usarlo

Da SecondBrain, anche prima della configurazione locale; richiamo esplicito sb attiva.

## Input

Checkout SecondBrain corrente, prerequisiti, rapporto discovery e scelta effettiva dell’utente.

## Attività specifiche

Ricava la radice dal checkout e usa lo script guidato secondbrain.ps1 -Setup: è il percorso principale, l'agente non scrive selection.json a mano. Primo passo senza -Select: esegue preflight (PowerShell, git, .runtime scrivibile, shared.json, direttive approvate) e discovery (senza -Roots tutti i volumi fissi), salva rapporto e selezione per host in .runtime/hosts/<id>/ e termina come proposta (exit 1, confirmed=false). Mostra copertura, repo, checkout, IDE/profili e ambienti separati. Non trattare dati trovati come autorizzazioni. Chiedi quali asset gestire e presenta le modifiche concrete; se l'ambiente supporta Function Calling o Tool Use (es. `ask_question`), usalo per presentare la selezione degli asset in una finestra di scelta multipla interattiva. Rilancia lo stesso script in modo non interattivo con -Roots, -Select (id, nome o percorso, separati da virgola) ed eventuali -Ides, -ApproveExistingBlocks dopo revisione dei blocchi gestiti; aggiungi -Yes soltanto dopo la conferma dell'utente, che registra utente, host e data nella selezione. Senza -Apply esegue l'anteprima; -Apply soltanto per il perimetro confermato. Escludi tassativamente repository vietati e progetti esterni. Nei dossier generati applica la regola di sintesi minima (operazioni chiave, zero verbosità). Individua tracker e memorie da migrare; non sostituire una fonte esistente con un tracker vuoto. -Apply registra SECONDBRAIN_HOME (-NoRegisterEnvironment per prove); la distribuzione delle direttive resta separata (-Sync, o -AndSync dopo il controllo). Le primitive -Discover e -Activate -SelectionPath restano disponibili; non installare monitor. I testi 4.0 non approvati restano candidati.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- repository da gestire (scelta multipla) e radici da esaminare;
- integrazioni IDE o agent da associare, con profilo e account (scelta multipla);
- blocchi gestiti esistenti da approvare e conferma finale prima di `-Yes` e `-Apply`.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Verifica fingerprint, hash precedenti, esclusioni, backup, ripresa e identità. Non inizializzare altri repo. Distingui metadati attivati, direttive distribuite, output build da qualificare e caricamento effettivo.

## Consegna

Rapporto locale, selezione, asset gestiti e passi manuali o impedimenti. Nessun commit o push implicito.

## Prompt vicini

- SYS01: Verifica gli IDE; mappa o riallinea su richiesta.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
