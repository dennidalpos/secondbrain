# DEV05 — Migra codice o un framework verso un obiettivo definito

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: versioni di origine e di destinazione con note di rilascio | **Esempio d'uso**: `migra gli script dalla vecchia versione del runtime a quella corrente`

## Scopo

Spostare un'area di codice verso una tecnologia o una versione concordata.

## Quando usarlo

Per una modernizzazione strutturale che va oltre il normale aggiornamento di un pacchetto.

## Input

Origine, destinazione, motivazione, compatibilità e vincoli di rilascio.

## Attività specifiche

Inventaria API deprecate, integrazioni e differenze semantiche. Usa le guide ufficiali della destinazione, migra per unità verificabili e rimuovi il percorso sostituito dopo aver verificato i consumatori. Mantieni un'opzione di recupero proporzionata.

## Verifiche

Confronta funzionalità e contratti con una baseline; esegui build e test pertinenti dichiarando le piattaforme non provate.

## Consegna

Unità migrate, differenze intenzionali, evidenze e passi ancora necessari.

## Prompt vicini

- DAT01: Migra schema e dati con confronto verificabile e recupero.
- DEV04: Aggiorna le dipendenze verificando compatibilità e regressioni.
