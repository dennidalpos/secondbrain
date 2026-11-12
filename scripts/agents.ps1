#requires -Version 7.5
<#
.SYNOPSIS
Agent CLIs for the task runner and the desktop orchestrator: capability probe, repository-specific directives and one-shot analyses.
.DESCRIPTION
-Probe [-Provider claude|codex|gemini] prints, for each agent CLI, whether it is installed, its version, the flags of its --help,
the models and effort levels it exposes (each with its source: probe or config; the fallback table only validates a typed model), its
status (ready, not-found, not-responding), where it was found (path, search folder or Store package) and its default light model
(roles.light of config/agent-models.json). Providers are probed in parallel.
-Clients adds the IDEs and AI clients detected on the workstation (scripts/ide-detect.ps1), each with the runner provider it maps to,
if any, and why it cannot be driven otherwise (no headless CLI). Read-only.
-Directives -RepositoryPath <checkout> prints the repository directive files (AGENTS.md and its managed block), the dossier-specific
directives (AGENTS.managed.md), the global and common blocks every session loads, AGENTS.md outside the managed blocks, the repository
block as it would be composed and the character counts against the startup budget. Read-only.
Add -DirectivesFile <markdown> to prepare a proposal for that text in a work folder (work.ps1, category work) and preview it with
approve-revision.ps1 -Preview; nothing in the dossier or the checkout changes. The output carries proposalPath and proposalHash.
-Directives -RepositoryPath <checkout> -ProposalPath <folder> -ExpectedProposalHash <hash> -Authorization <reference> -Apply approves the
reviewed proposal with approve-revision.ps1 and aligns the repository with secondbrain.ps1 -Sync -Repository <identity>.
-Analyze -Kind directives|task -RepositoryPath <checkout> -Provider <one> [-Model] [-Effort] [-TaskId] runs one read-only analysis with
the agent CLI (light model by default; DOC06 or REP18) in a work folder and prints its validated JSON. -Kind task-resolve -AnalysisPath
<folder> -AnswersFile <json> gives the owner's answers and runs the next round (at most three). -Kind task-view -AnalysisPath <folder> reopens it read-only. -Kind task-apply -AnalysisPath <folder>
-Authorization <reference> writes the reviewed result to the tracker through knowledge.ps1 -UpdateTaskId (ledger mode analysis).
Without a mode the script lists the modes and exits 2.
#>
[CmdletBinding()]
param([switch]$Probe,[ValidateSet('claude','codex','gemini')][string[]]$Provider,[switch]$Clients,
    [switch]$Directives,[string]$RepositoryPath,[string]$DirectivesFile,[string]$ProposalPath,
    [ValidatePattern('^$|^[0-9A-Fa-f]{64}$')][string]$ExpectedProposalHash,[string]$Authorization,[switch]$Apply,
    [switch]$Analyze,[ValidateSet('directives','task','task-view','task-resolve','task-apply')][string]$Kind,[string]$Model,[string]$Effort,[switch]$AllowCustomModel,
    [string]$TaskId,[string]$AnalysisPath,[string]$AnswersFile,[ValidateRange(60,3600)][int]$TimeoutSeconds=600,
    [string]$ConfigPath,[ValidateSet('en','it')][string]$Language)
