# MEM06 — Leggi memoria attiva, contesto e tracker del repository corrente

<role>
Sei un agente a inizio sessione: carichi la memoria del repository entro il budget di contesto e non oltre.
</role>

<context>
Da usare a inizio sessione o prima di pianificare nel repository corrente; anche per misurare il pacchetto iniziale o consultare il PARA centrale. Per elencare i task in dettaglio usa MEM04, per confrontarli con il codice REP08.
</context>

<inputs>
- il repository locale, il suo AGENTS.md e il dossier (`context.md`, `memory.md`, `tracker.json`).
</inputs>

<procedure>
1. Risolvi il dossier da `para.json` e `repository.json`; leggi `index.md`.
2. Carica contesto sintetico, memoria essenziale e proiezione dei task aperti nel profilo snello (30.000 caratteri, solo primo caricamento); chiedi il resto con `knowledge.ps1 -Startup -Profile Full` o `-Search`.
3. Leggi la fonte autorevole del tracker senza ripiego; non creare stub o memorie ridondanti.
4. Per misurare il pacchetto esegui `knowledge.ps1 -Startup -Report` (caratteri per parte, saturazione, peso delle direttive); se supera il tetto pianifica SYS05.
5. Per trovare altri dossier, aree o risorse risolvi le identità da `para-index.json` o `para.ps1 -Check`, leggi `para.json` e `brief.md`, distingui attive da ritirate o archiviate, e non riattivare archivi né collegare aree indipendenti.
</procedure>

<constraints>
- Carica approfondimenti e storico solo quando servono; tieni il codice distribuibile separato dalle memorie interne.
- Preserva i file personali e le differenze locali non autorizzate.
</constraints>

<exit_criteria>
- I percorsi del dossier sono validi e non provengono da archivi; le informazioni essenziali non sono troncate; il tracker è valido.
</exit_criteria>

<output_format>
Sintesi dello stato del repository, task aperti rilevanti, vincoli, piano per il lotto; su richiesta caratteri per parte con saturazione ed entità PARA trovate (percorso, stato).
</output_format>
