# Proposta concreta 4.3 — Schermata iniziale di `sb prompt` con link al catalogo e comandi

Stato: **in attesa di approvazione esplicita dell'utente**. Non è una direttiva attiva: `direttive/approved.json` non è stato modificato e nessuna sincronizzazione è stata eseguita.

Testi da esaminare integralmente:

- [Principi comuni 4.3](AGENTS.global_ide.md) (SHA-256 `5DE913340B5EC87C4ABBA9E5BA94E6A12D41755E728EF2B8DB7EEB5A450C21A8`, invariato)
- [Integrazione postazione 4.3](workstation.template.md) (SHA-256 `58B3CE129E60FB682211F050F5A1D2976ECBB531BB7F0B7C24A0449C7DD36BCB`)

Modifiche rispetto all'integrazione postazione attiva (riga «Prompt disponibili»):
- `sb prompt` senza argomenti riporta il link al file Markdown del catalogo completo e la tabella dei comandi `sb` con descrizione, senza riassumerli.
- `sb prompt tutti` riporta l'elenco compatto integrale, una riga per prompt, mai troncato né riassunto.
- `sb prompt ambito AREA` accetta id, prefisso dei codici o nome (test, TST, sistema).

Motivo: l'elenco a 5 righe per prompt (427 righe) veniva riassunto in chat, quindi risultava incompleto. Il catalogo completo resta nel file Markdown generato.

Evidenze: `scripts/prompts.ps1` (schermata predefinita, `-List -Compact`), tool MCP `get_prompt_home` e `list_prompts` con `compact`, verificati da `scripts/test-secondbrain-workflows.ps1` e `test-secondbrain-portable.ps1`.

Per attivare (solo dopo approvazione): `scripts/approve-revision.ps1 -Authorization <testo> -ConfigPath <config> -ProposalPath direttive/proposals/2026-10-31-sb-prompt-home`, poi `scripts/secondbrain.ps1 -Sync` e `-Check`. La sincronizzazione riscrive il blocco gestito dell'`AGENTS.md` di ogni repository gestito: valutare se limitarla con `-Repository`.
