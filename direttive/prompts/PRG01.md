# PRG01 — Trasforma una richiesta in requisiti e criteri di accettazione

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: richiesta utente e documentazione esistente | **Esempio d'uso**: `sb prompt PRG01: definisci criteri di accettazione per la ricerca full-text`

## Scopo

Rendere una richiesta verificabile e sufficientemente precisa per progettare.

## Quando usarlo

Per funzionalità ancora ambigue o richieste basate su feedback degli utenti.

## Input

Esigenza, utenti, esempi, vincoli e informazioni già disponibili.

## Attività specifiche

Separa problema, risultato desiderato e soluzione ipotizzata. Definisci scenari positivi, negativi e limite, confini e requisiti non funzionali rilevanti. Chiarisci solo le ambiguità che cambiano la soluzione, preferendo Function Calling o Tool Use (es. `ask_question`) per sottoporre scelte definite all'utente.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- ambiguità dei requisiti che cambiano la soluzione;
- scenari e requisiti non funzionali da includere (scelta multipla);
- confini del lavoro e criteri di accettazione.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Associa a ogni requisito un criterio osservabile; evita obiettivi inventati e soglie arbitrarie.

## Consegna

Requisiti, criteri di accettazione, esclusioni e domande residue. Salva nel tracker solo se richiesto.

## Prompt vicini

- PRG02: Confronta soluzioni architetturali e motiva una decisione.
- PRG04: Prepara un piano per fasi con dipendenze e verifiche.
