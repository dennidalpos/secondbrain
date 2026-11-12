# Proposte di direttive comuni

Una proposta contiene problema, repository di origine, evidenze, contesti applicabili, controesempi e testo minimo. Non è una direttiva attiva.

Dopo approvazione esplicita dell'utente, modificare le sorgenti, verificarne il diff, aggiornare gli hash con il comando di approvazione documentato e sincronizzare. Una modifica al file non equivale ad approvazione. Nel dubbio non introdurre una regola.

## Revisioni e proposte

Più proposte possono portare la stessa etichetta di revisione quando correggono il testo senza cambiare `VERSION`. La proposta che contiene il testo attivo è quella indicata in `direttive/approved.json` (campo `proposal.path`).

| Proposta | Etichetta | Stato |
|---|---|---|
| `2026-11-01-v1.0` | 1.0 | approvata, storico |
| `2026-11-01-adr` | 1.1 | approvata, storico |
| `2026-11-02-para-runtime-trace` | 1.2 | approvata (regole PARA, nomi in `.runtime`, avviso di compattazione) |
| `2026-11-02-prompt-list-maintenance` | 1.2 | approvata (solo `workstation.template.md`) |
| `2026-11-02-direttive-snelle` | 1.2 | approvata, testo attivo (correzioni e meno ripetizioni, #234) |
| `2026-11-03-chiusura-riepilogo` | 1.3 proposta | non approvata; riepilogo minimo alla chiusura, #245 |
| `2026-11-03-nonblocking-dossiers` | 1.2 o 1.3 proposta | non approvata; integra #245 con scritture differite e contratto MCP di #292 |
| `2026-11-05-direttive-standard` | 1.0 (testo, nessun bump) | in attesa di approvazione; sezioni standard, testo ridotto, cartelle `.runtime` e sessioni |
| `2026-11-12-contesto-snello` | 1.1 | in attesa di approvazione; direttive globali, di postazione e blocco repository ridotti, chiusura senza accumulo, tetto 25.000 |

Nota su `approved.json`: il campo `authorization` riporta «dell utente» senza apostrofo. È la ricevuta dell'approvazione registrata e non si riscrive a mano (l'hash del README e la tracciabilità restano quelli approvati); viene sostituita dalla prossima approvazione con `approve-revision.ps1` (revisione 1.3, #255).
