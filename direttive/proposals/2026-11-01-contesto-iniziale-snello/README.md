# Proposta concreta 4.3 — Contesto iniziale snello (20.000 caratteri) con livelli a richiesta

Stato: **in attesa di approvazione esplicita dell'utente**. Non è una direttiva attiva: `direttive/approved.json` non è stato modificato e nessuna sincronizzazione è stata eseguita.

Testi da esaminare integralmente:

- [Principi comuni 4.3](AGENTS.global_ide.md) (SHA-256 `DC71F0157A62D90CF87843EF7E5F9B979E45EE1B2A3EEB43AB6A40526C363CEA`)
- [Integrazione postazione 4.3](workstation.template.md) (SHA-256 `55BD29D05C7BB277CAB0B33C5C68DCA4EAE0CD91347C0727C49ECE4D65FC5295`)

Modifiche rispetto ai testi attivi:
- Principi comuni (punto sul caricamento): il pacchetto iniziale è snello, al più 20.000 caratteri (indice, sezioni essenziali, task pronti in forma breve, elenco dei livelli non caricati); il tetto vale solo per il primo caricamento, il contesto completo si carica poi senza ulteriore tetto in base alla richiesta. Nessuna informazione viene eliminata.
- Integrazione postazione (riga CLI): `knowledge.ps1 -Startup` usa il profilo snello per impostazione predefinita (`-Profile Full` e `-Search` senza tetto salvo `-Budget`; `-Report` misura caratteri e peso delle direttive).

Motivo: dopo `sb prompt` il pacchetto di avvio da ~48.500 caratteri occupava una quota rilevante della finestra di contesto.

Evidenze: `Get-SBStartupContext -Profile` e `Format-SBStartupReport` in `scripts/SecondBrain.Knowledge.psm1`, `knowledge.ps1 -Startup -Report`, strumento MCP `get_startup_context` con `profile`, test in `scripts/test-secondbrain-portable.ps1`, guida `docs/runtime-maintenance.md`.

Per attivare (solo dopo approvazione): `scripts/approve-revision.ps1 -Authorization <testo> -ConfigPath <config> -ProposalPath direttive/proposals/2026-11-01-contesto-iniziale-snello`, poi `scripts/secondbrain.ps1 -Sync` e `-Check`. La sincronizzazione riscrive il blocco gestito dell'`AGENTS.md` di ogni repository gestito e il blocco globale degli IDE: valutare se limitarla con `-Repository`.
