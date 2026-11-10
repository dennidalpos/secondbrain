# Proposta: ciclo memorie per repository

Proposta operativa del piano autorizzato il 5 novembre 2026. Non attivata e non distribuita. Il codice accetta envelope normalizzati autorizzati; la cattura nativa nei client resta da qualificare. Nessun numero di versione prodotto viene modificato.

La proposta aggiunge ai tre generatori comuni il contratto di persistenza per turno, i livelli di memoria per repository, il filtro dei privati, le evidenze, il caricamento selettivo e la manutenzione a lotti. Nel testo comune distingue la risintesi SYS05 dagli aggiornamenti incrementali MEM03 nei soli repository abilitati; le altre prescrizioni correnti sono preservate. I dettagli osservabili e i limiti sono in docs/riferimento/memory-cycle.md.

Prima dell'attivazione: approve-revision.ps1 -Preview -ProposalPath <questa-cartella>, approvazione esplicita dell'hash corrente, quindi attivazione del solo pilota SecondBrain e prove reali. Le fixture non valgono come prova GUI o SMB. Nessun commit, push, cancellazione o importazione retroattiva incluso.
