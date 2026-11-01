# DAT01 — Migra schema e dati con confronto e recupero verificabili

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: schema corrente, schema di destinazione e dati reali | **Esempio d'uso**: `sb prompt DAT01: migra schema del tracker con script di rollback atomico`

## Scopo

Eseguire una trasformazione dei dati senza perdere informazione necessaria.

## Quando usarlo

Per evoluzioni di schema, cambi di motore o migrazioni di formati persistiti.

## Input

Sorgente, destinazione, volumi, semantica, vincoli e ambiente autorizzato.

## Attività specifiche

Censisci dati e consumatori; verifica backup e recupero prima delle mutazioni. Definisci trasformazioni, idempotenza o ripresa, compatibilità e confronto. Prova prima su copia isolata e gestisci cambi concorrenti senza sovrascriverli.

## Verifiche

Confronta conteggi, chiavi, relazioni, valori significativi e casi limite; prova il recupero. Non migrare ambienti ulteriori per implicazione.

## Consegna

Manifest o evidenze proporzionate, trasformazioni, confronto, recupero provato e residui.

## Prompt vicini

- PRG03: Progetta contratti API, modelli dati e compatibilità.
- DAT02: Realizza importazioni e trasformazioni preservando gli originali.
