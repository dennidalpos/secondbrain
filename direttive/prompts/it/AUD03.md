# AUD03 — Verifica architettura e debito tecnico non ancora tracciati

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: accesso in lettura a codice, backlog e documentazione di architettura | **Esempio d'uso**: `audit di architettura e debito tecnico del repository`

## Scopo

Individuare accoppiamenti, violazioni dei confini tra moduli e debito tecnico che non sono nel backlog.

## Quando usarlo

Prima di un refactoring architetturale, dopo una crescita rapida o quando il costo delle modifiche aumenta.

## Input

Struttura dei moduli, dipendenze interne, decisioni architetturali documentate ed eventuale backlog o note.

## Attività specifiche

Ricostruisci moduli, livelli e dipendenze dal codice reale, non dalla documentazione. Cerca cicli di dipendenza, dipendenze invertite tra livelli, moduli con troppe responsabilità, responsabilità duplicate, configurazione sparsa, punti singoli di guasto e scorciatoie rimaste (marcatori TODO, FIXME, HACK, stub, test disabilitati). Distingui i marcatori reali da identificatori, fixture e testi di test che contengono la stessa parola. Confronta con le decisioni documentate e con il backlog.

## Verifiche

Ogni voce di debito ha un percorso, un impatto concreto e un costo stimato motivato (basso, medio, alto). Verifica che non sia già nel backlog con un altro identificatore e distingui le scelte deliberate e documentate dai difetti.

## Consegna

Mappa dei confini osservati, debito ordinato per impatto e attività proposte da registrare; per il piano di rientro usa PRG06.

## Prompt vicini

- AUD01: Esegui un audit completo del repository con un unico rapporto, anche esportato.
- COM04: Valuta impatto, rischi e dipendenze di una modifica.
- PRG06: Pianifica un refactoring architetturale a fasi con controlli e rollback.
