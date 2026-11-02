# DEV09 — Consolida e rendi leggibile il codice a fasi preservando il comportamento

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: suite di test e build verdi come baseline, convenzioni del repository | **Esempio d'uso**: `sb prompt DEV09: consolida e rendi leggibile il modulo di discovery`

## Scopo

Rendere il codice comprensibile a un nuovo programmatore e consolidare duplicazioni e convenzioni sull’intero perimetro senza cambiarne il comportamento.

## Quando usarlo

Dopo DEV08, AUD02 o AUD03, prima di nuove funzionalità su codice poco leggibile o per un subentro.

## Input

Perimetro, convenzioni del repository, rilievi di DEV08, suite di test e baseline verde.

## Attività specifiche

Parti da build e test verdi; se mancano, crea prima i test di caratterizzazione (TST01). Lavora a lotti piccoli e indipendenti, un modulo per volta: nomi che esprimono l’intento, funzioni brevi con una sola responsabilità, duplicazioni eliminate, condizioni semplificate, gestione degli errori coerente, commenti che spiegano il perché e struttura dei file prevedibile. Segui le convenzioni esistenti senza introdurne di nuove. Un lotto corrisponde a un commit logico proposto, mai mescolato a modifiche funzionali.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.
- perimetro e ordine dei moduli;
- soglie di leggibilità (per esempio lunghezza massima delle funzioni);
- granularità dei commit per lotto.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Dopo ogni lotto esegui build, test e linter e confronta contratti pubblici e output; interrompi e ripristina il lotto se il comportamento cambia. Non rimuovere codice senza verificarne i consumatori (REP04).

## Consegna

Lotti applicati con motivazione, metriche prima e dopo (AUD02) se disponibili, verifiche e residui.

## Prompt vicini

- DEV08: Rivedi leggibilità, coerenza e manutenibilità del codice senza modificarlo.
- DEV03: Esegui un refactoring preservando contratti e comportamento.
- PRG06: Pianifica un refactoring architetturale a fasi con verifiche e rollback.
- DEV11: Mantieni il repository: duplicati, export, codice morto e leggibilità.
