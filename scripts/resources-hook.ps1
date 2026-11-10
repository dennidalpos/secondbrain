#requires -Version 7.5
<#
.SYNOPSIS
Session-start bridge: runs resources.ps1 -Sync -IfStale in a detached process; never blocks the session.
.DESCRIPTION
Always exits 0 and prints nothing. The detached run does nothing when the latest source probe report is
under 14 days old and exits quietly when the archive is busy. -ShowConfiguration prints the Claude Code
SessionStart hook entry to add to your settings; this script does not edit any settings file.
#>
[CmdletBinding()]
param([string]$ConfigPath,[switch]$ShowConfiguration)
$ErrorActionPreference='Stop'
if($ShowConfiguration){
    $command='pwsh -NoProfile -File "'+$PSCommandPath+'"'
    @{hooks=@{SessionStart=@(@{hooks=@(@{type='command';command=$command})})}}|ConvertTo-Json -Depth 6
    exit 0
}
try{
    $arguments=@('-NoProfile','-File',(Join-Path $PSScriptRoot 'resources.ps1'),'-Sync','-IfStale')
    if($ConfigPath){$arguments+=@('-ConfigPath',$ConfigPath)}
    Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $arguments -WindowStyle Hidden|Out-Null
}catch{[void]$_}
exit 0
