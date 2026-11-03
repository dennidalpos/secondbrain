# DEV04 — Aggiorna le dipendenze verificando compatibilità e regressioni

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: manifest delle dipendenze e lock file | **Esempio d'uso**: `aggiorna il pacchetto di serializzazione JSON`

## Scopo

Aggiornare le dipendenze scelte a versioni motivate e compatibili, con compatibilità, build e test verificati. Per l'analisi preliminare dello stato delle dipendenze usa AUD04.

## Quando usarlo

Per la manutenzione dei pacchetti o per aggiornamenti dovuti ad avvisi o incompatibilità.

## Input

Pacchetti, versioni attuali, versione obiettivo e motivo dell'aggiornamento.

## Attività specifiche

Leggi manifest e lock file reali, note di rilascio e guide ufficiali alla migrazione. Valuta dipendenze transitive, runtime, dipendenze peer e modifiche incompatibili. Aggiorna con il gestore di pacchetti del progetto.

## Verifiche

Verifica lock, risoluzione, build e i comportamenti interessati. Non dichiarare risolta una vulnerabilità sul solo numero di versione.

## Consegna

Versioni modificate, incompatibilità gestite, controlli e rischi residui.

## Prompt vicini

- DEV05: Migra codice o un framework verso un obiettivo definito.
- SEC03: Correggi le vulnerabilità e rafforza le difese interessate.
- AUD04: Verifica le dipendenze: obsolete, vulnerabili, inutilizzate e licenze.
