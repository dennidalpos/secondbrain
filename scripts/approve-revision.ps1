#requires -Version 7.5
[CmdletBinding()]
param([string]$Authorization,[string]$ConfigPath,[string]$SessionId,[Parameter(Mandatory)][string]$ProposalPath,[switch]$Preview,
    [ValidatePattern('^[0-9A-Fa-f]{64}$')][string]$ExpectedProposalHash)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'approve.proposal.text' = @{ it = 'Testo della proposta mancante: {0}'; en = 'Proposal text missing: {0}' }
    'approve.source.missing' = @{ it = 'Sorgente mancante: {0}'; en = 'Source missing: {0}' }
    'approve.readme.missing' = @{ it = 'README della proposta mancante'; en = 'Proposal README missing' }
    'approve.proposal.portable' = @{ it = 'Direttive repository non portabili: {0}'; en = 'Non-portable repository directives: {0}' }
    'approve.proposal.review' = @{ it = 'Rivedere -Preview e fornire -ExpectedProposalHash e -Authorization per la proposta esaminata'; en = 'Review -Preview and supply -ExpectedProposalHash and -Authorization for the reviewed proposal' }
    'approve.private.invalid' = @{ it = 'Registro privato di approvazione delle direttive non valido'; en = 'Invalid private directive approval registry' }
}
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
$brain = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$config=Read-SBConfiguration $ConfigPath -ReadOnly:$Preview
$lock=Enter-SBOperation $config $SessionId -ReadOnly:$Preview
try {
    $ProposalPath=[IO.Path]::GetFullPath($ProposalPath)
    Assert-SBPlainPath $ProposalPath
    $readme=Join-Path $ProposalPath 'README.md'
    Assert-SBPlainPath $readme
    $readmeHash=Get-SBFileHash $readme
    if($readmeHash -eq 'absent'){throw (New-SBError 'approve.readme.missing')}
    $approvalPath=Join-Path $brain 'direttive/approved.json'
    $beforeApproval=Get-SBFileHash $approvalPath
    $previous=Read-SBJson $approvalPath @{}
    $privatePath=Resolve-SBParaPath $brain '.runtime/directive-approvals.json'
    $privateHash=Get-SBFileHash $privatePath
    $private=Read-SBJson $privatePath @{schemaVersion=1;files=@{}}
    if($private -isnot [Collections.IDictionary] -or $private.schemaVersion -ne 1 -or $private.files -isnot [Collections.IDictionary]){throw (New-SBError 'approve.private.invalid')}
    $commonSupplied=$false;$privateSupplied=$false
    $files=@{}
    if($previous.ContainsKey('files')){foreach($key in $previous.files.Keys){$files[$key]=$previous.files[$key]}}
    $sources=[ordered]@{}
    foreach($name in @('AGENTS.global_ide.md','workstation.template.md','AGENTS.repo.managed.md')){
        $sources['direttive/'+$name]=Join-Path $ProposalPath $name
    }
    foreach($area in Get-SBParaEntities $brain @()|Where-Object {$_.kind -eq 'area' -and $_.repository -and !$_.archived}){
        $relative=$area.path.Replace('\','/')+'/AGENTS.managed.md'
        $sources[$relative]=Join-Path $ProposalPath $relative
    }
    $ops=@();$changes=@();$hashes=@{}
    foreach($relative in $sources.Keys){
        $source=$sources[$relative]
        if(![IO.File]::Exists($source)){continue}
        Assert-SBPlainPath $source
        $target=Resolve-SBParaPath $brain $relative
        $oldHash=Get-SBFileHash $target
        $bytes=[IO.File]::ReadAllBytes($source)
        $hash=Get-SBHash $bytes
        $text=[Text.UTF8Encoding]::new($false,$true).GetString($bytes).TrimStart([char]0xFEFF)
        if($relative -notin @('direttive/AGENTS.global_ide.md','direttive/workstation.template.md') -and $text -match '(?im)<!--\s*secondbrain:|(?<![A-Za-z0-9+.-])[A-Z]:[\\/]|(?<![\w/])/(?:Users|home)/|\{\{'){throw (New-SBError 'approve.proposal.portable' @($relative))}
        if($relative.StartsWith('direttive/')){$files[$relative]=$hash;$commonSupplied=$true}
        else{$private.files[$relative]=$hash;$privateSupplied=$true}
        $hashes[$relative]=@{before=$oldHash;after=$hash}
        if($oldHash -ne $hash){
            $changes+=@{path=$relative;before=$(if($oldHash -ne 'absent'){Read-SBText $target});after=$text;beforeHash=$oldHash;afterHash=$hash}
            $ops+=@{path=$target;expected=$oldHash;bytes=$bytes}
        }
    }
    if(!$hashes.Count){throw (New-SBError 'approve.proposal.text' @($ProposalPath))}
    foreach($relative in @('direttive/AGENTS.global_ide.md','direttive/workstation.template.md')){
        if(!$files.ContainsKey($relative) -or (!$hashes.ContainsKey($relative) -and $files[$relative] -cne (Get-SBFileHash (Join-Path $brain $relative)))){throw (New-SBError 'approve.source.missing' @($relative))}
    }
    $proposalHash=Get-SBTextHash (ConvertTo-SBJson @{readme=$readmeHash;files=$hashes;approval=$beforeApproval;privateApproval=$privateHash})
    if($Preview){ConvertTo-SBJson @{proposalHash=$proposalHash;changes=$changes;files=$hashes};return}
    if(!$Authorization.Trim() -or $ExpectedProposalHash -ine $proposalHash){throw (New-SBError 'approve.proposal.review')}
    $proposal=@{readmeHash=$readmeHash;sha256=$proposalHash}
    $relativeProposal=[IO.Path]::GetRelativePath($brain,$ProposalPath).Replace('\','/')
    if($relativeProposal.StartsWith('direttive/proposals/')){$proposal.path=$relativeProposal}
    if($commonSupplied){
        $approval=@{schemaVersion=1;approvedAt=[DateTimeOffset]::Now.ToString('o');authorization=$Authorization;files=$files;proposal=$proposal}
        $ops+=@{path=$approvalPath;expected=$beforeApproval;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $approval))}
    }
    if($privateSupplied){
        $private.approvedAt=[DateTimeOffset]::Now.ToString('o');$private.authorization=$Authorization
        $private.proposal=@{path=$relativeProposal;readmeHash=$readmeHash;sha256=$proposalHash}
        $ops+=@{path=$privatePath;expected=$privateHash;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $private))}
    }
    [void](Invoke-SBParaTransaction -Operations $ops -BackupRoot $config.backupRoot -BrainRoot $brain)
    'Revisione approvata registrata; usare -Sync per distribuirla.'
}finally{Exit-SBOperation $lock}
