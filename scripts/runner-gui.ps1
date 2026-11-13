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
-RepositoryPath <checkout> opens the app on that repository (passed as --repo <path>): its dossier, tracker and ready tasks load at start.
-AppPath points to another copy of the app folder (tests). Progress goes to standard error, the final JSON to standard output.
On Windows, when this script runs inside an MSIX package or a job object (an agent started from a packaged app such as Claude desktop),
a child process stays in them and Windows terminates it when that app closes, crashes or is updated. The app is then started through
WMI (Win32_Process.Create), outside the package and the job, with this process's environment. -LaunchMethod auto (default) picks wmi
inside a package or job and shell otherwise; shell or wmi forces one (tests). The JSON reports packageFullName, inJob and launchMethod.
Exit codes: 0 success, 2 missing prerequisites or binary, 3 build failed, 4 no graphical session (Linux without DISPLAY or
WAYLAND_DISPLAY), 5 the app did not start (it exited at once, e.g. without the WebView2 runtime). scripts/runner.ps1 turns 2-5 into
the command-line fallback.
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Rebuild,[switch]$NoLaunch,[string]$AppPath,[string]$RepositoryPath,[ValidateSet('auto','shell','wmi')][string]$LaunchMethod='auto')
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
    'runnergui.display.missing' = @{it='Nessuna sessione grafica (DISPLAY o WAYLAND_DISPLAY assenti): il runner desktop non puo aprirsi';en='No graphical session (DISPLAY or WAYLAND_DISPLAY missing): the desktop runner cannot open'}
    'runnergui.launch.failed' = @{it='Il runner desktop non si e avviato ({0}). Requisiti: docs/orchestratore.it.md';en='The desktop runner did not start ({0}). Requirements: docs/orchestratore.md'}
    'runnergui.repository' = @{it='Repository da aprire: {0}';en='Repository to open: {0}'}
    'runnergui.launch.detached' = @{it='Avvio tramite WMI fuori dal contenitore del chiamante ({0}): chiusure, crash e aggiornamenti dell app chiamante non fermano il runner';en='Starting through WMI outside the caller''s container ({0}): closing, crashing or updating the calling app does not stop the runner'}
}
function Write-RunnerGuiLine([string]$Key,[object[]]$Arguments=@()){[Console]::Error.WriteLine((Get-SBMessage $Key $Arguments))}
function Stop-RunnerGui([string]$Key,[object[]]$Arguments,[int]$Code){
    Write-RunnerGuiLine $Key $Arguments
    if($IsLinux){Write-RunnerGuiLine 'runnergui.linux.webkit'}
    exit $Code
}
# What would carry a child process down with its caller on Windows: the MSIX package this process runs in ($null outside one,
# APPMODEL_ERROR_NO_PACKAGE) and the job object it belongs to. A packaged app such as Claude desktop starts its tools in a job that its
# package servicing (update, close, crash recovery) terminates, even when the tools themselves broke away from the package identity.
function Get-RunnerGuiContainment{
    if(!$IsWindows){return @{package=$null;inJob=$false}}
    if(!('SecondBrain.RunnerGuiContainment' -as [type])){
        Add-Type -Namespace SecondBrain -Name RunnerGuiContainment -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern int GetCurrentPackageFullName(ref uint length, System.Text.StringBuilder name);
[DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
[DllImport("kernel32.dll")] public static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool result);
'@
    }
    $package=$null;$length=[uint32]0
    if([SecondBrain.RunnerGuiContainment]::GetCurrentPackageFullName([ref]$length,$null) -eq 122){
        $name=[Text.StringBuilder]::new([int]$length)
        if([SecondBrain.RunnerGuiContainment]::GetCurrentPackageFullName([ref]$length,$name) -eq 0){$package=$name.ToString()}
    }
    $inJob=$false
    if(![SecondBrain.RunnerGuiContainment]::IsProcessInJob([SecondBrain.RunnerGuiContainment]::GetCurrentProcess(),[IntPtr]::Zero,[ref]$inJob)){$inJob=$false}
    @{package=$package;inJob=$inJob}
}
# One argument of a Windows command line, quoted by the CommandLineToArgvW rules (backslashes doubled before a quote).
function ConvertTo-RunnerGuiArgument([string]$Value){
    if($Value -and $Value -notmatch '[\s"]'){return $Value}
    '"'+([regex]::Replace($Value,'(\\*)("|$)',{param($m)$m.Groups[1].Value*2+$(if($m.Groups[2].Value){'\"'}else{''})}))+'"'
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
$repository=if($RepositoryPath){[IO.Path]::GetFullPath($RepositoryPath)}else{$null}
$result=[ordered]@{binary=$binary;exists=$exists;reason=$reason;build=($reason -ne 'current');newestSource=$(if($newest){[IO.Path]::GetRelativePath($app,$newest.FullName).Replace('\','/')}else{$null});built=$false;launched=$false;log=$null;repository=$repository;whatIf=[bool]$WhatIfPreference}

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
        $now=(Get-SBNow).UtcDateTime
        if($newest -and (Get-Item -LiteralPath $binary).LastWriteTimeUtc -lt $newest.LastWriteTimeUtc){(Get-Item -LiteralPath $binary).LastWriteTimeUtc=$now}
        $result.built=$true;$result.exists=$true
        Write-RunnerGuiLine 'runnergui.build.done' @($binary)
    }
}else{Write-RunnerGuiLine 'runnergui.current' @($binary)}

if(!$NoLaunch -and $PSCmdlet.ShouldProcess($binary,(Get-SBMessage 'runnergui.whatif.launch'))){
    if(!(Test-Path -LiteralPath $binary -PathType Leaf)){Write-RunnerGuiLine 'runnergui.binary.missing' @($binary);exit 2}
    if($IsLinux -and !$env:DISPLAY -and !$env:WAYLAND_DISPLAY){Write-RunnerGuiLine 'runnergui.display.missing';exit 4}
    Write-RunnerGuiLine 'runnergui.launch' @($root)
    if($repository){Write-RunnerGuiLine 'runnergui.repository' @($repository)}
    $appArguments=if($repository){@('--repo',$repository)}else{@()}
    $containment=Get-RunnerGuiContainment
    $method=if(!$IsWindows){'nohup'}elseif($LaunchMethod -ne 'auto'){$LaunchMethod}elseif($containment.package -or $containment.inJob){'wmi'}else{'shell'}
    $result.packageFullName=$containment.package;$result.inJob=$containment.inJob;$result.launchMethod=$method
    if($method -eq 'wmi'){
        # WmiPrvSE creates the process: it leaves the caller's package and job and inherits no handles. The environment block replaces the
        # default one, so it carries this process's variables with SECONDBRAIN_HOME. An app that exits with an error within three seconds
        # did not start; one already gone when looked up (a second instance handing over to the first) counts as started.
        Write-RunnerGuiLine 'runnergui.launch.detached' @($(if($containment.package){$containment.package}elseif($containment.inJob){'job'}else{'-'}))
        $environment=[Collections.Generic.List[string]]::new()
        foreach($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()){if($entry.Key -ne 'SECONDBRAIN_HOME'){$environment.Add([string]$entry.Key+'='+[string]$entry.Value)}}
        $environment.Add('SECONDBRAIN_HOME='+$root)
        $commandLine=(@($binary)+$appArguments|ForEach-Object {ConvertTo-RunnerGuiArgument $_}) -join ' '
        try{
            $startup=New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{EnvironmentVariables=[string[]]$environment;ShowWindow=[uint16]1}
            $created=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine=$commandLine;CurrentDirectory=$root;ProcessStartupInformation=$startup}
        }catch{Write-RunnerGuiLine 'runnergui.launch.failed' @($_.Exception.Message);exit 5}
        if($created.ReturnValue -ne 0){Write-RunnerGuiLine 'runnergui.launch.failed' @('Win32_Process.Create '+$created.ReturnValue);exit 5}
        $result.pid=[int]$created.ProcessId
        # Not a child of this process: its handle is opened at once (reading Handle) so the exit code stays readable after it exits.
        $process=Get-Process -Id $created.ProcessId -ErrorAction SilentlyContinue
        if($process){
            try{
                $null=try{$process.Handle}catch{$null}
                if($process.WaitForExit(3000)){
                    $exitCode=try{$process.ExitCode}catch{$null}
                    if($null -ne $exitCode -and $exitCode -ne 0){Write-RunnerGuiLine 'runnergui.launch.failed' @('exit '+$exitCode);exit 5}
                }
            }finally{$process.Dispose()}
        }
    }elseif($method -eq 'shell'){
        # Started through ShellExecute, which passes no handles: with CreateProcess the app inherited this script's standard output and a
        # caller reading it (an agent running sb runner) waited until the window was closed. The environment is inherited from this process.
        # An app that exits with an error within three seconds did not start.
        $info=[Diagnostics.ProcessStartInfo]::new($binary);$info.UseShellExecute=$true;$info.WorkingDirectory=$root
        foreach($argument in $appArguments){$info.ArgumentList.Add($argument)}
        $previousHome=$env:SECONDBRAIN_HOME;$env:SECONDBRAIN_HOME=$root
        $process=$null
        try{$process=[Diagnostics.Process]::Start($info)}catch{Write-RunnerGuiLine 'runnergui.launch.failed' @($_.Exception.Message);exit 5}finally{$env:SECONDBRAIN_HOME=$previousHome}
        if($process){try{if($process.WaitForExit(3000) -and $process.ExitCode -ne 0){Write-RunnerGuiLine 'runnergui.launch.failed' @('exit '+$process.ExitCode);exit 5}}finally{$process.Dispose()}}
    }else{
        # A desktop app outlives this shell: nohup through /bin/sh detaches it and appends its output to a log under .runtime.
        $hostId=try{Get-SBHostId}catch{'ws-'+(Get-SBTextHash ([Environment]::MachineName+'|'+[Environment]::UserName)).Substring(0,16).ToLowerInvariant()}
        $logDir=Join-Path $root ('.runtime/hosts/'+$hostId+'/logs')
        [IO.Directory]::CreateDirectory($logDir)|Out-Null
        $log=Join-Path $logDir 'runner-gui.log'
        # ProcessStartInfo.ArgumentList passes each argument as is (Start-Process would join them without quoting).
        $info=[Diagnostics.ProcessStartInfo]::new('/bin/sh')
        foreach($argument in @('-c','log="$1"; shift; nohup "$0" "$@" >>"$log" 2>&1 &',$binary,$log)+$appArguments){$info.ArgumentList.Add($argument)}
        $info.UseShellExecute=$false;$info.WorkingDirectory=$root;$info.Environment['SECONDBRAIN_HOME']=$root
        $shell=[Diagnostics.Process]::Start($info);$shell.WaitForExit();$shell.Dispose()
        $result.log=$log
        Write-RunnerGuiLine 'runnergui.launch.log' @($log)
    }
    $result.launched=$true
}
ConvertTo-SBJson $result
exit 0
