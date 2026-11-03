# DAT03 — Integra servizi API con gestione degli errori e nuovi tentativi delle richieste

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: documentazione dell'API, credenziali di prova e schema | **Esempio d'uso**: `implementa un client REST con backoff esponenziale e nuovi tentativi`

## Scopo

Collegare un servizio esterno con contratti verificabili e gestione dei guasti.

## Quando usarlo

Per nuove integrazioni o correzioni del comportamento ai confini.

## Input

API e versione, operazioni, autenticazione attesa, limiti e un ambiente di prova.

## Attività specifiche

Verifica la documentazione primaria e i contratti; gestisci timeout, annullamento, paginazione, limiti di frequenza ed errori. Usa i nuovi tentativi solo dove è sicuro e garantisci l'idempotenza quando si ripetono operazioni con effetti.

## Verifiche

Prova successo, risposte inattese, errori transitori e permanenti, richieste duplicate e assenza di segreti. Usa mock o una sandbox per gli effetti non autorizzati.

## Consegna

L'integrazione, configurazione priva di credenziali, test e i limiti delle chiamate reali.

## Prompt vicini

- PRG03: Progetta contratti API, modelli di dati e compatibilità.
- DOC02: Documenta API e contratti a partire dall'implementazione.
