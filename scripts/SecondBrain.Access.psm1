#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')

function Get-SBPendingTransaction([string]$BrainRoot) {
    # Riepilogo del marker di una transazione interrotta: chi, quando, manifest e se e raggiungibile da questa postazione.
    $marker=Join-Path $BrainRoot '.runtime/para-transaction.json'
    if(!(Test-Path -LiteralPath $marker)){return $null}
    $pending=try{Read-SBJson $marker @{}}catch{@{}}
    $manifest=if($pending.ContainsKey('manifest')){[string]$pending.manifest}else{''}
    if($manifest -and $pending.ContainsKey('brainRoot')){$manifest=Convert-SBBrainAlias $manifest ([string]$pending.brainRoot) $BrainRoot}
    @{marker=$marker;manifest=$manifest;computer=$(if($pending.ContainsKey('computer')){[string]$pending.computer}else{''});user=$(if($pending.ContainsKey('user')){[string]$pending.user}else{''});startedAt=$(if($pending.ContainsKey('startedAt')){[string]$pending.startedAt}else{''});reachable=($manifest -and (Test-Path -LiteralPath $manifest))}
}
function Format-SBPendingTransaction($Pending) {
    $who=if($Pending.user -or $Pending.computer){" avviata da $($Pending.user)@$($Pending.computer) il $($Pending.startedAt)"}else{''}
    "Transazione PARA incompleta$who (manifest: $($Pending.manifest)). Recuperare con scripts/recover.ps1 -ManifestPath <manifest> da qualunque postazione che raggiunga il manifest; non rimuovere il marker a mano."
}
function Get-SBLockWaitMs($Config,[int]$WaitMs=-1) {
    # Attesa predefinita del writer su cervello condiviso: parametro esplicito, poi SECONDBRAIN_LOCK_WAIT_SECONDS, poi policy condivisa, poi 60 s.
    if($WaitMs -ge 0){return $WaitMs}
    if($env:SECONDBRAIN_LOCK_WAIT_SECONDS -match '^\d{1,3}$'){return [Math]::Min([int]$env:SECONDBRAIN_LOCK_WAIT_SECONDS,600)*1000}
    if($Config -is [Collections.IDictionary] -and $Config.ContainsKey('lockWaitMs')){return [int]$Config.lockWaitMs}
    60000
}
function Read-SBConfiguration([string]$ConfigPath,[switch]$AllowPendingTransaction,[int]$MigrationDepth=0,[switch]$ReadOnly) {
    $brain = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if(!$ConfigPath){
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
        $ConfigPath=Get-SBHostConfigPath $brain
        if(!(Test-Path -LiteralPath $ConfigPath)){throw 'Postazione non attivata: eseguire la procedura di attivazione (SYS03, scripts/secondbrain.ps1 -Setup)'}
    }elseif(!(Test-Path -LiteralPath $ConfigPath -PathType Leaf)){throw "Configurazione non trovata: $ConfigPath"}
    $local = Read-SBJson ([IO.Path]::GetFullPath($ConfigPath)) $null
    if($MigrationDepth -gt 3){throw 'Catena di configurazioni migrate non valida'}
    if($local -and $local.ContainsKey('migratedTo')){
        $target=Assert-SBCentralDataPath $brain $local.migratedTo
        return Read-SBConfiguration $target -AllowPendingTransaction:$AllowPendingTransaction -MigrationDepth ($MigrationDepth+1) -ReadOnly:$ReadOnly
    }
    $shared = Read-SBJson (Join-Path $brain 'config/shared.json') $null
    if($local -and $local.schemaVersion -eq 1 -and $local.mode -eq 'portable'){
        foreach($key in @('workstationId','runtimeRoot','backupRoot','bindings','ides')){if(!$local.ContainsKey($key)){throw 'Configurazione portabile incompleta: '+$key}}
        if($local.workstationId -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$'){throw 'WorkstationId non valido'}
        [void](Assert-SBCentralDataPath $brain $ConfigPath)
        foreach($key in @('runtimeRoot','backupRoot')){
            $value=[string]$local[$key];if(![IO.Path]::IsPathFullyQualified($value)){$value=Join-Path $brain $value}
            $local[$key]=Assert-SBCentralDataPath $brain $value
        }
        foreach($binding in $local.bindings){if(!(Test-SBRepositoryIdentity $binding.identity) -or ![IO.Path]::IsPathFullyQualified($binding.path)){throw 'Associazione repository non valida'}}
        # La policy condivisa (config/shared.json) e l'unica fonte di owner ammessi e cartelle escluse anche in modalita portabile.
        # Fail-closed: senza policy valida non si assume "tutti gli owner ammessi".
        if(!($shared -is [Collections.IDictionary]) -or !$shared.ContainsKey('allowedOwners') -or !$shared.ContainsKey('excludedDirectories')){throw 'config/shared.json assente o incompleto (allowedOwners e excludedDirectories richiesti): ripristinare la policy condivisa'}
        $owners=@($shared.allowedOwners)
        foreach($owner in $owners){if($owner -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]*$'){throw 'Owner GitHub non valido in config/shared.json'}}
        $excludedDirs=@($shared.excludedDirectories)
        $local.brainRoot=$brain;$local.configPath=[IO.Path]::GetFullPath($ConfigPath);$local.repositoryRoot=$brain;$local.allowedOwners=$owners;$local.excludedDirectories=$excludedDirs;$local.sessionTimeoutMinutes=30
        $local.coordinationRoot=Join-Path $brain '.runtime/access'
        # Attesa del writer: lockWaitSeconds in config/shared.json (0-600, predefinito 60).
        $local.lockWaitMs=60000
        if($shared.ContainsKey('lockWaitSeconds')){
            $wait=$shared.lockWaitSeconds
            if(($wait -isnot [int] -and $wait -isnot [long]) -or $wait -lt 0 -or $wait -gt 600){throw 'lockWaitSeconds in config/shared.json deve essere un intero tra 0 e 600'}
            $local.lockWaitMs=[int]$wait*1000
        }
        $pending=Get-SBPendingTransaction $brain
        if($pending -and !$AllowPendingTransaction){
            # I lettori continuano con un avviso: i dati possono essere in uno stato intermedio finche il manifest non e recuperato.
            if(!$ReadOnly){throw (Format-SBPendingTransaction $pending)}
            $local.pendingTransaction=$pending
        }
        return $local
    }
    throw 'Configurazione della postazione richiesta: attivare la postazione con secondbrain.ps1 -Setup (SYS03)'
}

function Write-SBAccessMetadata([string]$Path, $Value) {
    Assert-SBPlainPath $Path
    $temp = $Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $Value))
        $stream = [IO.FileStream]::new($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
        # Un lettore su un altro host puo avere il file aperto un istante: la sostituzione viene ritentata invece di segnare la sessione come fallita.
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try { [IO.File]::Move($temp,$Path,$true); break }
            catch [IO.IOException], [UnauthorizedAccessException] { if ($attempt -eq 6) { throw }; Start-Sleep -Milliseconds (40 * $attempt) }
        }
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Test-SBSessionId([string]$SessionId) {
    if ($SessionId -notmatch '^[a-f0-9]{32}$') { throw 'SessionId non valido' }
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
            # Una sola segnalazione, con il titolare, appena inizia l'attesa.
            if ($OnWait -and !$notified) { $notified = $true; & $OnWait }
            Start-Sleep -Milliseconds $delay
            $delay = [Math]::Min(500, [int]($delay * 1.5))
        }
    }
}
function Test-SBBusyError($ErrorRecord) {
    # Contesa sul lock di scrittura dopo l'attesa (sharing/lock violation), non altri errori di I/O.
    $base = $ErrorRecord.Exception.GetBaseException()
    $base -is [IO.IOException] -and ($base.HResult -band 0xffff) -in @(32, 33)
}
function Test-SBQueueTicketAlive([string]$LeasePath) {
    # Il ticket e vivo finche il suo processo tiene aperto il lease; un lease apribile e di un processo terminato.
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
    # Ordine di arrivo: il nome inizia con i tick UTC a larghezza fissa, poi un guid di spareggio.
    if (!(Test-Path -LiteralPath $Root)) { return @() }
    $names = @(Get-ChildItem -LiteralPath $Root -Filter '*.lease' -File -ErrorAction SilentlyContinue | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) })
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $names
}
function Enter-SBQueue($Config, [int]$WaitMs, [scriptblock]$OnWait) {
    # Coda FIFO dei writer sopra writer.lock: il ticket e un lease esclusivo tenuto aperto; i ticket di processi terminati
    # (lease apribile) vengono rimossi senza toccare writer.lock ne i marker di transazione.
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
            if ([DateTimeOffset]::UtcNow -ge $deadline) { throw [IO.IOException]::new('Coda di scrittura SecondBrain non disponibile entro il tempo di attesa', [int]-2147024864) }
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
    # Ticket in coda, poi writer.lock entro l'attesa residua; il ticket si libera appena il lock e acquisito.
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
    # Sola lettura (con -Purge rimuove i ticket orfani): posizione 1 = prossimo writer.
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
    # Lettori senza lock: segnala su stderr uno stato potenzialmente intermedio, senza fallire.
    if ($Operation -and $Operation.concurrentWriter) { [Console]::Error.WriteLine('Avviso: un writer SecondBrain e attivo, i dati letti possono essere intermedi.') }
    $pending = if ($Operation -and $Operation.pendingTransaction) { $Operation.pendingTransaction } elseif ($Config -is [Collections.IDictionary] -and $Config.ContainsKey('pendingTransaction')) { $Config.pendingTransaction } else { $null }
    if ($pending) { [Console]::Error.WriteLine('Avviso: ' + (Format-SBPendingTransaction $pending)) }
}
function Get-SBOperationOwnerText($Config) {
    $owners = @(Get-SBAccessStatus $Config)
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
            # Lo stato e in sola lettura: la persistenza dell'abbandono richiede -Repair (o Clear-SBStaleSessions).
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
    if ($entry.Count -ne 1 -or $entry[0].status -ne 'active' -or $entry[0].mode -notin $modes) { throw $(if ($AllowRead) { 'Sessione assente o non verificabile' } else { 'Sessione di scrittura assente o non verificabile' }) }
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($entry[0].computer -ne [Environment]::MachineName -or $entry[0].user -ne $user -or $entry[0].workstationId -ne $Config.workstationId) { throw 'La sessione appartiene a un altro utente o postazione' }
    $entry[0]
}

