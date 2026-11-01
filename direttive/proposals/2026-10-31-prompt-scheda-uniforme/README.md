# Proposta concreta 4.3 — Scheda prompt uniforme, ID/alias e regola vincolante sui dubbi

Stato: **in attesa di approvazione esplicita dell'utente**. Non è una direttiva attiva: `direttive/approved.json` non è stato modificato e nessuna sincronizzazione è stata eseguita.

Task: `SB-EVO-20261031-06` (dipende da `SB-EVO-20261031-05`, ID e alias dei prompt).

Testi da esaminare integralmente:

- [Principi comuni 4.3](AGENTS.global_ide.md) (SHA-256 `5DE913340B5EC87C4ABBA9E5BA94E6A12D41755E728EF2B8DB7EEB5A450C21A8`)
- [Integrazione postazione 4.3](workstation.template.md) (SHA-256 `FA4D32FF8CE675B139CF512A9804FF6218294171DA8035AEF1DF61570A7B4FD2`)

Modifiche rispetto alla 4.2:
- Principi comuni: nel primo punto Function Calling / Tool Use passa da «preferenziale» a vincolante per i dubbi: fermarsi e chiedere a scelta multipla, senza procedere per ipotesi. Revisione 4.3 — 2026-10-31.
- Integrazione postazione: `sb prompt` accetta ID immutabile (`pmt-…`), codice o alias; descrive la scheda uniforme (ID e codice, Titolo, Cosa fa, Esempio d'uso, Modalità, Ambito, Cosa serve, Regola vincolante) esposta allo stesso modo da CLI, MCP e composizione, e ripete la regola sui dubbi.

Evidenze: la scheda e la regola sono già generate dal catalogo (`Format-SBWorkflowCard` in `scripts/SecondBrain.Prompts.psm1`) e verificate da `scripts/test-secondbrain-workflows.ps1` e `test-secondbrain-portable.ps1`.

Per attivare (solo dopo approvazione): `scripts/approve-revision.ps1 -Authorization <testo> -ConfigPath <config> -ProposalPath direttive/proposals/2026-10-31-prompt-scheda-uniforme`, poi `scripts/secondbrain.ps1 -Sync` e `-Check`. La sincronizzazione riscrive il blocco gestito dell'`AGENTS.md` di ogni repository gestito (cambia la revisione e gli hash nel blocco): valutare se limitarla con `-Repository`.