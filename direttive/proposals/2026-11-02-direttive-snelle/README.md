# Proposta: direttive comuni corrette e senza ripetizioni (#234)

Stato: **approvata dall'utente in chat (2026-11-02)**, opzione «Solo correzioni»; la revisione resta 1.2 (nessun cambio di `VERSION`).

## Problema ed evidenze

- `workstation.template.md` dichiarava «`-Search` senza tetto salvo `-Budget`»: dopo il lotto 6 la ricerca ha un tetto predefinito (20 riscontri, 10.000 caratteri, dossier in lavoro).
- Ripetizioni tra testo comune e di postazione: gestione PARA (MEM05), regola di sintesi minima, descrizioni del tetto Slim, aree e codici del catalogo prompt.
- Misura: 11.814 → 10.957 caratteri (-7%). Un taglio maggiore richiederebbe di togliere regole e non è proposto.

## Testo minimo (diff)

- Postazione: ricerca con tetto predefinito (`-Budget`, `-Limit`, `-AllDossiers`); righe 1–2 e 4–5 accorpate; MEM05/PARA, sintesi minima, aree e codici SEC07/DOC01/DOC03 rimossi (restano nel testo comune e nel catalogo, raggiungibili con `get_prompt_home`).
- Comune: tetto 20.000 solo al primo caricamento, ricerche con tetto predefinito; .runtime in forma più breve.
- Invariati: scheda uniforme, regola del dubbio, comandi `sb`, `get_prompt_home`, «senza riassumerli».

## Controesempi e applicabilità

Nessuna regola operativa cambia. I repository non perdono istruzioni: MEM05 e la sintesi minima restano nel testo comune.

## Se approvata

`approve-revision.ps1 -ProposalPath direttive/proposals/2026-11-02-direttive-snelle -Authorization "<richiesta>"`, poi `secondbrain.ps1 -Sync` e `-Check`.
