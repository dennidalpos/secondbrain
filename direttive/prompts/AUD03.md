# AUD03 — Audita architettura e debito tecnico non ancora tracciato

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: lettura del codice, del tracker e della documentazione architetturale | **Esempio d'uso**: `sb prompt AUD03: audit di architettura e debito tecnico del repository`

## Scopo

Individuare accoppiamenti, violazioni dei confini tra moduli e debiti tecnici che non compaiono nel tracker.

## Quando usarlo

Prima di un refactoring architetturale, dopo una crescita rapida o quando il costo delle modifiche aumenta.

## Input

Struttura dei moduli, dipendenze interne, decisioni architetturali documentate, tracker e memoria.

## Attività specifiche

Ricostruisci moduli, livelli e dipendenze dal codice reale e non dalla documentazione. Cerca cicli di dipendenza, dipendenze inverse tra livelli, moduli con troppe responsabilità, duplicazioni di responsabilità, configurazione sparsa, punti unici di guasto e scorciatoie rimaste (marker TODO, FIXME, HACK, stub, test disabilitati). Confronta con le decisioni documentate e con il tracker.

## Verifiche

Ogni debito ha percorso, impatto concreto e costo stimato (basso, medio, alto) motivato. Controlla che non sia già nel tracker con altro identificatore e distingui le scelte volute e documentate dai difetti.

## Consegna

Mappa dei confini osservati, debiti ordinati per impatto e task proposti da censire; per il piano di intervento usa PRG06.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto.
- COM04: Valuta impatto, rischi e dipendenze di una modifica.
- PRG06: Pianifica un refactoring architetturale a fasi con verifiche e rollback.
