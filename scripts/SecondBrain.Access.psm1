#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'access.station.inactive' = @{ it = 'Postazione non attivata: eseguire la procedura di attivazione (SYS03, scripts/secondbrain.ps1 -Setup)'; en = 'Workstation not activated: run the activation procedure (SYS03, scripts/secondbrain.ps1 -Setup)' }
    'access.config.missing' = @{ it = 'Configurazione non trovata: {0}'; en = 'Configuration not found: {0}' }
    'access.config.chain' = @{ it = 'Catena di configurazioni migrate non valida'; en = 'Invalid chain of migrated configurations' }
    'access.config.incomplete' = @{ it = 'Configurazione portabile incompleta: {0}'; en = 'Incomplete portable configuration: {0}' }
    'access.binding.invalid' = @{ it = 'Associazione repository non valida'; en = 'Invalid repository binding' }
    'access.shared.incomplete' = @{ it = 'config/shared.json assente o incompleto (allowedOwners e excludedDirectories richiesti): ripristinare la policy condivisa'; en = 'config/shared.json missing or incomplete (allowedOwners and excludedDirectories required): restore the shared policy' }
    'access.shared.owner' = @{ it = 'Owner GitHub non valido in config/shared.json'; en = 'Invalid GitHub owner in config/shared.json' }
    'access.shared.lockwait' = @{ it = 'lockWaitSeconds in config/shared.json deve essere un intero tra 0 e 600'; en = 'lockWaitSeconds in config/shared.json must be an integer between 0 and 600' }
    'access.config.required' = @{ it = 'Configurazione della postazione richiesta: attivare la postazione con secondbrain.ps1 -Setup (SYS03)'; en = 'Workstation configuration required: activate the workstation with secondbrain.ps1 -Setup (SYS03)' }
    'access.session.invalid' = @{ it = 'SessionId non valido'; en = 'Invalid SessionId' }
    'access.queue.timeout' = @{ it = 'Coda di scrittura SecondBrain non disponibile entro il tempo di attesa'; en = 'SecondBrain write queue not available within the wait time' }
    'access.session.missing' = @{ it = 'Sessione assente o non verificabile'; en = 'Session missing or not verifiable' }
    'access.session.missing.write' = @{ it = 'Sessione di scrittura assente o non verificabile'; en = 'Write session missing or not verifiable' }
    'access.session.foreign' = @{ it = 'La sessione appartiene a un altro utente o postazione'; en = 'The session belongs to another user or workstation' }
    'access.station.identity' = @{ it = 'workstationId gia registrato con un altra identita: usare un nuovo id'; en = 'workstationId already registered with another identity: use a new id' }
    'access.station.roots' = @{ it = 'runtimeRoot e backupRoot devono essere distinti per postazione'; en = 'runtimeRoot and backupRoot must be distinct per workstation' }
    'access.station.moved' = @{ it = 'workstationId ''{0}'' gia registrato con percorsi diversi (registrato: {1}; corrente: {2}). Verificare lo spostamento e riconciliare con scripts/access.ps1 -Reconcile.'; en = 'workstationId ''{0}'' already registered with different paths (registered: {1}; current: {2}). Check the move and reconcile with scripts/access.ps1 -Reconcile.' }
    'access.busy' = @{ it = 'SecondBrain occupato o coordinamento non disponibile dopo {0} s. Titolare: {1}'; en = 'SecondBrain busy or coordination unavailable after {0} s. Owner: {1}' }
    'access.pending.who' = @{ it = ' avviata da {0}@{1} il {2}'; en = ' started by {0}@{1} on {2}' }
    'access.pending' = @{ it = 'Transazione PARA incompleta{0} (manifest: {1}). Recuperare con scripts/recover.ps1 -ManifestPath <manifest> da qualunque postazione che raggiunga il manifest; non rimuovere il marker a mano.'; en = 'Incomplete PARA transaction{0} (manifest: {1}). Recover with scripts/recover.ps1 -ManifestPath <manifest> from any workstation that reaches the manifest; do not remove the marker by hand.' }
}

