# Istruzioni del repository: SecondBrain

<!-- secondbrain:repository:begin -->
Direttive comuni applicate: revisione **1.0** — 2026-11-04. <!-- secondbrain:source global=1A5F2C9A0CB77BAF17E938117EB61CB081A0C74612883844586592CB3013D3AC workstation=1EEB3165818F566AB6D830EB65A107EB6E2AF79A62BF2E26558A1B441E67DBEE -->
SecondBrain integra conoscenza e direttive comuni del repository.
Risolvi SECONDBRAIN_HOME dall’ambiente utente. Se la radice configurata non è raggiungibile, segnala l’indisponibilità del dossier. Per i progetti condivisi usa la radice UNC della squadra.
Risolvi il dossier per identità Git, indice PARA e repository.json. Carica il profilo Slim tramite scripts/knowledge.ps1 -Startup o MCP get_startup_context. Approfondisci con i riferimenti restituiti dal pacchetto.
Verifica i criteri di accettazione e aggiorna il tracker centrale alla chiusura. I task completati o annullati vanno nello storico; contesto e memoria contengono le sole novità verificate.
Conserva nel repository codice, guide e asset pubblicabili. Memorie private, tracker, backup e output operativi risiedono in SecondBrain.
Commit, push, cancellazioni e pubblicazione richiedono autorizzazioni specifiche.
<!-- secondbrain:repository:end -->

## Setup
- PowerShell 7.5+ e Git su Windows; nessuna dipendenza da installare. Gli script sono in `scripts/`, i testi in `direttive/`, la documentazione in `docs/`.
- Il clone è la radice SecondBrain: `.runtime/` (ignorata da Git) contiene configurazione, sessioni, fixture e backup della postazione.

## Verifiche
- Rapida e pura: `pwsh -NoProfile -File scripts/test-secondbrain.ps1 -Quick`; predefinita: senza opzioni; completa: `-Full`; un gruppo: `-Only quick|workflows|trackers|audit2|trace|concurrency|pending|sources|external-audit|git-environment|runtime|prompts`.
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
