# Script SecondBrain citati come script del checkout SecondBrain

Task OnlyWorkspace #098 (OW-DOC-AGENTS-REFS-20261104), origine: audit AUD01 DOC-04 del 4 novembre 2026, riverificato l'8 novembre 2026.

**Problema.** Il blocco gestito di `AGENTS.md` cita `scripts/knowledge.ps1`, `scripts/access.ps1` e `scripts/cleanup.ps1` senza dire che stanno nel checkout SecondBrain. Nei repository di prodotto la cartella `scripts/` non li contiene (verificato in OnlyWorkspace: assenti `knowledge.ps1`, `prompts.ps1`, `work.ps1`, `access.ps1`, `cleanup.ps1`).

**Contesti applicabili.** Ogni repository di prodotto con il blocco gestito `AGENTS.repo.managed.md`.

**Controesempio.** `scripts/work.ps1` è già qualificato («from the SecondBrain checkout»): non cambia.

**Testo minimo.** Solo `AGENTS.repo.managed.md`: la riga di caricamento Slim precisa «run from the SecondBrain checkout (it is not in this repository)»; `access.ps1` e `cleanup.ps1` diventano «the SecondBrain checkout's scripts/…». `AGENTS.global_ide.md` e `workstation.template.md` restano identici a `2026-11-06-english-directives`. Nessun cambio di `VERSION` e di etichetta (1.0).

Anteprima: `scripts/approve-revision.ps1 -Preview -ProposalPath direttive/proposals/2026-11-08-script-checkout-refs`. L'applicazione richiede hash esaminato e autorizzazione esplicita (data nel campo `authorization`).
