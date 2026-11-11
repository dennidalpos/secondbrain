# Tetto del primo caricamento a 50.000 caratteri

Origine: richiesta della persona titolare dell'11 novembre 2026 (alert del contesto a 50.000 caratteri) e implementazione in `Get-SBSlimStartupBudget`.

**Problema.** Le direttive comuni indicavano 30.000 caratteri per il primo caricamento, ma il tetto del profilo Slim è ora 50.000 (fonte unica `Get-SBSlimStartupBudget`); il testo e il codice non coincidevano.

**Contesti applicabili.** Direttive globali degli IDE (`AGENTS.global_ide.md`). Il testo di postazione resta invariato.

**Testo minimo.** Una sola modifica: «within 30,000 characters» diventa «within 50,000 characters» nel principio «Load in layers».

Anteprima: `scripts/approve-revision.ps1 -Preview -ProposalPath direttive/proposals/2026-11-11-startup-cap-50k`.
