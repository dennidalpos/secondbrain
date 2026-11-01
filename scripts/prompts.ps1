#requires -Version 7.5
<#
.SYNOPSIS
Consulta e compone i workflow del catalogo v2. Non esegue task o servizi AI.
.EXAMPLE
pwsh -NoProfile -File scripts/prompts.ps1
.EXAMPLE
pwsh -NoProfile -File scripts/prompts.ps1 -List -Compact
.EXAMPLE
pwsh -NoProfile -File scripts/prompts.ps1 -List -Category TST
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
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$RepositoryPath,
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$Repository,
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$ProjectId,
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$CheckoutPath,
    [Parameter(ParameterSetName='Compose')][Parameter(ParameterSetName='Context')][string]$CheckoutMapPath,
    [string]$ConfigPath,[string]$SessionId
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$lock=$null
try {
    # Memory discovery must remain available even if the prompt catalog is broken.
    if(!$Context){$catalog=Read-SBWorkflowCatalog $brain}
    if(!$ConfigPath -and $PSCmdlet.ParameterSetName -in @('Context','Compose')){
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
        $candidateConfig=Get-SBHostConfigPath $brain
        if(Test-Path -LiteralPath $candidateConfig){$ConfigPath=$candidateConfig}
    }
    if($ConfigPath){$config=Read-SBConfiguration $ConfigPath -ReadOnly;$lock=Enter-SBOperation $config $SessionId -ReadOnly;Write-SBReadWarnings $lock $config}
    if($PSCmdlet.ParameterSetName -eq 'Home'){
        Format-SBWorkflowHome $brain $catalog
    } elseif($PSCmdlet.ParameterSetName -eq 'List'){
        Format-SBWorkflowList $catalog $Category -Compact:$Compact
    } elseif($Show){
        $resolution=Resolve-SBWorkflowPrompt $catalog $Prompt
        if($resolution.warning){Write-Warning $resolution.warning}
        $selected=@($resolution.prompt)
        'CATALOGO PROMPT v2 — modalità '+$selected[0].mode+'; destinazione '+$selected[0].target+'; ID '+$selected[0].id
        $showBody=Read-SBWorkflowPrompt $brain $selected[0] $catalog
        Format-SBWorkflowCard $selected[0] $showBody
        $showBody
    } else {
        if(!$ConfigPath -and $Compose -and (Resolve-SBWorkflowPrompt $catalog $Prompt).prompt.code -ceq 'SYS03'){
            $selected=@((Resolve-SBWorkflowPrompt $catalog $Prompt).prompt)
            Read-SBWorkflowPrompt $brain $selected[0] $catalog
            'Bootstrap: usa il checkout SecondBrain corrente, senza percorsi preimpostati.'
            exit 0
        }
        if(!$ConfigPath){throw 'Postazione non attivata: usare sb attiva (SYS03)'}
        if(($Repository -and $RepositoryPath) -or ($ProjectId -and ($Repository -or $RepositoryPath)) -or ($CheckoutPath -and $RepositoryPath)){throw 'Selezioni di contesto incompatibili'}
        if($PSBoundParameters.ContainsKey('Objective') -and !$Objective.Trim()){throw 'Obiettivo vuoto'}
        $resolved=Get-SBWorkflowContext -Config $config -RepositoryPath $RepositoryPath -Repository $Repository -ProjectId $ProjectId -CheckoutPath $CheckoutPath -CheckoutMapPath $CheckoutMapPath
        if($Context){ConvertTo-SBJson $resolved}
        else {
            $resolution=Resolve-SBWorkflowPrompt $catalog $Prompt
            if($resolution.warning){Write-Warning $resolution.warning}
            $selected=@($resolution.prompt)
            $body=New-SBWorkflowComposition $brain $catalog $selected[0] $resolved $Objective
            if($OutputPath){
                $full=[IO.Path]::GetFullPath($OutputPath);Assert-SBPlainPath $full
                if($config.ContainsKey('mode') -and $config.mode -eq 'portable'){$full=Assert-SBCentralDataPath $brain $full}
                if([IO.Path]::GetExtension($full) -ne '.txt'){throw 'Output TXT nuovo richiesto'}
                $stream=[IO.FileStream]::new($full,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try{$stream.Write([Text.Encoding]::UTF8.GetBytes($body));$stream.Flush($true)}finally{$stream.Dispose()}
                'Creato: '+$full
            }else{$body}
        }
    }
    exit 0
} catch {Write-Error $_ -ErrorAction Continue;exit 2} finally {Exit-SBOperation $lock}
