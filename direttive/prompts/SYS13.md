# SYS13 — Fissa il blocco greenfield: niente versioni, changelog, migrazioni, alias

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: repository gestito, dossier attivo e conferma dell'utente | **Esempio d'uso**: `sb prompt SYS13: fissa il blocco greenfield su questo repository`

## Scopo

Impedire che agenti e script introducano, in un repository ancora greenfield (nessun utilizzatore esistente da proteggere), numeri di versione, voci di CHANGELOG, migrazioni o importazioni di schema, alias di compatibilità e `deprecations`, fissando il flag `lifecycle: greenfield` nel `repository.json` del dossier.

## Quando usarlo

Per un progetto nuovo o in riscrittura in cui la compatibilità all'indietro non è un vincolo. Non serve per prodotti già rilasciati, dove vale la regola di versione delle direttive (proposta del numero con scelta multipla).

## Input

Repository gestito con dossier attivo (SYS03), conferma esplicita dell'utente su ciò che il blocco vieta ed eventuali file già presenti (`VERSION`, `CHANGELOG.md`, alias) da valutare prima del blocco.

## Attività specifiche

Dal checkout del repository fissa il blocco con lo script, sotto lock e solo per il repository in lavoro: `pwsh -NoProfile -File scripts/knowledge.ps1 -SetLifecycle greenfield`. Non modificare `repository.json` a mano. Con il blocco attivo composizione dei prompt e `secondbrain.ps1 -Check` segnalano le violazioni: cambi non committati di `VERSION`, nuove voci in `CHANGELOG.md`, importazioni o migrazioni di schema registrate, alias di compatibilità in `repository.json` e `deprecations` nel catalogo (solo SecondBrain). Il confronto è con HEAD: una modifica già committata non è segnalata. Il blocco non cancella nulla di esistente e non autorizza commit o push. Per toglierlo usa SYS14.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- repository a cui applicare il blocco, se non è quello in lavoro;
- conferma di ciò che il blocco vieta;
- come trattare `VERSION`, `CHANGELOG.md` e alias già presenti.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

L'esito dello script riporta `lifecycle: greenfield`; `prompts.ps1 -Compose` mostra il blocco nei riferimenti locali; `secondbrain.ps1 -Check -Repository <identità>` non contiene `greenfield-violation` oppure le elenca come residui noti.

## Consegna

Stato del flag, violazioni già presenti, elenco di ciò che ora è vietato e come rimuovere il blocco (SYS14). Nessun commit o push implicito.

## Prompt vicini

- SYS14: Rimuovi il blocco greenfield e riprendi il ciclo normale di versione.
- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
