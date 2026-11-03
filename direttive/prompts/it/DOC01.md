# DOC01 — Scrivi guide e README coerenti con il prodotto reale

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: funzionalità implementate, comandi verificati e screenshot approvati | **Esempio d'uso**: `aggiorna le guide e aggiungi diagrammi di flusso Mermaid`

## Scopo

Scrivere o aggiornare guide, README e diagrammi di flusso che descrivono solo ciò che il prodotto fa davvero, per il pubblico indicato, con comandi ed esempi verificati.

## Quando usarlo

Per guide per utenti o maintainer, materiale di onboarding o un README da creare o aggiornare.

## Input

Pubblico, uso previsto, documenti esistenti e le parti da documentare.

## Attività specifiche

Verifica comandi, configurazione e comportamento sui file reali. Scrivi istruzioni orientate ai compiti, esempi senza segreti e i veri prerequisiti. Aggiorna la sorgente curata e non l'output generato.

Aggiungi diagrammi di flusso e di architettura in Mermaid (`flowchart TD/LR`, `sequenceDiagram`, `stateDiagram-v2`, `classDiagram`) direttamente nel Markdown per mostrare l'architettura dei moduli, le sequenze di chiamate, i cicli di vita o le pipeline di dati osservati nel codice reale. Segui la sintassi Mermaid standard compatibile con GitHub e con gli IDE (per esempio etichette tra virgolette per i caratteri speciali nei nodi, nessun tag HTML non supportato).

Per un README GitHub prepara scopo, utilità, funzionalità reali, screenshot, avvio rapido, prerequisiti, limiti e supporto. Riusa l'identità visiva esistente senza inventare capacità o badge, usa percorsi relativi e testo alternativo, metti in docs/assets solo gli asset pubblici selezionati e tieni evidenze e bozze fuori dal repository. Per gli screenshot usa DOC03. Le attribuzioni pubbliche legittime non vanno rimosse in modo indiscriminato. Nessuna pubblicazione o caricamento senza una richiesta specifica; GitHub Pages è escluso salvo richiesta.

Tieni rapporti e dati personali fuori dalle guide pubbliche: non devono contenere percorsi o informazioni private.

## Verifiche

Verifica collegamenti, comandi e che i diagrammi Mermaid si visualizzino correttamente in un ambiente compatibile; distingui gli esempi verificati da quelli illustrativi. Per il README controlla anche il Markdown renderizzato, le immagini, la modalità chiara/scura dove applicabile e i badge, ed esegui SEC07, dichiarando ciò che non hai potuto renderizzare o provare. Non riscrivere cronologia o note per una semplice guida.

## Consegna

Documenti aggiornati (README compreso), diagrammi di flusso Mermaid verificati, un'anteprima effettiva, le fonti delle informazioni, i pubblici coperti e i controlli con i loro limiti.

## Prompt vicini

- DOC02: Documenta API e contratti a partire dall'implementazione.
- SEC07: Controlla diff, repository e cronologia per dati sensibili prima di pubblicare.
- DOC03: Cattura screenshot reali e prepara asset pubblici.
