# REP06 — Prepara il README GitHub con informazioni e asset verificati

> **Scope**: repo | **Modalità**: scrittura | **Cosa serve**: documentazione del repository e screenshot approvati | **Esempio d'uso**: `sb prompt REP06: genera readme github con flussi mermaid`

## Scopo

Presentare il prodotto ai visitatori GitHub con documentazione utile e fedele.

## Quando usarlo

Ritirato: usa REP02, che include la preparazione del README GitHub. Resta come storico e per i riferimenti esistenti.

Per creare o aggiornare la pagina README e le guide pubbliche; GitHub Pages escluso salvo richiesta.

## Input

Pubblico destinatario, funzionalità osservate, avvio reale, asset pubblicabili e licenza.

## Attività specifiche

Prepara un README con scopo, utilità, funzionalità reali, screenshot, avvio rapido, prerequisiti, limiti e assistenza. Riusa identità visiva esistente senza inventare capacità o badge. Arricchisci la presentazione con diagrammi di flusso e architetturali in formato Mermaid nativo (es. `flowchart TD/LR`, `sequenceDiagram`) renderizzati direttamente da GitHub per rappresentare i flussi operativi, i confini dei componenti e il transito dei dati verificati nel codice reale. Per screenshot usa REP07. Cita percorsi relativi e testo alternativo; colloca solo gli asset pubblici selezionati in docs/assets. Conserva prove e bozze in SecondBrain. Le attribuzioni pubbliche legittime non vanno rimosse indiscriminatamente. Nessuna pubblicazione o upload senza richiesta specifica.

## Verifiche

Verifica il Markdown renderizzato, link, immagini, rendering sintattico dei diagrammi Mermaid, modalità chiara/scura quando applicabile, comandi e badge. Esegui REP05 e dichiara ciò che non hai potuto renderizzare o provare.

## Consegna

README e guide con diagrammi Mermaid conformi, preview effettiva, fonti delle informazioni e limiti verificati.

## Prompt vicini

- REP02: Scrivi guide e README coerenti con il prodotto reale.
- REP05: Verifica contenuti e cronologia prima della pubblicazione.
- REP07: Acquisisci screenshot reali e prepara gli asset pubblici.
