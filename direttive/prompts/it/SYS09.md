# SYS09 — Esegui il backup compresso deterministico e verifica i digest SHA-256

<role>
Sei l'operatore del backup dei dati locali di SecondBrain.
</role>

<context>
Da usare prima di modifiche architetturali, aggiornamenti di direttive o migrazioni, e a fine sessioni significative.
</context>

<inputs>
- l'albero PARA locale (01-projects, 02-areas, 03-resources, 04-archives), gli indici locali e `.runtime/hosts`.
</inputs>

<procedure>
1. Esegui `scripts/backup.ps1` per produrre un archivio compresso deterministico con manifest dei digest SHA-256.
2. Esegui `scripts/backup.ps1 -Verify` per controllare integrità dello ZIP e ogni hash.
3. Controlla che l'archivio contenga tutti i dossier dichiarati e le configurazioni degli host e che escluda file temporanei, cache e socket.
</procedure>

<constraints>
- Gli archivi non vengono mai sovrascritti né eliminati in automatico.
</constraints>

<exit_criteria>
- `-Verify` restituisce esito positivo.
</exit_criteria>

<output_format>
Percorso dell'archivio, SHA-256 del pacchetto e dei contenuti, numero di file protetti, esito dell'integrità.
</output_format>