function Enter-SBOperation($Config, [string]$SessionId, [switch]$ReadOnly, [int]$WaitMs = -1, [switch]$ReconcileWorkstation, [switch]$LockOnly) {
    # -LockOnly: solo coda e lock di scrittura (nessun registro postazioni ne guardia), per i writer che operano fuori dal cervello e a postazione non attivata.
    $result = @{ writer=$null; operation=$null; metadata=$null; ownerSessionId=$null; config=$Config; concurrentWriter=$false; pendingTransaction=$null }
    $waitTotal = Get-SBLockWaitMs $Config $WaitMs
    try {
        if (!(Test-Path -LiteralPath $Config.coordinationRoot)) {
            if ($ReadOnly) { return $result }
            Assert-SBPlainPath $Config.coordinationRoot
            [IO.Directory]::CreateDirectory($Config.coordinationRoot) | Out-Null
        }
        $writerPath = Join-Path $Config.coordinationRoot 'writer.lock'
        if ($ReadOnly) {
            # Le letture non prendono lock bloccanti (non affamano il writer): segnalano un writer attivo o una transazione pendente come avviso.
            if ($Config -is [Collections.IDictionary] -and $Config.ContainsKey('brainRoot')) { $result.pendingTransaction = Get-SBPendingTransaction $Config.brainRoot }
            if ($SessionId) {
                $session = Assert-SBSession $Config $SessionId -AllowRead
                if ($session.mode -eq 'Read' -and (Test-Path -LiteralPath $writerPath)) {
                    try { $probe = [IO.File]::Open($writerPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); $probe.Dispose() }
                    catch [IO.IOException] { $result.concurrentWriter = $true }
                }
            } elseif (Test-Path -LiteralPath $writerPath) {
                try { $probe = [IO.File]::Open($writerPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); $probe.Dispose() }
                catch [IO.IOException] { $result.concurrentWriter = $true }
            }
        } else {
            if ($SessionId) { Assert-SBSession $Config $SessionId | Out-Null }
            else {
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
            # La registrazione impedisce due postazioni con stesso id o baseline condivisa per errore.
            $registryPath = Join-Path $Config.coordinationRoot 'workstations.json'
            $registry = Read-SBJson $registryPath @{}
            $identity = [Environment]::MachineName+'|'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $station = @{identity=$identity;runtimeRoot=$Config.runtimeRoot;backupRoot=$Config.backupRoot;repositoryRoot=$Config.repositoryRoot}
            $known = $null
            if ($registry.ContainsKey($Config.workstationId)) {
                $known = $registry[$Config.workstationId]
                if ($known.identity -cne $identity) { throw 'workstationId gia registrato con un altra identita: usare un nuovo id' }
            }
            foreach ($key in $registry.Keys) {
                if ($key -ne $Config.workstationId -and ($registry[$key].runtimeRoot -ieq $Config.runtimeRoot -or $registry[$key].backupRoot -ieq $Config.backupRoot)) { throw 'runtimeRoot e backupRoot devono essere distinti per postazione' }
            }
            # Stessa identita con percorsi diversi (cartella spostata, alias UNC, baseline condivisa per errore): serve conferma esplicita.
            # Alias dello stesso percorso (maiuscole, drive mappato, UNC con FQDN) non sono uno spostamento.
            $moved = $known -and !((Test-SBSamePath $known.runtimeRoot $station.runtimeRoot) -and (Test-SBSamePath $known.backupRoot $station.backupRoot) -and (Test-SBSamePath $known.repositoryRoot $station.repositoryRoot))
            if ($moved -and !$ReconcileWorkstation) { throw "workstationId '$($Config.workstationId)' gia registrato con percorsi diversi (registrato: $($known.repositoryRoot); corrente: $($station.repositoryRoot)). Verificare lo spostamento e riconciliare con scripts/access.ps1 -Reconcile." }
            if (!$known -or $moved) { $registry[$Config.workstationId]=$station; Write-SBAccessMetadata $registryPath $registry }
            # La closure non vede le funzioni private del modulo: si cattura il comando prima di GetNewClosure().
            $assertSession=${function:Assert-SBSession}
            $writeGuard={
                if($SessionId){& $assertSession $Config $SessionId|Out-Null}
                # Un vero I/O sull'handle condiviso rileva la perdita del coordinamento.
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
            throw [IO.IOException]::new("SecondBrain occupato o coordinamento non disponibile dopo $([int]($waitTotal / 1000)) s. Titolare: $description",$_.Exception)
        }
        throw
    }
}

function Exit-SBOperation($Operation) {
    if (!$Operation) { return }
    Set-SBWriteGuard $null
    if ($Operation.operation) { $Operation.operation.Dispose() }
    # Il file del titolare si rimuove solo se e ancora quello scritto da questa operazione.
    if ($Operation.metadata -and [IO.File]::Exists($Operation.metadata)) {
        $recorded = try { Read-SBJson $Operation.metadata @{} } catch { @{} }
        if (!$Operation.ownerSessionId -or ($recorded.ContainsKey('sessionId') -and $recorded.sessionId -eq $Operation.ownerSessionId)) { [IO.File]::Delete($Operation.metadata) }
    }
    if ($Operation.writer) { $Operation.writer.Dispose() }
}

Export-ModuleMember -Function @(
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
