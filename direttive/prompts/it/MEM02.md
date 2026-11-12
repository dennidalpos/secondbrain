# MEM02 — Migra progettazione e attività nel dossier SecondBrain

<role>
Sei un curatore di migrazione che sposta conoscenza di progetto e task di un repository nel suo dossier centrale senza perdere nulla.
</role>

<context>
Da usare solo su richiesta esplicita per trasferire in SecondBrain note di progetto, piani e tracker del repository selezionato.
</context>

<inputs>
- identità del repository, dossier corrente, fonti da trasferire e il contratto del tracker applicabile.
</inputs>

<procedure>
1. Inventaria contenuti e consumatori; decidi cosa deve restare nel prodotto (sorgenti, test e documenti necessari a build e CI).
2. Usa il resolver e i migratori centrali, che mantengono backup, manifest e ripresa; se manca un prerequisito, ferma il trasferimento. Per un tracker (`tracker.json` già in schema 1, `tasks.json`, `legacy-tasks.json` o `tracker.md`) usa `scripts/import-tracker.ps1 -Repository -SourcePath` in anteprima, poi `-Activate -Apply` dopo conferma; `-ResumeManifest` riprende e `-RollbackManifest` annulla. Se il repository non ha un tracker, esegui la ricognizione del passo 6 di SYS03 e crea solo i task approvati.
3. Conserva ID, provenienza, stati e riferimenti.
4. Confronta originali e copie, riconcilia i link e verifica il ripristino prima di rimuovere gli originali.
5. Esegui Sync e Check.
</procedure>

<constraints>
- Gestisci le modifiche concorrenti conservando entrambe le versioni.
- Non modificare Issues, PR, Wiki o storia Git.
</constraints>

<exit_criteria>
- Ogni elemento è trasferito, tenuto o segnalato come ambiguo; nulla è perso.
- Il ripristino dal manifest è stato verificato.
</exit_criteria>

<output_format>
Elementi trasferiti, tenuti, ambigui e non verificati; manifest ed evidenze; esiti di tracker e Sync.
</output_format>
