# INT04 — Verifica internazionalizzazione di stringhe, formati e traduzioni

> **Scope**: repo/area | **Modalità**: verifica | **Cosa serve**: interfaccia o messaggi con lingue e formati supportati | **Esempio d'uso**: `sb prompt INT04: verifica stringhe, formati e traduzioni della CLI`

## Scopo

Verificare che stringhe, messaggi, date, numeri e codifiche dell'interfaccia rispettino le lingue e le impostazioni regionali supportate.

## Quando usarlo

Prima del rilascio di un'interfaccia o di messaggi in più lingue o con formati regionali. Per l'accessibilità usa INT03, per implementare le schermate INT02.

## Input

Elenco delle lingue e impostazioni regionali supportate, file di risorse o stringhe nel codice, interfaccia funzionante, codifica dei file.

## Attività specifiche

Individua stringhe incorporate nel codice, concatenazioni che impediscono la traduzione, formati di data, ora, numero e valuta fissi, ordinamenti dipendenti dalla lingua e codifiche non UTF-8. Confronta le lingue supportate cercando chiavi mancanti o inutilizzate, segnaposto non coerenti e testi troncati. Prova l'interfaccia con almeno una impostazione regionale diversa da quella di sviluppo. Non tradurre né modificare file senza richiesta esplicita.

## Verifiche

Riproduci ogni rilievo con la lingua o il formato indicato e verifica che i testi con accenti, caratteri non latini e percorsi con spazi si visualizzino correttamente. Distingui difetti dimostrati da proposte.

## Consegna

Rapporto con le lingue verificate, rilievi per file e riga, prove di riproduzione e raccomandazioni; modifiche solo se richieste.

## Prompt vicini

- INT02: Implementa un’interfaccia seguendo requisiti e riferimenti.
- INT03: Verifica accessibilità e utilizzo con tastiera e ausili.
- TST05: Verifica il comportamento reale rispetto ai requisiti.
