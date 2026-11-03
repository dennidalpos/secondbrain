# TST06 — Misura e ottimizza prestazioni e risorse: un collo di bottiglia o molti moduli

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: flusso, carico rappresentativo, ambiente, metrica e soglia | **Esempio d'uso**: `riduci i tempi di discovery degli host e l'uso di memoria`

## Scopo

Ridurre tempo, memoria e I/O con modifiche guidate dalle misure: un singolo collo di bottiglia dimostrabile oppure, con un profilo e obiettivi già disponibili, più moduli.

## Quando usarlo

Quando tempi, memoria, I/O o reattività non raggiungono un obiettivo. Per la sola analisi senza modifiche, o se mancano misure, usa prima AUD05.

## Input

Flusso o perimetro, carico rappresentativo, ambiente, metrica e soglia; per un'ottimizzazione ampia il profilo e la baseline (AUD05), gli obiettivi e i vincoli di compatibilità e leggibilità.

## Attività specifiche

Raccogli baseline ripetute e un profilo; individua il percorso dominante. Ordina le modifiche per beneficio misurato: algoritmi e strutture dati, lavoro ripetuto o memorizzabile in cache, chiamate di I/O e di rete raggruppabili, allocazioni, avvio, dipendenze pesanti. Applica una modifica alla volta alla causa misurata, mantenendo accettabili correttezza, leggibilità e costi operativi. Evita ottimizzazioni speculative e micro-ottimizzazioni senza effetto misurabile.

## Decisioni da raccogliere

- obiettivi misurabili, soglie e priorità;
- compromessi accettati tra leggibilità e prestazioni (solo ottimizzazione ampia).

## Verifiche

Confronta prima e dopo sullo stesso carico, riportando dispersione e condizioni; esegui i test funzionali, verifica che l'eventuale complessità aggiunta sia giustificata dal guadagno e scarta e annulla le modifiche senza beneficio. Non dedurre benefici dalla sola lettura del codice.

## Consegna

Misure confrontabili, modifiche, benefici osservati, compromessi accettati e i limiti del benchmark.

## Prompt vicini

- OPS03: Aggiungi log, metriche e diagnostica utili al problema.
- TST05: Verifica il comportamento reale rispetto ai requisiti.
- AUD05: Verifica le prestazioni e trova i percorsi critici senza modificare il codice.
- DEV03: Rifattorizza il codice preservando i contratti: mirato, a fasi o periodico.
