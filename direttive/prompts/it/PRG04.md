# PRG04 — Prepara un piano a fasi con dipendenze e controlli

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: requisiti concordati e perimetro del lavoro | **Esempio d'uso**: `pianifica la migrazione in tre rilasci atomici`

## Scopo

Preparare un piano praticabile senza lasciare impliciti le decisioni sostanziali.

## Quando usarlo

Per lavori complessi, modifiche multiple o una ripresa pianificata.

## Input

Obiettivo, perimetro autorizzato, stato attuale e criteri di completamento.

## Attività specifiche

Esplora il codice prima di pianificare. Definisci fasi ordinate, prerequisiti, interfacce, rischi, controlli e condizioni di recupero proporzionate. Chiarisci le scelte sostanziali non deducibili dai file.

## Verifiche

Verifica che ogni fase contribuisca all'obiettivo e abbia un esito verificabile. Non implementare e non aggiornare il backlog se non esplicitamente richiesto.

## Consegna

Piano completo con dipendenze, criteri di accettazione, ipotesi e limiti.

## Prompt vicini

- PRG01: Trasforma una richiesta in requisiti e criteri di accettazione.
- PRG05: Crea l'impalcatura di nuovi moduli con struttura, configurazione e test.
- REP01: Completa il prossimo task pronto del repository aperto.
- PRG06: Pianifica un refactoring architetturale a fasi con controlli e rollback.
