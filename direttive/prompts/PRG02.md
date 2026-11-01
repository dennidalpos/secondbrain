# PRG02 — Confronta soluzioni architetturali e motiva una decisione

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: alternative da valutare e vincoli di progetto | **Esempio d'uso**: `sb prompt PRG02: confronta sqlite vs json per la persistenza locale`

## Scopo

Scegliere un approccio compatibile con architettura e vincoli reali.

## Quando usarlo

Quando esistono alternative con differenze sostanziali di costo, rischio o manutenzione.

## Input

Problema, criteri di successo, vincoli e componenti coinvolti.

## Attività specifiche

Descrivi alternative praticabili, incluso il riuso dell’esistente. Confronta compromessi, dipendenze, reversibilità e conseguenze operative. Consulta fonti ufficiali quando la scelta dipende dalle capacità di una tecnologia. Presenta le scelte o raccogli la decisione finale tramite Function Calling o Tool Use (es. `ask_question`).

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- alternativa architetturale da adottare tra quelle confrontate;
- compromessi accettati (scelta multipla) e conferma finale della decisione.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Verifica assunzioni contro codice e versioni; distingui fatti, stime e preferenze. Non introdurre una nuova architettura per convenzione.

## Consegna

Decisione proposta con motivazione, alternative scartate e condizioni che la farebbero rivedere; nessuna scrittura implicita di ADR.

## Prompt vicini

- COM04: Valuta impatto, rischi e dipendenze di una modifica.
- PRG03: Progetta contratti API, modelli dati e compatibilità.
- PRG05: Crea lo scaffolding di nuovi moduli con struttura, configurazione e test.
