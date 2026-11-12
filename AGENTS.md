# Istruzioni del repository: SecondBrain

<!-- secondbrain:repository:begin -->
Direttive comuni applicate: revisione **1.1** — 2026-11-12. <!-- secondbrain:source global=8238B8C140EC9FE3C6E4002D94B0AADBB1EAE0E15A52566BF31854D2292AC06C workstation=CFB3267FB25931AF68B8791B8D01F31AC30D940679D6D3443567A45BE9FBA9A6 -->
## SecondBrain

Repository knowledge lives in the SecondBrain dossier; code, guides, and publishable assets stay here.

- Load the slim startup with the SecondBrain checkout's scripts/knowledge.ps1 -Startup or MCP get_startup_context, and follow its references for detail. If the root is unreachable, report the dossier as unavailable.
- Write only to this repository's dossier `01-projects/<repo>/`, only through SecondBrain scripts or MCP write tools. Work folders come from scripts/work.ps1 -Init; sessions, retention, and cleanup rules load from `sb prompt`.
- Commits, pushes, deletions, and publication require specific authorization.
<!-- secondbrain:repository:end -->

## Setup
- PowerShell 7.5+ e Git su Windows; nessuna dipendenza da installare. Gli script sono in `scripts/`, i testi in `direttive/`, la documentazione in `docs/`.
- Il clone è la radice SecondBrain: `.runtime/` (ignorata da Git) contiene configurazione, sessioni, fixture e backup della postazione.

## Verifiche
- Rapida e pura: `pwsh -NoProfile -File scripts/test-secondbrain.ps1 -Quick`; predefinita: senza opzioni; completa: `-Full`; un gruppo: `-Only quick|workflows|trackers|audit2|trace|concurrency|pending|sources|external-audit|git-environment|runtime|prompts|tracker-audit|mcp-writes|runner|ide|agents|lint|cleanclone|orchestrator-e2e` (`-Full` esegue le suite extra, `tracker-audit` compreso, in parallelo come processi separati; `-Sequential` le esegue una alla volta).
- App desktop `app/orchestrator` (Tauri 2): `npm ci` e `npm run build` (controllo TypeScript e build), `cargo test --manifest-path src-tauri/Cargo.toml`; guida in `docs/orchestratore.it.md`.
- Prompt: `scripts/build-prompts.ps1` rigenera gli indici dal catalogo e dalle schede, `-Check` segnala lo scostamento. Non modificare a mano i `README*.md` di `direttive/prompts/`.
- `scripts/secondbrain.ps1 -Check` e `scripts/ide-map.ps1 -Verify` verificano direttive, IDE e dossier.
- Le fixture dei test vanno in `.runtime/hosts/<host>/repos/tests-<hash>/fixture/`; i fallimenti dell’ACL in `concurrency` dipendono dall’ambiente e non da questo repository.

## Stile del codice
- PowerShell con `Set-StrictMode`, messaggi solo tramite chiavi `it`/`en` in `Add-SBMessages` (nessun `throw` o `Write-Host` con testo letterale), scritture solo con `Write-SBFile` e backup verificati.
- Prompt in inglese (`direttive/prompts/<CODICE>.md`) con controparte italiana (`it/`); i codici sono stabili e non si riutilizzano. Aggiungi o modifica prompt con SYS11.
- Le direttive comuni cambiano solo tramite proposta in `direttive/proposals/`, `scripts/approve-revision.ps1 -Preview` e approvazione esplicita; `VERSION` e `CHANGELOG.md` seguono la regola di versione.

## Sicurezza
- Nessun segreto, percorso personale o dato di account nel repository; le scansioni di pubblicazione (`scripts/publication.ps1` o MCP `check_publication`) precedono ogni push.
- Pulizie e migrazioni di `.runtime` (`scripts/cleanup.ps1 -Migrate`, `-Regenerable`) sono in anteprima per impostazione predefinita e richiedono `-Apply` con `-Authorization` esplicita.

## Pull request
- Una modifica per scopo, test pertinenti eseguiti e riportati, documentazione aggiornata; nessun commit o push senza richiesta specifica.
