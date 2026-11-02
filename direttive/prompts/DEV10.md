# DEV10 — Ottimizza il codice sull’intero perimetro con misure prima e dopo

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: baseline e profilo delle prestazioni (AUD05), suite di test verde | **Esempio d'uso**: `sb prompt DEV10: ottimizza I/O e allocazioni dei moduli di scansione`

## Scopo

Ridurre costi di calcolo, memoria e I/O sull’intero perimetro scelto con interventi motivati da misure.

## Quando usarlo

Dopo AUD05 o quando un obiettivo di risorse riguarda più moduli. Per un singolo collo di bottiglia usa TST06.

## Input

Profilo e baseline (AUD05), obiettivi, vincoli di compatibilità e di leggibilità.

## Attività specifiche

Ordina gli interventi per beneficio misurato: algoritmi e strutture dati, lavoro ripetuto o memorizzabile, I/O e chiamate di rete raggruppabili, allocazioni, avvio, dipendenze pesanti. Applica un intervento per volta mantenendo correttezza, leggibilità e costi operativi. Evita ottimizzazioni speculative e micro-ottimizzazioni senza effetto misurabile.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- obiettivi misurabili e priorità;
- compromessi accettati tra leggibilità e prestazioni.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Confronta prima e dopo con lo stesso carico riportando la dispersione, esegui i test funzionali e verifica che la complessità aggiunta sia giustificata dal guadagno. Scarta e ripristina gli interventi senza beneficio.

## Consegna

Interventi, misure confrontabili, benefici, compromessi accettati e limiti del benchmark.

## Prompt vicini

- TST06: Misura e migliora prestazioni e consumo di risorse.
- AUD05: Audita le prestazioni e individua i percorsi critici senza modificare il codice.
- DEV03: Esegui un refactoring preservando contratti e comportamento.
- DEV11: Mantieni il repository: duplicati, export, codice morto e leggibilità.
