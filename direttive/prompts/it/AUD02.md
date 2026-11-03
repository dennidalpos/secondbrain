# AUD02 — Misura il repository con metriche riproducibili e individua gli hotspot

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: accesso in lettura a repository, cronologia Git e strumenti di misura | **Esempio d'uso**: `metriche e hotspot del repository`

## Scopo

Quantificare dimensione, complessità, duplicazione, evoluzione nel tempo e copertura del repository con misure riproducibili.

## Quando usarlo

Per ottenere una base di riferimento oggettiva prima di refactoring, ottimizzazione o pianificazione, e per confrontare due momenti nel tempo.

## Input

Perimetro (percorsi e linguaggi), intervallo della cronologia Git e strumenti di misura già usati dal progetto.

## Attività specifiche

Usa gli strumenti del progetto oppure `git` e le utilità standard già presenti; non installare dipendenze senza autorizzazione. Misura file e righe per linguaggio, complessità ciclomatica e funzioni lunghe, duplicazione, variazioni per file (churn) e hotspot (modifiche frequenti in codice complesso), contributori per area, copertura dei test, numero ed età delle dipendenze, dimensione di binari e artefatti tracciati. Registra comando, versione dello strumento e data di ogni misura.

## Decisioni da raccogliere

- perimetro e linguaggi;
- intervallo della cronologia da analizzare.

## Verifiche

Ripeti ogni misura per verificarne la stabilità; escludi file generati, codice di terze parti e fixture dichiarandolo; non confrontare valori ottenuti con strumenti o soglie diversi.

## Consegna

Tabella delle metriche con metodo e perimetro, hotspot ordinati, soglie proposte (da confermare) e limiti; esportabile con AUD01.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto, anche esportato.
- DEV08: Rivedi leggibilità, coerenza e manutenibilità senza modificare il codice.
