# TST05 — Verifica il comportamento reale rispetto ai requisiti

> **Scope**: repo | **Modalità**: verifica | **Cosa serve**: criteri di accettazione e un ambiente funzionante | **Esempio d'uso**: `verifica che l'output sia conforme alle specifiche`

## Scopo

Stabilire che cosa funziona davvero nel perimetro indicato.

## Quando usarlo

Per i test di accettazione, per confermare una correzione o per verificare una consegna.

## Input

Criteri di accettazione, la build o l'applicazione da provare, ambiente e dati di prova.

## Attività specifiche

Associa i criteri a percorsi osservabili. Esegui i test positivi, negativi e limite pertinenti; raccogli esiti e riferimenti. Usa copie o fixture isolate per non modificare dati reali.

## Verifiche

Distingui ispezione statica, test automatici e interazione reale. Non correggere il codice né aggiornare le note per una richiesta di sola verifica.

## Consegna

Matrice di criterio, esito ed evidenza, difetti riproducibili e le parti non raggiungibili.

## Prompt vicini

- SEC01: Rivedi modifiche o codice con rilievi concreti e riferimenti.
- TST02: Copri i percorsi utente con test end-to-end.
