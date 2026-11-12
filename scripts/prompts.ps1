#requires -Version 7.5
<#
.SYNOPSIS
Browses and composes catalog workflows. Does not execute tasks or AI services.
.EXAMPLE
pwsh -NoProfile -File scripts/prompts.ps1
.EXAMPLE
pwsh -NoProfile -File scripts/prompts.ps1 -List -Compact
.EXAMPLE
pwsh -NoProfile -File scripts/prompts.ps1 -List -Category TST
.EXAMPLE
pwsh -NoProfile -File scripts/prompts.ps1 -Show -Prompt TST04
.EXAMPLE
pwsh -NoProfile -File scripts/prompts.ps1 -Compose -Prompt TST04 -Objective 'Diagnostica il job Windows'
#>
[CmdletBinding(DefaultParameterSetName='Home')]
param(
    [Parameter(ParameterSetName='Home')][switch]$Start,
    [Parameter(ParameterSetName='List')][switch]$List,
    [Parameter(ParameterSetName='List')][switch]$Compact,
    [Parameter(Mandatory,ParameterSetName='Show')][switch]$Show,
    [Parameter(Mandatory,ParameterSetName='Compose')][switch]$Compose,
    [Parameter(Mandatory,ParameterSetName='Context')][switch]$Context,
    [Parameter(Mandatory,ParameterSetName='Show')]
    [Parameter(Mandatory,ParameterSetName='Compose')][ValidatePattern('^([A-Z]{2,4}[0-9]{2}|pmt-[0-9a-f]{8})$')][string]$Prompt,
    [Parameter(ParameterSetName='List')][string]$Category,
    [Parameter(ParameterSetName='Compose')][string]$Objective,
    [Parameter(ParameterSetName='Compose')][string]$OutputPath,
    [Parameter(ParameterSetName='Home')][Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$RepositoryPath,
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$Repository,
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$ProjectId,
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$CheckoutPath,
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$CheckoutMapPath,
    [string]$ConfigPath,[string]$SessionId,
    [ValidateSet('en','it')][string]$Language
)
if($Language){$env:SECONDBRAIN_LANG=$Language}
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Pending.psm1')
Add-SBMessages @{
    'promptscli.workstation.inactive' = @{ it = 'Postazione non attivata: usare sb attiva (SYS03)'; en = 'Workstation not activated: use sb attiva (SYS03)' }
    'promptscli.context.incompatible' = @{ it = 'Selezioni di contesto incompatibili: usare una sola selezione di contesto per volta'; en = 'Incompatible context selections: use one context selection at a time' }
    'promptscli.goal.empty' = @{ it = 'Obiettivo vuoto: indicare l''obiettivo con -Objective'; en = 'Empty goal: give the goal with -Objective' }
    'promptscli.output.txt' = @{ it = 'Output TXT nuovo richiesto: indicare con -OutputPath un file TXT che non esiste ancora'; en = 'New TXT output required: give -OutputPath a TXT file that does not exist yet' }
    'promptscli.bootstrap' = @{ it = 'Bootstrap: usa il checkout SecondBrain corrente, senza percorsi preimpostati.'; en = 'Bootstrap: use the current SecondBrain checkout, with no preset paths.' }
    'promptscli.output.created' = @{ it = 'Creato: {0}'; en = 'Created: {0}' }
}
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$lock=$null
try {
    # #474: prompt reads never integrate pending writes (knowledge.ps1 -FlushPending does).
    # Memory discovery must remain available even if the prompt catalog is broken.
    if(!$Context){$catalog=Read-SBWorkflowCatalog $brain}
    if(!$ConfigPath -and $PSCmdlet.ParameterSetName -in @('Context','Compose')){
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
        $candidateConfig=Get-SBHostConfigPath $brain
        if(Test-Path -LiteralPath $candidateConfig){$ConfigPath=$candidateConfig}
    }
    if($ConfigPath){$config=Read-SBConfiguration $ConfigPath -ReadOnly;$lock=Enter-SBOperation $config $SessionId -ReadOnly;Write-SBReadWarnings $lock $config}
    if($PSCmdlet.ParameterSetName -eq 'Home'){
        $homeState=Get-SBWorkflowState $brain $(if($RepositoryPath){$RepositoryPath}else{(Get-Location).Path})
        Format-SBWorkflowHome $brain $catalog $homeState
    } elseif($PSCmdlet.ParameterSetName -eq 'List'){
        Format-SBWorkflowList $catalog $Category -Compact:$Compact
    } elseif($Show){
        $resolution=Resolve-SBWorkflowPrompt $catalog $Prompt
        if($resolution.warning){Write-Warning $resolution.warning}
        $selected=@($resolution.prompt)
        $showBody=Read-SBWorkflowPrompt $brain $selected[0] $catalog
        Format-SBWorkflowCard $selected[0] $showBody
        $showBody
    } else {
        if(!$ConfigPath -and $Compose -and (Resolve-SBWorkflowPrompt $catalog $Prompt).prompt.code -ceq 'SYS03'){
            $selected=@((Resolve-SBWorkflowPrompt $catalog $Prompt).prompt)
            Read-SBWorkflowPrompt $brain $selected[0] $catalog
            Get-SBMessage 'promptscli.bootstrap'
            exit 0
        }
        if(!$ConfigPath){throw (New-SBError 'promptscli.workstation.inactive')}
        if(($Repository -and $RepositoryPath) -or ($ProjectId -and ($Repository -or $RepositoryPath)) -or ($CheckoutPath -and $RepositoryPath)){throw (New-SBError 'promptscli.context.incompatible')}
        if($PSBoundParameters.ContainsKey('Objective') -and !$Objective.Trim()){throw (New-SBError 'promptscli.goal.empty')}
        $degraded=$null
        try{$resolved=Get-SBWorkflowContext -Config $config -RepositoryPath $RepositoryPath -Repository $Repository -ProjectId $ProjectId -CheckoutPath $CheckoutPath -CheckoutMapPath $CheckoutMapPath}
        catch{
            # Reduced mode: a Git checkout with no dossier still gets repository prompts (read, verify and code work), composed without SecondBrain context.
            # Central prompts and MEM/SYS writes to the dossier keep the error, as does any other context failure.
            $code=$_.Exception.Data['code']
            $candidate=if($Compose -and $code -eq 'prompts.dossier.unbound' -and !$Repository -and !$ProjectId){(Resolve-SBWorkflowPrompt $catalog $Prompt).prompt}else{$null}
            if(!$candidate -or $candidate.target -eq 'central' -or ($candidate.mode -eq 'write' -and $candidate.code -match '^(MEM|SYS)')){throw}
            $where=if($RepositoryPath){[IO.Path]::GetFullPath($RepositoryPath)}elseif($CheckoutPath){[IO.Path]::GetFullPath($CheckoutPath)}else{(Get-Location).Path}
            $degraded=(Get-SBWorkflowMessage 'home.degraded.compose' @(($where -replace '\\','/')))+"`n"+(Get-SBWorkflowMessage 'home.degraded')
            $resolved=@{repositories=@();project=$null;sourceRegistry=$null}
        }
        if($Context){ConvertTo-SBJson $resolved}
        else {
            $resolution=Resolve-SBWorkflowPrompt $catalog $Prompt
            if($resolution.warning){Write-Warning $resolution.warning}
            $selected=@($resolution.prompt)
            $body=if($degraded){New-SBWorkflowComposition $brain $catalog $selected[0] $resolved $Objective -Standalone -Degraded $degraded}else{New-SBWorkflowComposition $brain $catalog $selected[0] $resolved $Objective}
            if($OutputPath){
                $full=[IO.Path]::GetFullPath($OutputPath);Assert-SBPlainPath $full
                if($config.ContainsKey('mode') -and $config.mode -eq 'portable'){$full=Assert-SBCentralDataPath $brain $full}
                if([IO.Path]::GetExtension($full) -ne '.txt'){throw (New-SBError 'promptscli.output.txt')}
                $stream=[IO.FileStream]::new($full,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try{$stream.Write([Text.Encoding]::UTF8.GetBytes($body));$stream.Flush($true)}finally{$stream.Dispose()}
                Get-SBMessage 'promptscli.output.created' @($full)
            }else{$body}
        }
    }
    exit 0
} catch {if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; Write-Error $_ -ErrorAction Continue;exit 2} finally {Exit-SBOperation $lock}
