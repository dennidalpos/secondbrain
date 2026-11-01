# DEV07 — Classifica e riproduci un'issue prima di correggerla

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: testo dell'issue, ambiente e accesso in lettura al codice | **Esempio d'uso**: `sb prompt DEV07: classifica e riproduci l'issue sul parsing dei percorsi`

## Scopo

Valutare una segnalazione prima di intervenire: tipo, gravità, completezza, duplicati e riproducibilità, per decidere se e come lavorarla.

## Quando usarlo

Quando arriva una nuova issue o un rapporto di errore non ancora verificato. Per correggere un difetto già riproducibile usa DEV02.

## Input

Testo dell'issue, passi di riproduzione dichiarati, versioni e ambiente, log o allegati, issue e task già tracciati.

## Attività specifiche

Classifica la segnalazione (difetto, richiesta, domanda, fuori perimetro) e stimane gravità e impatto. Cerca duplicati tra issue e tracker e verifica con REP08 se il residuo è già noto. Tenta una riproduzione minima nell'ambiente indicato senza modificare codice, configurazione o dati reali; se non riproducibile, separa diagnosi statica e prove e indica quali informazioni mancano. Non chiudere né commentare issue su sistemi esterni senza richiesta esplicita.

## Decisioni da raccogliere

Se più esiti sono plausibili, fermati e usa Function Calling o Tool Use a scelta multipla (es. `ask_question`, `AskUserQuestion`): una decisione per domanda, scelta raccomandata come prima opzione con `(Recommended)`.

- classificazione e priorità proposte;
- esito: correggere ora (DEV02), tracciare nel tracker, chiedere informazioni o scartare.

Senza lo strumento, elenca opzioni numerate e attendi la risposta. Non richiedere di nuovo ciò che è già autorizzato nel perimetro del task.

## Verifiche

Accerta che la riproduzione sia dimostrata con comandi e output o dichiarata non riuscita con i motivi. Distingui fatti osservati, ipotesi e preferenze.

## Consegna

Scheda di triage con classificazione, gravità, duplicati, esito della riproduzione, informazioni mancanti e azione consigliata; nessuna modifica al codice.

## Prompt vicini

- DEV02: Riproduci un difetto e correggine la causa.
- REP08: Ispeziona il repo, individua task residui e incrocia memorie e codice reale.
- PRG01: Trasforma una richiesta in requisiti e criteri di accettazione.
