# REP02 — Scrivi guide e README coerenti con il prodotto reale

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: funzionalita implementate, comandi verificati e screenshot approvati | **Esempio d'uso**: `sb prompt REP02: aggiorna guide e genera flussi mermaid`

## Scopo

Scrivere o aggiornare guide, README e diagrammi di flusso che descrivano soltanto ciò che il prodotto fa davvero, per i destinatari indicati, con comandi ed esempi verificati.

## Quando usarlo

Per guide utente/manutentore, onboarding o README da creare o aggiornare.

## Input

Destinatari, uso previsto, documenti esistenti e parti da documentare.

## Attività specifiche

Verifica comandi, configurazione e comportamento sui file reali. Scrivi istruzioni orientate al compito, esempi senza segreti e prerequisiti effettivi. Aggiorna la fonte curata anziché output generati.

Integra diagrammi di flusso e architetturali in formato Mermaid (`flowchart TD/LR`, `sequenceDiagram`, `stateDiagram-v2`, `classDiagram`) inseriti direttamente nel Markdown per rappresentare visivamente architettura dei moduli, sequenze di chiamata, cicli di vita o pipeline di dati osservate nel codice reale. Segui la sintassi Mermaid standard compatibile con GitHub e gli IDE (es. etichette quotate per caratteri speciali nei nodi, assenza di tag HTML non supportati).

Per il README GitHub prepara scopo, utilità, funzionalità reali, screenshot, avvio rapido, prerequisiti, limiti e assistenza. Riusa l'identità visiva esistente senza inventare capacità o badge, cita percorsi relativi e testo alternativo, colloca solo gli asset pubblici selezionati in docs/assets e conserva prove e bozze in SecondBrain. Per gli screenshot usa REP07. Le attribuzioni pubbliche legittime non vanno rimosse indiscriminatamente. Nessuna pubblicazione o upload senza richiesta specifica; GitHub Pages escluso salvo richiesta.

Mantieni rapporti e dati personali in SecondBrain; le guide pubbliche non contengono percorsi o informazioni private.

## Verifiche

Verifica link, comandi e la corretta resa sintattica dei diagrammi Mermaid in ambiente compatibile; distingue esempi verificati da quelli illustrativi. Per il README controlla anche il Markdown renderizzato, le immagini, la modalità chiara/scura quando applicabile e i badge, ed esegui REP05 dichiarando ciò che non hai potuto renderizzare o provare. Non riscrivere memoria o storico per una semplice guida.

## Consegna

Documenti aggiornati (README compreso), diagrammi di flusso Mermaid verificati, preview effettiva, fonti delle informazioni, destinatari coperti e verifiche con limiti.

## Prompt vicini

- REP03: Documenta API e contratti a partire dall’implementazione.
- MEM01: Allinea istruzioni locali, contesto, memoria e tracker.
- REP05: Verifica contenuti e cronologia prima della pubblicazione.
- REP07: Acquisisci screenshot reali e prepara gli asset pubblici.
