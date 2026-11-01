# SYS04 — Controlla o allinea gli asset già gestiti della postazione

> **Scope**: central | **Modalità**: verifica | **Cosa serve**: configurazione postazione e direttive approvate | **Esempio d'uso**: `sb prompt SYS04: verifica allineamento direttive nei repository gestiti`

## Scopo

Verificare e allineare il cervello e le integrazioni senza ampliare implicitamente il perimetro.

## Quando usarlo

sb controlla per sola verifica; sb allinea per correggere gli asset già approvati.

## Input

Configurazione host risolta localmente, dossier e direttive approvate.

## Attività specifiche

Riesegui discovery dell’host e confronta gli asset con le associazioni approvate. Esegui -Check. Per sb allinea usa -Sync, applicando soltanto testi approvati e preservando conflitti. In presenza di divergenze, proponi le opzioni correttive tramite Function Calling o Tool Use (es. `ask_question`). Proponi i nuovi asset tramite SYS03. Per ogni dossier oltre budget prepara con SYS05 una sintesi revisionata, applicala e ripeti il controllo. La CLI non inventa sintesi automaticamente. Non eseguire task, build o test applicativi dei prodotti dalla manutenzione centrale. Controlla le fonti con SYS02 su richiesta, senza pianificazioni. Nessuna cancellazione di artefatti.

## Decisioni da raccogliere

Se più opzioni non sono ricavabili dal codice o dalle fonti, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`, opzioni atomiche e non numerate; scelta multipla quando le opzioni non si escludono.

- correzione da applicare per ogni divergenza (allinea, conserva il conflitto, rinvia);
- asset nuovi da proporre con SYS03 e dossier da compattare con SYS05 (scelta multipla);
- IDE o account con caricamento da riverificare dopo un cambio di login.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Controlla TOC, proiezioni task, riferimenti, host, account e caricamento. Non equiparare file allineati a sessioni verificate. Non dichiarare la scansione completa se restano aree non lette.

## Consegna

Esiti distinti per asset e copertura; modifiche effettive, conflitti e attività ancora necessarie.

## Prompt vicini

- SYS03: Attiva SecondBrain dopo discovery e selezione degli asset.
- SYS05: Compatta il dossier preservando originali, fatti e TOC.
- SYS01: Verifica gli IDE; mappa o riallinea su richiesta.
- SYS11: Aggiungi, modifica o rimuovi un prompt del catalogo centralizzato.
