# Istruzioni del repository: SecondBrain

<!-- secondbrain:repository:begin -->
Direttive comuni applicate: revisione **1.0** — 2026-11-05. <!-- secondbrain:source global=C06845FB809D4C540F2C780C0EFBE046BC5178E25FC46A279A4DDC888E8FF667 workstation=69147889C42BD2A55BBEDA96882E08F10B4C5D014DC903789FF36EE51236F624 -->
## SecondBrain

Direttive comuni e conoscenza del repository risiedono nel dossier SecondBrain; qui restano codice, guide e asset pubblicabili.

- Dossier: risolvilo per identità Git, indice PARA e repository.json. SECONDBRAIN_HOME viene dall’ambiente utente; se la radice non è raggiungibile, segnala l’indisponibilità del dossier. Per i progetti condivisi usa la radice UNC della squadra.
- Contesto: carica il profilo snello con scripts/knowledge.ps1 -Startup (o MCP get_startup_context) e approfondisci con i riferimenti restituiti.
- Chiusura: verifica i criteri di accettazione e aggiorna il tracker centrale; i task conclusi vanno nello storico, contesto e memoria contengono le sole novità verificate.
- Autorizzazioni: commit, push, cancellazioni e pubblicazione richiedono autorizzazione specifica.

### Cartelle SecondBrain e sessioni
- Build, cache, temporanei, fixture ed evidenze del prodotto stanno nelle cartelle locali del prodotto escluse da Git. Per le attività di SecondBrain crea le cartelle di lavoro dal clone SecondBrain con scripts/work.ps1 -Repository <identità> -Category <work|evidence|report|fixture|tmp> -Slug <nome> -Init -Task <descrizione> -SessionId <id>: producono .runtime/hosts/<host>/repos/<repo>/<categoria>/<yyyyMMdd>-<slug>/ con MANIFEST.json (proprietario, sessione, task, stato, scadenza). Non creare cartelle piatte o con altri nomi.
- Una cartella appartiene a una postazione, un utente e una sessione. Non scrivere nelle cartelle di altri utenti o postazioni; sulla radice condivisa di squadra si condividono solo dossier e access/.
- Sessione: per scritture prolungate apri scripts/access.ps1 -Start e chiudi con -End nello stesso script (try/finally); passa lo stesso SessionId alle CLI di SecondBrain, incluso work.ps1 per le sue cartelle di lavoro. Se la sessione è occupata, attendi o scegli un’altra attività: non forzare lock né cancellare marker.
- A fine sessione porta le evidenze o i rapporti utili nel dossier (history/), chiudi la cartella con lo stesso comando e -Close (aggiorna MANIFEST.json) e lascia fixture e tmp alla retention (7 giorni, ultime 5 conservate; work 30 giorni dalla chiusura; evidence e report mai automatici). Ricostruisci l’indice con scripts/cleanup.ps1 -RuntimeReport.
- Pulizia e migrazione (scripts/cleanup.ps1 -Migrate, -Regenerable) partono in anteprima e si applicano solo su richiesta esplicita, sulla propria postazione, con perimetro concreto e inattività delle sessioni.
- Backup, journal e artefatti ufficiali non si eliminano; i dati sensibili grezzi restano nell’area locale esclusa da Git.
<!-- secondbrain:repository:end -->

## Setup
- PowerShell 7.5+ e Git su Windows; nessuna dipendenza da installare. Gli script sono in `scripts/`, i testi in `direttive/`, la documentazione in `docs/`.
- Il clone è la radice SecondBrain: `.runtime/` (ignorata da Git) contiene configurazione, sessioni, fixture e backup della postazione.

## Verifiche
- Rapida e pura: `pwsh -NoProfile -File scripts/test-secondbrain.ps1 -Quick`; predefinita: senza opzioni; completa: `-Full`; un gruppo: `-Only quick|workflows|trackers|audit2|trace|concurrency|pending|sources|external-audit|git-environment|runtime|prompts|tracker-audit` (`-Full` esegue le suite extra, `tracker-audit` compreso, in parallelo come processi separati; `-Sequential` le esegue una alla volta).
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
