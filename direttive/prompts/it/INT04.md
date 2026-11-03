# INT04 — Verifica l'internazionalizzazione di stringhe, formati e traduzioni

> **Scope**: repo/area | **Modalità**: verifica | **Cosa serve**: interfaccia o messaggi con lingue e formati supportati | **Esempio d'uso**: `verifica stringhe, formati e traduzioni della CLI`

## Scopo

Verificare che stringhe, messaggi, date, numeri e codifiche dell'interfaccia rispettino le lingue e le impostazioni regionali supportate.

## Quando usarlo

Prima di rilasciare un'interfaccia o messaggi in più lingue o con formati regionali. Per l'accessibilità usa INT03, per implementare le schermate INT02.

## Input

Elenco di lingue e impostazioni regionali supportate, file di risorse o stringhe nel codice, un'interfaccia funzionante, codifiche dei file.

## Attività specifiche

Individua stringhe incorporate nel codice, concatenazioni che impediscono la traduzione, formati fissi di data, ora, numero e valuta, ordinamenti dipendenti dalla lingua e codifiche diverse da UTF-8. Confronta le lingue supportate cercando chiavi mancanti o inutilizzate, segnaposto incoerenti e testi troncati. Prova l'interfaccia con almeno un'impostazione regionale diversa da quella di sviluppo. Non tradurre né modificare file senza una richiesta esplicita.

## Verifiche

Riproduci ogni rilievo con la lingua o il formato indicato e verifica che testi con accenti, caratteri non latini e percorsi contenenti spazi vengano visualizzati correttamente. Distingui i difetti provati dalle proposte.

## Consegna

Un rapporto con le lingue verificate, rilievi per file e riga, evidenze di riproduzione e raccomandazioni; modifiche solo se richieste.

## Prompt vicini

- INT02: Implementa un'interfaccia seguendo requisiti e riferimenti.
- INT03: Verifica l'accessibilità e l'uso con tastiera e tecnologie assistive.
- TST05: Verifica il comportamento reale rispetto ai requisiti.
