# DOC02 — Documenta API e contratti a partire dall'implementazione

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: codice sorgente dei contratti e degli endpoint | **Esempio d'uso**: `documenta i parametri e gli schemi di risposta degli endpoint`

## Scopo

Descrivere fedelmente l'interfaccia esposta ai consumatori.

## Quando usarlo

Per la documentazione di endpoint, librerie, CLI o formati pubblici.

## Input

Interfacce, consumatori, versione e formato di documentazione già in uso.

## Attività specifiche

Ricava firme, input, output, errori, autenticazione e compatibilità dal codice. Usa esempi realistici senza dati sensibili; genera specifiche leggibili da macchina solo nel formato e nella versione adatti al progetto.

## Verifiche

Confronta esempi e schemi con l'implementazione e con i test di contratto; esegui il validatore se esiste. Segnala le discrepanze senza cambiare arbitrariamente il comportamento.

## Consegna

Documentazione e specifiche verificabili, esempi e le differenze ancora da chiarire.

## Prompt vicini

- PRG03: Progetta contratti API, modelli di dati e compatibilità.
- DOC01: Scrivi guide e README coerenti con il prodotto reale.
