#requires -Version 7.5
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'test-git-environment.ps1')
. (Join-Path $PSScriptRoot 'test-run-evidence.ps1')
if (!$IsWindows) { 'SUCCESS GIT ENVIRONMENT: Windows-only checks skipped'; return }
$checks = 0
function Assert-GitEnvironment($Value, [string]$Message) {
    if (!$Value) { throw ('FAIL GIT ENVIRONMENT: ' + $Message) }
    $script:checks++
}
function Get-GitEnvironmentSnapshot {
    $snapshot = [ordered]@{}
    @(Get-ChildItem Env:GIT_CONFIG*; Get-Item Env:GIT_TEMPLATE_DIR -ErrorAction SilentlyContinue) | Sort-Object Name | ForEach-Object { $snapshot[$_.Name] = $_.Value }
    $snapshot | ConvertTo-Json -Compress
}
$original = @{}
@(Get-ChildItem Env:GIT_CONFIG*; Get-Item Env:GIT_TEMPLATE_DIR -ErrorAction SilentlyContinue) | ForEach-Object { $original[$_.Name] = $_.Value }
$savedRoot = $env:SECONDBRAIN_TEST_ROOT
$savedContext=$env:SECONDBRAIN_TEST_RUN_CONTEXT
try {
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
    $brainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $testBase=if($savedRoot){$savedRoot}else{Join-Path $brainRoot '.runtime/tests'}
    $testBase=Assert-SBCentralDataPath $brainRoot $testBase
    $fixture=Join-Path $testBase ('fixture-'+(Get-Date -Format yyyyMMdd)+'-git-env-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    [IO.Directory]::CreateDirectory($fixture)|Out-Null
    $globalConfig=Join-Path $fixture 'global.config'
    [IO.File]::WriteAllText($globalConfig,"[core]`nlongpaths = false`n[secondbrain]`nfixtureGlobal = preserved`n")
    $globalHash=Get-SBFileHash $globalConfig
    Get-ChildItem Env:GIT_CONFIG* | Remove-Item
    Remove-Item Env:GIT_TEMPLATE_DIR -ErrorAction SilentlyContinue
    foreach ($mode in @('absent','enabled','additional')) {
        if ($mode -eq 'enabled') {
            $env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
        } elseif ($mode -eq 'additional') {
            $env:GIT_CONFIG_COUNT = '2'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'false'
            $env:GIT_CONFIG_KEY_1 = 'secondbrain.fixture'; $env:GIT_CONFIG_VALUE_1 = 'preserved'
            # Unused trailing entries must also survive restoration.
            $env:GIT_CONFIG_KEY_2 = 'unused.key'; $env:GIT_CONFIG_VALUE_2 = 'unused value'
            $env:GIT_CONFIG_GLOBAL = $globalConfig
        }
        $before = Get-GitEnvironmentSnapshot
        foreach ($fail in @($false,$true)) {
            $snapshot = Enter-SBTestGitEnvironment
            $caught = $false
            try {
                $effective = & pwsh -NoProfile -Command 'git config --type=bool --get core.longpaths'
                Assert-GitEnvironment ($LASTEXITCODE -eq 0 -and $effective -ceq 'true') ('child effective value: ' + $mode)
                if ($mode -eq 'additional') {
                    Assert-GitEnvironment ((& git config --get secondbrain.fixture) -ceq 'preserved') 'inherited pair preserved'
                    Assert-GitEnvironment ((& git config --get secondbrain.fixtureGlobal) -ceq 'preserved') 'inherited global config preserved'
                }
                if ($fail) { throw 'deliberate fixture failure' }
            } catch {
                if (!$fail -or $_.Exception.Message -ne 'deliberate fixture failure') { throw }
                $caught = $true
            } finally { Exit-SBTestGitEnvironment $snapshot }
            Assert-GitEnvironment ((Get-GitEnvironmentSnapshot) -ceq $before) ('exact environment restored: ' + $mode)
            Assert-GitEnvironment ($caught -eq $fail) 'success/failure paths exercised'
        }
    }
    $env:GIT_CONFIG_COUNT='1';$env:GIT_CONFIG_KEY_0='core.longpaths';$env:GIT_CONFIG_VALUE_0='true'
    $before=Get-GitEnvironmentSnapshot;$caught=$false
    try { Assert-SBTestGitEnvironment } catch { $caught=$true }
    Assert-GitEnvironment ($caught -and (Get-GitEnvironmentSnapshot) -ceq $before) 'standalone command-only override rejected when inherited file config disables longpaths'
    $snapshot = Enter-SBTestGitEnvironment
    try {
        $checkout=Join-Path $fixture 'repo'
        [IO.Directory]::CreateDirectory($checkout)|Out-Null
        & git -C $checkout init -q
        Assert-GitEnvironment ($LASTEXITCODE -eq 0) 'long-path fixture init succeeds'
        $top=& git -C $checkout rev-parse --show-toplevel
        Assert-GitEnvironment ($LASTEXITCODE -eq 0 -and (Test-SBSamePath $top $checkout)) 'fixture resolves itself rather than the parent repository'
        $relative=('nested-segment/'*12)+'payload.txt'
        $payload=Join-Path $checkout $relative
        Assert-GitEnvironment ($payload.Length -gt 260) 'tracked payload exceeds MAX_PATH under the actual runtime root'
        [IO.Directory]::CreateDirectory((Split-Path $payload))|Out-Null
        [IO.File]::WriteAllText($payload,'long-path-payload')
        & git -C $checkout add -- $relative
        Assert-GitEnvironment ($LASTEXITCODE -eq 0) 'long tracked path added'
        & git -C $checkout -c user.name=Fixture -c user.email=fixture@example.com commit -qm 'Synthetic long path'
        Assert-GitEnvironment ($LASTEXITCODE -eq 0) 'long tracked path committed'
        $content=& git -C $checkout show ('HEAD:'+$relative)
        Assert-GitEnvironment ($LASTEXITCODE -eq 0 -and $content -ceq 'long-path-payload') 'long tracked payload read back exactly'
        Assert-GitEnvironment ((Get-SBFileHash $globalConfig) -eq $globalHash) 'inherited persistent config unchanged'
    } finally { Exit-SBTestGitEnvironment $snapshot }
    $env:GIT_CONFIG_COUNT = 'invalid'
    $before = Get-GitEnvironmentSnapshot; $caught = $false
    try { Enter-SBTestGitEnvironment | Out-Null } catch { $caught = $true }
    Assert-GitEnvironment ($caught -and (Get-GitEnvironmentSnapshot) -ceq $before) 'invalid count rejected without changes'
    $env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'core.longpaths'; $env:GIT_CONFIG_VALUE_0 = 'true'
    $before = Get-GitEnvironmentSnapshot
    # The runner must restore even if fixture setup fails before its main test block.
    $env:SECONDBRAIN_TEST_ROOT = [IO.Path]::GetPathRoot($PSScriptRoot)
    $caught = $false
    try { & (Join-Path $PSScriptRoot 'test-secondbrain.ps1') -Only quick | Out-Null } catch { $caught = $true }
    Assert-GitEnvironment ($caught -and (Get-GitEnvironmentSnapshot) -ceq $before) ('runner restores environment on setup failure (caught='+$caught+'; exact='+((Get-GitEnvironmentSnapshot) -ceq $before)+')')
    $env:SECONDBRAIN_TEST_ROOT = $savedRoot
    $runnerEnvironmentBefore=@{root=$env:SECONDBRAIN_TEST_ROOT;context=$env:SECONDBRAIN_TEST_RUN_CONTEXT;template=$env:GIT_TEMPLATE_DIR;keep=$env:SECONDBRAIN_TEST_KEEP}|ConvertTo-Json -Compress
    & (Join-Path $PSScriptRoot 'test-secondbrain.ps1') -Only quick -KeepFixtures | Out-Null
    Assert-GitEnvironment ((Get-GitEnvironmentSnapshot) -ceq $before) 'runner restores environment after a successful child suite'
    Assert-GitEnvironment ((@{root=$env:SECONDBRAIN_TEST_ROOT;context=$env:SECONDBRAIN_TEST_RUN_CONTEXT;template=$env:GIT_TEMPLATE_DIR;keep=$env:SECONDBRAIN_TEST_KEEP}|ConvertTo-Json -Compress) -ceq $runnerEnvironmentBefore) 'runner restores root, parent context, retention and template exactly'
    $parent=if($savedContext){Read-SBJson $savedContext $null}else{$null}
    $childBase=if($parent){$parent.baseRoot}else{$testBase}
    $latest=Read-SBJson (Join-Path $childBase 'esito.json') $null
    $child=Read-SBJson $latest.report $null
    Assert-GitEnvironment ($child.status -eq 'passed' -and $child.inputsStable -and $child.eligibleForClosure) 'successful child retains stable input hashes and eligibility'
    Assert-GitEnvironment ((Test-Path $child.directory) -and (Test-Path $child.log) -and !$child.fixtures.removed) 'successful child keeps fixtures, permanent report and runner log'
    Assert-GitEnvironment ($child.suites.Count -eq 1 -and (Test-Path $child.suites[0].log) -and $child.suites[0].exitCode -eq 0) 'per-suite log and exit code retained'
    if($parent){
        Assert-GitEnvironment ((Test-SBSamePath (Split-Path $child.directory) (Split-Path $savedRoot)) -and (Test-SBSamePath $child.parent.report $savedContext)) 'nested runner is a linked sibling of the parent'
        $oldChild=Join-Path $savedRoot $child.runId
        Assert-GitEnvironment ($child.directory.Length -lt $oldChild.Length -and !(Test-Path $oldChild)) 'sibling run removes one run segment without shortening long-path payloads'
        [IO.File]::WriteAllText((Join-Path $fixture 'runner-depth.json'),(ConvertTo-SBJson @{before=$oldChild.Length;after=$child.directory.Length;removedCharacters=($oldChild.Length-$child.directory.Length);parent=$savedRoot;child=$child.directory}))
        $env:SECONDBRAIN_TEST_ROOT=$fixture;$caught=$false
        try{New-SBTestRun $brainRoot 'Only' @{}|Out-Null}catch{$caught=$true}
        Assert-GitEnvironment $caught 'parent context with an unrelated fixture root is rejected'
        $env:SECONDBRAIN_TEST_ROOT=$savedRoot
    }
    # Two independent processes share a base, never a permanent report or fixture directory.
    $parallelBase=Join-Path $fixture 'parallel'
    $processes=@(1..2|ForEach-Object {
        $info=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
        $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
        foreach($argument in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'test-secondbrain.ps1'),'-Only','quick')){$info.ArgumentList.Add($argument)}
        $info.Environment['SECONDBRAIN_TEST_ROOT']=$parallelBase;$info.Environment.Remove('SECONDBRAIN_TEST_RUN_CONTEXT')|Out-Null
        $info.Environment.Remove('SECONDBRAIN_TEST_KEEP')|Out-Null
        $info.Environment['SB_SYNTHETIC_SECRET']='must-not-appear-in-report'
        $p=[Diagnostics.Process]::Start($info);@{process=$p;output=$p.StandardOutput.ReadToEndAsync();error=$p.StandardError.ReadToEndAsync()}
    })
    try{
        foreach($entry in $processes){$entry.process.WaitForExit();Assert-GitEnvironment ($entry.process.ExitCode -eq 0) ('concurrent runner succeeds: '+$entry.error.Result)}
    }finally{foreach($entry in $processes){$entry.process.Dispose()}}
    $parallelReports=@(Get-ChildItem $parallelBase -Directory -Filter 'run-*'|ForEach-Object {Read-SBJson (Join-Path $_.FullName 'run.json') $null})
    Assert-GitEnvironment ($parallelReports.Count -eq 2 -and @($parallelReports.runId|Select-Object -Unique).Count -eq 2 -and @($parallelReports|Where-Object {$_.status -eq 'passed' -and (Test-Path $_.log)}).Count -eq 2) 'concurrent runs retain distinct complete reports and logs'
    Assert-GitEnvironment (@($parallelReports|Where-Object {$_.fixtures.kept -and !$_.fixtures.keepRequested}).Count -eq 2) 'retention is the default without either compatibility option'
    Assert-GitEnvironment ((Read-SBJson (Join-Path $parallelBase 'esito.json') $null).runId -in $parallelReports.runId) 'latest summary links one complete permanent report'
    Assert-GitEnvironment (@($parallelReports|Where-Object {(Read-SBText $_.report).Contains('must-not-appear-in-report')}).Count -eq 0) 'unlisted environment values are excluded from reports'
    # Fingerprint a synthetic input repository: edits and additions invalidate its snapshots.
    $evidenceRepo=Join-Path $fixture 'inputs';[IO.Directory]::CreateDirectory($evidenceRepo)|Out-Null
    & git -C $evidenceRepo init -q;Assert-GitEnvironment ($LASTEXITCODE -eq 0) 'input evidence fixture initialized'
    $source=Join-Path $evidenceRepo 'source.txt';[IO.File]::WriteAllText($source,'before')
    & git -C $evidenceRepo add -- source.txt
    $inputBefore=Get-SBTestInputSnapshot $evidenceRepo
    [IO.File]::WriteAllText($source,'after')
    $inputAfter=Get-SBTestInputSnapshot $evidenceRepo
    Assert-GitEnvironment ($inputBefore.sha256 -cne $inputAfter.sha256) 'working-tree edit changes input fingerprint'
    $env:SECONDBRAIN_TEST_ROOT=Join-Path $evidenceRepo '.runtime/fixture-input-change';$env:SECONDBRAIN_TEST_RUN_CONTEXT=$null
    $invalidRun=New-SBTestRun $evidenceRepo 'Only' @{};$invalidRun.inputsBefore=$inputBefore;$caught=$false
    try{Complete-SBTestRun $invalidRun $true 1 @() $false}catch{$caught=$true}
    $invalidReport=Read-SBJson $invalidRun.report $null
    Assert-GitEnvironment ($caught -and $invalidReport.status -eq 'invalidated' -and !$invalidReport.eligibleForClosure -and (Test-Path $invalidRun.directory)) 'changed input invalidates closure while retaining evidence'
    [IO.File]::WriteAllText((Join-Path $evidenceRepo 'new.txt'),'new')
    Assert-GitEnvironment ((Get-SBTestInputSnapshot $evidenceRepo).sha256 -cne $inputAfter.sha256) 'new nonignored input changes fingerprint'
    # Preparation failures retain errors and a failed report, even if Git cannot enumerate inputs.
    $env:SECONDBRAIN_TEST_ROOT=Join-Path $fixture 'failed';$env:GIT_CONFIG_COUNT='invalid';$caught=$false
    $failedBefore=Get-GitEnvironmentSnapshot
    try{& (Join-Path $PSScriptRoot 'test-secondbrain.ps1') -Only quick|Out-Null}catch{$caught=$true}
    $failed=Read-SBJson (Join-Path $env:SECONDBRAIN_TEST_ROOT 'esito.json') $null
    $failedReport=Read-SBJson $failed.report $null
    Assert-GitEnvironment ($caught -and $failedReport.status -eq 'failed' -and !$failedReport.eligibleForClosure -and $failedReport.error -and (Test-Path $failedReport.log)) 'preparation failure keeps error, log and failed permanent report'
    Assert-GitEnvironment ((Get-GitEnvironmentSnapshot) -ceq $failedBefore) 'runner restores environment after evidence preparation failure'
    $env:SECONDBRAIN_TEST_ROOT=$savedRoot;$env:SECONDBRAIN_TEST_RUN_CONTEXT=$savedContext;$env:GIT_CONFIG_COUNT='1'
    Remove-Item Env:GIT_CONFIG_VALUE_0
    $before = Get-GitEnvironmentSnapshot; $caught = $false
    try { Enter-SBTestGitEnvironment | Out-Null } catch { $caught = $true }
    Assert-GitEnvironment ($caught -and (Get-GitEnvironmentSnapshot) -ceq $before) 'missing inherited value rejected without changes'
    'SUCCESS GIT ENVIRONMENT: ' + $checks + ' checks'
} finally {
    $env:SECONDBRAIN_TEST_ROOT = $savedRoot
    $env:SECONDBRAIN_TEST_RUN_CONTEXT=$savedContext
    Get-ChildItem Env:GIT_CONFIG* | Remove-Item
    Remove-Item Env:GIT_TEMPLATE_DIR -ErrorAction SilentlyContinue
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
}
