#requires -Version 7.5
# Minimal profiles; reports and fixtures are retained after every outcome.
[CmdletBinding(DefaultParameterSetName='Fast')]
param(
    [Parameter(Mandatory,ParameterSetName='Full')][switch]$Full,
    [Parameter(Mandatory,ParameterSetName='Quick')][switch]$Quick,
    [Parameter(Mandatory,ParameterSetName='Only')][ValidateNotNullOrEmpty()]
    [ValidateSet('portable','workflows','trackers','audit2','trace','concurrency','pending','sources','resources','setup-status','external-audit','quick','git-environment','runtime','prompts','tracker-audit','mcp-writes','runner','ide','agents','lint','cleanclone')][string[]]$Only,
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
$budget=if($Only){0}elseif($Quick){15}elseif($Full){600}else{120}
$run=$null;$gitEnvironment=$null;$success=$false;$checks=0;$results=[Collections.Generic.List[object]]::new()
$saved=@{}
foreach($name in @('SECONDBRAIN_TEST_ROOT','SECONDBRAIN_TEST_RUN_CONTEXT','SECONDBRAIN_TEST_KEEP','GIT_TEMPLATE_DIR','SECONDBRAIN_RUNNER_REPOSITORY')){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
    $run=New-SBTestRun $brain $level $PSBoundParameters $profileWatch
    $run.noGit=$pure;$run.budgetSeconds=$budget
    $run.inputsBefore=Get-SBTestInputSnapshot $brain -NoGit:$pure
    $run.environment=Get-SBTestEvidenceEnvironment -NoGit:$pure
    Save-SBTestRunRecord $run
    $env:SECONDBRAIN_TEST_ROOT=$run.directory;$env:SECONDBRAIN_TEST_RUN_CONTEXT=$run.report;$env:SECONDBRAIN_TEST_KEEP='1'
    # The suites work on synthetic fixtures and exercise global views: a runner session scope (#382) inherited by the test process does not apply to them; restored at the end.
    foreach($name in @('SECONDBRAIN_RUNNER_REPOSITORY')){[Environment]::SetEnvironmentVariable($name,$null,'Process')}
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
            # 'pending' is both an essential group (in-process pending block) and the standalone CLI suite test-secondbrain-pending.ps1 (#521).
            $extras=if($Only){@($Only|Where-Object {$_ -in @('trace','concurrency','pending','sources','resources','setup-status','external-audit','runtime','prompts','tracker-audit','mcp-writes','runner','ide','agents','lint','cleanclone')})}elseif($Full){@('trace','concurrency','pending','sources','resources','setup-status','external-audit','runtime','prompts','tracker-audit','mcp-writes','runner','ide','agents','lint','cleanclone')}else{@()}
            # Full runs the extra suites as separate processes alongside the essential suite (own fixtures, own logs); -Sequential restores one-by-one execution.
            $parallel=[bool]($Full -and !$Sequential -and $extras.Count)
            function Start-SuiteJob($Spec){
                Start-Job -Name ('suite-'+$Spec.key) -ArgumentList $Spec -ScriptBlock {
                    param($Spec)
                    $Key=$Spec.key;$File=$Spec.file;$suiteArguments=@($Spec.arguments)
                    $watch=[Diagnostics.Stopwatch]::StartNew()
                    $output=@(& pwsh -NoProfile -File $File @suiteArguments 2>&1|ForEach-Object {[string]$_});$code=$LASTEXITCODE
                    [pscustomobject]@{key=$Key;seconds=[math]::Round($watch.Elapsed.TotalSeconds,3);exitCode=$code;output=$output}
                }
            }
            $jobs=@()
            if($parallel){
                # Portable's extended checks use an independent fixture. Run them
                # alongside the remaining groups; Sequential keeps the original order.
                $specs=@($extras|Where-Object {$_ -ne 'concurrency'}|ForEach-Object {@{key=$_;file=(Join-Path $PSScriptRoot ('test-secondbrain-'+$_+'.ps1'));arguments=@()}})
                $specs+=@{key='essential-portable';file=(Join-Path $PSScriptRoot 'test-secondbrain-essential.ps1');arguments=@('-Groups','portable','-Extended')}
                $groups=@($groups|Where-Object {$_ -ne 'portable'})
                $jobs=@($specs|ForEach-Object {Start-SuiteJob $_})
                # concurrency measures lock contention and failed under the load of the parallel suites (#431): it runs alone after them.
                $extras=@($extras|Where-Object {$_ -eq 'concurrency'})
            }
            # Default profile: the essential groups run as separate processes with their own fixtures so the profile stays within its budget (#465); -Sequential, -Only and -Full keep their own behavior.
            if(!$Full -and !$Sequential -and !$Only -and $groups.Count -gt 1){
                $essentialFile=Join-Path $PSScriptRoot 'test-secondbrain-essential.ps1'
                $jobs=@(@(@('trackers','workflows'),@('pending'))|ForEach-Object {Start-SuiteJob @{key=('essential-'+($_ -join '-'));file=$essentialFile;arguments=@('-Groups',($_ -join ','))}})
                $groups=@('portable')
            }
            try{
                if($groups.Count){Invoke-MinimalSuite 'essential' {& (Join-Path $PSScriptRoot 'test-secondbrain-essential.ps1') -Groups $groups -Extended:$Full}}
            }catch{
                if($jobs.Count){$jobs|Wait-Job|Receive-Job|Out-Null;$jobs|Remove-Job -Force}
                throw
            }
            $failedJob=$null
            foreach($job in $jobs){
                $job|Wait-Job|Out-Null
                $outcome=@(Receive-Job $job)|Select-Object -Last 1;Remove-Job $job -Force
                if(!$outcome){$outcome=[pscustomobject]@{key=($job.Name -replace '^suite-','');seconds=0;exitCode=1;output=@('Suite job returned no result.')}}
                $log=Join-Path $run.directory ('suite-'+$outcome.key+'.log')
                [IO.File]::WriteAllLines($log,[string[]]@($outcome.output),[Text.UTF8Encoding]::new($false))
                $code=if($outcome.exitCode){1}else{0}
                $results.Add(@{key=$outcome.key;seconds=$outcome.seconds;exitCode=$code;status=$(if($code){'failed'}else{'passed'});log=$log})
                if($code){if(!$failedJob){$failedJob=$outcome};$outcome.output|Write-Output;continue}
                Write-Output ((@($outcome.output|Where-Object {$_ -match '^SUCCESS'}) -join '; ')+' ['+$outcome.key+', '+[math]::Round($outcome.seconds,2)+' s]')
                $outcome.output|Write-Output
            }
            if($failedJob){throw ('Suite failed: '+$failedJob.key)}
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
