# Accessi e concorrenza

Leggere direttamente `AGENTS.md` e dossier: la consultazione non richiede processi `-Hold`. Una singola Sync acquisisce e rilascia i lock automaticamente. Per vedere i titolari:

```powershell
./scripts/access.ps1 -Status          # sola lettura
./scripts/access.ps1 -Status -Purge   # elimina prima le sessioni chiuse, scadute o abbandonate da oltre 60 minuti
./scripts/access.ps1 -Queue           # coda FIFO dei writer in attesa (ticket waiting/orphan); -Queue -Purge rimuove i soli orfani
```

## Sessione di scrittura prolungata

Eseguire apertura, lavoro e chiusura nello stesso processo/script. Passare `-SessionId` agli script SecondBrain:

```powershell
$cfg = (Resolve-Path .runtime/hosts/<id>/workstation.json).Path
$session = & pwsh -NoProfile -File scripts/access.ps1 -Start -Mode Write `
  -Client Codex -Repository example-user/secondbrain `
  -TargetPath (Get-Location).Path -ConfigPath $cfg | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Sessione non aperta' }
try {
    # Modifiche concordate; poi sincronizzare.
    & pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync `
      -ConfigPath $cfg -SessionId $session.sessionId
    if ($LASTEXITCODE -ne 0) { throw 'Controllare esito della Sync' }
} finally {
    & pwsh -NoProfile -File scripts/access.ps1 -End `
      -ConfigPath $cfg -SessionId $session.sessionId
}
```

La sessione scade da sola dopo 30 minuti senza rinnovo (`sessionTimeoutSeconds` in `config/shared.json`, intero tra 10 e 86400, predefinito 1800): lease e heartbeat terminano, una sessione esclusiva rilascia `writer.lock` e il suo `SessionId` non scrive più. Se il processo di supporto viene interrotto la sessione risulta `abandoned` e il lock è libero. Per proseguire usare `access.ps1 -Renew -ConfigPath $cfg -SessionId $session.sessionId` durante il lavoro. `-Start` avvia un supporto nascosto che mantiene lease e heartbeat.

Una normale sessione `Write` registra l'identita del lavoro e non mantiene `writer.lock` per tutta la durata. Ogni CLI acquisisce il lock solo durante l'operazione centrale. Per task, memoria, contesto e rapporti usare i [comandi con scritture differite](pending-writes.md): salvano la richiesta e continuano se il centro e occupato. La sessione non protegge scritture dirette con editor o API del filesystem. `-Exclusive` mantiene il comportamento esclusivo, per prove o operazioni esplicitamente circoscritte; non e la modalita ordinaria degli agenti.

## Lock e limiti

`writer.lock` ammette un solo writer per archivio; `operation.lock` serializza le operazioni, anche della stessa sessione. Un writer che trova il lock occupato attende (predefinito 60 s: `-WaitSeconds`, `SECONDBRAIN_LOCK_WAIT_SECONDS` o `lockWaitSeconds` in `config/shared.json`), scrive il titolare su stderr e solo a timeout esce con 3 (per le operazioni fuori dalla coda dei dossier, incluso `mcp-server.ps1 -Pair -Apply`). L'attesa è in **coda FIFO**: ogni writer prende un ticket in `.runtime/access/queue/` (nome ordinato per istante di arrivo) e apre `writer.lock` solo quando è il primo ticket vivo, così chi arriva prima entra prima. Ogni ticket ha una lease esclusiva: se il processo muore, la lease diventa apribile e il ticket orfano viene rimosso dai successivi senza forzare alcun lock. `access.ps1 -Queue` elenca i ticket (`waiting` o `orphan`) e con `-Purge` rimuove soltanto gli orfani. Check, prompt, `knowledge.ps1` in lettura, verifica IDE e MCP non prendono lock bloccanti: segnalano un writer attivo o una transazione pendente come avviso (`warnings`). Per scritture personalizzate che usano le API, racchiudere l'operazione in `Enter-SBOperation` / `Exit-SBOperation`. Uso con più PC: [shared-brain.md](shared-brain.md).

Il registro `workstations.json` lega ogni `workstationId` a identità e percorsi. Lo stesso id con percorsi diversi (cartella spostata o baseline condivisa per errore; maiuscole, UNC con FQDN o nome breve, drive mappato e `\\localhost\X$` sono alias e non contano) è un errore con indicazione dei percorsi: dopo averne verificato il motivo si conferma con `access.ps1 -Reconcile`, che aggiorna il registro sotto lock di scrittura. Un id già registrato con un'altra identità resta sempre rifiutato. La configurazione richiede `config/shared.json` valido (`allowedOwners` ed `excludedDirectories`): se manca o è incompleto ogni comando si ferma, senza ammettere implicitamente tutti gli owner.

`abandoned` indica una lease rilasciata; `unverified` uno stato non affidabile. Un heartbeat vecchio non autorizza a sottrarre il lock. Non cancellare lock per forzare accessi.

Il protocollo coordina strumenti cooperanti; non intercetta editor esterni. `SessionId` è un identificatore operativo: autorizzazioni effettive e protezione della condivisione restano affidate a Windows/SMB.

Fonti: [CLI](../../scripts/access.ps1), [protocollo](../../scripts/SecondBrain.Access.psm1).
