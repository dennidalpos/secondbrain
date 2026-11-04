#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName='Tasks')]
param([Parameter(ParameterSetName='Tasks')][switch]$Tasks,[Parameter(ParameterSetName='Tasks')][switch]$All,[switch]$ReadyOnly,[string]$Repository,
    [Parameter(Mandatory,ParameterSetName='Startup')][switch]$Startup,
    [Parameter(ParameterSetName='Startup')][ValidateSet('Slim','Full')][string]$Profile='Slim',
    [Parameter(ParameterSetName='Startup')][switch]$Report,
    [Parameter(Mandatory,ParameterSetName='Compact')][switch]$Compact,
    [Parameter(ParameterSetName='Compact')][Parameter(ParameterSetName='Renumber')][Parameter(ParameterSetName='HistoryMigration')][switch]$Apply,[Parameter(ParameterSetName='Compact')][string]$CandidatePath,
    [Parameter(Mandatory,ParameterSetName='Search')][string]$Search,[Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Startup')][Parameter(ParameterSetName='Compact')][int]$Budget=50000,
    [Parameter(Mandatory,ParameterSetName='TaskUpdate')][string]$UpdateTaskId,[Parameter(ParameterSetName='TaskUpdate')][string]$Status,[Parameter(ParameterSetName='TaskUpdate')][string]$StateReason,
    [Parameter(Mandatory,ParameterSetName='FileSave')][string]$SaveFile,
    [Parameter(Mandatory,ParameterSetName='FileAppend')][string]$AppendFile,
    [Parameter(Mandatory,ParameterSetName='FileSave')][Parameter(Mandatory,ParameterSetName='FileAppend')][string]$ContentPath,
    [Parameter(Mandatory,ParameterSetName='FileSave')][string]$ExpectedHash,
    [Parameter(Mandatory,ParameterSetName='FlushPending')][switch]$FlushPending,
    [Parameter(Mandatory,ParameterSetName='PendingWrites')][switch]$PendingWrites,
    [Parameter(Mandatory,ParameterSetName='TaskNew')][string]$NewTask,[Parameter(ParameterSetName='TaskNew')][string]$TaskId,[Parameter(ParameterSetName='TaskNew')][string]$Description,
    [Parameter(ParameterSetName='TaskNew')][string]$Priority='P2',[Parameter(ParameterSetName='TaskNew')][ValidateSet('autonomous','user_required','unspecified')][string]$Execution='autonomous',
    [Parameter(ParameterSetName='TaskNew')][string[]]$DependsOn=@(),[Parameter(Mandatory,ParameterSetName='TaskNew')][string[]]$Acceptance,
    [Parameter(Mandatory,ParameterSetName='TaskNew')][string]$Provenance,[Parameter(ParameterSetName='TaskNew')][string]$ProvenancePointer,
    [Parameter(Mandatory,ParameterSetName='Renumber')][switch]$RenumberTasks,
    [Parameter(Mandatory,ParameterSetName='HistoryMigration')][switch]$MigrateHistoryMessages,
    [Parameter(Mandatory,ParameterSetName='HistoryMessages')][switch]$HistoryMessages,
    [Parameter(Mandatory,ParameterSetName='Lifecycle')][ValidateSet('greenfield','none')][string]$SetLifecycle,
    [Parameter(Mandatory,ParameterSetName='Task')][string]$Task,
    [Parameter(Mandatory,ParameterSetName='Section')][string]$Section,[Parameter(ParameterSetName='Section')][string]$Source,
    [Parameter(ParameterSetName='Startup')][Parameter(ParameterSetName='Compact')][Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Task')][Parameter(ParameterSetName='Section')][string]$Dossier,[string]$CheckoutPath,[string]$ConfigPath,[string]$SessionId,
    [Parameter(ParameterSetName='Search')][ValidateSet('Literal','Relevance')][string]$Mode='Literal',
    [Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Tasks')][ValidateRange(0,[int]::MaxValue)][int]$Offset=0,[Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Tasks')][ValidateRange(0,[int]::MaxValue)][int]$Limit=0,
    [Parameter(ParameterSetName='Search')][switch]$AllDossiers,[Parameter(ParameterSetName='Search')][switch]$IncludeOriginals,
    [Parameter(ParameterSetName='Startup')][string[]]$TaskIds=@(),
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
Add-SBMessages @{
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
    if($readOnly -and !$bufferedWrite){
        $pendingResult=Invoke-SBPendingWrites -BrainRoot $brain -Config $config -SessionId $SessionId
        if($pendingResult.applied.Count -or $pendingResult.conflicts.Count -or $pendingResult.pending -or $pendingResult.errors.Count){[Console]::Error.WriteLine((Format-SBPendingNotice $pendingResult))}
    }
    # Slim: 20,000-character limit (essential parts; the rest on request). Full: workstation startupBudget or 50,000.
    # The startup limit applies only to initial loading (Slim: 20,000); Full is unlimited (0) unless -Budget is explicit; -Compact uses startupBudget or 50,000.
    # Search has a default limit (-1: 20 matches and 10,000 characters); explicit -Limit 0 / -Budget 0 removes it.
    $effectiveBudget = if($PSBoundParameters.ContainsKey('Budget')){ $Budget } elseif($Startup -and $Profile -eq 'Slim'){ Get-SBSlimStartupBudget } elseif($Search){ -1 } elseif($Startup){ 0 } elseif($config -and $config.ContainsKey('startupBudget') -and $config.startupBudget -gt 0){ [int]$config.startupBudget } else { 50000 }
    $effectiveLimit = if($PSBoundParameters.ContainsKey('Limit')){ $Limit } else { -1 }
    # Cooperative scope: explicit repository, otherwise the working checkout's repository (current directory).
    $resolveWorking={
        if($Repository){return $Repository}
        $resolved=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$resolved){throw (New-SBError 'knowledgecli.repository.all')}
        $resolved
    }
    if($Startup){
        if(!$Dossier){$Dossier=Join-Path $brain (Resolve-SBWorkingDossier $brain (& $resolveWorking))}
        elseif(![IO.Path]::IsPathRooted($Dossier)){$Dossier=Join-Path $brain $Dossier}
        $result=Get-SBStartupContext -BrainRoot $brain -Dossier $Dossier -CheckoutPath $CheckoutPath -TaskIds $TaskIds -Budget $effectiveBudget -ReadyOnly:$ReadyOnly -Profile $Profile
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
            exit 0
        }
    }
    elseif($Compact){
        if(!$Dossier){$Dossier=Join-Path $brain (Resolve-SBWorkingDossier $brain (& $resolveWorking))}
        elseif(![IO.Path]::IsPathRooted($Dossier)){$Dossier=Join-Path $brain $Dossier}
        $result=Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $Dossier -CandidatePath $CandidatePath -BackupRoot $config.backupRoot -Apply:$Apply -CheckoutPath $CheckoutPath -Budget $effectiveBudget}
    elseif($Search){
        # Default scope: the working repository's dossier, if resolvable; -AllDossiers selects all active areas.
        $searchRepository=$Repository
        if(!$Dossier -and !$Repository -and !$AllDossiers){try{$searchRepository=& $resolveWorking}catch{$searchRepository=''}}
        $result=Find-SBKnowledge -BrainRoot $brain -Search $Search -Dossier $Dossier -Repository $searchRepository -Budget $effectiveBudget -Mode $Mode -Offset $Offset -Limit $effectiveLimit -IncludeOriginals:$IncludeOriginals
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
        $repoId=if($Repository){$Repository}else{$working}
        if($repoId -cne $working){throw (New-SBError 'tracker.write.foreign' @($repoId,$working))}
        $arguments=@{TaskId=$UpdateTaskId;Status=$Status}
        if($PSBoundParameters.ContainsKey('StateReason')){$arguments.StateReason=$StateReason}
        $submission=New-SBPendingWrite -BrainRoot $brain -Repository $working -Operation task.status -Arguments $arguments -Config $config -SessionId $SessionId
        $result=Complete-SBPendingSubmission $submission $config $SessionId
    }
    elseif($SetLifecycle){
        # Greenfield guard: like tasks, lifecycle changes are limited to the working repository.
        $working=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$working){throw (New-SBError 'knowledgecli.repository.checkout')}
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
        $repoId=if($Repository){$Repository}else{$working}
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
    if($Search -or $All){(ConvertTo-SBStableValue $result|ConvertTo-Json -Depth 40 -Compress)}else{ConvertTo-SBJson $result}
    if($Startup -and !$result.withinBudget){exit 1}
}catch{
    if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 };
    if(Test-SBBusyError $_){Write-Output $_.Exception.Message;exit 3}
    Write-Error $_ -ErrorAction Continue;exit 2
}finally{Exit-SBOperation $lock}
