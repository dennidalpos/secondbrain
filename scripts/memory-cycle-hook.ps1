#requires -Version 7.5
# Native Stop bridge. A missing or stale per-turn permit never writes anything.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('claude-code','codex','antigravity')][string]$Client,
    [Parameter(Mandatory)][string]$PermitPath,[string]$ConfigPath,[switch]$Diagnostics)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.MemoryCycle.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{'cycle.hook.failed'=@{it='Ciclo memorie: acquisizione non eseguita; hook non bloccante ({0})';en='Memory cycle: capture not performed; nonblocking hook ({0})'}}
$session=$null;$lock=$null;$config=$null
$phase='permit';$outcome='suppressed'
try{
    if(![Console]::IsInputRedirected -or ![IO.File]::Exists($PermitPath)){exit 0}
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $permitFull=[IO.Path]::GetFullPath($PermitPath)
    $permitRoot=[IO.Path]::GetFullPath((Join-Path $brain ('.runtime/hosts/'+(Get-SBHostId)+'/repos'))).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(!$permitFull.StartsWith($permitRoot,[StringComparison]::OrdinalIgnoreCase)){exit 0}
    Assert-SBPlainPath $PermitPath
    $permit=Read-SBJson $PermitPath $null
    if(!(Test-SBCyclePersistence $permit)){exit 0}
    if(!$permit.ContainsKey('workspace') -or !$permit.ContainsKey('repository')){exit 0}
    $phase='scope'
    $workspace=Assert-SBCycleWorkspace $brain $permit.repository $permit.workspace
    if(!$permitFull.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){exit 0}
    [void](Resolve-SBCycleDossier $brain $permit.repository)
    $phase='native-event'
    $native=[Console]::In.ReadToEnd()|ConvertFrom-Json -AsHashtable
    $prepared=ConvertFrom-SBCycleNativeTurn $Client $native $permit
    if($prepared.state -ne 'prepared'){exit 0}
    $phase='binding'
    $config=Read-SBConfiguration $ConfigPath -ReadOnly
    $nativeRoots=@()
    if($native.ContainsKey('cwd') -and $native.cwd){$nativeRoots+=,[string]$native.cwd}
    if($native.ContainsKey('workspacePaths')){$nativeRoots+=@($native.workspacePaths)}
    if(!$nativeRoots.Count){exit 0}
    $identities=@()
    foreach($nativeRoot in $nativeRoots){
        if(![IO.Path]::IsPathFullyQualified([string]$nativeRoot)){exit 0}
        $currentRoot=[IO.Path]::GetFullPath([string]$nativeRoot).TrimEnd('\','/')
        $bindings=@($config.bindings|Where-Object {
            $bound=[IO.Path]::GetFullPath([string]$_.path).TrimEnd('\','/')
            (Test-SBSamePath $bound $currentRoot) -or $currentRoot.StartsWith($bound+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
        }|Sort-Object {([string]$_.path).Length} -Descending)
        if(!$bindings.Count){exit 0}
        $identities+=,[string]$bindings[0].identity
    }
    $identities=@($identities|Sort-Object -Unique)
    if($identities.Count -ne 1 -or $identities[0] -cne $permit.repository){exit 0}
    $phase='writer'
    $session=& (Join-Path $PSScriptRoot 'access.ps1') -Start -Mode Write -Client memory-cycle-hook -Repository $permit.repository -ConfigPath $config.configPath|ConvertFrom-Json -AsHashtable
    $lock=Enter-SBOperation $config $session.sessionId
    $allowed=if($permit.ContainsKey('allowedAttachmentPaths')){@($permit.allowedAttachmentPaths)}else{@()}
    $phase='capture'
    $result=Save-SBCycleTurn -BrainRoot $brain -Envelope $prepared.envelope -Workspace $permit.workspace -BackupRoot $config.backupRoot -AllowedAttachmentPaths $allowed -Apply
    $outcome=$result.state
    if($result.state -in @('captured','duplicate')){
        if($permit.ContainsKey('candidatePath') -and $permit.candidatePath){
            $candidateFull=[IO.Path]::GetFullPath($permit.candidatePath)
            $scope=[IO.Path]::GetFullPath($permit.workspace).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
            if(!$candidateFull.StartsWith($scope,[StringComparison]::OrdinalIgnoreCase) -or !$permit.ContainsKey('candidateSha256')){exit 0}
            Assert-SBPlainPath $candidateFull
            if((Get-SBFileHash $candidateFull) -cne $permit.candidateSha256){exit 0}
            $candidate=Read-SBJson $permit.candidatePath $null
            if($candidate -and $candidate.ContainsKey('captureSha256') -and $candidate.captureSha256 -ceq 'bind-current-turn'){
                $candidate.capturePath=$result.path;$candidate.captureSha256=Get-SBFileHash $result.path
            }
            if($candidate -and $candidate.repository -ceq $permit.repository -and $candidate.capturePath -ceq $result.path){
                $phase='promotion'
                [void](Invoke-SBCyclePromotion -BrainRoot $brain -Candidate $candidate -Workspace $permit.workspace -BackupRoot $config.backupRoot -Apply)
            }
        }
    }
}catch{
    # Do not print transcript data or exception messages containing paths/content.
    $outcome='error'
    [Console]::Error.WriteLine((Get-SBMessage 'cycle.hook.failed' @($_.Exception.GetType().Name)))
}finally{
    if($Diagnostics){
        [Console]::Error.WriteLine((@{schemaVersion=1;phase=$phase;outcome=$outcome}|ConvertTo-Json -Compress))
    }
    if($lock){Exit-SBOperation $lock}
    if($session){& (Join-Path $PSScriptRoot 'access.ps1') -End -SessionId $session.sessionId -ConfigPath $config.configPath|Out-Null}
}
exit 0
