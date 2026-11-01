#requires -Version 7.5
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Authorization,[Parameter(Mandatory)][string]$ConfigPath,[string]$SessionId,[string]$ProposalPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
# Scrittura occupata oltre l'attesa: exit 3 (il titolare e nel messaggio).
trap { if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
$config=Read-SBConfiguration $ConfigPath
$lock=Enter-SBOperation $config $SessionId
try {
$brain = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if($ProposalPath){
    foreach($name in @('AGENTS.global_ide.md','workstation.template.md')){
        $source=Join-Path $ProposalPath $name
        $target=Join-Path $brain ('direttive/'+$name)
        if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw 'Testo della proposta mancante: '+$name}
        Write-SBFile $target ([IO.File]::ReadAllBytes($source)) (Get-SBFileHash $target) $config.backupRoot|Out-Null
    }
}
$files = @{}
foreach($relative in @('direttive/AGENTS.global_ide.md','direttive/workstation.template.md')) {
    $hash = Get-SBFileHash (Join-Path $brain $relative)
    if ($hash -eq 'absent') { throw 'Sorgente mancante: '+$relative }
    $files[$relative] = $hash
}
$approval = @{ schemaVersion=1; approvedAt=[DateTimeOffset]::Now.ToString('o'); authorization=$Authorization; files=$files }
if($ProposalPath){
    # L'hash del README lega l'approvazione al testo della proposta, non solo alla richiesta.
    $readme=Join-Path $ProposalPath 'README.md'
    if(!(Test-Path -LiteralPath $readme -PathType Leaf)){throw 'README della proposta mancante'}
    $approval.proposal=@{path=[IO.Path]::GetRelativePath($brain,[IO.Path]::GetFullPath($ProposalPath)).Replace('\','/');readmeHash=Get-SBFileHash $readme}
}
$path = Join-Path $brain 'direttive/approved.json'
Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $approval))) (Get-SBFileHash $path) $config.backupRoot | Out-Null
'Revisione approvata registrata; usare -Sync per distribuirla.'
}finally{Exit-SBOperation $lock}
