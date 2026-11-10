#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName='Tasks')]
param([Parameter(ParameterSetName='Tasks')][switch]$Tasks,[Parameter(ParameterSetName='Tasks')][switch]$All,[switch]$ReadyOnly,[string]$Repository,
    [Parameter(Mandatory,ParameterSetName='Startup')][switch]$Startup,
    [Parameter(ParameterSetName='Startup')][ValidateSet('Slim','Full')][string]$Profile='Slim',
    [Parameter(ParameterSetName='Startup')][switch]$Report,
    [Parameter(Mandatory,ParameterSetName='Compact')][switch]$Compact,
    [Parameter(ParameterSetName='Compact')][Parameter(ParameterSetName='Renumber')][Parameter(ParameterSetName='HistoryMigration')][Parameter(ParameterSetName='ArchiveTasks')][switch]$Apply,[Parameter(ParameterSetName='Compact')][string]$CandidatePath,
    [Parameter(Mandatory,ParameterSetName='ArchiveTasks')][switch]$ArchiveTasks,
    [Parameter(Mandatory,ParameterSetName='Search')][string]$Search,[Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Startup')][Parameter(ParameterSetName='Compact')][int]$Budget=50000,
    [Parameter(Mandatory,ParameterSetName='TaskUpdate')][string]$UpdateTaskId,[Parameter(ParameterSetName='TaskUpdate')][string]$Status,[Parameter(ParameterSetName='TaskUpdate')][string]$StateReason,
    [Parameter(Mandatory,ParameterSetName='FileSave')][string]$SaveFile,
    [Parameter(Mandatory,ParameterSetName='FileAppend')][string]$AppendFile,
    [Parameter(Mandatory,ParameterSetName='FileSave')][Parameter(Mandatory,ParameterSetName='FileAppend')][string]$ContentPath,
    [Parameter(Mandatory,ParameterSetName='FileSave')][string]$ExpectedHash,
    [Parameter(Mandatory,ParameterSetName='FlushPending')][switch]$FlushPending,
    [Parameter(Mandatory,ParameterSetName='PendingWrites')][switch]$PendingWrites,
    [Parameter(Mandatory,ParameterSetName='TaskNew')][string]$NewTask,[Parameter(ParameterSetName='TaskNew')][string]$TaskId,[Parameter(ParameterSetName='TaskNew')][string]$Description,
    [Parameter(ParameterSetName='TaskNew')][Parameter(ParameterSetName='TaskUpdate')][string]$Priority='P2',[Parameter(ParameterSetName='TaskNew')][Parameter(ParameterSetName='TaskUpdate')][ValidateSet('autonomous','user_required','unspecified')][string]$Execution='autonomous',
    [Parameter(ParameterSetName='TaskNew')][Parameter(ParameterSetName='TaskUpdate')][AllowEmptyCollection()][AllowEmptyString()][string[]]$DependsOn=@(),[Parameter(Mandatory,ParameterSetName='TaskNew')][string[]]$Acceptance,
    [Parameter(ParameterSetName='TaskUpdate')][AllowEmptyString()][string]$Stream,
    [Parameter(ParameterSetName='TaskUpdate')][AllowEmptyString()][string]$Awaiting,[Parameter(ParameterSetName='TaskUpdate')][AllowEmptyCollection()][AllowEmptyString()][string[]]$ReadRepositories,
    [Parameter(Mandatory,ParameterSetName='TaskNew')][string]$Provenance,[Parameter(ParameterSetName='TaskNew')][string]$ProvenancePointer,
    [Parameter(Mandatory,ParameterSetName='Renumber')][switch]$RenumberTasks,
    [Parameter(Mandatory,ParameterSetName='HistoryMigration')][switch]$MigrateHistoryMessages,
    [Parameter(Mandatory,ParameterSetName='HistoryMessages')][switch]$HistoryMessages,
    [Parameter(Mandatory,ParameterSetName='Lifecycle')][ValidateSet('greenfield','none')][string]$SetLifecycle,
    [Parameter(Mandatory,ParameterSetName='Roadmap')][switch]$Roadmap,
    [Parameter(ParameterSetName='Roadmap')][ValidateSet('Markdown','Json')][string]$Format='Markdown',
    [Parameter(ParameterSetName='Roadmap')][ValidatePattern('^\d{4}-\d{2}-\d{2}$')][string]$Since,
    [Parameter(Mandatory,ParameterSetName='Task')][string]$Task,
    [Parameter(Mandatory,ParameterSetName='Section')][string]$Section,[Parameter(ParameterSetName='Section')][string]$Source,
    [Parameter(ParameterSetName='Startup')][Parameter(ParameterSetName='Compact')][Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Task')][Parameter(ParameterSetName='Section')][string]$Dossier,[string]$CheckoutPath,[string]$ConfigPath,[string]$SessionId,
    [Parameter(ParameterSetName='Search')][ValidateSet('Literal','Relevance')][string]$Mode='Literal',
    [Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Tasks')][ValidateRange(0,[int]::MaxValue)][int]$Offset=0,[Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Tasks')][ValidateRange(0,[int]::MaxValue)][int]$Limit=0,
    [Parameter(ParameterSetName='Search')][switch]$AllDossiers,[Parameter(ParameterSetName='Search')][switch]$IncludeOriginals,
    [Parameter(ParameterSetName='Search')][ValidateSet('normative','policy','informazioni','prompt','memoria')][string[]]$Category=@(),
    [Parameter(ParameterSetName='Startup')][string[]]$TaskIds=@(),
    [Parameter(ParameterSetName='Startup')][Parameter(ParameterSetName='Search')][string]$PreviousRevision,
    [switch]$NoRecovery,
    [ValidateSet('en','it')][string]$Language)
if($Language){$env:SECONDBRAIN_LANG=$Language}
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Pending.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1')
Add-SBMessages @{
    'tracker.update.empty' = @{it='Specificare almeno un campo da aggiornare';en='Specify at least one field to update'}
    'knowledgecli.pending.size' = @{it='Il contenuto supera il limite di 2 MiB';en='Content exceeds the 2 MiB limit'}
    'tracker.write.foreign' = @{ it = 'Scrittura rifiutata: il tracker di ''{0}'' non appartiene al repository in lavoro ''{1}'''; en = 'Write refused: the tracker of ''{0}'' does not belong to the working repository ''{1}''' }
    'knowledgecli.repository.all' = @{ it = 'Repository in lavoro non risolvibile: eseguire dal checkout, indicare -Repository o -CheckoutPath (-All per la vista globale dei task, sola lettura)'; en = 'Working repository not resolvable: run from the checkout, give -Repository or -CheckoutPath (-All for the read-only global task view)' }
    'knowledgecli.lifecycle.working' = @{ it = 'Il ciclo di vita si modifica soltanto per il repository in lavoro'; en = 'The lifecycle can be changed only for the working repository' }
    'knowledgecli.repository.checkout' = @{ it = 'Repository in lavoro non risolvibile: eseguire dal checkout o indicare -CheckoutPath'; en = 'Working repository not resolvable: run from the checkout or give -CheckoutPath' }
    'knowledgecli.params.incompatible' = @{ it = 'Parametri incompatibili: -All e -Repository'; en = 'Incompatible parameters: -All and -Repository' }
}
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$lock=$null
try{
    $bufferedWrite=($UpdateTaskId -or $NewTask -or $SaveFile -or $AppendFile)
    $readOnly=($bufferedWrite -or (!$Apply -and !$SetLifecycle))
    $config=Read-SBConfiguration $ConfigPath -ReadOnly:$readOnly;$lock=Enter-SBOperation $config $SessionId -ReadOnly:$readOnly
    if($readOnly){Write-SBReadWarnings $lock $config}
    $pendingResult=$null
    if($NoRecovery -and ($bufferedWrite -or $Apply -or $SetLifecycle -or $FlushPending)){throw (New-SBError 'knowledgecli.params.incompatible')}
    if($readOnly -and !$bufferedWrite -and !$ArchiveTasks -and !$NoRecovery){
        $pendingResult=Invoke-SBPendingWrites -BrainRoot $brain -Config $config -SessionId $SessionId
        if($pendingResult.applied.Count -or $pendingResult.conflicts.Count -or $pendingResult.pending -or $pendingResult.errors.Count){[Console]::Error.WriteLine((Format-SBPendingNotice $pendingResult))}
    }
    # Full is unlimited unless -Budget is explicit; Slim and Compact share the 30,000 default.
    # Search has a default limit (-1: 20 matches and 10,000 characters); explicit -Limit 0 / -Budget 0 removes it.
    $effectiveBudget = if($PSBoundParameters.ContainsKey('Budget')){ $Budget } elseif($Compact -or ($Startup -and $Profile -eq 'Slim')){ Get-SBSlimStartupBudget } elseif($Search){ -1 } elseif($Startup){ 0 } else { 30000 }
    $effectiveLimit = if($PSBoundParameters.ContainsKey('Limit')){ $Limit } else { -1 }
    # Cooperative scope: explicit repository, otherwise the working checkout's repository (current directory).
    $resolveWorkingRaw={
        if($Repository){return $Repository}
        $resolved=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$resolved){throw (New-SBError 'knowledgecli.repository.all')}
        $resolved
    }
    # Runner sessions (#382): reads stay in the task repository or its read allowlist, writes in the task repository; no effect outside a runner session.
    $resolveWorking={$id=& $resolveWorkingRaw;Assert-SBRunnerReadScope -Repository $id;$id}
    $writeScope={param($Id) Assert-SBRunnerReadScope -Repository $Id -Write}
    if($Dossier){Assert-SBRunnerReadScope -Dossier $Dossier -BrainRoot $brain -Write:($Apply -or [bool]$SetLifecycle)}
    if($All -or $AllDossiers){Assert-SBRunnerReadScope -Global;Assert-SBProjectIsolation $brain}
    if($Startup){
        if(!$Dossier){$Dossier=Join-Path $brain (Resolve-SBWorkingDossier $brain (& $resolveWorking))}
        elseif(![IO.Path]::IsPathRooted($Dossier)){$Dossier=Join-Path $brain $Dossier}
        $result=Get-SBStartupContext -BrainRoot $brain -Dossier $Dossier -CheckoutPath $CheckoutPath -TaskIds $TaskIds -Budget $effectiveBudget -ReadyOnly:$ReadyOnly -Profile $Profile -PreviousRevision $PreviousRevision
        if($Report){
            $directives=@{}
            try{
                Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
                foreach($ide in @(Get-SBIDEAssets|Where-Object {$_.instructions -and (Test-Path -LiteralPath $_.instructions -PathType Leaf)})){$directives[$ide.name+' (globale)']=([IO.File]::ReadAllText($ide.instructions).Length.ToString()+' caratteri')}
            }catch{$directives['IDE']='non rilevabile: '+$_.Exception.Message}
            $checkout=if($CheckoutPath){$CheckoutPath}else{(Get-Location).Path}
            $agents=Join-Path $checkout 'AGENTS.md'
            if(Test-Path -LiteralPath $agents -PathType Leaf){$directives['AGENTS.md del checkout']=([IO.File]::ReadAllText($agents).Length.ToString()+' caratteri')}
            Format-SBStartupReport $result $directives
            if(!$result.withinBudget){Write-Error -ErrorAction Continue $(if($result.diagnostic){$result.diagnostic}else{Get-SBMessage 'knowledge.budget.exceeded'});exit 1}
            exit 0
        }
    }
    elseif($ArchiveTasks){$archiveRepository=& $resolveWorking;if($Apply){& $writeScope $archiveRepository};$result=Move-SBTerminalTrackerTasks -BrainRoot $brain -Identity $archiveRepository -Apply:$Apply -BackupRoot $config.backupRoot}
    elseif($Compact){
        if(!$Dossier){$compactRepository=& $resolveWorking;if($Apply){& $writeScope $compactRepository};$Dossier=Join-Path $brain (Resolve-SBWorkingDossier $brain $compactRepository)}
        elseif(![IO.Path]::IsPathRooted($Dossier)){$Dossier=Join-Path $brain $Dossier}
        $result=Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $Dossier -CandidatePath $CandidatePath -BackupRoot $config.backupRoot -Apply:$Apply -CheckoutPath $CheckoutPath -Budget $effectiveBudget}
    elseif($Search){
        # Default scope: the working repository's dossier, if resolvable; -AllDossiers selects all active dossiers (refused under project isolation).
        $searchRepository=$Repository
        if(!$Dossier -and !$Repository -and !$AllDossiers){try{$searchRepository=& $resolveWorking}catch{$searchRepository=''}}
        # In a runner session an unresolvable scope falls back to the task repository instead of all dossiers.
        $runnerScope=Get-SBRunnerReadScope
        if($runnerScope -and !$Dossier -and !$searchRepository){$searchRepository=$runnerScope.repository}
        if(!$Dossier -and !$searchRepository -and !$AllDossiers){Assert-SBProjectIsolation $brain}
        if($Repository){Assert-SBRunnerReadScope -Repository $Repository}
        $result=Find-SBKnowledge -BrainRoot $brain -Search $Search -Dossier $Dossier -Repository $searchRepository -Budget $effectiveBudget -Mode $Mode -Offset $Offset -Limit $effectiveLimit -IncludeOriginals:$IncludeOriginals -Category $Category -PreviousRevision $PreviousRevision
    }
    elseif($Roadmap){
        # Single-repository roadmap: only this repository's tracker history and git log.
        if(!$Dossier){$Dossier=Join-Path $brain (Resolve-SBWorkingDossier $brain (& $resolveWorking))}
        elseif(![IO.Path]::IsPathRooted($Dossier)){$Dossier=Join-Path $brain $Dossier}
        $roadmapCheckout=if($CheckoutPath){$CheckoutPath}else{(Get-Location).Path}
        $result=Get-SBRoadmap -BrainRoot $brain -Dossier $Dossier -CheckoutPath $roadmapCheckout -Since $Since
    }
    elseif($Task -or $Section){
        # Deeper layers: complete task details (including archived tasks) or a whole named section from the working repository's dossier.
        if(!$Dossier){$Dossier=Join-Path $brain (Resolve-SBWorkingDossier $brain (& $resolveWorking))}
        elseif(![IO.Path]::IsPathRooted($Dossier)){$Dossier=Join-Path $brain $Dossier}
        $result=if($Task){Get-SBTaskDetail -BrainRoot $brain -Dossier $Dossier -Task $Task -CheckoutPath $CheckoutPath}else{Get-SBSection -BrainRoot $brain -Dossier $Dossier -Title $Section -Source $Source}
    }
    elseif($FlushPending){$result=$pendingResult}
    elseif($PendingWrites){$result=@(Get-SBPendingWrites $brain)}
    elseif($SaveFile -or $AppendFile){
        $working=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$working){throw (New-SBError 'knowledgecli.repository.checkout')}
        & $writeScope $working
        if($Repository -and $Repository -cne $working){throw (New-SBError 'tracker.write.foreign' @($Repository,$working))}
        Assert-SBPlainPath $ContentPath
        if((Get-Item -LiteralPath $ContentPath).Length -gt 2MB){throw (New-SBError 'knowledgecli.pending.size')}
        $operationName=if($SaveFile){'file.save'}else{'file.append'}
        $relative=if($SaveFile){$SaveFile}else{$AppendFile}
        $expected=if($SaveFile){@{hash=$ExpectedHash}}else{@{}}
        $submission=New-SBPendingWrite -BrainRoot $brain -Repository $working -Operation $operationName -Arguments @{relativePath=$relative;content=(Read-SBText $ContentPath)} -Expected $expected -Config $config -SessionId $SessionId
        $result=Complete-SBPendingSubmission $submission $config $SessionId
    }
    elseif($UpdateTaskId){
        # Writes stay in the working repository: a -Repository differing from the current checkout is rejected.
        $working=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$working){throw (New-SBError 'knowledgecli.repository.checkout')}
        & $writeScope $working
        $repoId=if($Repository){$Repository}else{$working}
        if($repoId -cne $working){throw (New-SBError 'tracker.write.foreign' @($repoId,$working))}
        $arguments=@{TaskId=$UpdateTaskId}
        foreach($field in @('Status','StateReason','Priority','Execution','DependsOn','Stream','Awaiting','ReadRepositories')){
            if($PSBoundParameters.ContainsKey($field)){$arguments[$field]=$PSBoundParameters[$field]}
        }
        if($arguments.Count -eq 1){throw (New-SBError 'tracker.update.empty')}
        $submission=New-SBPendingWrite -BrainRoot $brain -Repository $working -Operation task.update -Arguments $arguments -Config $config -SessionId $SessionId
        $result=Complete-SBPendingSubmission $submission $config $SessionId
    }
    elseif($SetLifecycle){
        # Greenfield guard: like tasks, lifecycle changes are limited to the working repository.
        $working=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$working){throw (New-SBError 'knowledgecli.repository.checkout')}
        & $writeScope $working
        if($Repository -and $Repository -cne $working){throw (New-SBError 'knowledgecli.lifecycle.working')}
        $result=Set-SBRepositoryLifecycle -Dossier (Join-Path $brain (Resolve-SBWorkingDossier $brain $working)) -Lifecycle $SetLifecycle -BackupRoot $config.backupRoot
    }
    elseif($HistoryMessages){
        $repoId=& $resolveWorking
        $resolved=Resolve-SBTracker -BrainRoot $brain -Identity $repoId -AllowedOwners @()
        $archive=Read-SBJson (Join-Path (Split-Path $resolved.path) 'history/tracker-archive.json') $null
        $archiveView=@()
        if($archive){$archiveView=@(Get-SBTrackerHistoryMessages $archive)}
        $result=@{repository=$repoId;history=@(Get-SBTrackerHistoryMessages $resolved.data);archive=$archiveView}
    }
    elseif($NewTask -or $RenumberTasks -or $MigrateHistoryMessages){
        # Creation and numbering stay in the working repository, like status updates.
        $working=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$working){throw (New-SBError 'knowledgecli.repository.checkout')}
        & $writeScope $working
        $repoId=if($Repository){$Repository}else{$working}
        & $writeScope $repoId
        $result=if($NewTask){
            # With pwsh -File, lists arrive as one string: ';' separates criteria and dependencies.
            $DependsOn=@($DependsOn|ForEach-Object{$_ -split ';'}|ForEach-Object{$_.Trim()}|Where-Object{$_})
            $Acceptance=@($Acceptance|ForEach-Object{$_ -split ';'}|ForEach-Object{$_.Trim()}|Where-Object{$_})
            if($repoId -cne $working){throw (New-SBError 'tracker.write.foreign' @($repoId,$working))}
            $arguments=@{Title=$NewTask;Id=$TaskId;Description=$Description;Priority=$Priority;Execution=$Execution;DependsOn=$DependsOn;Acceptance=$Acceptance;ProvenanceReference=$Provenance;ProvenancePointer=$ProvenancePointer}
            $submission=New-SBPendingWrite -BrainRoot $brain -Repository $working -Operation task.new -Arguments $arguments -Config $config -SessionId $SessionId
            Complete-SBPendingSubmission $submission $config $SessionId
        }elseif($MigrateHistoryMessages){
            Invoke-SBTrackerHistoryMigration -BrainRoot $brain -Identity $repoId -WorkingRepository $working -BackupRoot $config.backupRoot -Apply:$Apply
        }else{
            Invoke-SBTrackerRenumber -BrainRoot $brain -Identity $repoId -WorkingRepository $working -BackupRoot $config.backupRoot -Apply:$Apply
        }
        $result.Remove('data')
    }
    elseif($All){
        if($Repository){throw (New-SBError 'knowledgecli.params.incompatible')}
        # Global paging matches MCP (50 entries per page, -Limit 0 = all): object with total, nextOffset and tasks.
        $pageLimit=if($PSBoundParameters.ContainsKey('Limit')){$Limit}else{50}
        $result=Get-SBGlobalTaskPage -BrainRoot $brain -Offset $Offset -Limit $pageLimit -ReadyOnly:$ReadyOnly
    }
    else{$result=@(Get-SBGlobalTasks -BrainRoot $brain -Repository (& $resolveWorking) -ReadyOnly:$ReadyOnly)}
    # Search and task lists use compact JSON (no indentation): fewer characters in the agent's context.
    if($Roadmap -and $Format -eq 'Markdown'){ConvertTo-SBRoadmapMarkdown $result}
    elseif($Search -or $All){(ConvertTo-SBStableValue $result|ConvertTo-Json -Depth 40 -Compress)}else{ConvertTo-SBJson $result}
    if($Startup -and !$result.withinBudget){exit 1}
}catch{
    if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 };
    if(Test-SBBusyError $_){Write-Output $_.Exception.Message;exit 3}
    Write-Error $_ -ErrorAction Continue;exit 2
}finally{Exit-SBOperation $lock}
