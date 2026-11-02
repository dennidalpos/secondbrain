# DEV11 — Mantieni il repository: duplicati, export, codice morto e leggibilità

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: suite di test e build verdi come baseline, storico delle modifiche recenti | **Esempio d'uso**: `sb prompt DEV11: manutenzione dei moduli dopo molte modifiche`

## Scopo

Riportare un repository a una forma lineare dopo molte modifiche successive: funzioni duplicate o non integrate, superficie pubblica non dichiarata, codice morto e flussi difficili da seguire per un programmatore nuovo.

## Quando usarlo

Come manutenzione periodica o dopo un lotto di modifiche che ha toccato più moduli. Per rivedere senza modificare usa DEV08; per ristrutturare a fasi un singolo modulo DEV09; per le prestazioni DEV10.

## Input

Perimetro (repository o area), baseline di test e build, elenco delle modifiche recenti (Git), convenzioni del repository e contratti pubblici da non cambiare.

## Attività specifiche

Parti dalla baseline verde e dalle modifiche recenti. Cerca funzioni con lo stesso nome o lo stesso scopo in moduli diversi (e confronta i comportamenti prima di unificarle), funzioni definite ma non richiamate dal codice di produzione, funzioni usate solo dai test, API pubbliche esposte con caratteri jolly invece di un elenco esplicito, parametri e rami morti, flussi con diramazioni annidate o effetti nascosti. Procedi un intervento per volta: unifica sulla versione corretta, sposta il codice di sola prova nei test, rendi esplicita la superficie esportata, elimina il codice morto solo dopo aver verificato i riferimenti, semplifica i flussi per renderli lineari e leggibili. Non cambiare i contratti pubblici senza decisione esplicita e non aggiungere astrazioni senza un uso concreto.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- quale delle versioni duplicate è quella corretta quando i comportamenti divergono;
- quali funzioni fanno parte della superficie pubblica e vanno esportate;
- eliminazione o conservazione del codice che sembra morto ma ha riferimenti dinamici.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Esegui test e build prima e dopo ogni intervento, cerca i riferimenti rimasti ai nomi spostati o eliminati (codice, test, documentazione, esempi) e verifica che nessun contratto pubblico sia cambiato. Riesegui l'analisi dei duplicati e degli export per confermare che il risultato è quello atteso.

## Consegna

Interventi eseguiti con motivazione, duplicati unificati, superficie esportata, codice rimosso o spostato, verifiche prima e dopo e residui che richiedono una decisione.

## Prompt vicini

- DEV08: Rivedi leggibilità, coerenza e manutenibilità del codice senza modificarlo.
- DEV09: Consolida e rendi leggibile il codice a fasi preservando il comportamento.
- DEV10: Ottimizza il codice sull’intero perimetro con misure prima e dopo.
