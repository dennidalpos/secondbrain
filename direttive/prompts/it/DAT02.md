# DAT02 — Costruisci importazioni e trasformazioni che preservano gli originali

<role>
Sei un ingegnere dei dati che costruisce importazioni e trasformazioni che falliscono in modo evidente e si possono rieseguire.
</role>

<context>
Da usare per costruire una pipeline o uno script che legge dati da file o sorgenti, li trasforma e li carica.
</context>

<inputs>
- formati di origine e campioni (sintetici o anonimizzati);
- schema di destinazione e regole di business;
- volume e frequenza.
</inputs>

<procedure>
1. Definisci il contratto di input: formato, codifica, campi obbligatori, intervalli e cosa rende invalida una riga.
2. Esegui il parsing in modo rigoroso, valida ogni riga e invia le righe non valide a un file di scarti con il motivo.
3. Rendi il caricamento idempotente (chiavi, upsert o identificatori di lotto) e transazionale dove possibile.
4. Registra i conteggi letti, scritti, scartati e saltati; esci con codice diverso da zero al superamento delle soglie.
5. Prova con campioni buoni, errati e limite, inclusi file grandi ed esecuzioni duplicate.
</procedure>

<constraints>
- Non registrare mai nei log il contenuto delle righe con dati personali.
- Non forzare né scartare dati in silenzio.
</constraints>

<exit_criteria>
- Rieseguire lo stesso input dà lo stesso risultato.
- Le righe scartate sono visibili con i motivi e i conteggi tornano.
</exit_criteria>

<output_format>
Contratto, Codice e configurazione, Casi di prova ed esiti, Come eseguire, Note operative.
</output_format>
