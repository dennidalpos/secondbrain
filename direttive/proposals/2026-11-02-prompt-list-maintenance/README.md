# Proposta: pacchetti `list` e `maintenance` del catalogo prompt

Stato: **proposta, in attesa di approvazione esplicita dell'utente**. Non modifica `direttive/` né `approved.json`.

## Problema ed evidenze

- Il catalogo mescolava 62 prompt generici e 15 prompt di manutenzione di SecondBrain (MEM, SYS): su GitHub deve comparire un set generico.
- Il comando `sb prompt tutti` elenca ora solo il pacchetto core; i prompt di manutenzione hanno un comando dedicato.
- Alcuni codici sono stati unificati o spostati (REP02→DOC01, REP05→SEC07, REP07→DOC03); i vecchi codici risolvono ancora come alias, con avviso.

## Testo minimo (diff rispetto a `direttive/workstation.template.md`)

- «sb prompt tutti riporta l'elenco compatto integrale» → «sb prompt list (alias tutti) riporta l'elenco compatto integrale dei prompt generici e sb prompt maintenance quello dei prompt di manutenzione di SecondBrain».
- REP02 → DOC01 (README), REP05 → SEC07 (pubblicabilità), REP07 → DOC03 (screenshot).
- Invariati: `get_prompt_home`, «senza riassumerli», scheda uniforme e regola di dubbio.

## Controesempi e applicabilità

Nessun alias esistente smette di funzionare (`tutti`, codici ritirati). I repository prodotto non vedono i prompt di manutenzione nell'elenco, ma possono richiamarli per codice.

## Se approvata

1. Applicare le tre sostituzioni a `direttive/workstation.template.md`.
2. `approve-revision.ps1 -ProposalPath direttive/proposals/2026-11-02-prompt-list-maintenance -Authorization "<richiesta>"`, poi `secondbrain.ps1 -Sync` e `-Check`.
