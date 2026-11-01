#requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Repository,[string]$Project='root',[string]$Runtime='default',[string]$ConfigPath,
    [string]$FilePath,[string[]]$Arguments=@(),[string]$WorkingDirectory,[switch]$Run)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
$config=Read-SBConfiguration $ConfigPath
$plan=Get-SBWorkEnvironment $config.brainRoot $config.workstationId $Repository $Project $Runtime
if(!$Run){ConvertTo-SBJson $plan;exit 0}
if(!$FilePath -or !$WorkingDirectory){throw 'Run richiede eseguibile e directory espliciti; nessuna shell implicita'}
$bindings=@($config.bindings|Where-Object {$_.identity -ceq $Repository -and [IO.Path]::GetFullPath($_.path) -eq [IO.Path]::GetFullPath($WorkingDirectory)})
if($bindings.Count -ne 1){throw 'Checkout non gestito o ambiguo'}
foreach($path in @($plan.environment.Values)+@($plan.buildRoot)){[IO.Directory]::CreateDirectory($path)|Out-Null}
$start=[Diagnostics.ProcessStartInfo]::new($FilePath);$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WorkingDirectory=$WorkingDirectory
foreach($argument in $Arguments){$start.ArgumentList.Add($argument)}
foreach($key in $plan.environment.Keys){$start.Environment[$key]=$plan.environment[$key]}
$process=[Diagnostics.Process]::Start($start)
try{$process.WaitForExit();exit $process.ExitCode}finally{$process.Dispose()}
