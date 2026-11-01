# DAT03 — Integra servizi API gestendo errori e ripetizione delle richieste

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: specifiche api, endpoint e gestione rate limit | **Esempio d'uso**: `sb prompt DAT03: implementa client rest con retry esponenziale e backoff`

## Scopo

Collegare un servizio esterno con contratti e gestione dei guasti verificabili.

## Quando usarlo

Per nuove integrazioni o correzioni del comportamento ai confini.

## Input

API e versione, operazioni, autenticazione prevista, limiti e ambiente di prova.

## Attività specifiche

Verifica documentazione primaria e contratti; gestisci timeout, cancellazione, paginazione, rate limit ed errori. Usa retry soltanto dove sicuro e prevedi idempotenza quando si ripetono operazioni con effetti.

## Verifiche

Prova successo, risposte inattese, errori transitori e permanenti, richieste duplicate e segreti assenti. Usa mock o sandbox per effetti non autorizzati.

## Consegna

Integrazione, configurazione priva di credenziali, prove e limiti delle chiamate reali.

## Prompt vicini

- PRG03: Progetta contratti API, modelli dati e compatibilità.
- REP03: Documenta API e contratti a partire dall’implementazione.
