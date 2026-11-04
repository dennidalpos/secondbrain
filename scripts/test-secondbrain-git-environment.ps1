#requires -Version 7.5
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'test-git-environment.ps1')
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
    Assert-GitEnvironment ($caught -and (Get-GitEnvironmentSnapshot) -ceq $before) 'runner restores environment on setup failure'
    $env:SECONDBRAIN_TEST_ROOT = $savedRoot
    & (Join-Path $PSScriptRoot 'test-secondbrain.ps1') -Only quick -KeepFixtures | Out-Null
    Assert-GitEnvironment ((Get-GitEnvironmentSnapshot) -ceq $before) 'runner restores environment after a successful child suite'
    Remove-Item Env:GIT_CONFIG_VALUE_0
    $before = Get-GitEnvironmentSnapshot; $caught = $false
    try { Enter-SBTestGitEnvironment | Out-Null } catch { $caught = $true }
    Assert-GitEnvironment ($caught -and (Get-GitEnvironmentSnapshot) -ceq $before) 'missing inherited value rejected without changes'
    'SUCCESS GIT ENVIRONMENT: ' + $checks + ' checks'
} finally {
    $env:SECONDBRAIN_TEST_ROOT = $savedRoot
    Get-ChildItem Env:GIT_CONFIG* | Remove-Item
    Remove-Item Env:GIT_TEMPLATE_DIR -ErrorAction SilentlyContinue
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
}
