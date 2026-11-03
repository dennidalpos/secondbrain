#requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Repository,[string]$Project='root',[string]$Runtime='default',[string]$ConfigPath,
    [string]$FilePath,[string[]]$Arguments=@(),[string]$WorkingDirectory,[switch]$Run)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'work.run.explicit' = @{ it = 'Run richiede eseguibile e directory espliciti; nessuna shell implicita'; en = 'Run requires an explicit executable and directory; no implicit shell' }
    'work.checkout.unmanaged' = @{ it = 'Checkout non gestito o ambiguo'; en = 'Checkout not managed or ambiguous' }
}
$config=Read-SBConfiguration $ConfigPath
$plan=Get-SBWorkEnvironment $config.brainRoot $config.workstationId $Repository $Project $Runtime
if(!$Run){ConvertTo-SBJson $plan;exit 0}
if(!$FilePath -or !$WorkingDirectory){throw (New-SBError 'work.run.explicit')}
$bindings=@($config.bindings|Where-Object {$_.identity -ceq $Repository -and [IO.Path]::GetFullPath($_.path) -eq [IO.Path]::GetFullPath($WorkingDirectory)})
if($bindings.Count -ne 1){throw (New-SBError 'work.checkout.unmanaged')}
foreach($path in @($plan.environment.Values)+@($plan.buildRoot)){[IO.Directory]::CreateDirectory($path)|Out-Null}
$start=[Diagnostics.ProcessStartInfo]::new($FilePath);$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WorkingDirectory=$WorkingDirectory
foreach($argument in $Arguments){$start.ArgumentList.Add($argument)}
foreach($key in $plan.environment.Keys){$start.Environment[$key]=$plan.environment[$key]}
$process=[Diagnostics.Process]::Start($start)
try{$process.WaitForExit();exit $process.ExitCode}finally{$process.Dispose()}
