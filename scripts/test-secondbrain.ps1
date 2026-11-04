#requires -Version 7.5
# Minimal profiles; reports and fixtures are retained after every outcome.
[CmdletBinding(DefaultParameterSetName='Fast')]
param(
    [Parameter(Mandatory,ParameterSetName='Full')][switch]$Full,
    [Parameter(Mandatory,ParameterSetName='Quick')][switch]$Quick,
    [Parameter(Mandatory,ParameterSetName='Only')][ValidateNotNullOrEmpty()]
    [ValidateSet('portable','workflows','trackers','audit2','trace','concurrency','pending','sources','external-audit','quick','git-environment')][string[]]$Only,
    [switch]$KeepFixtures,[switch]$Sequential
)
$profileWatch=[Diagnostics.Stopwatch]::StartNew()
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
. (Join-Path $PSScriptRoot 'test-git-environment.ps1')
. (Join-Path $PSScriptRoot 'test-run-evidence.ps1')
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$level=if($Only){'Only'}elseif($Quick){'Quick'}elseif($Full){'Full'}else{'Fast'}
$pure=[bool]($Quick -or ($Only -and @($Only|Where-Object {$_ -ne 'quick'}).Count -eq 0))
$budget=if($Only){0}elseif($Quick){15}elseif($Full){300}else{90}
$run=$null;$gitEnvironment=$null;$success=$false;$checks=0;$results=[Collections.Generic.List[object]]::new()
$saved=@{}
foreach($name in @('SECONDBRAIN_TEST_ROOT','SECONDBRAIN_TEST_RUN_CONTEXT','SECONDBRAIN_TEST_KEEP','GIT_TEMPLATE_DIR')){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
    $run=New-SBTestRun $brain $level $PSBoundParameters $profileWatch
    $run.noGit=$pure;$run.budgetSeconds=$budget
    $run.inputsBefore=Get-SBTestInputSnapshot $brain -NoGit:$pure
    $run.environment=Get-SBTestEvidenceEnvironment -NoGit:$pure
    Save-SBTestRunRecord $run
    $env:SECONDBRAIN_TEST_ROOT=$run.directory;$env:SECONDBRAIN_TEST_RUN_CONTEXT=$run.report;$env:SECONDBRAIN_TEST_KEEP='1'
    if(!$pure){$gitEnvironment=Enter-SBTestGitEnvironment}
    & {
        function Invoke-MinimalSuite([string]$Key,[scriptblock]$Body){
            $watch=[Diagnostics.Stopwatch]::StartNew();$code=0
            try{$output=@(& $Body)}catch{$output=@(($_|Out-String),$_.ScriptStackTrace);$code=1}
            $watch.Stop()
            $log=Join-Path $run.directory ('suite-'+$Key+'.log')
            [IO.File]::WriteAllLines($log,[string[]]@($output|ForEach-Object {[string]$_}),[Text.UTF8Encoding]::new($false))
            $results.Add(@{key=$Key;seconds=[math]::Round($watch.Elapsed.TotalSeconds,3);exitCode=$code;status=$(if($code){'failed'}else{'passed'});log=$log})
            if($code){$output|Write-Output;throw ('Suite failed: '+$Key)}
            $summary=@($output|Where-Object {$_ -match '^SUCCESS'})
            Write-Output (($summary -join '; ')+' ['+$Key+', '+[math]::Round($watch.Elapsed.TotalSeconds,2)+' s]')
            if($Full){$output|Write-Output}
        }
        if(!$Only -or 'quick' -in $Only){Invoke-MinimalSuite 'quick' {& (Join-Path $PSScriptRoot 'test-secondbrain-quick.ps1')}}
        if(!$pure){
            $groups=if($Only){@($Only|Where-Object {$_ -in @('portable','trackers','workflows','pending','audit2','git-environment')})}elseif($Full){@('portable','trackers','workflows','pending','audit2','git-environment')}else{@('portable','trackers','workflows','pending')}
            if($groups.Count){Invoke-MinimalSuite 'essential' {& (Join-Path $PSScriptRoot 'test-secondbrain-essential.ps1') -Groups $groups -Extended:$Full}}
            $extras=if($Only){@($Only|Where-Object {$_ -in @('trace','concurrency','sources','external-audit')})}elseif($Full){@('trace','concurrency','sources','external-audit')}else{@()}
            foreach($extra in $extras){
                $suiteFile=Join-Path $PSScriptRoot ('test-secondbrain-'+$extra+'.ps1')
                Invoke-MinimalSuite $extra {
                    # The external transport harness closes over script-local mock functions.
                    # A child process gives those functions the same scope as its direct entry point.
                    if($extra -eq 'external-audit'){
                        & pwsh -NoProfile -File $suiteFile
                        if($LASTEXITCODE){throw ('External audit failed with code '+$LASTEXITCODE)}
                    }else{& $suiteFile}
                }
            }
        }
    } *>&1 | Tee-Object -FilePath $run.log
    $checks=$results.Count
    if(!$checks){throw 'No test suite ran.'}
    $success=$true
} catch {
    if($run){$run.error=$_.Exception.Message;[IO.File]::AppendAllText($run.log,("`nERROR: "+$_+"`n"))}
    throw
} finally {
    try {
        try{if($gitEnvironment){Exit-SBTestGitEnvironment $gitEnvironment}}finally{
            foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}
        }
    } catch {
        $success=$false
        if($run){$run.error=$_.Exception.Message}
        throw
    } finally {
        if($run){Complete-SBTestRun $run $success $results.Count $results.ToArray() ([bool]$KeepFixtures)}
    }
}
'SUCCESS '+$level+': '+[math]::Round($run.durationSeconds,2)+' s; groups='+$checks+'; retained report: '+$run.report
