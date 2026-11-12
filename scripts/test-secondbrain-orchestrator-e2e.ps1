#requires -Version 7.5
# End-to-end tests of the desktop orchestrator: the real release binary driven by Playwright through the WebView2 DevTools protocol,
# on the synthetic SecondBrain of test-orchestrator-fixture.ps1 (isolated app settings, fake Claude Code, no real agent on PATH).
# Windows only (WebView2). Skipped with a reason when the binary or Playwright is missing; build with runner-gui.ps1 -NoLaunch and npm ci.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$app=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../app/orchestrator'))
$binary=Join-Path $app 'src-tauri/target/release/secondbrain-orchestrator.exe'
$playwright=Join-Path $app 'node_modules/@playwright/test/package.json'
$skip=if(!$IsWindows){'not Windows (WebView2 DevTools is Windows only)'}
    elseif(!(Test-Path -LiteralPath $binary)){'release binary missing (scripts/runner-gui.ps1 -NoLaunch builds it)'}
    elseif(!(Test-Path -LiteralPath $playwright)){'Playwright missing (npm ci in app/orchestrator)'}
    elseif(!(Get-Command npx -ErrorAction SilentlyContinue)){'npx not on PATH'}
if($skip){'SUCCESS ORCHESTRATOR-E2E: skipped, '+$skip;exit 0}
# The binary must include the current sources, or the scenarios would test an old interface.
$sources=@(Get-ChildItem -LiteralPath (Join-Path $app 'src'),(Join-Path $app 'src-tauri/src') -File -Recurse)+@(Get-Item -LiteralPath (Join-Path $app 'index.html'))
$newest=($sources|Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
if($newest -gt (Get-Item -LiteralPath $binary).LastWriteTimeUtc){throw 'FAIL ORCHESTRATOR-E2E: the release binary is older than the sources; rebuild with scripts/runner-gui.ps1 -NoLaunch'}
$root=Join-Path (Get-SBTestRoot) ('orchestrator-e2e-'+[guid]::NewGuid().ToString('N').Substring(0,12))
$fixtureText=(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test-orchestrator-fixture.ps1') -Root $root 2>&1|Out-String)
if($LASTEXITCODE){throw ('FAIL ORCHESTRATOR-E2E: fixture: '+$fixtureText)}
$fixture=$fixtureText|ConvertFrom-Json -AsHashtable
$fixture.binary=$binary
$fixture.webviewData=Join-Path $root 'webview'
$fixtureFile=Join-Path $root 'fixture.json'
[IO.File]::WriteAllText($fixtureFile,($fixture|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$env:SB_E2E_FIXTURE=$fixtureFile
$env:SB_E2E_OUTPUT=Join-Path $root 'playwright'
Push-Location $app
try{
    $output=@(& npx --no-install playwright test -c e2e/playwright.config.ts 2>&1|ForEach-Object {[string]$_});$code=$LASTEXITCODE
}finally{Pop-Location}
$log=Join-Path $root 'playwright.log'
[IO.File]::WriteAllLines($log,[string[]]$output,[Text.UTF8Encoding]::new($false))
if($code){throw ('FAIL ORCHESTRATOR-E2E: Playwright exited '+$code+'; log '+$log+[Environment]::NewLine+((@($output|Select-Object -Last 60)) -join [Environment]::NewLine))}
$passed=@($output|Where-Object {$_ -match '^\s*(\d+) passed'}|ForEach-Object {[regex]::Match($_,'(\d+) passed').Groups[1].Value})|Select-Object -Last 1
'SUCCESS ORCHESTRATOR-E2E: '+$passed+' scenarios passed; retained fixture '+$root
