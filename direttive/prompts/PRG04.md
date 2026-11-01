# PRG04 — Prepara un piano per fasi con dipendenze e verifiche

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: obiettivi del lotto e mappa delle dipendenze | **Esempio d'uso**: `sb prompt PRG04: pianifica la migrazione in tre rilasci atomici`

## Scopo

Preparare un piano attuabile senza lasciare decisioni sostanziali implicite.

## Quando usarlo

Per lavoro complesso, interventi multipli o una ripresa programmata.

## Input

Obiettivo, perimetro autorizzato, stato corrente e criteri di completamento.

## Attività specifiche

Esplora il codice prima di pianificare. Definisci fasi ordinate, prerequisiti, interfacce, rischi, verifiche e condizioni di recupero proporzionate. Chiarisci scelte sostanziali non deducibili dai file.

## Verifiche

Controlla che ogni fase contribuisca all’obiettivo e abbia un esito verificabile. Non implementare e non aggiornare il tracker salvo richiesta esplicita.

## Consegna

Piano completo con dipendenze, criteri di accettazione, assunzioni e limiti.

## Prompt vicini

- PRG01: Trasforma una richiesta in requisiti e criteri di accettazione.
- REP01: Completa il prossimo task eseguibile del repository aperto.
- PRG05: Crea lo scaffolding di nuovi moduli con struttura, configurazione e test.
- PRG06: Pianifica un refactoring architetturale a fasi con verifiche e rollback.
