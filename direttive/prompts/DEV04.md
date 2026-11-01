# DEV04 — Aggiorna dipendenze verificando compatibilità e regressioni

> **Scope**: repo/area/file | **Modalità**: scrittura | **Cosa serve**: manifest dipendenze e changelog della libreria | **Esempio d'uso**: `sb prompt DEV04: aggiorna pacchetto System.Text.Json`

## Scopo

Portare dipendenze selezionate a versioni motivate e compatibili.

## Quando usarlo

Per manutenzione di pacchetti o aggiornamenti con advisory o incompatibilità.

## Input

Pacchetti, versioni attuali, destinazione e motivazione dell’aggiornamento.

## Attività specifiche

Leggi manifest e lock reali, note di rilascio e guide ufficiali di migrazione. Valuta dipendenze transitive, runtime, peer dependency e cambiamenti incompatibili. Aggiorna con il package manager del progetto.

## Verifiche

Verifica lock, risoluzione, build e comportamenti influenzati. Non dichiarare risolta una vulnerabilità sulla sola base del numero di versione.

## Consegna

Versioni cambiate, incompatibilità gestite, verifiche e rischi residui.

## Prompt vicini

- DEV05: Migra codice o framework verso una destinazione definita.
- SEC03: Correggi vulnerabilità e rafforza le difese interessate.
