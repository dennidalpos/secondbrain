# SEC01 — Rivedi modifiche o codice con rilievi concreti e riferimenti

> **Scope**: repo | **Modalità**: lettura | **Cosa serve**: diff, commit o file da analizzare | **Esempio d'uso**: `rivedi la pull request alla ricerca di fughe di dati`

## Scopo

Individuare difetti che vale la pena correggere nel codice in revisione.

## Quando usarlo

Prima di integrare modifiche o per una revisione mirata.

## Input

Diff, commit o area; criteri e profondità richiesti.

## Attività specifiche

Esamina i file in staging, non in staging e i nuovi file pertinenti, oppure il perimetro esplicito. Segui contratti, chiamanti, errori e test. Verifica i difetti sospetti con evidenze proporzionate; non cercare un numero fisso di problemi.

## Verifiche

Per ogni rilievo verifica impatto, condizioni e riferimento preciso. Non modificare file, non ripulire e non aggiornare il backlog in modo implicito.

## Consegna

Rilievi ordinati per gravità con file e riga e una riproduzione; controlli e limiti. Se non emergono difetti, dillo.

## Prompt vicini

- SEC02: Analizza minacce, confini di fiducia e scenari di abuso.
- TST05: Verifica il comportamento reale rispetto ai requisiti.
- AUD01: Esegui un audit completo del repository con un unico rapporto, anche esportato.
