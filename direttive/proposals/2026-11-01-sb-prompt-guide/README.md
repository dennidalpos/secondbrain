# Proposta concreta 4.3 — `sb prompt` come punto di partenza: primi passi e guide

Stato: **in attesa di approvazione esplicita dell'utente**. Non è una direttiva attiva: `direttive/approved.json` non è stato modificato e nessuna sincronizzazione è stata eseguita.

Testi da esaminare integralmente:

- [Principi comuni 4.3](AGENTS.global_ide.md) (SHA-256 `5DE913340B5EC87C4ABBA9E5BA94E6A12D41755E728EF2B8DB7EEB5A450C21A8`, invariato)
- [Integrazione postazione 4.3](workstation.template.md) (SHA-256 `EE88931F7CE28193B5E154E0671004D67021F64508EC32FB7BEEA77EC2833302`)

Modifica rispetto all'integrazione postazione attiva (riga «Prompt disponibili»): `sb prompt` senza argomenti riporta, oltre al link al catalogo e alla tabella dei comandi, i **primi passi** e le **guide** per chi usa il progetto per la prima volta (sicurezza e backup, setup, MCP, modifica di prompt e direttive), senza riassumerli e **senza eseguire** alcun primo passo che scriva file dell'utente se non richiesto.

Motivo: i nuovi utenti pubblici devono partire da `sb prompt` e sapere, prima di lanciare script, cosa viene modificato e dove stanno i backup.

Evidenze: `scripts/SecondBrain.Prompts.psm1` (`Get-SBWorkflowFirstSteps`, `Get-SBWorkflowGuides`, `Format-SBWorkflowHome`), strumento MCP `get_prompt_home`, guida `docs/safety-backups.md`, test in `scripts/test-secondbrain-workflows.ps1`.

Per attivare (solo dopo approvazione): `scripts/approve-revision.ps1 -Authorization <testo> -ConfigPath <config> -ProposalPath direttive/proposals/2026-11-01-sb-prompt-guide`, poi `scripts/secondbrain.ps1 -Sync` e `-Check`. La sincronizzazione riscrive il blocco gestito dell'`AGENTS.md` di ogni repository gestito: valutare se limitarla con `-Repository`.
