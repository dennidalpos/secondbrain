#requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Authorization,[Parameter(Mandatory)][string]$ConfigPath,[string]$SessionId,[string]$ProposalPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'approve.proposal.text' = @{ it = 'Testo della proposta mancante: {0}'; en = 'Proposal text missing: {0}' }
    'approve.source.missing' = @{ it = 'Sorgente mancante: {0}'; en = 'Source missing: {0}' }
    'approve.readme.missing' = @{ it = 'README della proposta mancante'; en = 'Proposal README missing' }
}
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
$config=Read-SBConfiguration $ConfigPath
$lock=Enter-SBOperation $config $SessionId
try {
$brain = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if($ProposalPath){
    foreach($name in @('AGENTS.global_ide.md','workstation.template.md')){
        $source=Join-Path $ProposalPath $name
        $target=Join-Path $brain ('direttive/'+$name)
        if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw (New-SBError 'approve.proposal.text' @($name))}
        Write-SBFile $target ([IO.File]::ReadAllBytes($source)) (Get-SBFileHash $target) $config.backupRoot -BackupDirty | Out-Null
    }
}
$files = @{}
foreach($relative in @('direttive/AGENTS.global_ide.md','direttive/workstation.template.md')) {
    $hash = Get-SBFileHash (Join-Path $brain $relative)
    if ($hash -eq 'absent') { throw (New-SBError 'approve.source.missing' @($relative)) }
    $files[$relative] = $hash
}
$approval = @{ schemaVersion=1; approvedAt=[DateTimeOffset]::Now.ToString('o'); authorization=$Authorization; files=$files }
if($ProposalPath){
    # The README hash binds approval to the proposal text, not just the request.
    $readme=Join-Path $ProposalPath 'README.md'
    if(!(Test-Path -LiteralPath $readme -PathType Leaf)){throw (New-SBError 'approve.readme.missing')}
    $approval.proposal=@{path=[IO.Path]::GetRelativePath($brain,[IO.Path]::GetFullPath($ProposalPath)).Replace('\','/');readmeHash=Get-SBFileHash $readme}
}
$path = Join-Path $brain 'direttive/approved.json'
Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $approval))) (Get-SBFileHash $path) $config.backupRoot -BackupDirty | Out-Null
'Revisione approvata registrata; usare -Sync per distribuirla.'
}finally{Exit-SBOperation $lock}