if($Language){$env:SECONDBRAIN_LANG=$Language}
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAdapters.psm1')
Add-SBMessages @{
    'agents.usage' = @{it='Nessuna opzione indicata. Usare -Probe [-Provider claude|codex|gemini], -Directives -RepositoryPath <checkout> [-DirectivesFile <md>] (anteprima) o con -ProposalPath -ExpectedProposalHash -Authorization -Apply, oppure -Analyze -Kind directives|task|task-resolve|task-apply';en='No mode given. Use -Probe [-Provider claude|codex|gemini], -Directives -RepositoryPath <checkout> [-DirectivesFile <md>] (preview) or with -ProposalPath -ExpectedProposalHash -Authorization -Apply, or -Analyze -Kind directives|task|task-resolve|task-apply'}
    'agents.repository.required' = @{it='-Directives e -Analyze richiedono -RepositoryPath con il percorso di un checkout gestito';en='-Directives and -Analyze need -RepositoryPath with the path of a managed checkout'}
    'agents.repository.unresolved' = @{it='Checkout non associato a un dossier attivo: {0}. Registralo con secondbrain.ps1 -AddRepo';en='Checkout not bound to an active dossier: {0}. Register it with secondbrain.ps1 -AddRepo'}
    'agents.directives.file' = @{it='File delle direttive non trovato: {0}';en='Directives file not found: {0}'}
    'agents.apply.required' = @{it='-Apply richiede -ProposalPath, -ExpectedProposalHash e -Authorization della proposta esaminata';en='-Apply needs -ProposalPath, -ExpectedProposalHash and -Authorization of the reviewed proposal'}
    'agents.step.failed' = @{it='{0} terminato con codice {1}: {2}';en='{0} ended with exit code {1}: {2}'}
    'agents.analysis.provider' = @{it='-Analyze richiede un solo -Provider (claude, codex o gemini)';en='-Analyze needs exactly one -Provider (claude, codex or gemini)'}
    'agents.analysis.task' = @{it='-Kind task richiede -TaskId del task da analizzare';en='-Kind task needs -TaskId of the task to analyze'}
    'agents.analysis.path' = @{it='Cartella di analisi non valida: {0}. Usa analysisPath restituito da -Kind task';en='Invalid analysis folder: {0}. Use the analysisPath returned by -Kind task'}
    'agents.analysis.answers' = @{it='Risposte non valide in {0}: serve un array JSON di oggetti con questionId, question e answer';en='Invalid answers in {0}: a JSON array of objects with questionId, question and answer is required'}
    'agents.analysis.rounds' = @{it='Raggiunto il massimo di {0} giri di domande: applica il risultato o riavvia l''analisi';en='The maximum of {0} question rounds is reached: apply the result or start the analysis again'}
    'agents.analysis.unresolved' = @{it='L''ultimo giro chiede ancora risposte (verdetto {0}): rispondi alle domande prima di applicare';en='The last round still asks for answers (verdict {0}): answer the questions before applying'}
    'agents.analysis.awaiting' = @{it='Il task attende {0}: l''analisi non può togliere l''attesa senza una risposta esplicita della persona';en='The task awaits {0}: the analysis cannot clear the wait without an explicit answer of the owner'}
    'agents.analysis.authorization' = @{it='-Kind task-apply richiede -Authorization (riferimento alla conferma della persona)';en='-Kind task-apply needs -Authorization (reference to the owner confirmation)'}
}
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$configArgs=if($ConfigPath){@('-ConfigPath',$ConfigPath)}else{@()}
$utf8=[Text.UTF8Encoding]::new($false)
$maxRounds=3
function Invoke-AgentsStep([string]$Script,[string[]]$StepArgs,[int[]]$AllowedExit=@(0)){
    # Child SecondBrain CLI: JSON on stdout, diagnostics on stderr; a non-zero exit is reported with its message.
    $path=Join-Path $PSScriptRoot $Script
    $errFile=[IO.Path]::GetTempFileName()
    try{
        $out=(& pwsh -NoProfile -File $path @StepArgs 2>$errFile|Out-String)
        $code=$LASTEXITCODE
        $err=[IO.File]::ReadAllText($errFile)
    }finally{Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue}
    if($code -notin $AllowedExit){throw (New-SBError 'agents.step.failed' @($Script,$code,($err+$out).Trim()))}
    $i=$out.IndexOfAny([char[]]@('[','{'))
    if($i -lt 0){return $null}
    $value=$out.Substring($i)|ConvertFrom-Json -AsHashtable
    if($value -is [hashtable]){$value.exitCode=$code}
    $value
}
function Get-AgentsRepository([string]$Path){
    if(!$Path){throw (New-SBError 'agents.repository.required')}
    $full=[IO.Path]::GetFullPath($Path)
    $context=Invoke-AgentsStep 'prompts.ps1' (@('-Context','-RepositoryPath',$full)+$configArgs)
    $repo=@($context.repositories|Where-Object {$_ -and $_.identity -and $_.dossier})
    if($repo.Count -ne 1){throw (New-SBError 'agents.repository.unresolved' @($full))}
    $repo[0]
}
function Get-AgentsDirectiveBlocks($Repo){
    # What every session of the repository loads besides the startup package: the global block (IDE instructions), the common repository
    # block and AGENTS.md outside the managed blocks; plus the dossier-specific text and the repository block composed from it.
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1')
    $global=try{Get-SBPortableGlobal $brain}catch{''}
    $commonPath=Join-Path $brain 'direttive/AGENTS.repo.managed.md'
    $common=if(Test-Path -LiteralPath $commonPath -PathType Leaf){(Read-SBText $commonPath).Trim()}else{''}
    $agentsFile=[string]$Repo.agents
    $agentsText=if($agentsFile -and (Test-Path -LiteralPath $agentsFile -PathType Leaf)){Read-SBText $agentsFile}else{''}
    $outside=([regex]::Replace($agentsText,'(?s)<!-- secondbrain:([\w-]+):begin -->.*?<!-- secondbrain:\1:end -->','')).Trim()
    $dossierFile=Join-Path $Repo.dossier 'AGENTS.managed.md'
    $current=if(Test-Path -LiteralPath $dossierFile -PathType Leaf){Read-SBText $dossierFile}else{''}
    @{global=$global;common=$common;agentsFile=$agentsFile;agentsText=$agentsText;outside=$outside;dossier=$current}
}
function Get-AgentsComposedBlock([string]$Common,[string]$Specific){
    # The repository block as secondbrain.ps1 -Sync would write it for the given specific text (approval aside): stamp, common body, specific text.
    $revision=Get-SBApprovedDirectiveRevision $brain
    $stamp=if($revision){'Direttive comuni applicate: revisione **'+$revision.version+'** — '+$revision.date+'.'}else{''}
    (@($stamp,$Common.Trim(),$Specific.Trim())|Where-Object {$_}) -join "`n`n"
}
function Get-AgentsCounts($Blocks,[string]$Specific){
    $composed=Get-AgentsComposedBlock $Blocks.common $Specific
    $budget=25000
    $loaded=$Blocks.global.Length+$Blocks.outside.Length+$composed.Length
    [ordered]@{global=$Blocks.global.Length;common=$Blocks.common.Length;dossier=$Specific.Length;agentsOutside=$Blocks.outside.Length;composed=$composed.Length;loaded=$loaded;budget=$budget;percent=[math]::Round(100*$loaded/$budget,1)}
}
function Initialize-AgentsWork($Repo,[string]$Slug,[string]$Task){
    [string](Invoke-AgentsStep 'work.ps1' (@('-Repository',[string]$Repo.identity,'-Category','work','-Slug',$Slug,'-Init','-Task',$Task,'-Client','orchestrator')+$configArgs)).root
}
function Close-AgentsWork($Repo,[string]$Slug){
    try{[void](Invoke-AgentsStep 'work.ps1' (@('-Repository',[string]$Repo.identity,'-Category','work','-Slug',$Slug,'-Close')+$configArgs))}catch{[void]$_}
}
function Read-AgentsAnalysis([string]$Path){
    # The state of a task analysis lives in its work folder (analysis.json), so the window can close between rounds.
    $full=if($Path){[IO.Path]::GetFullPath($Path)}else{''}
    $file=if($full){Join-Path $full 'analysis.json'}else{''}
    if(!$file -or (Split-Path -Leaf $full) -notmatch '^\d{8}-analysis-task-\d+-\d{6}$' -or !(Test-Path -LiteralPath $file -PathType Leaf)){throw (New-SBError 'agents.analysis.path' @($Path))}
    $state=Read-SBText $file|ConvertFrom-Json -AsHashtable -Depth 40 -DateKind String
    if($state -isnot [hashtable] -or $state.schemaVersion -ne 1 -or !$state.taskId -or $state.rounds -isnot [array]){throw (New-SBError 'agents.analysis.path' @($Path))}
    @{path=$full;file=$file;state=$state}
}
function Save-AgentsAnalysis($Analysis){[IO.File]::WriteAllText($Analysis.file,(ConvertTo-SBJson $Analysis.state),$utf8)}
function Get-AgentsTaskContext($Repo,[string]$Id){
    # The task as the tracker holds it (archived included), why the runner skips it, and the status of its dependencies.
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1')
    $detail=Invoke-AgentsStep 'knowledge.ps1' (@('-Task',$Id,'-CheckoutPath',[string]$Repo.checkout)+$configArgs)
    $task=$detail.task
    $object=ConvertTo-SBJson $task|ConvertFrom-Json
    $reason=Get-SBRunnerExclusionReason $object
    $active=@(Invoke-AgentsStep 'knowledge.ps1' (@('-Tasks','-CheckoutPath',[string]$Repo.checkout)+$configArgs))
    $statusById=@{};foreach($t in $active){if($t -is [hashtable] -and $t.ContainsKey('id')){$statusById[[string]$t.id]=[string]$t.status}}
    $deps=@(@($task['dependencies'])|Where-Object {$_}|ForEach-Object {
        $depId=[string]$_['id'];$depRepo=[string]$_['repository']
        $label=if($depRepo){"$depRepo#$depId"}else{$depId}
        @{id=$label;status=$(if($depRepo){'other-repository'}elseif($statusById.ContainsKey($depId)){$statusById[$depId]}else{'archived'})}
    })
    $open=@($deps|Where-Object {$_.status -notin @('done','archived')})
    if(!$reason -and $open.Count){$reason='dependency:'+((@($open|ForEach-Object {$_.id})) -join ',')}
    @{task=$task;reason=$reason;dependencies=$deps}
}
function Invoke-AgentsTaskRound($Repo,$Analysis,$Context){
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAnalysis.psm1')
    $state=$Analysis.state
    $round=@($state.rounds).Count+1
    $prompt=New-SBTaskAnalysisPrompt -BrainRoot $brain -Task $Context.task -Reason $Context.reason -Dependencies $Context.dependencies -Rounds $state.rounds -Language $state.language -Round $round -MaxRounds $maxRounds
    $out=Invoke-SBAgentOneShot -Provider $state.provider -Model $state.model -Effort $state.effort -Prompt $prompt -SchemaPath (Get-SBAnalysisSchemaPath $brain 'task') `
        -CheckoutPath ([string]$Repo.checkout) -OutputFolder (Join-Path $Analysis.path "round-$round") -BrainRoot $brain -TimeoutSeconds $TimeoutSeconds -AllowCustomModel:$AllowCustomModel
    if(!$state.model -and $out.model){$state.model=$out.model}
    if(!$state.effort -and $out.effort){$state.effort=$out.effort}
    $state.rounds=@($state.rounds)+@([ordered]@{round=$round;at=[DateTimeOffset]::UtcNow.ToString('o');result=$out.result;answers=@();attempts=$out.attempts;seconds=$out.seconds;nativeSchema=$out.nativeSchema})
    Save-AgentsAnalysis $Analysis
    $out
}
function Get-AgentsAnalysisView($Analysis,$Context){
    $state=$Analysis.state
    $last=@($state.rounds)[-1]
    [ordered]@{
        analysisPath=$Analysis.path;taskId=$state.taskId;seq=$state.seq;repository=$state.repository;provider=$state.provider;model=$state.model;effort=$state.effort
        round=@($state.rounds).Count;maxRounds=$maxRounds;reason=$Context.reason;dependencies=$Context.dependencies
        task=[ordered]@{id=$Context.task['id'];seq=$Context.task['seq'];title=$Context.task['title'];status=$Context.task['status'];execution=$Context.task['execution'];description=$Context.task['description'];acceptance=@($Context.task['acceptance']);extensions=$Context.task['extensions']}
        result=$last.result;answered=@(@($state.rounds)|ForEach-Object {@($_.answers)}|Where-Object {$_})
    }
}
try{
    if($Probe){
        $ids=if($Provider){@($Provider)}else{@(Get-SBAgentProviderIds)}
        $agents=@(Get-SBAgentCapabilitiesAll -Provider $ids -BrainRoot $brain)
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAnalysis.psm1')
        foreach($a in $agents){$a.light=Get-SBLightModel $brain ([string]$a.provider)}
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
    if($Analyze){
        $repo=Get-AgentsRepository $RepositoryPath
        $lang=if($env:SECONDBRAIN_LANG -eq 'en'){'en'}else{'it'}
        if($Kind -in @('directives','task') -and @($Provider).Count -ne 1){throw (New-SBError 'agents.analysis.provider')}
        switch($Kind){
            'directives' {
                Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAnalysis.psm1')
                $blocks=Get-AgentsDirectiveBlocks $repo
                $slug='analysis-directives-'+(Get-Date).ToString('HHmmss')
                $root=Initialize-AgentsWork $repo $slug 'Analisi delle direttive di repository (orchestratore, DOC06)'
                try{
                    $counts=Get-AgentsCounts $blocks $blocks.dossier
                    $prompt=New-SBDirectivesAnalysisPrompt -BrainRoot $brain -Identity ([string]$repo.identity) -GlobalText $blocks.global -CommonText $blocks.common -DossierText $blocks.dossier -AgentsOutside $blocks.outside -Budget $counts.budget -UsedCharacters ($counts.loaded-$counts.dossier) -Language $lang
                    $out=Invoke-SBAgentOneShot -Provider $Provider[0] -Model $Model -Effort $Effort -Prompt $prompt -SchemaPath (Get-SBAnalysisSchemaPath $brain 'directives') -CheckoutPath ([string]$repo.checkout) -OutputFolder $root -BrainRoot $brain -TimeoutSeconds $TimeoutSeconds -AllowCustomModel:$AllowCustomModel
                    $markdown=ConvertTo-SBDirectivesMarkdown $out.result
                    ConvertTo-SBJson ([ordered]@{
                        identity=$repo.identity;folder=$root;provider=$out.provider;model=$out.model;effort=$out.effort;role=$out.role;attempts=$out.attempts;seconds=$out.seconds;nativeSchema=$out.nativeSchema
                        markdown=$markdown;portable=(Test-SBDirectiveText $markdown);sections=@($out.result.sections);coveredElsewhere=@($out.result.coveredElsewhere);warnings=@($out.result.warnings)
                        counts=(Get-AgentsCounts $blocks $markdown)
                    })
                }finally{Close-AgentsWork $repo $slug}
                exit 0
            }
            'task' {
                if(!$TaskId){throw (New-SBError 'agents.analysis.task')}
                $context=Get-AgentsTaskContext $repo $TaskId
                $slug='analysis-task-'+[string]$context.task['seq']+'-'+(Get-Date).ToString('HHmmss')
                $root=Initialize-AgentsWork $repo $slug ("Analisi di autonomia del task $TaskId (orchestratore, REP18)")
                $analysis=@{path=$root;file=(Join-Path $root 'analysis.json');state=[ordered]@{schemaVersion=1;taskId=[string]$context.task['id'];seq=$context.task['seq'];repository=[string]$repo.identity;slug=$slug;provider=$Provider[0];model=$Model;effort=$Effort;language=$lang;createdAt=[DateTimeOffset]::UtcNow.ToString('o');rounds=@();applied=$null}}
                Save-AgentsAnalysis $analysis
                [void](Invoke-AgentsTaskRound $repo $analysis $context)
                ConvertTo-SBJson (Get-AgentsAnalysisView $analysis $context)
                exit 0
            }
            'task-view' {
                # Read-only: the state of an analysis started earlier (the window reopens it without a new agent call).
                $analysis=Read-AgentsAnalysis $AnalysisPath
                $context=Get-AgentsTaskContext $repo ([string]$analysis.state.taskId)
                $view=Get-AgentsAnalysisView $analysis $context
                $view.applied=$analysis.state['applied']
                ConvertTo-SBJson $view
                exit 0
            }
            'task-resolve' {
                $analysis=Read-AgentsAnalysis $AnalysisPath
                if(!$AnswersFile -or !(Test-Path -LiteralPath $AnswersFile -PathType Leaf)){throw (New-SBError 'agents.analysis.answers' @($AnswersFile))}
                try{$answers=@(Read-SBText $AnswersFile|ConvertFrom-Json -AsHashtable)}catch{throw (New-SBError 'agents.analysis.answers' @($AnswersFile))}
                if(!$answers.Count -or @($answers|Where-Object {$_ -isnot [hashtable] -or !$_['question'] -or !$_['answer']}).Count){throw (New-SBError 'agents.analysis.answers' @($AnswersFile))}
                if(@($analysis.state.rounds).Count -ge $maxRounds){throw (New-SBError 'agents.analysis.rounds' @($maxRounds))}
                $stamp=[DateTimeOffset]::UtcNow.ToString('o')
                @($analysis.state.rounds)[-1].answers=@($answers|ForEach-Object {[ordered]@{questionId=[string]$_['questionId'];question=[string]$_.question;answer=[string]$_.answer;at=$stamp}})
                Save-AgentsAnalysis $analysis
                $context=Get-AgentsTaskContext $repo ([string]$analysis.state.taskId)
                [void](Invoke-AgentsTaskRound $repo $analysis $context)
                ConvertTo-SBJson (Get-AgentsAnalysisView $analysis $context)
                exit 0
            }
            'task-apply' {
                if(!$Authorization){throw (New-SBError 'agents.analysis.authorization')}
                $analysis=Read-AgentsAnalysis $AnalysisPath
                $state=$analysis.state
                $result=@($state.rounds)[-1].result
                if($result.verdict -notin @('autonomous-now','not-automatable')){throw (New-SBError 'agents.analysis.unresolved' @($result.verdict))}
                $context=Get-AgentsTaskContext $repo ([string]$state.taskId)
                $task=$context.task
                $ext=if($task['extensions'] -is [hashtable]){$task.extensions}else{@{}}
                $answers=@(@($state.rounds)|ForEach-Object {@($_.answers)}|Where-Object {$_})
                $updateArgs=@('-UpdateTaskId',[string]$state.taskId,'-CheckoutPath',[string]$repo.checkout)
                $decisionsFile=$null
                if($answers.Count){
                    $decisionsFile=Join-Path $analysis.path 'decisions.json'
                    [IO.File]::WriteAllText($decisionsFile,(ConvertTo-SBJson @($answers|ForEach-Object {[ordered]@{questionId=$_.questionId;question=$_.question;answer=$_.answer;at=$_.at;decidedBy='owner (orchestrator)'}})),$utf8)
                    $updateArgs+=@('-DecisionsFile',$decisionsFile)
                }
                if($result.verdict -eq 'autonomous-now'){
                    $call=@(@($result.calls)|Where-Object {$_.name -eq 'propose_task_update'})|Select-Object -First 1
                    if(!$call){throw (New-SBError 'agents.analysis.unresolved' @($result.verdict))}
                    $u=$call.arguments
                    # A real wait of the owner is cleared only by an explicit answer recorded in this analysis.
                    $awaiting=[string]$ext['awaiting']
                    $newAwaiting=if($u['awaiting']){[string]$u.awaiting}else{''}
                    if($awaiting -and $awaiting -ne 'structural-completion' -and $newAwaiting -ne $awaiting -and !$answers.Count){throw (New-SBError 'agents.analysis.awaiting' @($awaiting))}
                    if($u['description']){$updateArgs+=@('-Description',[string]$u.description)}
                    $criteria=@(@($u['acceptance'])|Where-Object {$_}|ForEach-Object {([string]$_).Replace(';',',').Trim()})
                    if($criteria.Count){$updateArgs+=@('-Acceptance',($criteria -join ';'))}
                    $updateArgs+=@('-Execution',$(if($u['execution']){[string]$u.execution}else{'autonomous'}),'-Awaiting',$newAwaiting)
                    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
                    $requires=@(@($u['requires'])|Where-Object {$_ -and [string]$_ -cin (Get-SBTaskRequiresValues)})
                    $updateArgs+=@('-Requires',($requires -join ';'))
                    if($null -ne $u['dependencies']){$updateArgs+=@('-DependsOn',((@($u.dependencies)|Where-Object {$_}) -join ';'))}
                    if($u['stateReason']){$updateArgs+=@('-StateReason',[string]$u.stateReason)}
                    if([string]$task['status'] -in @('blocked','unknown')){$updateArgs+=@('-Status','todo')}
                }else{
                    $call=@(@($result.calls)|Where-Object {$_.name -eq 'mark_not_automatable'})|Select-Object -First 1
                    $why=if($call -and $call.arguments['reason']){[string]$call.arguments.reason}else{[string]$result.summary}
                    $updateArgs+=@('-StateReason',$why,'-Execution','user_required')
                }
                # The analysis tool is the executor of this write (ledger mode analysis); the owner confirmed it with -Authorization.
                $previous=$env:SECONDBRAIN_EXECUTOR
                try{
                    $env:SECONDBRAIN_EXECUTOR=(ConvertTo-Json ([ordered]@{tool=$state.provider;mode='analysis';model=$state.model;effort=$state.effort}) -Compress)
                    $written=Invoke-AgentsStep 'knowledge.ps1' (@($updateArgs)+$configArgs) -AllowedExit @(0,5)
                }finally{$env:SECONDBRAIN_EXECUTOR=$previous}
                $applied=if($written -and $written.exitCode -eq 5){'deferred'}else{$true}
                $state.applied=[ordered]@{at=[DateTimeOffset]::UtcNow.ToString('o');authorization=$Authorization;verdict=$result.verdict;state=$applied}
                Save-AgentsAnalysis $analysis
                Close-AgentsWork $repo ([string]$state.slug)
                ConvertTo-SBJson ([ordered]@{applied=$applied;taskId=$state.taskId;verdict=$result.verdict;analysisPath=$analysis.path;update=$written})
                exit 0
            }
            default {throw (New-SBError 'agents.usage')}
        }
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
    $blocks=Get-AgentsDirectiveBlocks $repo
    $agentsFile=$blocks.agentsFile
    $block=try{Get-SBManagedContent $blocks.agentsText 'repository'}catch{$null}
    $current=$blocks.dossier
    $result=[ordered]@{identity=$repo.identity;checkout=$repo.checkout;agentsFile=$agentsFile;managedBlock=$block;dossierDirectives=$current;dossierRelative=$relative
        globalBlock=$blocks.global;commonBlock=$blocks.common;agentsOutside=$blocks.outside;composedPreview=(Get-AgentsComposedBlock $blocks.common $current);counts=(Get-AgentsCounts $blocks $current);proposal=$null}
    if($DirectivesFile){
        $source=[IO.Path]::GetFullPath($DirectivesFile)
        if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw (New-SBError 'agents.directives.file' @($source))}
        $text=Read-SBText $source
        # Proposal folder: README.md plus the dossier path of AGENTS.managed.md, as approve-revision.ps1 expects.
        $folder=Invoke-AgentsStep 'work.ps1' (@('-Repository',[string]$repo.identity,'-Category','work','-Slug','directives','-Init','-Task','Proposta direttive di repository (orchestratore)')+$configArgs)
        $root=[string]$folder.root
        $readme="# Repository directives proposal`n`nRepository: $($repo.identity)`nPrepared by scripts/agents.ps1 -Directives from the selected file.`n"
        [IO.File]::WriteAllText((Join-Path $root 'README.md'),$readme,$utf8)
        $target=Join-Path $root $relative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $target))|Out-Null
        [IO.File]::WriteAllText($target,$text.TrimEnd()+"`n",$utf8)
        $preview=Invoke-AgentsStep 'approve-revision.ps1' (@('-ProposalPath',$root,'-Preview')+$configArgs)
        $result.proposal=[ordered]@{proposalPath=$root;proposalHash=$(if($preview -and $preview.ContainsKey('proposalHash')){$preview.proposalHash}else{$null});preview=$preview}
        $result.composedPreview=Get-AgentsComposedBlock $blocks.common $text
        $result.counts=Get-AgentsCounts $blocks $text
    }
    ConvertTo-SBJson $result
    exit 0
}catch{
    Write-Error $_ -ErrorAction Continue
    exit 2
}
