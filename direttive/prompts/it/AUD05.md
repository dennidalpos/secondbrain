# AUD05 — Verifica le prestazioni e trova i percorsi critici senza modificare il codice

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: scenario di carico rappresentativo e strumenti di profilazione o misura | **Esempio d'uso**: `trova i percorsi critici per tempo e memoria`

## Scopo

Individuare, con misure, i percorsi che dominano tempo, memoria e I/O, prima di ottimizzare.

## Quando usarlo

Prima di TST06, quando mancano misure o l'obiettivo non è definito.

## Input

Flussi significativi, carico rappresentativo, ambiente ed eventuali obiettivi o soglie.

## Attività specifiche

Definisci scenari e metriche (latenza, throughput, memoria, I/O, avvio), raccogli baseline ripetute e un profilo con gli strumenti del progetto o della piattaforma. Individua i percorsi dominanti, il lavoro ripetuto, le chiamate di I/O o di rete evitabili, le strutture dati inadatte, gli avvii lenti, la crescita della memoria e i rischi di scalabilità (complessità superlineare).

## Decisioni da raccogliere

- scenari e carico da misurare;
- metriche e soglie obiettivo.

## Verifiche

Riporta la dispersione e le condizioni di misura; non dedurre colli di bottiglia dalla sola lettura del codice; distingui il costo misurato dalle stime. Non modificare file.

## Consegna

Baseline, percorsi critici ordinati per beneficio atteso, ipotesi da verificare e attività proposte per TST06.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto, anche esportato.
- TST06: Misura e ottimizza prestazioni e risorse: un collo di bottiglia o molti moduli.
