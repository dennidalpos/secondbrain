# DEV07 — Fai il triage di una segnalazione e riproducila, senza modificare il codice

> **Scope**: repo/area | **Modalità**: lettura | **Cosa serve**: testo della segnalazione, ambiente e accesso in lettura al codice | **Esempio d'uso**: `fai il triage e riproduci la segnalazione sul parsing dei percorsi`

## Scopo

Valutare una segnalazione prima di agire: tipo, gravità, completezza, duplicati e riproducibilità, per decidere se e come lavorarci.

## Quando usarlo

Quando arriva una nuova segnalazione o un rapporto di errore non verificato. Per correggere un difetto già riproducibile usa DEV02; per trovare la causa radice dai log COM05.

## Input

Testo della segnalazione, passi di riproduzione dichiarati, versioni e ambiente, log o allegati, segnalazioni e task già tracciati.

## Attività specifiche

Classifica la segnalazione (difetto, richiesta, domanda, fuori ambito) e stima gravità e impatto. Cerca duplicati tra segnalazioni e backlog e usa REP08 per verificare se il residuo è già noto. Tenta una riproduzione minima nell'ambiente indicato senza modificare codice, configurazione o dati reali; se non è riproducibile, separa la diagnosi statica dalle evidenze e dichiara quali informazioni mancano. Non chiudere né commentare segnalazioni in sistemi esterni senza una richiesta esplicita.

## Decisioni da raccogliere

- classificazione e priorità proposte;
- esito: correggere ora (DEV02), tracciare nel backlog, chiedere informazioni o scartare.

## Verifiche

Assicurati che la riproduzione sia mostrata con comandi e output oppure dichiarata non riuscita con i motivi. Distingui fatti osservati, ipotesi e preferenze.

## Consegna

Nota di triage con classificazione, gravità, duplicati, esito della riproduzione, informazioni mancanti e azione consigliata; nessuna modifica al codice.

## Prompt vicini

- DEV02: Riproduci un difetto e correggine la causa.
- REP08: Ispeziona il repo e trova i task residui rispetto al codice reale.
- PRG01: Trasforma una richiesta in requisiti e criteri di accettazione.
- COM05: Analizza log e incidenti per trovare la causa radice, senza toccare il codice.
