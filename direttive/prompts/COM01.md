# COM01 — Esplora il repository e individua componenti e comandi principali

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: accesso in lettura al repository e shell | **Esempio d'uso**: `sb prompt COM01: esplora struttura e moduli principali`

## Scopo

Ottenere una mappa iniziale utile a lavorare nel repository.

## Quando usarlo

All’ingresso in un prodotto o in una sua area poco conosciuta.

## Input

Repository o area di interesse; domanda che motiva l’esplorazione.

## Attività specifiche

Individua entrypoint, manifest, moduli, persistenza e test. Segui le istruzioni locali e verifica i comandi nei file reali. Collega i componenti alle responsabilità senza elencare indiscriminatamente ogni file. Se emergono percorsi alternativi da esplorare, presentali tramite Function Calling o Tool Use (es. `ask_question`).

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- componenti o percorsi alternativi da approfondire (scelta multipla);
- profondità dell'esplorazione e destinazione del rapporto.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Controlla che comandi e percorsi citati esistano; distingui architettura osservata e ipotesi. Non avviare setup o build per sola curiosità.

## Consegna

Mappa sintetica, punti di ingresso, rischi iniziali e prossimi file da leggere.

## Prompt vicini

- COM02: Ricostruisci un flusso e le sue dipendenze nel codice.
- COM04: Valuta impatto, rischi e dipendenze di una modifica.
