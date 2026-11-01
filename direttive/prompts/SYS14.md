# SYS14 — Rimuovi il blocco greenfield e riprendi il ciclo normale di versione

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: repository gestito con blocco greenfield attivo e conferma dell'utente | **Esempio d'uso**: `sb prompt SYS14: rimuovi il blocco greenfield da questo repository`

## Scopo

Rimuovere il blocco greenfield di un repository, rimettendo in vigore il ciclo normale di versione, CHANGELOG e migrazioni previsto dalle direttive.

## Quando usarlo

Quando il progetto ha utilizzatori da proteggere o sta per essere rilasciato e la compatibilità all'indietro torna a essere un vincolo.

## Input

Repository gestito con `lifecycle: greenfield` nel dossier e conferma esplicita dell'utente. La rimozione non è retroattiva: non crea versioni, voci di CHANGELOG o migrazioni.

## Attività specifiche

Dal checkout del repository rimuovi il blocco con lo script, sotto lock e solo per il repository in lavoro: `pwsh -NoProfile -File scripts/knowledge.ps1 -SetLifecycle none`. Non modificare `repository.json` a mano. Da quel momento la regola di versione delle direttive torna in vigore: quando le modifiche lo giustificano proponi il numero e chiedi con scelta multipla se cambiarlo. Eventuali violazioni segnalate prima della rimozione restano da valutare con l'utente.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- repository da cui togliere il blocco, se non è quello in lavoro;
- conferma che compatibilità, versioni e migrazioni tornano a essere gestite;
- se avviare subito la proposta di una prima versione.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

L'esito dello script riporta `lifecycle` vuoto; la composizione non mostra più il blocco e `secondbrain.ps1 -Check -Repository <identità>` non contiene `greenfield-violation`.

## Consegna

Stato del flag, eventuali violazioni residue e decisioni sulla versione. Nessun commit o push implicito.

## Prompt vicini

- SYS13: Fissa il blocco greenfield: niente versioni, changelog, migrazioni, alias.
- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
