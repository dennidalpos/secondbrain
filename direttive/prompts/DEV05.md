# DEV05 — Migra codice o framework verso una destinazione definita

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: versione sorgente e destinazione con note di rilascio | **Esempio d'uso**: `sb prompt DEV05: migra script da Windows PowerShell 5.1 a PowerShell 7.5`

## Scopo

Trasferire un’area di codice a una tecnologia o versione concordata.

## Quando usarlo

Per modernizzazione strutturale che supera un normale aggiornamento pacchetti.

## Input

Sorgente, destinazione, motivazione, compatibilità e vincoli di rilascio.

## Attività specifiche

Censisci API deprecate, integrazioni e differenze semantiche. Usa guide ufficiali della destinazione, migra per unità verificabili e rimuovi il percorso sostituito dopo controllo dei consumatori. Conserva un recupero proporzionato.

## Verifiche

Confronta funzionalità e contratti con baseline; esegui build e test interessati, dichiarando piattaforme non provate.

## Consegna

Unità migrate, differenze intenzionali, prove e passaggi ancora necessari.

## Prompt vicini

- DEV04: Aggiorna dipendenze verificando compatibilità e regressioni.
- DAT01: Migra schema e dati con confronto e recupero verificabili.
