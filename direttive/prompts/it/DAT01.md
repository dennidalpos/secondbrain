# DAT01 — Migra schema e dati con confronto verificabile e recupero

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: schema di origine, schema di destinazione e dati sintetici | **Esempio d'uso**: `migra lo schema con uno script di rollback atomico`

## Scopo

Eseguire una trasformazione dei dati senza perdere informazioni necessarie.

## Quando usarlo

Per l'evoluzione dello schema, il cambio di motore o la migrazione di formati persistiti.

## Input

Origine, destinazione, volumi, semantica, vincoli e l'ambiente autorizzato.

## Attività specifiche

Inventaria dati e consumatori; verifica backup e recupero prima di ogni modifica. Definisci trasformazioni, idempotenza o ripresa, compatibilità e confronto. Prova prima su una copia isolata e gestisci le modifiche concorrenti senza sovrascriverle.

## Verifiche

Confronta conteggi, chiavi, relazioni, valori significativi e casi limite; prova il recupero. Non migrare altri ambienti per implicazione.

## Consegna

Manifest o evidenze proporzionate, trasformazioni, confronto, recupero provato e residui.

## Prompt vicini

- DAT02: Costruisci importazioni e trasformazioni che preservano gli originali.
- PRG03: Progetta contratti API, modelli di dati e compatibilità.
