#requires -Version 7.5
# One-shot read-only analyses with an agent CLI (desktop orchestrator): repository directive proposals (DOC06) and task autonomy
# analysis (REP18). The agent reads the checkout with read-only tools and answers one JSON object validated against a schema in
# config/analysis/; for tasks the object carries tool calls (ask_user, propose_task_update, mark_not_automatable) that the orchestrator
# dispatches as multiple-choice questions and a reviewed tracker update. Nothing here writes to the dossier or the checkout: the output
# goes to the work folder the caller names, and tracker writes go through knowledge.ps1 in scripts/agents.ps1.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAdapters.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.RunnerStatus.psm1')
Add-SBMessages @{
    'analysis.agent.notready' = @{it='{0} non è pronto ({1}): installa o aggiorna la CLI, poi rileva di nuovo gli agenti';en='{0} is not ready ({1}): install or update the CLI, then probe the agents again'}
    'analysis.quota.exhausted' = @{it='Quota {0} esaurita fino a {1}: analisi non avviata. Scegli un altro agente o riprova dopo il ripristino';en='{0} quota exhausted until {1}: analysis not started. Pick another agent or retry after the reset'}
    'analysis.limit' = @{it='Limite di {0} durante l''analisi ({1}): {2}';en='{0} limit during the analysis ({1}): {2}'}
    'analysis.agent.failed' = @{it='Analisi non riuscita con {0} ({1}, uscita {2}): {3}';en='Analysis failed with {0} ({1}, exit {2}): {3}'}
    'analysis.output.invalid' = @{it='Risposta di {0} non conforme allo schema dopo {1} tentativi: {2}. Riprova o scegli un modello più capace';en='{0} answer does not match the schema after {1} attempts: {2}. Retry or pick a more capable model'}
    'analysis.card.missing' = @{it='Scheda di prompt {0} non trovata in direttive/prompts';en='Prompt card {0} not found in direttive/prompts'}
}
$script:SBAnalysisKinds=@{directives=@{card='DOC06';schema='directives.schema.json'};task=@{card='REP18';schema='task.schema.json'}}
function Get-SBAnalysisSchemaPath([string]$BrainRoot,[ValidateSet('directives','task')][string]$Kind) {
    Join-Path $BrainRoot ('config/analysis/'+$script:SBAnalysisKinds[$Kind].schema)
}
function Get-SBLightModel([string]$BrainRoot,[string]$Provider) {
    # Default light model of one-shot analyses: roles.light.<provider> of config/agent-models.json, replaced by the workstation override.
    $role=@{model=$null;effort=$null;source='none'}
    foreach($path in @((Join-Path $BrainRoot 'config/agent-models.json'),(Join-Path $BrainRoot ('.runtime/hosts/'+(Get-SBHostId)+'/agent-models.local.json')))){
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){continue}
        try{$data=Read-SBText $path|ConvertFrom-Json -AsHashtable}catch{continue}
        if($data -isnot [hashtable] -or $data['roles'] -isnot [hashtable] -or $data.roles['light'] -isnot [hashtable] -or $data.roles.light[$Provider] -isnot [hashtable]){continue}
        $entry=$data.roles.light[$Provider]
        $role=@{model=$(if($entry['model']){[string]$entry.model}else{$null});effort=$(if($entry['effort']){[string]$entry.effort}else{$null});source=[IO.Path]::GetFileName($path)}
    }
    $role
}
function Get-SBPromptCardText([string]$BrainRoot,[string]$Code) {
    $path=Join-Path $BrainRoot ('direttive/prompts/'+$Code+'.md')
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw (New-SBError 'analysis.card.missing' @($Code))}
    (Read-SBText $path).Trim()
}
function Get-SBAnalysisLanguageName([string]$Language) { if($Language -eq 'en'){'English'}else{'Italian'} }
function Limit-SBAnalysisText([string]$Text,[int]$Max) {
    if(!$Text){return ''}
    if($Text.Length -le $Max){return $Text}
    $Text.Substring(0,$Max)+"`n[... truncated: $($Text.Length-$Max) more characters]"
}
function New-SBDirectivesAnalysisPrompt {
    # Prompt of the directive proposal: the DOC06 card, the blocks already loaded in every session (global, common, current dossier text,
    # AGENTS.md outside the managed blocks) and the character budget. The agent reads the checkout itself with read-only tools.
    param([string]$BrainRoot,[string]$Identity,[string]$GlobalText,[string]$CommonText,[string]$DossierText,[string]$AgentsOutside,[int]$Budget=25000,[int]$UsedCharacters=0,[string]$Language='it')
    $lang=Get-SBAnalysisLanguageName $Language
    @(
        (Get-SBPromptCardText $BrainRoot 'DOC06'),
        '',
        '# Task for this session',
        "Repository: $Identity. The current directory is its checkout: survey it with your read-only tools (manifests, build and test scripts, CI workflows, folder structure, existing guides), then propose the repository-specific directives.",
        "Write titles, bodies and rationales in $lang. Bodies are Markdown, without HTML comments, without absolute paths and without template placeholders in double braces.",
        "Character budget: every session loads about $UsedCharacters of $Budget characters already; keep the proposal short (aim for 1,500 to 3,000 characters in total).",
        '',
        '## Global directives (already loaded in every session, do not repeat)',
        (Limit-SBAnalysisText $GlobalText 9000),
        '',
        '## Common repository block (already loaded, do not repeat)',
        (Limit-SBAnalysisText $CommonText 4000),
        '',
        '## Current repository-specific directives in the dossier (improve or replace)',
        $(if($DossierText){Limit-SBAnalysisText $DossierText 6000}else{'(none yet)'}),
        '',
        '## AGENTS.md of the checkout outside the managed blocks (already loaded, do not repeat)',
        $(if($AgentsOutside){Limit-SBAnalysisText $AgentsOutside 6000}else{'(empty)'})
    ) -join "`n"
}
function New-SBTaskAnalysisPrompt {
    # Prompt of the task autonomy analysis: the REP18 card, the task as the tracker holds it, why the runner does not take it now,
    # the state of its dependencies and the answers already given in earlier rounds.
    param([string]$BrainRoot,$Task,[string]$Reason,$Dependencies=@(),$Rounds=@(),[string]$Language='it',[int]$Round=1,[int]$MaxRounds=3)
    $lang=Get-SBAnalysisLanguageName $Language
    $answered=@()
    foreach($r in @($Rounds)){foreach($a in @($r['answers'])){if($a){$answered+=,$a}}}
    @(
        (Get-SBPromptCardText $BrainRoot 'REP18'),
        '',
        '# Task for this session',
        "Analyze only task $($Task['id']) of this repository. The current directory is its checkout: read code and files with your read-only tools when the decision depends on them.",
        "Write summary, questions, options and the proposed update in $lang. Round $Round of at most $MaxRounds$(if($Round -ge $MaxRounds){': this is the last round, do not ask further questions'}).",
        "Why the runner does not take it now: $(if($Reason){$Reason}else{'runnable already'}).",
        'The runner takes a task only when status is todo, execution is autonomous, its stream is not qualifica-finale, intervento-su-richiesta or coordinamento-prodotti, awaiting is empty or structural-completion, every dependency is done, and requires does not name computer-use.',
        '',
        '## Task (tracker JSON)',
        (ConvertTo-SBJson $Task),
        '',
        '## Dependencies and their status',
        $(if(@($Dependencies).Count){(@($Dependencies)|ForEach-Object {"- $($_.id): $($_.status)"}) -join "`n"}else{'(none)'}),
        '',
        '## Answers of the owner so far',
        $(if($answered.Count){ConvertTo-SBJson $answered}else{'(none yet)'})
    ) -join "`n"
}
function Invoke-SBAgentOneShot {
    # One read-only analysis: quota read now, the installed CLI with the ReadOnly profile in the checkout, the answer extracted from the
    # CLI envelope and validated against the schema; one retry with the validation errors when it does not match. No model or effort
    # given: the light role of config/agent-models.json. Files in -OutputFolder: prompt.txt, agent-output-<n>.jsonl, agent-error-<n>.txt, result.json.
    param([Parameter(Mandatory)][string]$Provider,[string]$Model,[string]$Effort,[Parameter(Mandatory)][string]$Prompt,[Parameter(Mandatory)][string]$SchemaPath,
        [Parameter(Mandatory)][string]$CheckoutPath,[string]$OutputFolder,[string]$BrainRoot,[string]$HostId,[int]$TimeoutSeconds=600,[string]$AgentPath,
        [switch]$AllowCustomModel,$Capabilities,[int]$MaxAttempts=2)
    if(!$BrainRoot){$BrainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))}
    if(!$HostId){$HostId=Get-SBHostId}
    $info=Get-SBAgentProvider $Provider
    $caps=if($Capabilities){$Capabilities}else{Get-SBAgentCapabilities -Provider $Provider -BrainRoot $BrainRoot -AgentPath $AgentPath}
    if($caps.status -ne 'ready'){throw (New-SBError 'analysis.agent.notready' @($info.name,$caps.status))}
    $role='explicit'
    if(!$Model -and !$Effort){
        $light=Get-SBLightModel $BrainRoot $Provider
        $Model=if($light.model -and $caps.supports.model){$light.model}else{$null}
        $Effort=if($light.effort -and $caps.supports.effort){$light.effort}else{$null}
        $role='light'
    }
    [void](Test-SBAgentSelection $caps $Model $Effort -AllowCustomModel:($AllowCustomModel -or $role -eq 'light'))
    $observation=Get-SBRunnerQuotaObservation $BrainRoot $HostId $Provider
    $quota=Get-SBAgentQuota -Provider $Provider -Observation $observation
    if($quota.state -eq 'exhausted'){throw (New-SBError 'analysis.quota.exhausted' @($info.name,$quota.resetAt))}
    $exe=Resolve-SBAgentExecutable $(if($AgentPath){$AgentPath}else{$info.command})
    if(!$exe){throw (New-SBError 'analysis.agent.notready' @($info.name,'not-found'))}
    $shim=[bool]([string]$exe.path -match '\.(cmd|bat)$')
    $invocation=New-SBAgentInvocation -Provider $Provider -Capabilities $caps -Model $Model -Effort $Effort -Profile ReadOnly -SchemaPath $SchemaPath -NoInlineSchema:$shim
    $schemaText=Read-SBText $SchemaPath
    $instructions=@(
        '',
        '# Output',
        'Answer with exactly one JSON object and nothing else (no prose, no code fence). It must validate against this JSON Schema; use null for fields that do not apply to a call:',
        $schemaText.Trim()
    ) -join "`n"
    $basePrompt=$Prompt.TrimEnd()+"`n"+$instructions
    $utf8=[Text.UTF8Encoding]::new($false)
    if($OutputFolder){[IO.Directory]::CreateDirectory($OutputFolder)|Out-Null;[IO.File]::WriteAllText((Join-Path $OutputFolder 'prompt.txt'),$basePrompt,$utf8)}
    $attempt=0;$current=$basePrompt;$check=$null;$parsed=$null;$seconds=0
    while($attempt -lt $MaxAttempts){
        $attempt++
        $log=if($OutputFolder){Join-Path $OutputFolder "agent-output-$attempt.jsonl"}else{$null}
        $run=Invoke-SBAgentProcess -Executable $exe -Arguments $invocation.arguments -Prompt $current -WorkingDirectory $CheckoutPath -TimeoutSeconds $TimeoutSeconds -OutputLog $log -TickSeconds 0
        $seconds+=$run.seconds
        if($OutputFolder){[IO.File]::WriteAllText((Join-Path $OutputFolder "agent-error-$attempt.txt"),$run.error,$utf8)}
        $limit=if($run.state -ne 'timeout'){Get-SBAgentLimitState -Provider $Provider -Output $run.output -ErrorOutput $run.error -ExitCode $run.exitCode}else{$null}
        if($limit){throw (New-SBError 'analysis.limit' @($info.name,$limit.state,$limit.message))}
        if($run.state -ne 'finished' -or $run.exitCode -ne 0){
            $tail=((@([string]$run.error -split "`r?`n")|Where-Object {$_.Trim()}|Select-Object -Last 6) -join ' ').Trim()
            throw (New-SBError 'analysis.agent.failed' @($info.name,$run.state,$run.exitCode,$(if($tail){$tail}else{'-'})))
        }
        $parsed=ConvertFrom-SBAgentStructuredOutput -Provider $Provider -Output $run.output
        $check=Test-SBAgentStructuredOutput $parsed.json $schemaText
        if($check.valid){break}
        $current=$basePrompt+"`n`n# Correction`nYour previous answer did not validate: "+(($check.errors) -join '; ')+". Reply again with only the corrected JSON object."
    }
    if(!$check.valid){throw (New-SBError 'analysis.output.invalid' @($info.name,$attempt,(($check.errors) -join '; ')))}
    $result=$parsed.json|ConvertFrom-Json -AsHashtable -Depth 40
    $outcome=[ordered]@{provider=$Provider;model=$Model;effort=$Effort;role=$role;nativeSchema=[bool]$invocation.nativeSchema;omitted=@($invocation.omitted);attempts=$attempt;seconds=$seconds;quota=$quota.state;result=$result}
    if($OutputFolder){[IO.File]::WriteAllText((Join-Path $OutputFolder 'result.json'),(ConvertTo-SBJson $outcome),$utf8)}
    $outcome
}
function Test-SBDirectiveText([string]$Text) {
    # The same portability rules approve-revision.ps1 applies to repository directive texts.
    !($Text -match '(?im)<!--\s*secondbrain:|(?<![A-Za-z0-9+.-])[A-Z]:[\\/]|(?<![\w/])/(?:Users|home)/|\{\{')
}
function ConvertTo-SBDirectivesMarkdown($Result) {
    # Sections of a directive proposal as the Markdown that goes into AGENTS.managed.md.
    (@($Result['sections'])|ForEach-Object {'## '+([string]$_.title).Trim()+"`n`n"+([string]$_.body).Trim()}) -join "`n`n"
}
Export-ModuleMember -Function @('Get-SBAnalysisSchemaPath','Get-SBLightModel','Get-SBPromptCardText','New-SBDirectivesAnalysisPrompt','New-SBTaskAnalysisPrompt','Invoke-SBAgentOneShot','Test-SBDirectiveText','ConvertTo-SBDirectivesMarkdown')
