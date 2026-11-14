#requires -Version 7.5
<#
.SYNOPSIS
Opens the SecondBrain desktop app from the repository root, independently of any IDE or agent.
.DESCRIPTION
Runs scripts/runner-gui.ps1: the app (app/orchestrator) is built first when its binary is missing or older than its sources, then
started detached, outside the caller's package or job when needed. Opening the app never starts task execution: the queue runs only
when started from the window.
When the app cannot open, the reason from runner-gui.ps1 is followed by what to do next: install the missing build tools (exit 2),
read the build output (exit 3), use a graphical session (exit 4) or install the WebView2 runtime (exit 5). The exit code is the one
of runner-gui.ps1; the JSON it prints stays on standard output.
-RepositoryPath <checkout> opens the app on that repository. -Rebuild forces the build. -NoLaunch builds without starting the app.
-WhatIf reports the decision and builds and starts nothing. -AppPath points to another copy of the app folder (tests).
.EXAMPLE
pwsh -File start.ps1
.EXAMPLE
pwsh -File start.ps1 -RepositoryPath D:\src\my-product
#>
[CmdletBinding(SupportsShouldProcess)]
param([string]$RepositoryPath,[switch]$Rebuild,[switch]$NoLaunch,[string]$AppPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$scripts=Join-Path $PSScriptRoot 'scripts'
Import-Module (Join-Path $scripts 'SecondBrain.Core.psm1')
Import-Module (Join-Path $scripts 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'start.next.prerequisites' = @{en='Next step: install Node.js (it provides npm) from https://nodejs.org and Rust (it provides cargo) from https://rustup.rs, open a new terminal and run start.ps1 again. Without them, the command-line runner still works: pwsh -File scripts/runner.ps1 -Mode cli'}
    'start.next.build' = @{en='Next step: read the build output above, fix the reported error and run start.ps1 -Rebuild. Guide: docs/orchestratore.md'}
    'start.next.display' = @{en='Next step: start a graphical session (DISPLAY or WAYLAND_DISPLAY), or use the command-line runner: pwsh -File scripts/runner.ps1 -Mode cli'}
    'start.next.launch' = @{en='Next step: on Windows install the Microsoft Edge WebView2 runtime from https://developer.microsoft.com/microsoft-edge/webview2, then run start.ps1 again. Guide: docs/orchestratore.md'}
    'start.next.unknown' = @{en='The desktop app did not open (exit {0}). Guide: docs/orchestratore.md'}
}
$arguments=@()
if($RepositoryPath){$arguments+=@('-RepositoryPath',[IO.Path]::GetFullPath($RepositoryPath))}
if($AppPath){$arguments+=@('-AppPath',[IO.Path]::GetFullPath($AppPath))}
if($Rebuild){$arguments+='-Rebuild'}
if($NoLaunch){$arguments+='-NoLaunch'}
if($WhatIfPreference){$arguments+='-WhatIf'}
# A child process, so runner-gui.ps1 keeps its own exit codes; its progress and reasons go to standard error, the JSON to standard output.
& (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $scripts 'runner-gui.ps1') @arguments
$code=$LASTEXITCODE
if($code){
    # Exit 2 also covers a missing app folder or binary: the install advice is given only when a build tool is really missing.
    # cargo counts as present in ~/.cargo/bin too, where rustup installs it and where runner-gui.ps1 looks for it.
    $cargoBin=Join-Path $(if($env:CARGO_HOME){$env:CARGO_HOME}else{Join-Path $HOME '.cargo'}) ('bin/cargo'+$(if($IsWindows){'.exe'}else{''}))
    $toolMissing=!(Get-Command npm -CommandType Application -ErrorAction SilentlyContinue) -or
        (!(Get-Command cargo -CommandType Application -ErrorAction SilentlyContinue) -and !(Test-Path -LiteralPath $cargoBin -PathType Leaf))
    $key=switch($code){2{if($toolMissing){'start.next.prerequisites'}else{'start.next.unknown'}}3{'start.next.build'}4{'start.next.display'}5{'start.next.launch'}default{'start.next.unknown'}}
    [Console]::Error.WriteLine((Get-SBMessage $key @($code)))
}
exit $code
