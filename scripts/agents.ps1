#requires -Version 7.5
<#
.SYNOPSIS
Agent CLIs for the task runner and the desktop orchestrator: capability probe and repository-specific directives.
.DESCRIPTION
-Probe [-Provider claude|codex|gemini] prints, for each agent CLI, whether it is installed, its version, the flags of its --help,
the models and effort levels it exposes (each with its source: probe or config; the fallback table only validates a typed model), its
status (ready, not-found, not-responding) and where it was found (path, search folder or Store package). Providers are probed in parallel.
-Clients adds the IDEs and AI clients detected on the workstation (scripts/ide-detect.ps1), each with the runner provider it maps to,
if any, and why it cannot be driven otherwise (no headless CLI). Read-only.
-Directives -RepositoryPath <checkout> prints the repository directive files (AGENTS.md and its managed block) and the dossier-specific
directives (AGENTS.managed.md). Read-only.
Add -DirectivesFile <markdown> to prepare a proposal for that text in a work folder (work.ps1, category work) and preview it with
approve-revision.ps1 -Preview; nothing in the dossier or the checkout changes. The output carries proposalPath and proposalHash.
-Directives -RepositoryPath <checkout> -ProposalPath <folder> -ExpectedProposalHash <hash> -Authorization <reference> -Apply approves the
reviewed proposal with approve-revision.ps1 and aligns the repository with secondbrain.ps1 -Sync -Repository <identity>.
Without a mode the script lists the modes and exits 2.
#>
[CmdletBinding()]
param([switch]$Probe,[ValidateSet('claude','codex','gemini')][string[]]$Provider,[switch]$Clients,
    [switch]$Directives,[string]$RepositoryPath,[string]$DirectivesFile,[string]$ProposalPath,
    [ValidatePattern('^$|^[0-9A-Fa-f]{64}$')][string]$ExpectedProposalHash,[string]$Authorization,[switch]$Apply,
    [string]$ConfigPath,[ValidateSet('en','it')][string]$Language)