function Get-SBPendingTransaction([string]$BrainRoot) {
    # Summarize an interrupted transaction marker: owner, time, manifest and reachability from this workstation.
    $marker=Join-Path $BrainRoot '.runtime/para-transaction.json'
    if(!(Test-Path -LiteralPath $marker)){return $null}
    $pending=try{Read-SBJson $marker @{}}catch{@{}}
    $manifest=if($pending.ContainsKey('manifest')){[string]$pending.manifest}else{''}
    if($manifest -and $pending.ContainsKey('brainRoot')){$manifest=Convert-SBBrainAlias $manifest ([string]$pending.brainRoot) $BrainRoot}
    @{marker=$marker;manifest=$manifest;computer=$(if($pending.ContainsKey('computer')){[string]$pending.computer}else{''});user=$(if($pending.ContainsKey('user')){[string]$pending.user}else{''});startedAt=$(if($pending.ContainsKey('startedAt')){[string]$pending.startedAt}else{''});reachable=($manifest -and (Test-Path -LiteralPath $manifest))}
}
function Format-SBPendingTransaction($Pending) {
    $who=if($Pending.user -or $Pending.computer){Get-SBMessage 'access.pending.who' @($Pending.user,$Pending.computer,$Pending.startedAt)}else{''}
    (Get-SBMessage 'access.pending' @($who,$Pending.manifest))
}
function Get-SBLockWaitMs($Config,[int]$WaitMs=-1) {
    # Default writer wait on a shared brain: explicit parameter, then SECONDBRAIN_LOCK_WAIT_SECONDS, shared policy, then 60 s.
    if($WaitMs -ge 0){return $WaitMs}
    if($env:SECONDBRAIN_LOCK_WAIT_SECONDS -match '^\d{1,3}$'){return [Math]::Min([int]$env:SECONDBRAIN_LOCK_WAIT_SECONDS,600)*1000}
    if($Config -is [Collections.IDictionary] -and $Config.ContainsKey('lockWaitMs')){return [int]$Config.lockWaitMs}
    60000
}
function Read-SBConfiguration([string]$ConfigPath,[switch]$AllowPendingTransaction,[int]$MigrationDepth=0,[switch]$ReadOnly,[string]$BrainRoot) {
    $brain = if($BrainRoot){[IO.Path]::GetFullPath($BrainRoot)}else{[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
    if(!$ConfigPath){
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
        $ConfigPath=Get-SBHostConfigPath $brain
        if(!(Test-Path -LiteralPath $ConfigPath)){throw (New-SBError 'access.station.inactive')}
    }elseif(!(Test-Path -LiteralPath $ConfigPath -PathType Leaf)){throw (New-SBError 'access.config.missing' @($ConfigPath))}
    $local = Read-SBJson ([IO.Path]::GetFullPath($ConfigPath)) $null
    if($MigrationDepth -gt 3){throw (New-SBError 'access.config.chain')}
    if($local -and $local.ContainsKey('migratedTo')){
        $target=Assert-SBCentralDataPath $brain $local.migratedTo
        return Read-SBConfiguration $target -AllowPendingTransaction:$AllowPendingTransaction -MigrationDepth ($MigrationDepth+1) -ReadOnly:$ReadOnly -BrainRoot $brain
    }
    $shared = Read-SBJson (Join-Path $brain 'config/shared.json') $null
    if($local -and $local.schemaVersion -eq 1 -and $local.mode -eq 'portable'){
        foreach($key in @('workstationId','runtimeRoot','backupRoot','bindings','ides')){if(!$local.ContainsKey($key)){throw (New-SBError 'access.config.incomplete' @($key))}}
        if($local.workstationId -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$'){throw (New-SBError 'core.workstation.invalid')}
        [void](Assert-SBCentralDataPath $brain $ConfigPath)
        foreach($key in @('runtimeRoot','backupRoot')){
            $value=[string]$local[$key];if(![IO.Path]::IsPathFullyQualified($value)){$value=Join-Path $brain $value}
            $local[$key]=Assert-SBCentralDataPath $brain $value
        }
        foreach($binding in $local.bindings){if(!(Test-SBRepositoryIdentity $binding.identity) -or ![IO.Path]::IsPathFullyQualified($binding.path)){throw (New-SBError 'access.binding.invalid')}}
        # Shared policy (config/shared.json) is the only source of allowed owners and excluded folders, including portable mode.
        # Fail closed: without a valid policy, never assume that all owners are allowed.
        if(!($shared -is [Collections.IDictionary]) -or !$shared.ContainsKey('allowedOwners') -or !$shared.ContainsKey('excludedDirectories')){throw (New-SBError 'access.shared.incomplete')}
        $owners=@($shared.allowedOwners)
        foreach($owner in $owners){if($owner -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]*$'){throw (New-SBError 'access.shared.owner')}}
        $excludedDirs=@($shared.excludedDirectories)
        $local.brainRoot=$brain;$local.configPath=[IO.Path]::GetFullPath($ConfigPath);$local.repositoryRoot=$brain;$local.allowedOwners=$owners;$local.excludedDirectories=$excludedDirs;$local.sessionTimeoutMinutes=30
        $local.coordinationRoot=Join-Path $brain '.runtime/access'
        # Writer wait: lockWaitSeconds in config/shared.json (0-600, default 60).
        $local.lockWaitMs=60000
        if($shared.ContainsKey('lockWaitSeconds')){
            $wait=$shared.lockWaitSeconds
            if(($wait -isnot [int] -and $wait -isnot [long]) -or $wait -lt 0 -or $wait -gt 600){throw (New-SBError 'access.shared.lockwait')}
            $local.lockWaitMs=[int]$wait*1000
        }
        $pending=Get-SBPendingTransaction $brain
        if($pending -and !$AllowPendingTransaction){
            # Readers continue with a warning: data may remain in an intermediate state until the manifest is recovered.
            if(!$ReadOnly){throw (Format-SBPendingTransaction $pending)}
            $local.pendingTransaction=$pending
        }
        return $local
    }
    throw (New-SBError 'access.config.required')
}

function Write-SBAccessMetadata([string]$Path, $Value) {
    Assert-SBPlainPath $Path
    $temp = $Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $Value))
        $stream = [IO.FileStream]::new($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
        # A reader on another host may briefly hold the file open: retry replacement instead of marking the session failed.
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try { [IO.File]::Move($temp,$Path,$true); break }
            catch [IO.IOException], [UnauthorizedAccessException] { if ($attempt -eq 6) { throw }; Start-Sleep -Milliseconds (40 * $attempt) }
        }
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Test-SBSessionId([string]$SessionId) {
    if ($SessionId -notmatch '^[a-f0-9]{32}$') { throw (New-SBError 'access.session.invalid') }
}

function Open-SBLockFile([string]$Path, [IO.FileMode]$Mode, [IO.FileAccess]$Access, [IO.FileShare]$Share, [int]$WaitMs = 1000, [scriptblock]$OnWait) {
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds([Math]::Max(0, $WaitMs))
    $delay = 100; $notified = $false
    while ($true) {
        try {
            return [IO.File]::Open($Path, $Mode, $Access, $Share)
        } catch [IO.IOException] {
            $hr = $_.Exception.GetBaseException().HResult -band 0xffff
            if ($hr -notin @(32, 33) -or [DateTimeOffset]::UtcNow -ge $deadline) { throw }
            # Report the owner once, as soon as waiting begins.
            if ($OnWait -and !$notified) { $notified = $true; & $OnWait }
            Start-Sleep -Milliseconds $delay
            $delay = [Math]::Min(500, [int]($delay * 1.5))
        }
    }
}
function Test-SBBusyError($ErrorRecord) {
    # Writer-lock contention after waiting (sharing/lock violation), excluding other I/O errors.
    $base = $ErrorRecord.Exception.GetBaseException()
    $base -is [IO.IOException] -and ($base.HResult -band 0xffff) -in @(32, 33)
}
function Test-SBQueueTicketAlive([string]$LeasePath) {
    # A ticket is live while its process holds the lease open; an openable lease belongs to an exited process.
    $probe = $null
    try { $probe = [IO.File]::Open($LeasePath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); return $false }
    catch [IO.FileNotFoundException] { return $false }
    catch [IO.DirectoryNotFoundException] { return $false }
    catch [UnauthorizedAccessException] { return $false }
    catch [IO.IOException] { if (($_.Exception.HResult -band 0xffff) -in @(32, 33)) { return $true }; throw }
    finally { if ($probe) { $probe.Dispose() } }
}
function Remove-SBQueueTicketFiles([string]$Root, [string]$Name) {
    foreach ($suffix in @('.json','.lease')) { try { [IO.File]::Delete((Join-Path $Root ($Name+$suffix))) } catch {} }
}
function Get-SBQueueTicketNames([string]$Root) {
    # Arrival order: the name starts with fixed-width UTC ticks, followed by a GUID tie-breaker.
    if (!(Test-Path -LiteralPath $Root)) { return @() }
    $names = @(Get-ChildItem -LiteralPath $Root -Filter '*.lease' -File -ErrorAction SilentlyContinue | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) })
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $names
}
function Enter-SBQueue($Config, [int]$WaitMs, [scriptblock]$OnWait) {
    # FIFO writer queue over writer.lock: the ticket is an exclusive open lease; tickets from exited processes
    # (openable leases) are removed without touching writer.lock or transaction markers.
    $root = Join-Path $Config.coordinationRoot 'queue'
    Assert-SBPlainPath $root
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $name = [DateTimeOffset]::UtcNow.UtcTicks.ToString('D19') + '-' + [guid]::NewGuid().ToString('N')
    $leasePath = Join-Path $root ($name+'.lease')
    Assert-SBPlainPath $leasePath
    $ticket = @{ name=$name; root=$root; lease=[IO.FileStream]::new($leasePath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    try {
        Write-SBAccessMetadata (Join-Path $root ($name+'.json')) @{ticket=$name;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;computer=[Environment]::MachineName;processId=$PID;client='SecondBrain script';workstationId=$Config.workstationId;enqueuedAt=[DateTimeOffset]::UtcNow.ToString('o')}
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds([Math]::Max(0, $WaitMs))
        $delay = 100; $notified = $false
        while ($true) {
            $ahead = $null
            foreach ($other in @(Get-SBQueueTicketNames $root)) {
                if ($other -ceq $name) { break }
                if (Test-SBQueueTicketAlive (Join-Path $root ($other+'.lease'))) { $ahead = $other; break }
                Remove-SBQueueTicketFiles $root $other
            }
            if (!$ahead) { return $ticket }
            if ([DateTimeOffset]::UtcNow -ge $deadline) { throw (New-SBError 'access.queue.timeout' @() ([IO.IOException]) -2147024864) }
            if ($OnWait -and !$notified) { $notified = $true; & $OnWait }
            Start-Sleep -Milliseconds $delay
            $delay = [Math]::Min(500, [int]($delay * 1.5))
        }
    } catch { Exit-SBQueue $ticket; throw }
}
function Exit-SBQueue($Ticket) {
    if (!$Ticket) { return }
    if ($Ticket.lease) { $Ticket.lease.Dispose() }
    Remove-SBQueueTicketFiles $Ticket.root $Ticket.name
}
function Open-SBWriterLock($Config, [string]$WriterPath, [int]$WaitMs, [scriptblock]$OnWait) {
    # Queue a ticket, then acquire writer.lock within the remaining wait; release the ticket as soon as the lock is acquired.
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds([Math]::Max(0, $WaitMs))
    $state = @{ notified=$false }
    $notify = { if (!$state.notified) { $state.notified = $true; if ($OnWait) { & $OnWait } } }.GetNewClosure()
    $ticket = Enter-SBQueue $Config $WaitMs $notify
    try {
        $remaining = [int][Math]::Max(0, ($deadline - [DateTimeOffset]::UtcNow).TotalMilliseconds)
        Open-SBLockFile $WriterPath ([IO.FileMode]::OpenOrCreate) ([IO.FileAccess]::ReadWrite) ([IO.FileShare]::None) $remaining $notify
    } finally { Exit-SBQueue $ticket }
}
function Get-SBQueueStatus($Config, [switch]$Purge) {
    # Read-only (-Purge removes orphan tickets): position 1 = next writer.
    $root = Join-Path $Config.coordinationRoot 'queue'
    $position = 0
    foreach ($name in @(Get-SBQueueTicketNames $root)) {
        $meta = Read-SBJson (Join-Path $root ($name+'.json')) @{}
        $alive = Test-SBQueueTicketAlive (Join-Path $root ($name+'.lease'))
        $entry = @{} + $meta
        $entry.ticket = $name
        if ($alive) { $position++; $entry.state = 'waiting'; $entry.position = $position } else { $entry.state = 'orphan'; if ($Purge) { Remove-SBQueueTicketFiles $root $name } }
        $entry
    }
}
function Write-SBReadWarnings($Operation, $Config) {
    # Lock-free readers: warn on stderr about a potentially intermediate state without failing.
    if ($Operation -and $Operation.concurrentWriter) { [Console]::Error.WriteLine('Avviso: un writer SecondBrain e attivo, i dati letti possono essere intermedi.') }
    $pending = if ($Operation -and $Operation.pendingTransaction) { $Operation.pendingTransaction } elseif ($Config -is [Collections.IDictionary] -and $Config.ContainsKey('pendingTransaction')) { $Config.pendingTransaction } else { $null }
    if ($pending) { [Console]::Error.WriteLine('Avviso: ' + (Format-SBPendingTransaction $pending)) }
}
function Get-SBOperationOwnerText($Config) {
    $owners = @(Get-SBAccessStatus $Config|Where-Object {$_.status -eq 'active' -and $_.mode -eq 'Write' -and (!$_.ContainsKey('exclusive') -or $_.exclusive)})
    $owner = Read-SBJson (Join-Path $Config.coordinationRoot 'operation-owner.json') @{}
    if ($owners.Count) { ($owners | ForEach-Object { "$($_.user)@$($_.computer), $($_.client), $($_.path), sessione $($_.sessionId)" }) -join '; ' }
    elseif ($owner.Count) { "$($owner.user)@$($owner.computer), $($owner.client), $($owner.path), dal $($owner.heartbeat)" }
    else { 'titolare non identificato' }
}

function Get-SBAccessStatus($Config, [switch]$Repair) {
    $root = Join-Path $Config.coordinationRoot 'sessions'
    $files=if(Test-Path -LiteralPath $root){@(Get-ChildItem -LiteralPath $root -Filter '*.json' -File)}else{@()}
    foreach ($file in $files) {
        $entry = Read-SBJson $file.FullName $null
        if (!$entry -or $entry.status -notin @('active','abandoned')) { continue }
        $entry = @{} + $entry
        if ($entry.status -eq 'active') {
            $lease = $null
            try {
                $lease = [IO.File]::Open((Join-Path $root ($entry.sessionId+'.lease')),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
                $entry.status = 'abandoned'
            } catch [IO.FileNotFoundException] { $entry.status = 'abandoned' }
            catch [IO.IOException] {
                if (($_.Exception.GetBaseException().HResult -band 0xffff) -notin @(32,33) -or ([DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($entry.heartbeat)).TotalSeconds -gt 15) { $entry.status = 'unverified' }
            } finally { if ($lease) { $lease.Dispose() } }
            # Status is read-only: persisting abandonment requires -Repair (or Clear-SBStaleSessions).
            if ($Repair -and $entry.status -eq 'abandoned') {
                try { Write-SBAccessMetadata $file.FullName $entry } catch {}
                foreach ($suffix in @('.stop','.renew','.lease')) { [IO.File]::Delete((Join-Path $root ($entry.sessionId+$suffix))) }
            }
        }
        $entry
    }
    $owner=Read-SBJson (Join-Path $Config.coordinationRoot 'operation-owner.json') $null
    if($owner){
        $probe=$null
        try{$probe=[IO.File]::Open((Join-Path $Config.coordinationRoot 'writer.lock'),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException]{if(($_.Exception.GetBaseException().HResult -band 0xffff) -in @(32,33)){$owner.status='active';$owner}}
        finally{if($probe){$probe.Dispose()}}
    }
}

function Clear-SBStaleSessions($Config, [int]$MaxAgeMinutes = 60) {
    $root = Join-Path $Config.coordinationRoot 'sessions'
    if (!(Test-Path -LiteralPath $root)) { return 0 }
    $removedCount = 0
    $cutoff = [DateTimeOffset]::UtcNow.AddMinutes(-[Math]::Max(0, $MaxAgeMinutes))
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        $entry = Read-SBJson $file.FullName $null
        if (!$entry) { continue }
        $status = $entry.status
        if ($status -eq 'active') {
            $lease = $null
            try {
                $lease = [IO.File]::Open((Join-Path $root ($entry.sessionId+'.lease')),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
                $status = 'abandoned'
            } catch [IO.FileNotFoundException] { $status = 'abandoned' }
            catch [IO.IOException] {}
            finally { if ($lease) { $lease.Dispose() } }
            if ($status -eq 'abandoned') {
                $entry.status = 'abandoned'
                try { Write-SBAccessMetadata $file.FullName $entry } catch {}
                foreach ($suffix in @('.stop','.renew','.lease')) { [IO.File]::Delete((Join-Path $root ($entry.sessionId+$suffix))) }
            }
        }
        if ($status -in @('closed','failed','expired','abandoned')) {
            $ts = if ($entry.ContainsKey('heartbeat')) { [DateTimeOffset]::Parse($entry.heartbeat) } else { [DateTimeOffset]$file.LastWriteTimeUtc }
            if ($MaxAgeMinutes -le 0 -or $ts -le $cutoff) {
                foreach ($suffix in @('.json','.stop','.renew','.lease')) {
                    $p = Join-Path $root ($entry.sessionId+$suffix)
                    if ([IO.File]::Exists($p)) { [IO.File]::Delete($p) }
                }
                $removedCount++
            }
        }
    }
    $removedCount
}

function Assert-SBSession($Config, [string]$SessionId, [switch]$AllowRead) {
    Test-SBSessionId $SessionId
    $entry = @(Get-SBAccessStatus $Config | Where-Object sessionId -eq $SessionId)
    $modes = if ($AllowRead) { @('Read','Write') } else { @('Write') }
    if ($entry.Count -ne 1 -or $entry[0].status -ne 'active' -or $entry[0].mode -notin $modes) { throw (New-SBError $(if ($AllowRead) { 'access.session.missing' } else { 'access.session.missing.write' })) }
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($entry[0].computer -ne [Environment]::MachineName -or $entry[0].user -ne $user -or $entry[0].workstationId -ne $Config.workstationId) { throw (New-SBError 'access.session.foreign') }
    $entry[0]
}

function Enter-SBOperation($Config, [string]$SessionId, [switch]$ReadOnly, [int]$WaitMs = -1, [switch]$ReconcileWorkstation, [switch]$LockOnly) {
    # -LockOnly: writer queue and lock only (no workstation registry or guard), for writers outside the brain and on inactive workstations.
    $result = @{ writer=$null; operation=$null; metadata=$null; ownerSessionId=$null; config=$Config; concurrentWriter=$false; pendingTransaction=$null; previousGuard=(Get-SBWriteGuard) }
    $waitTotal = Get-SBLockWaitMs $Config $WaitMs
    try {
        if (!(Test-Path -LiteralPath $Config.coordinationRoot)) {
            if ($ReadOnly) { return $result }
            Assert-SBPlainPath $Config.coordinationRoot
            [IO.Directory]::CreateDirectory($Config.coordinationRoot) | Out-Null
        }
        $writerPath = Join-Path $Config.coordinationRoot 'writer.lock'
        if ($ReadOnly) {
            # Reads take no blocking locks (avoiding writer starvation): report an active writer or pending transaction as a warning.
            if ($Config -is [Collections.IDictionary] -and $Config.ContainsKey('brainRoot')) { $result.pendingTransaction = Get-SBPendingTransaction $Config.brainRoot }
            if ($SessionId) {
                $session = Assert-SBSession $Config $SessionId -AllowRead
                if (($session.mode -eq 'Read' -or ($session.ContainsKey('exclusive') -and !$session.exclusive)) -and (Test-Path -LiteralPath $writerPath)) {
                    try { $probe = [IO.File]::Open($writerPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); $probe.Dispose() }
                    catch [IO.IOException] { $result.concurrentWriter = $true }
                }
            } elseif (Test-Path -LiteralPath $writerPath) {
                try { $probe = [IO.File]::Open($writerPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); $probe.Dispose() }
                catch [IO.IOException] { $result.concurrentWriter = $true }
            }
        } else {
            $exclusiveSession=$false
            if ($SessionId) {
                $session=Assert-SBSession $Config $SessionId
                # Old running sessions held writer.lock; preserve their contract until End.
                $exclusiveSession=(!$session.ContainsKey('exclusive') -or [bool]$session.exclusive)
            }
            if (!$exclusiveSession) {
                Assert-SBPlainPath $writerPath
                $onWait = { [Console]::Error.WriteLine('SecondBrain: scrittura occupata, attesa fino a ' + [int]($waitTotal / 1000) + ' s. Titolare: ' + (Get-SBOperationOwnerText $Config)) }.GetNewClosure()
                $result.writer = Open-SBWriterLock $Config $writerPath $waitTotal $onWait
                $result.metadata = Join-Path $Config.coordinationRoot 'operation-owner.json'
                $result.ownerSessionId = [guid]::NewGuid().ToString('N')
                Write-SBAccessMetadata $result.metadata @{sessionId=$result.ownerSessionId;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;computer=[Environment]::MachineName;processId=$PID;client='SecondBrain script';repository=(Get-SBBrainIdentity $Config.brainRoot);workstationId=$Config.workstationId;path=$Config.brainRoot;mode='Write';heartbeat=[DateTimeOffset]::UtcNow.ToString('o')}
            }
            $opPath = Join-Path $Config.coordinationRoot 'operation.lock'
            Assert-SBPlainPath $opPath
            $result.operation = Open-SBLockFile $opPath ([IO.FileMode]::OpenOrCreate) ([IO.FileAccess]::ReadWrite) ([IO.FileShare]::None) $waitTotal
            if ($LockOnly) { return $result }
            # Registration prevents two workstations from accidentally sharing an ID or baseline.
            $registryPath = Join-Path $Config.coordinationRoot 'workstations.json'
            $registry = Read-SBJson $registryPath @{}
            $identity = [Environment]::MachineName+'|'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $station = @{identity=$identity;runtimeRoot=$Config.runtimeRoot;backupRoot=$Config.backupRoot;repositoryRoot=$Config.repositoryRoot}
            $known = $null
            if ($registry.ContainsKey($Config.workstationId)) {
                $known = $registry[$Config.workstationId]
                if ($known.identity -cne $identity) { throw (New-SBError 'access.station.identity') }
            }
            foreach ($key in $registry.Keys) {
                if ($key -ne $Config.workstationId -and ($registry[$key].runtimeRoot -ieq $Config.runtimeRoot -or $registry[$key].backupRoot -ieq $Config.backupRoot)) { throw (New-SBError 'access.station.roots') }
            }
            # Same identity with different paths (moved folder, UNC alias, accidentally shared baseline): explicit confirmation required.
            # Aliases of the same path (case, mapped drive, UNC with FQDN) are not relocations.
            $moved = $known -and !((Test-SBSamePath $known.runtimeRoot $station.runtimeRoot) -and (Test-SBSamePath $known.backupRoot $station.backupRoot) -and (Test-SBSamePath $known.repositoryRoot $station.repositoryRoot))
            if ($moved -and !$ReconcileWorkstation) { throw (New-SBError 'access.station.moved' @($Config.workstationId,$known.repositoryRoot,$station.repositoryRoot)) }
            if (!$known -or $moved) { $registry[$Config.workstationId]=$station; Write-SBAccessMetadata $registryPath $registry }
            # The closure cannot see private module functions: capture the command before GetNewClosure().
            $assertSession=${function:Assert-SBSession}
            $writeGuard={
                if($SessionId){& $assertSession $Config $SessionId|Out-Null}
                # Actual I/O on the shared handle detects loss of coordination.
                $result.operation.Position=0;$result.operation.WriteByte(1);$result.operation.Flush($true)
                if($result.writer){$result.writer.Position=0;$result.writer.WriteByte(1);$result.writer.Flush($true)}
            }.GetNewClosure()
            Set-SBWriteGuard $writeGuard
        }
        return $result
    } catch {
        Exit-SBOperation $result
        $base = $_.Exception.GetBaseException()
        if ($base -is [IO.IOException] -and ($base.HResult -band 0xffff) -in @(32, 33)) {
            $description = Get-SBOperationOwnerText $Config
            throw (New-SBError 'access.busy' @([int]($waitTotal / 1000),$description) ([IO.IOException]) 0 $_.Exception)
        }
        throw
    }
}

function Exit-SBOperation($Operation) {
    if (!$Operation) { return }
    $previousGuard=if($Operation.ContainsKey('previousGuard')){$Operation.previousGuard}else{$null}
    Set-SBWriteGuard $previousGuard
    if ($Operation.operation) { $Operation.operation.Dispose() }
    # Remove the owner file only if it is still the file written by this operation.
    if ($Operation.metadata -and [IO.File]::Exists($Operation.metadata)) {
        $recorded = try { Read-SBJson $Operation.metadata @{} } catch { @{} }
        if (!$Operation.ownerSessionId -or ($recorded.ContainsKey('sessionId') -and $recorded.sessionId -eq $Operation.ownerSessionId)) { [IO.File]::Delete($Operation.metadata) }
    }
    if ($Operation.writer) { $Operation.writer.Dispose() }
}

Export-ModuleMember -Function @(
    'Assert-SBSession',
    'Get-SBPendingTransaction',
    'Format-SBPendingTransaction',
    'Get-SBLockWaitMs',
    'Read-SBConfiguration',
    'Write-SBAccessMetadata',
    'Test-SBSessionId',
    'Open-SBLockFile',
    'Test-SBBusyError',
    'Open-SBWriterLock',
    'Get-SBQueueStatus',
    'Write-SBReadWarnings',
    'Get-SBOperationOwnerText',
    'Get-SBAccessStatus',
    'Clear-SBStaleSessions',
    'Enter-SBOperation',
    'Exit-SBOperation'
)
