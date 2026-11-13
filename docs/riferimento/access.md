# Access and concurrency

[Retained Italian source; use this English page for current behavior](access.it.md)

Initial instruction and dossier reads do not need a Hold process. A single CLI write manages its own operation locks. Inspect sessions and queued writers with:

~~~powershell
pwsh -NoProfile -File scripts/access.ps1 -Status
pwsh -NoProfile -File scripts/access.ps1 -Queue
~~~

A stale heartbeat is evidence to investigate, not permission to take a live lock. Purge is an explicit maintenance operation; ordinary inspection does not remove sessions.

## Write sessions

Open, perform the authorized work and close in the same script:

~~~powershell
$session = & pwsh -NoProfile -File scripts/access.ps1 -Start -Mode Write -Client Codex -Repository github.com/example-user/my-app -TargetPath C:/Projects/MyApp | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { return }
try {
    & pwsh -NoProfile -File scripts/secondbrain.ps1 -Sync -SessionId $session.sessionId
} finally {
    & pwsh -NoProfile -File scripts/access.ps1 -End -SessionId $session.sessionId
}
~~~

Replace the example identity and checkout with the actual binding. Pass ConfigPath for a nondefault configuration and inspect each child exit code before continuing dependent work.

Sessions expire by themselves after 30 minutes without renewal (`sessionTimeoutSeconds` in `config/shared.json`, integer 10-86400, default 1800): the lease and heartbeat end, an exclusive session releases writer.lock and its SessionId can no longer write. If the helper process is interrupted the session reports abandoned and the lock is free. Use Renew with the same SessionId to continue. Start launches a hidden helper maintaining the lease and heartbeat. A normal Write session records identity without holding writer.lock throughout the session. Exclusive sessions are for explicitly bounded exclusive work.

## Locks

writer.lock admits one writer; operation.lock serializes central operations, including operations from the same session. FIFO tickets have exclusive leases. Recovery of a dead process's ticket does not steal a live lock.

The default writer wait is 60 seconds, controlled by WaitSeconds, SECONDBRAIN_LOCK_WAIT_SECONDS or shared lockWaitSeconds. Timeout returns exit 3 and reports the owner. Readers avoid blocking locks and report active writers or incomplete transactions. Knowledge reads never integrate queued writes; only an explicit knowledge.ps1 -FlushPending does, for the own dossier.

Custom central writes require Enter-SBOperation/Exit-SBOperation and expected hashes. A session alone does not protect direct filesystem edits from external editors. Use [deferred writes](pending-writes.md) for supported dossier changes.

## Workstation identity and limits

workstations.json binds workstationId to Windows identity and paths. A real relocation needs verification and explicit Reconcile; a different identity cannot reuse the same ID. Supported path aliases are normalized. Valid shared policy, including allowedOwners and excludedDirectories, is required; missing policy fails closed.

SessionId identifies work; Windows and SMB enforce actual access rights. Do not remove locks, journals or incomplete-transaction markers. Local alias tests do not establish real two-host SMB behavior. See [shared brain](shared-brain.md), [access CLI](../../scripts/access.ps1) and [protocol](../../scripts/SecondBrain.Access.psm1).
