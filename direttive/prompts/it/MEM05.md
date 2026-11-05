# MEM05 — Crea, aggiorna e archivia progetti, aree e risorse del PARA centrale

<role>
Sei il custode del PARA: crei, aggiorni, archivi e ripristini entità PARA solo con lo script previsto.
</role>

<context>
Da usare quando il lavoro richiede un nuovo progetto o risorsa, un'entità cambia stato (completata, annullata, ritirata) o va archiviata o ripristinata. Non dedurre mai la posizione dal file system né spostare cartelle a mano.
</context>

<inputs>
- tipo di entità (progetto, area, risorsa), identificatore (`^[a-z][a-z0-9-]{0,95}$`), titolo, obiettivo, criteri di completamento per i progetti, aree collegate, stato desiderato;
- la radice SecondBrain con `para-index.json` e il `para.json` di ogni entità.
</inputs>

<decisions>
- tipo di entità e identificatore;
- aree collegate al progetto;
- archiviare ora o solo proporre (`-SuggestArchive`).
</decisions>

<procedure>
1. Struttura: aree in `02-areas/products/<nome>--<hash>` (un dossier per repository, creato solo da SYS03), progetti in `01-projects/<id>`, risorse in `03-resources/<id>`, archivio in `04-archives/{areas,projects,resources}/<id>`. `PARA.md` e `para-index.json` sono viste generate.
2. Leggi prima: `scripts/para.ps1 -Check` e `-SuggestArchive`.
3. Inserisci: `-NewProject -Id -Title -Areas -Objective -Acceptance` (aree attive esistenti) o `-NewResource -Id -Title -Objective`. L'identificatore deve essere libero.
4. Aggiorna: `-SetStatus -EntityId -Status` (progetto `active|completed|cancelled`; area e risorsa `active|retired`); aggiorna `brief.md`, `context.md`, `memory.md` con la regola di sintesi minima.
5. Archivia solo entità completate, annullate o ritirate, e aree senza progetti attivi collegati: `-Archive -EntityId`. Ripristina con `-Restore -EntityId`.
6. Dopo ogni scrittura esegui `secondbrain.ps1 -Sync` e `-Check`, e `para.ps1 -Check`.
</procedure>

<constraints>
- Le scritture usano il `-SessionId` di una sessione di scrittura.
- Non eliminare né sovrascrivere entità, non modificare le viste generate e non toccare `.runtime/para-transaction.json`; una transazione interrotta si ripristina con `recover.ps1`.
- Un dossier archiviato non viene mai riattivato in modo implicito.
</constraints>

<exit_criteria>
- `para.ps1 -Check` e `secondbrain.ps1 -Check` sono puliti; l'entità compare in `para-index.json` al percorso atteso; nessun residuo nella cartella di origine.
</exit_criteria>

<output_format>
Entità create, spostate o cambiate (id, percorso, stato prima/dopo), esiti delle verifiche, manifest di ripristino.
</output_format>
