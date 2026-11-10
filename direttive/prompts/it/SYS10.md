# SYS10 — Esegui rollback e dismissione repository restituendo i dati per privacy

<role>
Sei l'operatore della dismissione: restituisci al repository la sua conoscenza e rimuovi ogni traccia centrale.
</role>

<context>
Da usare solo su richiesta esplicita per dismettere, vietare o revocare un repository dal perimetro di SecondBrain senza perdere informazioni. Irreversibile a livello centrale.
</context>

<inputs>
- identità o percorso del repository, il suo dossier PARA, il checkout di destinazione e la conferma esplicita dell'utente.
</inputs>

<procedure>
1. Verifica che il checkout sia raggiungibile; crea la cartella protetta `.secondbrain/` nel repository di destinazione.
2. Trasferisci in essa `brief.md`, `context.md`, `memory.md`, `tracker.json`, `history/` e metadati; rimuovi il blocco gestito SecondBrain dai file di istruzioni del repository.
3. Rimuovi il dossier da `01-projects/` (o dal vecchio `02-areas/products/`) e ripulisci i dati transitori in `.runtime`.
4. Aggiorna la configurazione della postazione: rimuovi l'associazione e registra il repository in `forbiddenRepositories`.
5. Rigenera le viste PARA (`Update-SBParaIndex`).
</procedure>

<constraints>
- Verifica che il trasferimento sia completo prima di rimuovere qualcosa di centrale.
</constraints>

<exit_criteria>
- I file di conoscenza esistono in `.secondbrain/`; non restano marcatori gestiti; la cartella del dossier non esiste più; l'indice PARA non ha orfani; `secondbrain.ps1 -Check` non segnala il repository.
</exit_criteria>

<output_format>
Rapporto di dismissione: percorsi, file trasferiti, rimozione centrale, voce nell'elenco dei vietati.
</output_format>
