# AUD02 — Misura il repository con metriche riproducibili e individua i punti critici

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: lettura del repository, della storia Git e degli strumenti di misura | **Esempio d'uso**: `sb prompt AUD02: metriche e hotspot del repository`

## Scopo

Quantificare dimensione, complessità, duplicazione, variazione nel tempo e copertura del repository con misure riproducibili.

## Quando usarlo

Per avere una base oggettiva prima di refactoring, ottimizzazioni o pianificazione, e per confrontare due momenti.

## Input

Perimetro (percorsi e linguaggi), intervallo di storia Git e strumenti di misura già adottati dal progetto.

## Attività specifiche

Usa gli strumenti del progetto o `git` e utilità standard già presenti; non installare dipendenze senza autorizzazione. Rileva file e righe per linguaggio, complessità ciclomatica e funzioni lunghe, duplicazione, variazione per file (churn) e hotspot (modifiche frequenti in codice complesso), contributori per area, copertura dei test, numero ed età delle dipendenze, dimensione di binari e artefatti tracciati. Registra comando, versione dello strumento e data di ogni misura.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- perimetro e linguaggi;
- intervallo di storia da analizzare.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Ripeti ogni misura per verificarne la stabilità; escludi file generati, vendor e fixture dichiarandolo; non confrontare valori ottenuti con strumenti o soglie diverse.

## Consegna

Tabella delle metriche con metodo e perimetro, hotspot ordinati, soglie proposte (da confermare) e limiti; esportabile con AUD06.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto.
- DEV08: Rivedi leggibilità, coerenza e manutenibilità del codice senza modificarlo.
- AUD06: Esporta rapporti e metriche nel formato scelto dall’utente.