if($Language){$env:SECONDBRAIN_LANG=$Language}
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAdapters.psm1')
Add-SBMessages @{
    'agents.usage' = @{it='Nessuna opzione indicata. Usare -Probe [-Provider claude|codex|gemini] oppure -Directives -RepositoryPath <checkout> [-DirectivesFile <md>] (anteprima) o con -ProposalPath -ExpectedProposalHash -Authorization -Apply';en='No mode given. Use -Probe [-Provider claude|codex|gemini] or -Directives -RepositoryPath <checkout> [-DirectivesFile <md>] (preview) or with -ProposalPath -ExpectedProposalHash -Authorization -Apply'}
    'agents.repository.required' = @{it='-Directives richiede -RepositoryPath con il percorso di un checkout gestito';en='-Directives needs -RepositoryPath with the path of a managed checkout'}
    'agents.repository.unresolved' = @{it='Checkout non associato a un dossier attivo: {0}. Registralo con secondbrain.ps1 -AddRepo';en='Checkout not bound to an active dossier: {0}. Register it with secondbrain.ps1 -AddRepo'}
    'agents.directives.file' = @{it='File delle direttive non trovato: {0}';en='Directives file not found: {0}'}
    'agents.apply.required' = @{it='-Apply richiede -ProposalPath, -ExpectedProposalHash e -Authorization della proposta esaminata';en='-Apply needs -ProposalPath, -ExpectedProposalHash and -Authorization of the reviewed proposal'}
    'agents.step.failed' = @{it='{0} terminato con codice {1}: {2}';en='{0} ended with exit code {1}: {2}'}
}
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$configArgs=if($ConfigPath){@('-ConfigPath',$ConfigPath)}else{@()}
function Invoke-AgentsStep([string]$Script,[string[]]$StepArgs){
    # Child SecondBrain CLI: JSON on stdout, diagnostics on stderr; a non-zero exit is reported with its message.
    $path=Join-Path $PSScriptRoot $Script
    $errFile=[IO.Path]::GetTempFileName()
    try{
        $out=(& pwsh -NoProfile -File $path @StepArgs 2>$errFile|Out-String)
        $code=$LASTEXITCODE
        $err=[IO.File]::ReadAllText($errFile)
    }finally{Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue}
    if($code -ne 0){throw (New-SBError 'agents.step.failed' @($Script,$code,($err+$out).Trim()))}
    $i=$out.IndexOfAny([char[]]@('[','{'))
    if($i -lt 0){return $null}
    $out.Substring($i)|ConvertFrom-Json -AsHashtable
}
function Get-AgentsRepository([string]$Path){
    if(!$Path){throw (New-SBError 'agents.repository.required')}
    $full=[IO.Path]::GetFullPath($Path)
    $context=Invoke-AgentsStep 'prompts.ps1' (@('-Context','-RepositoryPath',$full)+$configArgs)
    $repo=@($context.repositories|Where-Object {$_ -and $_.identity -and $_.dossier})
    if($repo.Count -ne 1){throw (New-SBError 'agents.repository.unresolved' @($full))}
    $repo[0]
}
try{
    if($Probe){
        $ids=if($Provider){@($Provider)}else{@(Get-SBAgentProviderIds)}
        $agents=@(Get-SBAgentCapabilitiesAll -Provider $ids -BrainRoot $brain)
        $output=[ordered]@{agents=$agents}
        if($Clients){
            # IDEs and clients seen on the workstation: only the ones with a headless CLI of a runner provider can run tasks.
            Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
            $map=@{'Claude Code'='claude';'Codex'='codex';'Gemini CLI'='gemini'}
            $output.clients=@(@(Get-SBIDEDetection '')|ForEach-Object {
                $name=[string]$_.name;$mapped=if($map.ContainsKey($name)){$map[$name]}else{$null}
                $agent=if($mapped){@($agents|Where-Object {$_.provider -eq $mapped})[0]}else{$null}
                [ordered]@{name=$name;confidence=$_.confidence;provider=$mapped;runnable=[bool]($agent -and $agent.status -eq 'ready');reason=$(if(!$mapped){'no-headless-cli'}elseif(!$agent -or $agent.status -ne 'ready'){'cli-'+$(if($agent){$agent.status}else{'not-found'})}else{$null})}
            })
        }
        ConvertTo-SBJson $output
        exit 0
    }
    if(!$Directives){throw (New-SBError 'agents.usage')}
    $repo=Get-AgentsRepository $RepositoryPath
    $relative=[IO.Path]::GetRelativePath($brain,(Join-Path $repo.dossier 'AGENTS.managed.md')).Replace('\','/')
    if($Apply){
        if(!$ProposalPath -or !$ExpectedProposalHash -or !$Authorization){throw (New-SBError 'agents.apply.required')}
        $approved=Invoke-AgentsStep 'approve-revision.ps1' (@('-ProposalPath',$ProposalPath,'-ExpectedProposalHash',$ExpectedProposalHash,'-Authorization',$Authorization)+$configArgs)
        $sync=Invoke-AgentsStep 'secondbrain.ps1' (@('-Sync','-Repository',[string]$repo.identity)+$configArgs)
        # The proposal folder (work/<date>-directives) is closed once applied, so its retention starts and it does not stay open.
        if((Split-Path -Leaf $ProposalPath) -match '^\d{8}-directives$'){try{[void](Invoke-AgentsStep 'work.ps1' (@('-Repository',[string]$repo.identity,'-Category','work','-Slug','directives','-Close')+$configArgs))}catch{[void]$_}}
        ConvertTo-SBJson @{applied=$true;identity=$repo.identity;approval=$approved;sync=$sync}
        exit 0
    }
    $agentsFile=[string]$repo.agents
    $agentsText=if($agentsFile -and (Test-Path -LiteralPath $agentsFile -PathType Leaf)){Read-SBText $agentsFile}else{''}
    $block=try{Get-SBManagedContent $agentsText 'repository'}catch{$null}
    $dossierFile=Join-Path $repo.dossier 'AGENTS.managed.md'
    $current=if(Test-Path -LiteralPath $dossierFile -PathType Leaf){Read-SBText $dossierFile}else{''}
    $result=[ordered]@{identity=$repo.identity;checkout=$repo.checkout;agentsFile=$agentsFile;managedBlock=$block;dossierDirectives=$current;dossierRelative=$relative;proposal=$null}
    if($DirectivesFile){
        $source=[IO.Path]::GetFullPath($DirectivesFile)
        if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw (New-SBError 'agents.directives.file' @($source))}
        $text=Read-SBText $source
        # Proposal folder: README.md plus the dossier path of AGENTS.managed.md, as approve-revision.ps1 expects.
        $folder=Invoke-AgentsStep 'work.ps1' (@('-Repository',[string]$repo.identity,'-Category','work','-Slug','directives','-Init','-Task','Proposta direttive di repository (orchestratore)')+$configArgs)
        $root=[string]$folder.root
        $readme="# Repository directives proposal`n`nRepository: $($repo.identity)`nPrepared by scripts/agents.ps1 -Directives from the selected file.`n"
        [IO.File]::WriteAllText((Join-Path $root 'README.md'),$readme,[Text.UTF8Encoding]::new($false))
        $target=Join-Path $root $relative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $target))|Out-Null
        [IO.File]::WriteAllText($target,$text.TrimEnd()+"`n",[Text.UTF8Encoding]::new($false))
        $preview=Invoke-AgentsStep 'approve-revision.ps1' (@('-ProposalPath',$root,'-Preview')+$configArgs)
        $result.proposal=[ordered]@{proposalPath=$root;proposalHash=$(if($preview -and $preview.ContainsKey('proposalHash')){$preview.proposalHash}else{$null});preview=$preview}
    }
    ConvertTo-SBJson $result
    exit 0
}catch{
    Write-Error $_ -ErrorAction Continue
    exit 2
}
