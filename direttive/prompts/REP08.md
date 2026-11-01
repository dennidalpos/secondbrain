# REP08 — Ispeziona il repo, individua task residui e incrocia memorie e codice reale

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: albero di lavoro, dossier di memoria e tracker | **Esempio d'uso**: `sb prompt REP08: ispeziona il repo e rileva task residui`

## Scopo

Individuare task incompiuti, lavorazioni a metà, debiti tecnici non tracciati e discrepanze tra memorie/tracker e il codice reale del repository. Non si limita a elencare il tracker (MEM04) né a caricare il contesto (SYS06): confronta ciò che è dichiarato con ciò che esiste.

## Quando usarlo

All'avvio di una nuova sessione, prima di pianificare un lotto, durante il subentro in un progetto o quando si sospetta che lavorazioni precedenti siano state interrotte.

## Input

Working tree e indice Git, storico commit recente, dossier del repository (`context.md`, `memory.md`, `tracker.json`) ed eventuali file transitori o note residue.

## Attività specifiche

Ispeziona lo stato Git: working tree, file staged non committati, file non tracciati o rami locali orfani. Cerca nel codice sorgente tracce di lavorazioni lasciate a metà, come marker `TODO`, `FIXME`, `HACK`, `XXX`, eccezioni non implementate (`NotImplementedException`), stub vuoti, test disabilitati (`@Ignore`, `[Ignore]`, `Skip`, `.skip()`) o mock provvisori.

Consulta `context.md`, `memory.md` e `tracker.json`: incrocia ogni attività aperta, promessa tecnica o gotcha con i file, classi e test reali. Verifica se un task è stato parzialmente eseguito senza essere documentato, oppure completato senza aggiornamento del tracker. Distingui con rigore i fatti verificati nel codice dalle semplici dichiarazioni.

## Verifiche

Verifica la reale presenza e lo stato dei file o simboli indicati come incompiuti; accerta se le modifiche parziali rompono la build o la suite di test. Controlla che i residui rilevati non siano già tracciati nel tracker sotto altro identificatore per evitare duplicazioni.

## Consegna

Rapporto strutturato con: lavorazioni in corso o a metà, residui e debiti tecnici nel codice (con percorsi e linee), discrepanze rispetto a memoria e tracker, e proposta concreta di task prioritizzati da censire.

## Prompt vicini

- COM01: Esplora il repository e individua componenti e comandi principali.
- REP01: Completa il prossimo task eseguibile del repository aperto.
- MEM04: Elenca e descrivi le attività del tracker e i problemi che risolvono.
- SYS06: Leggi memoria attiva, contesto e tracker del repository corrente.
