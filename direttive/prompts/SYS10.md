# SYS10 — Esegui rollback e dismissione repository restituendo i dati per privacy

> **Scope**: central | **Modalità**: scrittura | **Cosa serve**: dossier del repository, checkout di destinazione e consenso utente | **Esempio d'uso**: `sb prompt SYS10: esegui rollback del repository dismesso e pulisci i dati`

## Scopo

Restituire tutta la conoscenza e i dati archiviati in SecondBrain al repository di competenza, eliminando ogni residuo centrale per la massima tutela della privacy e tracciando il repository come vietato.

## Quando usarlo

Su richiesta esplicita dell'utente per dismettere, vietare o revocare un repository dal perimetro di SecondBrain senza alcuna perdita di informazione.

## Input

Identificativo o percorso del repository, dossierPARA associato, percorso del checkout target e conferma esplicita dell'utente.

## Attività specifiche

Verifica la raggiungibilità del checkout del repository. Crea all'interno del repository di destinazione la cartella protetta `.secondbrain/` e trasferisci al suo interno `brief.md`, `context.md`, `memory.md`, `tracker.json`, `history/` e metadati. Se presente, rimuovi il blocco gestito SecondBrain da `AGENTS.md` del repository per eliminare ogni accoppiamento.

Rimuovi integralmente la cartella del dossier da `02-areas/products/`. Pulisci i dati transitori e di ambiente in `.runtime`. Aggiorna la configurazione della postazione (`workstation.json`): rimuovi il repository dai binding attivi e registralo in `forbiddenRepositories` per impedirne future inclusioni automatiche. Infine, invoca `Update-SBParaIndex` per rigenerare `para-index.json` e `PARA.md`.

## Verifiche

Accerta che tutti i file di conoscenza siano stati trasposti nel repository di competenza in `.secondbrain/`. Controlla che `AGENTS.md` sia pulito e non contenga marcatori gestiti. Verifica che la cartella del dossier in SecondBrain sia inesistente e che l'indice PARA non contenga riferimenti orfani. Verifica che `secondbrain.ps1 -Check` non segnali il repository.

## Consegna

Rapporto di dismissione con percorsi coinvolti, elenco file trasferiti, conferma rimozione dossier centrale e registrazione nella lista dei repository vietati.

## Prompt vicini

- SYS03: Attiva SecondBrain dopo discovery e selezione degli asset.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
- SYS05: Compatta il dossier preservando originali, fatti e TOC.
