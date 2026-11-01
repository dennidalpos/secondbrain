# AUD06 — Esporta rapporti e metriche nel formato scelto dall’utente

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: risultati già verificati di audit, metriche o verifiche e formato di uscita | **Esempio d'uso**: `sb prompt AUD06: esporta i rilievi dell’audit in SARIF e in HTML`

## Scopo

Trasformare risultati già verificati di audit, metriche e verifiche in un rapporto nel formato richiesto dall’utente.

## Quando usarlo

Dopo AUD01-AUD05, SEC01, SEC04, REP05 o qualunque analisi da condividere o archiviare.

## Input

Risultati verificati, destinatari, formato di uscita e destinazione.

## Attività specifiche

Chiedi formato e destinazione a ogni esecuzione. Formati: Markdown, JSON, HTML autonomo, CSV (tabelle di rilievi e metriche), SARIF 2.1.0 (rilievi di analisi), DOCX, PDF e XLSX con gli strumenti o le competenze disponibili nell’IDE. Parti da una struttura dati unica (rilievi con identificativo, gravità, percorso, riga, prova e stato; metriche con metodo e data) da cui derivare ogni formato, senza reinterpretare i risultati. Salva gli output operativi sotto `SecondBrain/.runtime` in una cartella dedicata al rapporto e non nel repository prodotto; pubblicali solo su richiesta esplicita e dopo REP05. Non includere segreti, valori sensibili o percorsi privati: riporta hash e posizioni.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- formato o formati di uscita (scelta multipla);
- destinazione del file;
- gravità minima dei rilievi da includere.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Apri o valida il file prodotto (schema JSON o SARIF, righe e colonne del CSV, apertura del documento), confronta i conteggi con la fonte e dichiara i formati non verificabili nell’ambiente. Non sovrascrivere rapporti esistenti: crea una nuova versione datata.

## Consegna

File nel formato scelto, percorso, conteggi e limiti della conversione.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto.
- AUD02: Misura il repository con metriche riproducibili e individua i punti critici.
- SEC01: Revisiona modifiche o codice con rilievi concreti e riferimenti.
