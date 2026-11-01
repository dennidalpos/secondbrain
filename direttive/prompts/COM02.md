# COM02 — Ricostruisci un flusso e le sue dipendenze nel codice

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: punto di ingresso o scenario da tracciare | **Esempio d'uso**: `sb prompt COM02: ricostruisci il flusso di autenticazione e sessioni`

## Scopo

Spiegare il percorso effettivo di una richiesta, evento o dato.

## Quando usarlo

Quando serve comprendere un comportamento preciso prima di intervenire.

## Input

Evento iniziale, operazione o sintomo; risultato di cui ricostruire l’origine.

## Attività specifiche

Segui chiamanti e chiamati dal punto d’ingresso fino agli effetti. Individua validazioni, autorizzazioni, trasformazioni, errori, confini asincroni e dipendenze esterne. Evidenzia responsabilità e punti in cui cambia lo stato. Se emergono bivi o scenari alternativi su cui raccogliere indicazioni, presentali tramite Function Calling o Tool Use (es. `ask_question`).

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- flusso o scenario alternativo da seguire quando il punto d'ingresso ha più rami;
- confini (asincroni, esterni) da includere nella traccia (scelta multipla).

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Verifica ogni passaggio contro simboli e riferimenti reali; separa i rami possibili da quelli osservati a runtime.

## Consegna

Sequenza del flusso con riferimenti puntuali e diagramma soltanto se chiarisce le relazioni.

## Prompt vicini

- COM01: Esplora il repository e individua componenti e comandi principali.
- DEV02: Riproduci un difetto e correggine la causa.
