#requires -Version 7.5
<#
.SYNOPSIS
Registers cooperative access to SecondBrain; see docs/riferimento/operations.md.
Status (-Status) is read-only; -Purge removes sessions closed, expired or abandoned for more than 60 minutes.
-Reconcile explicitly confirms a workstation relocation (same workstationId, different paths) and updates the registry.
-Queue lists the FIFO writer queue (position 1 = next); -Purge removes tickets of exited processes without touching writer.lock.
-Start honours a new -SessionId (32 hex digits) or generates one; read it from the returned metadata and pass it to every CLI and to -End.
Exit 3: writer busy beyond the wait limit (-WaitSeconds, SECONDBRAIN_LOCK_WAIT_SECONDS or lockWaitSeconds in config/shared.json).
.EXAMPLE
pwsh -NoProfile -File scripts/access.ps1 -Start -Mode Write -Client Codex -Repository my-org/secondbrain
#>
[CmdletBinding(DefaultParameterSetName='Status')]
param(
    [Parameter(Mandatory,ParameterSetName='Reconcile')][switch]$Reconcile,
    [Parameter(Mandatory,ParameterSetName='Start')][switch]$Start,
    [Parameter(ParameterSetName='Status')][switch]$Status,
    [Parameter(Mandatory,ParameterSetName='Queue')][switch]$Queue,
    [Parameter(ParameterSetName='Status')][Parameter(ParameterSetName='Queue')][switch]$Purge,
    [Parameter(Mandatory,ParameterSetName='End')][switch]$End,
    [Parameter(Mandatory,ParameterSetName='Renew')][switch]$Renew,
    [Parameter(Mandatory,ParameterSetName='Hold')][switch]$Hold,
    [string]$ConfigPath,
    [ValidateSet('Read','Write')][string]$Mode='Read',
    [string]$Client='PowerShell',
    [string]$Repository='secondbrain',
    [string]$TargetPath=(Get-Location).Path,
    [string]$SessionId,
    [Parameter(ParameterSetName='Start')][Parameter(ParameterSetName='Hold')][switch]$Exclusive,
    [ValidateRange(0,600)][int]$WaitSeconds=-1
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'access.metadata.final' = @{ it = 'Metadati finali non disponibili'; en = 'Final metadata not available' }
    'access.session.foreign' = @{ it = 'La sessione appartiene a un altro utente o postazione: avviane una tua con access.ps1 -Start'; en = 'The session belongs to another user or workstation: start your own with access.ps1 -Start' }
    'access.coordinator.exited' = @{ it = 'Processo di coordinamento terminato prima della registrazione'; en = 'Coordination process exited before registration' }
    'access.session.exists' = @{ it = 'SessionId gia in uso: scegliere un identificatore nuovo oppure omettere -SessionId'; en = 'SessionId already in use: choose a new identifier or omit -SessionId' }
    'access.open.timeout' = @{ it = 'Timeout apertura sessione'; en = 'Timeout opening the session' }
}
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
if ($WaitSeconds -ge 0) { $env:SECONDBRAIN_LOCK_WAIT_SECONDS=[string]$WaitSeconds }
$config=Read-SBConfiguration $ConfigPath -ReadOnly:($PSCmdlet.ParameterSetName -in @('Status','Queue','Start','Hold','End','Renew'))
$sessions=Join-Path $config.coordinationRoot 'sessions'
if ($Reconcile) {
    # Explicitly confirm relocated workstation folders: update the registration under the writer lock.
    $operation=Enter-SBOperation $config -ReconcileWorkstation
    try { ConvertTo-SBJson @{reconciled=$true;workstationId=$config.workstationId;repositoryRoot=$config.repositoryRoot;runtimeRoot=$config.runtimeRoot;backupRoot=$config.backupRoot} } finally { Exit-SBOperation $operation }
    exit 0
}
if ($PSCmdlet.ParameterSetName -eq 'Status') {
    if ($Purge) { Clear-SBStaleSessions $config 60 | Out-Null }
    @(Get-SBAccessStatus $config) | ConvertTo-Json -Depth 8
    # An interrupted transaction blocks writes on every host: identify who, when and how to recover it.
    if ($config.ContainsKey('pendingTransaction')) { [Console]::Error.WriteLine((Format-SBPendingTransaction $config.pendingTransaction)) }
    exit 0
}
if ($Queue) {
    @(Get-SBQueueStatus $config -Purge:$Purge) | ConvertTo-Json -Depth 8
    exit 0
}
if ($End -or $Renew) {
    Test-SBSessionId $SessionId
    $metadata=Read-SBJson (Join-Path $sessions ($SessionId+'.json')) $null
    if (!$metadata -or $metadata.computer -ne [Environment]::MachineName -or $metadata.user -ne [Security.Principal.WindowsIdentity]::GetCurrent().Name -or $metadata.workstationId -ne $config.workstationId) { throw (New-SBError 'access.session.foreign') }
    $signal=Join-Path $sessions ($SessionId+$(if($End){'.stop'}else{'.renew'}))
    Write-SBAccessMetadata $signal @{at=[DateTimeOffset]::UtcNow.ToString('o')}
    if ($End) {
        for($i=0;$i -lt 50;$i++){if((Read-SBJson (Join-Path $sessions ($SessionId+'.json')) @{}).status -ne 'active'){break};Start-Sleep -Milliseconds 100}
    }
    exit 0
}
Assert-SBPlainPath $sessions
[IO.Directory]::CreateDirectory($sessions)|Out-Null
if ($Start) {
    # A caller-supplied SessionId is honoured (it must be new); otherwise one is generated and returned in the metadata.
    if($SessionId){Test-SBSessionId $SessionId;if(Test-Path -LiteralPath (Join-Path $sessions ($SessionId+'.json'))){throw (New-SBError 'access.session.exists')}}
    else{$SessionId=[guid]::NewGuid().ToString('N')}
    # Closed, expired or abandoned sessions of earlier runs are removed here, so the folder never accumulates them.
    Clear-SBStaleSessions $config 60|Out-Null
    $processInfo=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
    # ShellExecute also isolates inheritable handles from native Windows pipelines.
    # The protocol communicates through atomic metadata, without helper stdout.
    $processInfo.UseShellExecute=$true;$processInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    foreach($arg in @('-NoProfile','-NonInteractive','-File',$PSCommandPath,'-Hold','-ConfigPath',$config.configPath,'-SessionId',$SessionId,'-Mode',$Mode,'-Client',$Client,'-Repository',$Repository,'-TargetPath',$TargetPath)){$processInfo.ArgumentList.Add($arg)}
    if($Exclusive){$processInfo.ArgumentList.Add('-Exclusive')}
    $process=[Diagnostics.Process]::Start($processInfo)
    try {
        # The writer session waits in the queue up to lockWaitMs; the opening window includes that wait.
        $openPolls=100+$(if($Mode -eq 'Write'){[int]((Get-SBLockWaitMs $config)/100)}else{0})
        for($i=0;$i -lt $openPolls;$i++) {
            $entry=Read-SBJson (Join-Path $sessions ($SessionId+'.json')) $null
            if($entry){if($entry.status -ne 'active'){if($entry.ContainsKey('busy') -and $entry.busy){[Console]::Error.WriteLine($entry.error);exit 3};throw $entry.error};ConvertTo-SBJson $entry;exit 0}
            if($process.HasExited){throw (New-SBError 'access.coordinator.exited')}
            Start-Sleep -Milliseconds 100
        }
        $process.Kill();throw (New-SBError 'access.open.timeout')
    } finally {$process.Dispose()}
}
Test-SBSessionId $SessionId
$writer=$null;$lease=$null
$path=Join-Path $sessions ($SessionId+'.json')
$metadata=@{sessionId=$SessionId;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;computer=[Environment]::MachineName;processId=$PID;client=$Client;repository=$Repository;path=[IO.Path]::GetFullPath($TargetPath);mode=$Mode;exclusive=[bool]$Exclusive;workstationId=$config.workstationId;startedAt=[DateTimeOffset]::UtcNow.ToString('o');heartbeat=[DateTimeOffset]::UtcNow.ToString('o');status='active'}
try {
    if($Mode -eq 'Write' -and $Exclusive) {
        $writerPath=Join-Path $config.coordinationRoot 'writer.lock';Assert-SBPlainPath $writerPath
        $waitMs=Get-SBLockWaitMs $config
        $onWait={ [Console]::Error.WriteLine('SecondBrain: scrittura occupata, attesa fino a '+[int]($waitMs/1000)+' s. Titolare: '+(Get-SBOperationOwnerText $config)) }.GetNewClosure()
        $writer=Open-SBWriterLock $config $writerPath $waitMs $onWait
    }
    $lease=[IO.File]::Open((Join-Path $sessions ($SessionId+'.lease')),[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $expires=[DateTimeOffset]::UtcNow.AddMinutes($config.sessionTimeoutMinutes)
    while($true) {
        if(Test-Path -LiteralPath (Join-Path $sessions ($SessionId+'.stop'))){break}
        $renewPath=Join-Path $sessions ($SessionId+'.renew')
        if(Test-Path -LiteralPath $renewPath){$expires=[DateTimeOffset]::UtcNow.AddMinutes($config.sessionTimeoutMinutes);[IO.File]::Delete($renewPath)}
        if([DateTimeOffset]::UtcNow -ge $expires){$metadata.status='expired';break}
        # Flush also checks that the handle is still usable; no further writes after an error.
        if($writer){$writer.Flush($true)}
        $lease.Flush($true)
        $metadata.heartbeat=[DateTimeOffset]::UtcNow.ToString('o');$metadata.expiresAt=$expires.ToString('o')
        Write-SBAccessMetadata $path $metadata
        Start-Sleep -Milliseconds 500
    }
    if($metadata.status -eq 'active'){$metadata.status='closed'}
} catch {
    $metadata.status='failed'
    if(Test-SBBusyError $_){$metadata.busy=$true;$metadata.error='SecondBrain occupato dopo '+[int]((Get-SBLockWaitMs $config)/1000)+' s. Titolare: '+(Get-SBOperationOwnerText $config)}
    else{$metadata.error=$_.Exception.Message}
}
finally {
    try{Write-SBAccessMetadata $path $metadata}catch{Write-Warning (Get-SBMessage 'access.metadata.final')}
    if($lease){$lease.Dispose()};if($writer){$writer.Dispose()}
    foreach($suffix in @('.stop','.renew','.lease')){[IO.File]::Delete((Join-Path $sessions ($SessionId+$suffix)))}
}
