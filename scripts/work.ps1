#requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Repository,[string]$Project='root',[string]$Runtime='default',[string]$Category,[string]$Slug,[string]$ConfigPath,
    [string]$FilePath,[string[]]$Arguments=@(),[string]$WorkingDirectory,[switch]$Run,
    [switch]$Init,[switch]$Close,[string]$Task,[string]$SessionId,[string]$Client='agent')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'work.run.explicit' = @{ it = 'Run richiede eseguibile e directory espliciti; nessuna shell implicita'; en = 'Run requires an explicit executable and directory; no implicit shell' }
    'work.init.categoryslug' = @{ it = 'Init richiede Category e Slug'; en = 'Init requires Category and Slug' }
    'work.close.manifest' = @{ it = 'Close richiede una cartella inizializzata con MANIFEST.json'; en = 'Close requires a folder initialized with MANIFEST.json' }
    'work.checkout.unmanaged' =@{ it = 'Checkout non gestito o ambiguo'; en = 'Checkout not managed or ambiguous' }
}
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1')
# Runner session perimeter: work folders are written only for the task repository.
Assert-SBRunnerReadScope -Repository $Repository -Write
$config=Read-SBConfiguration $ConfigPath
$plan=if($Category -or $Slug){Get-SBWorkEnvironment -BrainRoot $config.brainRoot -HostId $config.workstationId -Repository $Repository -Category $Category -Slug $Slug}else{Get-SBWorkEnvironment $config.brainRoot $config.workstationId $Repository $Project $Runtime}
if($Init){
    # Creates the nested folder and its MANIFEST.json (owner, session, task, status, expiry): the folder is then traceable and subject to retention.
    if(!$Category -or !$Slug){throw (New-SBError 'work.init.categoryslug')}
    [IO.Directory]::CreateDirectory($plan.root)|Out-Null
    $manifestPath=Join-Path $plan.root 'MANIFEST.json'
    if(!(Test-Path -LiteralPath $manifestPath)){
        $today=(Get-SBNow).LocalDateTime
        # Every category has an expiry (days from creation): evidence and reports are reviewed after 90 days, never removed automatically.
        $retention=@{work=30;fixture=7;tmp=7;evidence=90;report=90}
        $expires=if($retention.ContainsKey($Category)){$today.AddDays($retention[$Category]).ToString('yyyy-MM-dd')}else{$null}
        $record=@{schemaVersion=1;category=$Category;name=(Split-Path $plan.root -Leaf);created=$today.ToString('yyyy-MM-dd');hostId=$config.workstationId;repository=(Get-SBRuntimeRepoSegment $Repository);owner=@{user=$env:USERNAME;computer=$env:COMPUTERNAME;client=$Client};sessionId=$SessionId;task=$Task;status='open';expires=$expires}
        [IO.File]::WriteAllText($manifestPath,(ConvertTo-SBJson $record),[Text.UTF8Encoding]::new($false))
    }
    $plan.manifest=$manifestPath;$plan.initialized=$true
    ConvertTo-SBJson $plan;exit 0
}
if($Close){
    # Marks the folder as closed: the retention clock starts here (work 30 days, evidence and report 90 days; fixture and tmp keep their expiry).
    if(!$Category -or !$Slug){throw (New-SBError 'work.init.categoryslug')}
    $manifestPath=Join-Path $plan.root 'MANIFEST.json'
    $record=Read-SBJson $manifestPath $null
    if($null -eq $record){throw (New-SBError 'work.close.manifest')}
    $now=(Get-SBNow).LocalDateTime;$record.status='closed';$record.closed=$now.ToString('yyyy-MM-dd')
    if($Category -eq 'work'){$record.expires=$now.AddDays(30).ToString('yyyy-MM-dd')}
    elseif($Category -in @('evidence','report')){$record.expires=$now.AddDays(90).ToString('yyyy-MM-dd')}
    Write-SBFile $manifestPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $record))) (Get-SBFileHash $manifestPath) (Join-Path $config.runtimeRoot 'backups')|Out-Null
    $plan.manifest=$manifestPath;$plan.closed=$true
    ConvertTo-SBJson $plan;exit 0
}
if(!$Run){ConvertTo-SBJson $plan;exit 0}
if(!$FilePath -or !$WorkingDirectory){throw (New-SBError 'work.run.explicit')}
$bindings=@($config.bindings|Where-Object {$_.identity -ceq $Repository -and [IO.Path]::GetFullPath($_.path) -eq [IO.Path]::GetFullPath($WorkingDirectory)})
if($bindings.Count -ne 1){throw (New-SBError 'work.checkout.unmanaged')}
# Only the work root is created and exported; TEMP/TMP, caches and build outputs of the product stay in the native OS and product folders.
foreach($path in @($plan.environment.Values)){[IO.Directory]::CreateDirectory($path)|Out-Null}
$start=[Diagnostics.ProcessStartInfo]::new($FilePath);$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WorkingDirectory=$WorkingDirectory
foreach($argument in $Arguments){$start.ArgumentList.Add($argument)}
foreach($key in $plan.environment.Keys){$start.Environment[$key]=$plan.environment[$key]}
$process=[Diagnostics.Process]::Start($start)
try{$process.WaitForExit();exit $process.ExitCode}finally{$process.Dispose()}
