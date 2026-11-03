# PRG02 — Confronta le opzioni architetturali e motiva una decisione

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: alternative da valutare e vincoli del progetto | **Esempio d'uso**: `confronta SQLite e JSON per la persistenza locale`

## Scopo

Scegliere un approccio compatibile con l'architettura reale e con i vincoli.

## Quando usarlo

Quando ci sono alternative con differenze sostanziali di costo, rischio o manutenzione.

## Input

Problema, criteri di successo, vincoli e componenti coinvolti.

## Attività specifiche

Descrivi le alternative praticabili, compreso il riuso di ciò che esiste. Confronta compromessi, dipendenze, reversibilità e conseguenze operative. Consulta fonti ufficiali quando la scelta dipende dalle capacità di una tecnologia. Presenta le scelte e raccogli la decisione finale come opzioni definite.

## Decisioni da raccogliere

- alternativa architetturale da adottare tra quelle confrontate;
- compromessi accettati (scelta multipla) e conferma finale della decisione.

## Verifiche

Verifica le ipotesi su codice e versioni; distingui fatti, stime e preferenze. Non introdurre una nuova architettura per convenzione.

## Consegna

Decisione proposta con la motivazione, alternative scartate e le condizioni che la farebbero rivedere; nessuna scrittura implicita di registri delle decisioni.

## Prompt vicini

- COM04: Valuta impatto, rischi e dipendenze di una modifica.
- PRG03: Progetta contratti API, modelli di dati e compatibilità.
- PRG05: Crea l'impalcatura di nuovi moduli con struttura, configurazione e test.
