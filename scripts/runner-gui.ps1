#requires -Version 7.5
<#
.SYNOPSIS
Opens the desktop runner (Tauri 2 app in app/orchestrator), compiling it first when the binary is missing or out of date.
.DESCRIPTION
The binary is app/orchestrator/src-tauri/target/release/secondbrain-orchestrator (.exe on Windows). It is rebuilt when it is missing,
when -Rebuild is given, or when it is older than the newest of src/**, index.html, package.json, package-lock.json, src-tauri/src/**,
src-tauri/Cargo.toml and src-tauri/tauri.conf.json. The build needs npm and cargo in the PATH: npm ci runs only when node_modules is
missing, then npm run tauri build -- --no-bundle. The app starts detached with SECONDBRAIN_HOME set to this checkout; on macOS and Linux
its output goes to .runtime/hosts/<host>/logs/runner-gui.log.
-NoLaunch builds when needed and does not start the app. -WhatIf builds and starts nothing and reports the decision.
-AppPath points to another copy of the app folder (tests). Progress goes to standard error, the final JSON to standard output.
Exit codes: 0 success, 2 missing prerequisites or binary, 3 build failed.
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Rebuild,[switch]$NoLaunch,[string]$AppPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Add-SBMessages @{
    'runnergui.prereq.missing' = @{it='Per compilare il runner servono {0} nel PATH. Requisiti e installazione: docs/orchestratore.it.md';en='Building the runner needs {0} in the PATH. Requirements and setup: docs/orchestratore.md'}
    'runnergui.linux.webkit' = @{it='Su Linux servono anche le librerie WebKitGTK: sudo apt-get install -y libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev patchelf';en='On Linux the WebKitGTK libraries are also needed: sudo apt-get install -y libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev patchelf'}
    'runnergui.app.missing' = @{it='Cartella dell app non trovata: {0}';en='App folder not found: {0}'}
    'runnergui.build.reason' = @{it='Compilazione del runner ({0}): {1}';en='Building the runner ({0}): {1}'}
    'runnergui.build.npmci' = @{it='node_modules assente: npm ci';en='node_modules missing: npm ci'}
    'runnergui.build.failed' = @{it='Compilazione non riuscita ({0}, uscita {1}). Vedi docs/orchestratore.it.md';en='Build failed ({0}, exit {1}). See docs/orchestratore.md'}
    'runnergui.build.done' = @{it='Runner compilato: {0}';en='Runner built: {0}'}
    'runnergui.binary.missing' = @{it='Binario del runner assente dopo la compilazione: {0}';en='Runner binary missing after the build: {0}'}
    'runnergui.current' = @{it='Runner aggiornato: {0}';en='Runner up to date: {0}'}
    'runnergui.launch' = @{it='Avvio del runner (SECONDBRAIN_HOME={0})';en='Starting the runner (SECONDBRAIN_HOME={0})'}
    'runnergui.launch.log' = @{it='Output del runner in {0}';en='Runner output in {0}'}
    'runnergui.whatif.build' = @{it='Compilazione del runner ({0})';en='Build the runner ({0})'}
    'runnergui.whatif.launch' = @{it='Avvio del runner';en='Start the runner'}
}
function Write-RunnerGuiLine([string]$Key,[object[]]$Arguments=@()){[Console]::Error.WriteLine((Get-SBMessage $Key $Arguments))}
function Stop-RunnerGui([string]$Key,[object[]]$Arguments,[int]$Code){
    Write-RunnerGuiLine $Key $Arguments
    if($IsLinux){Write-RunnerGuiLine 'runnergui.linux.webkit'}
    exit $Code
}

$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$app=if($AppPath){[IO.Path]::GetFullPath($AppPath)}else{Join-Path $root 'app/orchestrator'}
if(!(Test-Path -LiteralPath $app -PathType Container)){Write-RunnerGuiLine 'runnergui.app.missing' @($app);exit 2}
$binary=Join-Path $app ('src-tauri/target/release/secondbrain-orchestrator'+$(if($IsWindows){'.exe'}else{''}))

# Newest source file: the inputs of the frontend build and of the Rust crate.
$sources=@()
foreach($dir in @('src','src-tauri/src')){$full=Join-Path $app $dir;if(Test-Path -LiteralPath $full -PathType Container){$sources+=@(Get-ChildItem -LiteralPath $full -Recurse -File)}}
foreach($file in @('index.html','package.json','package-lock.json','src-tauri/Cargo.toml','src-tauri/tauri.conf.json')){$full=Join-Path $app $file;if(Test-Path -LiteralPath $full -PathType Leaf){$sources+=Get-Item -LiteralPath $full}}
$newest=$sources|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1
$exists=Test-Path -LiteralPath $binary -PathType Leaf
$reason=if($Rebuild){'forced'}elseif(!$exists){'missing'}elseif($newest -and $newest.LastWriteTimeUtc -gt (Get-Item -LiteralPath $binary).LastWriteTimeUtc){'stale'}else{'current'}
$result=[ordered]@{binary=$binary;exists=$exists;reason=$reason;build=($reason -ne 'current');newestSource=$(if($newest){[IO.Path]::GetRelativePath($app,$newest.FullName).Replace('\','/')}else{$null});built=$false;launched=$false;log=$null;whatIf=[bool]$WhatIfPreference}

if($result.build){
    if($PSCmdlet.ShouldProcess($app,(Get-SBMessage 'runnergui.whatif.build' @($reason)))){
        # rustup installs cargo in ~/.cargo/bin, often outside the PATH of non-login shells: add it for this process when present.
        if(!(Get-Command cargo -CommandType Application -ErrorAction SilentlyContinue)){
            $cargoHome=if($env:CARGO_HOME){$env:CARGO_HOME}else{Join-Path $HOME '.cargo'}
            $cargoBin=Join-Path $cargoHome 'bin'
            if(Test-Path -LiteralPath (Join-Path $cargoBin $(if($IsWindows){'cargo.exe'}else{'cargo'})) -PathType Leaf){$env:PATH=$cargoBin+[IO.Path]::PathSeparator+$env:PATH}
        }
        $missing=@('npm','cargo'|Where-Object {!(Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue)})
        if($missing.Count){Stop-RunnerGui 'runnergui.prereq.missing' @($missing -join ', ') 2}
        # The Application form (npm.cmd on Windows) passes `--` through unchanged, unlike the npm.ps1 shim.
        $npm=(Get-Command npm -CommandType Application|Select-Object -First 1).Source
        Write-RunnerGuiLine 'runnergui.build.reason' @($reason,$binary)
        Push-Location -LiteralPath $app
        try{
            if(!(Test-Path -LiteralPath (Join-Path $app 'node_modules') -PathType Container)){
                Write-RunnerGuiLine 'runnergui.build.npmci'
                & $npm ci 2>&1|ForEach-Object {[Console]::Error.WriteLine([string]$_)}
                if($LASTEXITCODE){Stop-RunnerGui 'runnergui.build.failed' @('npm ci',$LASTEXITCODE) 3}
            }
            & $npm run tauri build -- --no-bundle 2>&1|ForEach-Object {[Console]::Error.WriteLine([string]$_)}
            if($LASTEXITCODE){Stop-RunnerGui 'runnergui.build.failed' @('npm run tauri build -- --no-bundle',$LASTEXITCODE) 3}
        }finally{Pop-Location}
        if(!(Test-Path -LiteralPath $binary -PathType Leaf)){Stop-RunnerGui 'runnergui.binary.missing' @($binary) 3}
        # Cargo may skip relinking when nothing it tracks changed: mark the binary as current so the next start does not rebuild again.
        $now=[DateTime]::UtcNow
        if($newest -and (Get-Item -LiteralPath $binary).LastWriteTimeUtc -lt $newest.LastWriteTimeUtc){(Get-Item -LiteralPath $binary).LastWriteTimeUtc=$now}
        $result.built=$true;$result.exists=$true
        Write-RunnerGuiLine 'runnergui.build.done' @($binary)
    }
}else{Write-RunnerGuiLine 'runnergui.current' @($binary)}

if(!$NoLaunch -and $PSCmdlet.ShouldProcess($binary,(Get-SBMessage 'runnergui.whatif.launch'))){
    if(!(Test-Path -LiteralPath $binary -PathType Leaf)){Write-RunnerGuiLine 'runnergui.binary.missing' @($binary);exit 2}
    Write-RunnerGuiLine 'runnergui.launch' @($root)
    $environment=@{SECONDBRAIN_HOME=$root}
    if($IsWindows){
        Start-Process -FilePath $binary -WorkingDirectory $root -Environment $environment|Out-Null
    }else{
        # A desktop app outlives this shell: nohup through /bin/sh detaches it and appends its output to a log under .runtime.
        $hostId=try{Get-SBHostId}catch{'ws-'+(Get-SBTextHash ([Environment]::MachineName+'|'+[Environment]::UserName)).Substring(0,16).ToLowerInvariant()}
        $logDir=Join-Path $root ('.runtime/hosts/'+$hostId+'/logs')
        [IO.Directory]::CreateDirectory($logDir)|Out-Null
        $log=Join-Path $logDir 'runner-gui.log'
        # ProcessStartInfo.ArgumentList passes each argument as is (Start-Process would join them without quoting).
        $info=[Diagnostics.ProcessStartInfo]::new('/bin/sh')
        foreach($argument in @('-c','nohup "$0" >>"$1" 2>&1 &',$binary,$log)){$info.ArgumentList.Add($argument)}
        $info.UseShellExecute=$false;$info.WorkingDirectory=$root;$info.Environment['SECONDBRAIN_HOME']=$root
        $shell=[Diagnostics.Process]::Start($info);$shell.WaitForExit();$shell.Dispose()
        $result.log=$log
        Write-RunnerGuiLine 'runnergui.launch.log' @($log)
    }
    $result.launched=$true
}
ConvertTo-SBJson $result
exit 0
