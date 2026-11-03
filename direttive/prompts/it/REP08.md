# REP08 — Ispeziona il repo e trova i task residui rispetto al codice reale

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: working tree, cronologia recente ed eventuale backlog o note | **Esempio d'uso**: `ispeziona il repo e rileva i task residui`

## Scopo

Trovare task incompiuti, lavoro lasciato a metà, debito tecnico non tracciato e discrepanze tra ciò che note o backlog dichiarano e il codice reale del repository. Non si limita a elencare il backlog né a caricare il contesto: confronta ciò che è dichiarato con ciò che esiste.

## Quando usarlo

All'inizio di una nuova sessione, prima di pianificare un lotto di lavoro, durante un passaggio di consegne o quando si sospetta che un lavoro precedente sia stato interrotto.

## Input

Working tree e indice Git, cronologia recente dei commit, il backlog ed eventuali note o documentazione del progetto, ed eventuali file transitori o note residue.

## Attività specifiche

Ispeziona lo stato Git: working tree, file in staging ma non committati, file non tracciati o rami locali orfani. Cerca nei sorgenti le tracce di lavoro lasciato a metà, come i marcatori `TODO`, `FIXME`, `HACK`, `XXX`, le eccezioni di non implementato (`NotImplementedException`), gli stub vuoti, i test disabilitati (`@Ignore`, `[Ignore]`, `Skip`, `.skip()`) o i mock temporanei.

Leggi il backlog e le eventuali note: confronta ogni voce aperta, promessa tecnica o insidia nota con file, classi e test reali. Verifica se un task è stato fatto in parte senza essere documentato, o completato senza che il backlog sia stato aggiornato. Distingui con rigore i fatti verificati nel codice dalle semplici dichiarazioni.

## Verifiche

Verifica che i file o i simboli segnalati come incompiuti esistano davvero e in quale stato; accertati se le modifiche parziali rompono la build o la suite di test. Verifica che i residui trovati non siano già nel backlog con un altro identificatore, per evitare duplicati.

## Consegna

Un rapporto strutturato con: lavoro in corso o a metà, residui e debito tecnico nel codice (con percorsi e righe), discrepanze con note e backlog, e una proposta concreta di attività prioritizzate da registrare.

## Prompt vicini

- COM01: Esplora il repository e individua componenti principali e comandi.
- REP01: Completa il prossimo task pronto del repository aperto.
