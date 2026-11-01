# DEV03 — Esegui un refactoring preservando contratti e comportamento

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: codice da migliorare e test esistenti | **Esempio d'uso**: `sb prompt DEV03: estrai modulo per la gestione transazioni para`

## Scopo

Ridurre complessità senza cambiare il comportamento richiesto.

## Quando usarlo

Per duplicazioni, responsabilità confuse o componenti difficili da mantenere.

## Input

Area, obiettivo di semplificazione e invarianti osservabili.

## Attività specifiche

Individua chiamanti, dipendenze e copertura. Semplifica con passi piccoli; rimuovi componenti sostituiti soltanto dopo ricerca dei riferimenti. Evita di mescolare modifiche funzionali non richieste.

## Verifiche

Confronta contratti e risultati prima/dopo; esegui i test pertinenti e segnala invarianti non coperti.

## Consegna

Semplificazioni realizzate, contratti preservati e prove di equivalenza disponibili.

## Prompt vicini

- DEV05: Migra codice o framework verso una destinazione definita.
- REP04: Rimuovi residui e codice inutilizzato dopo le verifiche.
- DEV09: Consolida e rendi leggibile il codice a fasi preservando il comportamento.
- DEV10: Ottimizza il codice sull’intero perimetro con misure prima e dopo.
