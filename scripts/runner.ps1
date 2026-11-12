#requires -Version 7.5
<#
.SYNOPSIS
sb runner: opens the task runner for a repository, the desktop runner by default, with the command-line runner as fallback.
.DESCRIPTION
-Mode auto (default) opens the desktop runner (scripts/runner-gui.ps1, built when stale) on the repository; when it cannot open
(npm or cargo missing, build failed, no graphical session, the app exits at once) it falls back to the command-line runner and
prints its preview (scripts/run-ready-tasks.ps1 without -Run: nothing runs and nothing changes). -Mode gui opens only the desktop
runner and reports its failure; -Mode cli prints only the command-line preview.
The repository is the Git root of -RepositoryPath (default: the current directory), so a prompt started inside a product checkout
opens that product's dossier, tracker and ready tasks. The JSON on standard output names the mode used, the reason of a fallback and,
for the command line, the preview and the next command (the run itself starts only after the person confirms it, see REP15).
Exit codes: 0 runner opened or preview shown, 2 gui mode failed or the preview failed.
#>
[CmdletBinding()]
param([ValidateSet('auto','gui','cli')][string]$Mode='auto',[string]$RepositoryPath='.',[switch]$Rebuild,[string]$AppPath,[string]$ConfigPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'runner.mode.gui' = @{it='Apertura del runner desktop su {0}';en='Opening the desktop runner on {0}'}
    'runner.mode.fallback' = @{it='Runner desktop non disponibile ({0}): uso il runner da riga di comando';en='Desktop runner unavailable ({0}): using the command-line runner'}
    'runner.mode.cli' = @{it='Runner da riga di comando su {0}: anteprima senza esecuzione';en='Command-line runner on {0}: preview without running'}
}
# Exit codes of runner-gui.ps1 mapped to the fallback reason.
$guiReasons=@{2='prerequisites-missing';3='build-failed';4='no-display';5='launch-failed'}
$full=[IO.Path]::GetFullPath($RepositoryPath)
$top=if(Test-Path -LiteralPath $full -PathType Container){Invoke-SBGit $full @('rev-parse','--show-toplevel')}else{@{code=1}}
$repository=if($top.code -eq 0 -and $top.output){[IO.Path]::GetFullPath($top.output)}else{$full}
$configArgs=if($ConfigPath){@('-ConfigPath',$ConfigPath)}else{@()}
function Invoke-RunnerScript([string]$Script,[string[]]$ScriptArgs){
    # Child script: stderr goes straight to this console (progress), stdout is parsed as the JSON result.
    $out=(& (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $PSScriptRoot $Script) @ScriptArgs|Out-String)
    $code=$LASTEXITCODE
    $i=$out.IndexOf('{')
    @{code=$code;data=$(if($i -ge 0){try{$out.Substring($i)|ConvertFrom-Json -AsHashtable}catch{$null}}else{$null})}
}
$result=[ordered]@{mode=$null;requested=$Mode;repository=$repository;launched=$false;fallbackReason=$null;gui=$null;preview=$null;next=$null}
if($Mode -ne 'cli'){
    [Console]::Error.WriteLine((Get-SBMessage 'runner.mode.gui' @($repository)))
    $guiArgs=@('-RepositoryPath',$repository)
    if($AppPath){$guiArgs+=@('-AppPath',$AppPath)}
    if($Rebuild){$guiArgs+='-Rebuild'}
    $gui=Invoke-RunnerScript 'runner-gui.ps1' $guiArgs
    $result.gui=$gui.data
    if($gui.code -eq 0){
        $result.mode='gui';$result.launched=$true
        ConvertTo-SBJson $result;exit 0
    }
    $result.fallbackReason=if($guiReasons.ContainsKey($gui.code)){$guiReasons[$gui.code]}else{'exit-'+$gui.code}
    if($Mode -eq 'gui'){$result.mode='gui';ConvertTo-SBJson $result;exit 2}
    [Console]::Error.WriteLine((Get-SBMessage 'runner.mode.fallback' @($result.fallbackReason)))
}
[Console]::Error.WriteLine((Get-SBMessage 'runner.mode.cli' @($repository)))
$preview=Invoke-RunnerScript 'run-ready-tasks.ps1' (@('-CheckoutPath',$repository,'-MaxTasks','0')+$configArgs)
$result.mode='cli';$result.preview=$preview.data
$result.next='pwsh -NoProfile -File "'+(Join-Path $PSScriptRoot 'run-ready-tasks.ps1')+'" -CheckoutPath "'+$repository+'" -Run -Events'
ConvertTo-SBJson $result
exit $(if($preview.code -eq 0){0}else{2})
