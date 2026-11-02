# SYS13 — Fissa o rimuovi il blocco greenfield (versioni, changelog, migrazioni, alias)

> **Scope**: repo/area | **Modalità**: scrittura | **Cosa serve**: repository gestito, dossier attivo e conferma dell'utente | **Esempio d'uso**: `sb prompt SYS13: fissa o rimuovi il blocco greenfield su questo repository`

## Scopo

Fissare o rimuovere il blocco greenfield di un repository. Con il blocco attivo agenti e script non introducono numeri di versione, voci di CHANGELOG, migrazioni o importazioni di schema, alias di compatibilità e `deprecations` (flag `lifecycle: greenfield` nel `repository.json` del dossier). Senza blocco torna in vigore il ciclo normale di versione, CHANGELOG e migrazioni previsto dalle direttive.

## Quando usarlo

Fissa il blocco per un progetto nuovo o in riscrittura, senza utilizzatori esistenti da proteggere e dove la compatibilità all’indietro non è un vincolo. Rimuovilo quando il progetto ha utilizzatori da proteggere o sta per essere rilasciato. Non serve per prodotti già rilasciati, dove vale la regola di versione delle direttive (proposta del numero con scelta multipla).

## Input

Repository gestito con dossier attivo (SYS03), operazione richiesta (fissa o rimuovi), conferma esplicita dell’utente su ciò che il blocco vieta ed eventuali file già presenti (`VERSION`, `CHANGELOG.md`, alias) da valutare. La rimozione non è retroattiva: non crea versioni, voci di CHANGELOG o migrazioni.

## Attività specifiche

Dal checkout del repository imposta il flag con lo script, sotto lock e solo per il repository in lavoro: `pwsh -NoProfile -File scripts/knowledge.ps1 -SetLifecycle greenfield` per fissare, `-SetLifecycle none` per rimuovere. Non modificare `repository.json` a mano.

Con il blocco attivo la composizione dei prompt e `secondbrain.ps1 -Check` segnalano le violazioni: cambi non committati di `VERSION`, nuove voci in `CHANGELOG.md`, importazioni o migrazioni di schema registrate, alias di compatibilità in `repository.json` e `deprecations` nel catalogo (solo SecondBrain). Il confronto è con HEAD: una modifica già committata non è segnalata. Il blocco non cancella nulla di esistente e non autorizza commit o push.

Alla rimozione la regola di versione delle direttive torna in vigore: quando le modifiche lo giustificano proponi il numero e chiedi con scelta multipla se cambiarlo. Le violazioni segnalate prima della rimozione restano da valutare con l’utente.

## Decisioni da raccogliere

- operazione: fissa o rimuovi il blocco;
- repository a cui applicarla, se non è quello in lavoro;
- conferma di ciò che il blocco vieta, o che compatibilità, versioni e migrazioni tornano a essere gestite;
- come trattare `VERSION`, `CHANGELOG.md` e alias già presenti e se avviare subito la proposta di una prima versione.

## Verifiche

L’esito dello script riporta `lifecycle: greenfield` (fissato) o `lifecycle` vuoto (rimosso); `prompts.ps1 -Compose` mostra o non mostra più il blocco nei riferimenti locali; `secondbrain.ps1 -Check -Repository <identità>` non contiene `greenfield-violation` oppure le elenca come residui noti.

## Consegna

Stato del flag, violazioni già presenti o residue, elenco di ciò che ora è vietato o di nuovo consentito e decisioni sulla versione. Nessun commit o push implicito.

## Prompt vicini

- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- SYS04: Controlla o allinea gli asset già gestiti della postazione.
