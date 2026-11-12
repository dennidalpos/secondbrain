# MEM06 — Leggi memoria, contesto e tracker del repository corrente ed elenca i task
<role>
Sei un agente a inizio sessione: carichi la memoria del repository entro il budget di contesto e non oltre, e presenti con chiarezza il suo tracker.
</role>
<context>
Da usare a inizio sessione, prima di pianificare o di scegliere il prossimo task nel repository corrente; anche per descrivere i task aperti e i problemi che risolvono, o per misurare il pacchetto iniziale. Per confrontare il tracker con il codice usa REP08, per eseguire un task REP01. Altri dossier ed entità PARA sono fuori perimetro: usa MEM05 da SecondBrain.
</context>
<inputs>
- il repository locale, il suo AGENTS.md e il dossier (`context.md`, `memory.md`, `tracker.json`).
</inputs>
<procedure>
1. Risolvi il dossier di questo repository da `para.json` e `repository.json`; leggi `index.md`.
2. Carica contesto sintetico, memoria essenziale e proiezione dei task aperti nel profilo snello (25.000 caratteri, solo primo caricamento); chiedi il resto con `knowledge.ps1 -Startup -Profile Full` o `-Search`.
3. Leggi la fonte autorevole del tracker dichiarata da `repository.json`, senza ripiego; non creare stub o memorie ridondanti.
4. Raggruppa i task per stato (aperti, in corso, bloccati, chiusi); per ogni task aperto riassumi l'obiettivo, il problema reale che risolve, i criteri di accettazione e le dipendenze bloccanti; ordina per priorità e mostra quali task sono pronti e quali attendono di essere sbloccati.
5. Per misurare il pacchetto esegui `knowledge.ps1 -Startup -Report` (caratteri per parte, saturazione, peso delle direttive); se supera il tetto pianifica SYS05.
</procedure>
<constraints>
- Sola lettura; non duplicare task né trattare ipotesi come fatti.
- Gli identificatori devono rispettare lo schema del tracker; le dipendenze citate devono esistere.
- Resta nel repository corrente: non leggere altri dossier né viste globali.
- Carica approfondimenti e storico solo quando servono; tieni il codice distribuibile separato dalle memorie interne.
- Preserva i file personali e le differenze locali non autorizzate.
</constraints>
<exit_criteria>
- I percorsi del dossier sono validi e non provengono da archivi; le informazioni essenziali non sono troncate; il tracker è valido.
- I task bloccati indicano il motivo reale; i task pronti sono chiaramente marcati.
</exit_criteria>
<output_format>
Sintesi dello stato del repository, Panoramica per stato ordinata per priorità (ID, obiettivo, problema risolto, dipendenze), Pronti ora, In attesa, vincoli, piano per il lotto; su richiesta caratteri per parte con saturazione.
</output_format>
