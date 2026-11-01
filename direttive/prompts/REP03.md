# REP03 — Documenta API e contratti a partire dall’implementazione

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: codice dei controller o handler e contratti dati | **Esempio d'uso**: `sb prompt REP03: documenta parametri e schema risposte degli endpoint`

## Scopo

Descrivere fedelmente l’interfaccia esposta ai consumatori.

## Quando usarlo

Per documentazione di endpoint, librerie, CLI o formati pubblici.

## Input

Interfacce, consumatori, versione e formato documentale già usato.

## Attività specifiche

Ricava firme, input, output, errori, autenticazione e compatibilità dal codice. Usa esempi realistici senza dati sensibili; genera specifiche machine-readable soltanto nel formato/versione appropriati al progetto.

## Verifiche

Confronta esempi e schemi con implementazione e test di contratto; esegui il validatore presente. Segnala discrepanze senza cambiarne arbitrariamente il comportamento.

## Consegna

Documentazione e specifiche verificabili, esempi e differenze ancora da chiarire.

## Prompt vicini

- PRG03: Progetta contratti API, modelli dati e compatibilità.
- REP02: Scrivi guide e README coerenti con il prodotto reale.
