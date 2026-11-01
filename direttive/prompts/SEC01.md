# SEC01 — Revisiona modifiche o codice con rilievi concreti e riferimenti

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: diff, commit o file da analizzare | **Esempio d'uso**: `sb prompt SEC01: revisiona pull request per rilevamento leak dati`

## Scopo

Individuare difetti utili da correggere nel codice esaminato.

## Quando usarlo

Prima di integrare modifiche o per una review mirata.

## Input

Diff, commit o area; criteri e profondità richiesti.

## Attività specifiche

Esamina staged, unstaged e nuovi file pertinenti, oppure il perimetro esplicito. Segui contratti, chiamanti, errori e test. Verifica le ipotesi di difetto con prove proporzionate; non cercare un numero prefissato di problemi.

## Verifiche

Per ogni rilievo controlla impatto, condizioni e riferimento preciso. Non modificare file, fare pulizia o aggiornare tracker implicitamente.

## Consegna

Rilievi ordinati per gravità con file/riga e riproduzione; verifiche e limiti. Se non emergono difetti, dichiaralo.

## Prompt vicini

- TST05: Verifica il comportamento reale rispetto ai requisiti.
- SEC02: Analizza minacce, confini di fiducia e scenari di abuso.
- AUD06: Esporta rapporti e metriche nel formato scelto dall’utente.
