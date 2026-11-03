#requires -Version 7.5
<#
.SYNOPSIS
Registra gli accessi cooperativi a SecondBrain; vedere docs/riferimento/operations.md.
Lo stato (-Status) e in sola lettura; -Purge elimina le sessioni chiuse, scadute o abbandonate da piu di 60 minuti.
-Reconcile conferma esplicitamente uno spostamento della postazione (stesso workstationId, percorsi diversi) e aggiorna il registro.
-Queue elenca la coda FIFO dei writer (posizione 1 = prossimo); con -Purge rimuove i ticket di processi terminati senza toccare writer.lock.
Exit 3: scrittura occupata oltre l'attesa (-WaitSeconds, SECONDBRAIN_LOCK_WAIT_SECONDS o lockWaitSeconds in config/shared.json).
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
    [ValidateRange(0,600)][int]$WaitSeconds=-1
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'access.metadata.final' = @{ it = 'Metadati finali non disponibili'; en = 'Final metadata not available' }
    'access.session.foreign' = @{ it = 'Sessione non appartenente alla postazione corrente'; en = 'Session does not belong to the current workstation' }
    'access.coordinator.exited' = @{ it = 'Processo di coordinamento terminato prima della registrazione'; en = 'Coordination process exited before registration' }
    'access.open.timeout' = @{ it = 'Timeout apertura sessione'; en = 'Timeout opening the session' }
}
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
if ($WaitSeconds -ge 0) { $env:SECONDBRAIN_LOCK_WAIT_SECONDS=[string]$WaitSeconds }
$config=Read-SBConfiguration $ConfigPath -ReadOnly:($PSCmdlet.ParameterSetName -in @('Status','Queue'))
$sessions=Join-Path $config.coordinationRoot 'sessions'
if ($Reconcile) {
    # Conferma esplicita dello spostamento di cartelle della postazione: aggiorna la registrazione sotto lock di scrittura.
    $operation=Enter-SBOperation $config -ReconcileWorkstation
    try { ConvertTo-SBJson @{reconciled=$true;workstationId=$config.workstationId;repositoryRoot=$config.repositoryRoot;runtimeRoot=$config.runtimeRoot;backupRoot=$config.backupRoot} } finally { Exit-SBOperation $operation }
    exit 0
}
if ($PSCmdlet.ParameterSetName -eq 'Status') {
    if ($Purge) { Clear-SBStaleSessions $config 60 | Out-Null }
    @(Get-SBAccessStatus $config) | ConvertTo-Json -Depth 8
    # Una transazione interrotta blocca le scritture di tutti gli host: chi, quando e come recuperarla.
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
    $SessionId=[guid]::NewGuid().ToString('N')
    $processInfo=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
    # ShellExecute isola anche gli handle ereditabili delle pipeline native Windows.
    # Il protocollo comunica tramite metadati atomici, senza stdout del supporto.
    $processInfo.UseShellExecute=$true;$processInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    foreach($arg in @('-NoProfile','-NonInteractive','-File',$PSCommandPath,'-Hold','-ConfigPath',$config.configPath,'-SessionId',$SessionId,'-Mode',$Mode,'-Client',$Client,'-Repository',$Repository,'-TargetPath',$TargetPath)){$processInfo.ArgumentList.Add($arg)}
    $process=[Diagnostics.Process]::Start($processInfo)
    try {
        # La sessione di scrittura attende in coda fino a lockWaitMs: la finestra di apertura la include.
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
$metadata=@{sessionId=$SessionId;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;computer=[Environment]::MachineName;processId=$PID;client=$Client;repository=$Repository;path=[IO.Path]::GetFullPath($TargetPath);mode=$Mode;workstationId=$config.workstationId;startedAt=[DateTimeOffset]::UtcNow.ToString('o');heartbeat=[DateTimeOffset]::UtcNow.ToString('o');status='active'}
try {
    if($Mode -eq 'Write') {
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
        # Flush verifica anche che l'handle sia ancora utilizzabile; nessuna nuova scrittura dopo un errore.
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
