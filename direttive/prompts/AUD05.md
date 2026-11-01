# AUD05 — Audita le prestazioni e individua i percorsi critici senza modificare il codice

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: scenario di carico rappresentativo e strumenti di profilo o di misura | **Esempio d'uso**: `sb prompt AUD05: individua i percorsi critici per tempo e memoria`

## Scopo

Individuare con misure i percorsi che dominano tempo, memoria e I/O, prima di ottimizzare.

## Quando usarlo

Prima di TST06 o DEV10, quando mancano misure o l’obiettivo non è definito.

## Input

Flussi significativi, carico rappresentativo, ambiente e obiettivi o soglie, se esistono.

## Attività specifiche

Definisci scenari e metriche (latenza, throughput, memoria, I/O, avvio), acquisisci baseline ripetute e profilo con gli strumenti del progetto o della piattaforma. Individua percorsi dominanti, lavoro ripetuto, chiamate di I/O o di rete evitabili, strutture dati inadatte, avvio lento, crescita di memoria e rischi di scala (complessità superlineare).

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- scenari e carico da misurare;
- metriche e soglie obiettivo.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Riporta dispersione e condizioni di misura; non dedurre colli di bottiglia dalla sola lettura del codice; distingui costo misurato da stima. Non modificare file.

## Consegna

Baseline, percorsi critici ordinati per beneficio atteso, ipotesi da verificare e task proposti per TST06 o DEV10.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto.
- TST06: Misura e migliora prestazioni e consumo di risorse.
- DEV10: Ottimizza il codice sull’intero perimetro con misure prima e dopo.
