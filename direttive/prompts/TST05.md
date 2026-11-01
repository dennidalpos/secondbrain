# TST05 — Verifica il comportamento reale rispetto ai requisiti

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: criteri di accettazione e ambiente funzionante | **Esempio d'uso**: `sb prompt TST05: verifica conformita output rispetto alle specifiche`

## Scopo

Accertare cosa funziona realmente nel perimetro indicato.

## Quando usarlo

Per collaudo, conferma di una correzione o verifica di una consegna.

## Input

Criteri di accettazione, build o applicazione da provare, ambiente e dati di prova.

## Attività specifiche

Associa i criteri a percorsi osservabili. Esegui prove positive, negative e limite pertinenti; raccogli esiti e riferimenti. Usa copie o fixture isolate per non cambiare dati reali.

## Verifiche

Distingui ispezione statica, test automatizzati e interazione reale. Non correggere codice né aggiornare dossier per una richiesta di sola verifica.

## Consegna

Matrice criterio/esito/prova, difetti riproducibili e parti non accessibili.

## Prompt vicini

- TST02: Copri percorsi utente con test end-to-end.
- SEC01: Revisiona modifiche o codice con rilievi concreti e riferimenti.
