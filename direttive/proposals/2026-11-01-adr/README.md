# Proposta: ADR leggere, CHANGELOG e rimando a REP02

Stato: **approvata dall'utente il 2026-11-01 come revisione 1.1** (`VERSION` 1.1.0); registrata in `direttive/approved.json`.

- `AGENTS.global_ide.md`: l'intestazione riporta «Revisione 1.1 — 2026-11-01».

## Problema ed evidenze

- La convenzione «Decisione: … — Motivo: …» è già in uso in `memory.md`, in MEM01, nelle guide e nella chiusura composta, ma non è nelle direttive comuni (task `SB-EVO-METHOD-ADR-20261101`, decisione utente 2026-11-01: adottare).
- La regola sul cambio di versione non cita il `CHANGELOG.md`, ammesso in `check-distribution.ps1` e aggiornato solo con cambio accettato.
- `workstation.template.md` rimanda a REP06, ritirato e fuso in REP02 (risolve ancora con avviso).

## Testo minimo (diff rispetto a `direttive/`)

- `AGENTS.global_ide.md`, bullet «Cambio di versione»: dopo «esegui il cambio in autonomia ovunque serva» aggiunta «, registrando nel CHANGELOG.md soltanto il numero accettato».
- `AGENTS.global_ide.md`, bullet «A chiusura del task»: dopo «in memory.md» aggiunta «(ogni decisione in una riga «Decisione: … — Motivo: …», senza file ADR separati)».
- `workstation.template.md`: «REP06 prepara README» → «REP02 prepara README».

## Controesempi e applicabilità

Nessuna ADR in file separati: evita nuovi artefatti e rispetta la sintesi minima. Vale per tutti i repository con dossier; nessun impatto sui prodotti oltre al blocco gestito di `AGENTS.md`.

## Se approvata

1. Decidere la revisione (le direttive riportano la stessa major.minor di `VERSION`: test in workflows). Un cambio a 1.1 richiede la tua conferma e il cambio di `VERSION`, `CHANGELOG.md` e dei riferimenti.
2. `scripts/approve-revision.ps1 -Authorization "<approvazione>" -ConfigPath <config> -ProposalPath direttive/proposals/2026-11-01-adr` (copia i testi, aggiorna gli hash in `approved.json`).
3. Verificare il diff, `secondbrain.ps1 -Sync` e `-Check`, suite directives/workflows. Commit e push solo su richiesta.
