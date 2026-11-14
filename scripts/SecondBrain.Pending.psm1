#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskLedger.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Decisions.psm1')
$script:SBPendingDecisionError=$null
Add-SBMessages @{
    'pending.invalid' = @{it='Richiesta differita non valida: {0}';en='Invalid deferred request: {0}'}
    'pending.conflict' = @{it='La base della scrittura e cambiata: richiesta conservata senza sovrascrivere. Controllala con knowledge.ps1 -PendingWrites e, se superata, scartala con -DiscardPending';en='The write base changed: request preserved without overwriting. Check it with knowledge.ps1 -PendingWrites and, if outdated, discard it with -DiscardPending'}
    'pending.discard.notfound' = @{it='Nessuna richiesta differita con questo ID: elenca le richieste con knowledge.ps1 -PendingWrites';en='No deferred request with this ID: list requests with knowledge.ps1 -PendingWrites'}
    'pending.discard.state' = @{it='Solo le richieste in conflitto o non valide si possono scartare (stato: {0})';en='Only conflicting or invalid requests can be discarded (state: {0})'}
    'pending.batch.format' = @{it='File del lotto non valido: atteso un array JSON di aggiornamenti oppure un oggetto {"updates": [...]}';en='Invalid batch file: expected a JSON array of updates or an object {"updates": [...]}'}
    'pending.batch.field' = @{it='Campo sconosciuto "{0}": campi ammessi {1}';en='Unknown field "{0}": allowed fields are {1}'}
    'pending.batch.size' = @{it='Il lotto supera {0} aggiornamenti: dividerlo in altri file';en='The batch exceeds {0} updates: split it into several files'}
    'pending.batch.recovery' = @{it='Una transazione incompleta attende il ripristino: nessun aggiornamento del lotto applicato';en='An incomplete transaction awaits recovery: no update of the batch was applied'}
    'pending.notice' = @{it='Scritture differite: {0} integrate, {1} conflitti, {2} pendenti; stato {3}.';en='Deferred writes: {0} applied, {1} conflicts, {2} pending; state {3}.'}
}

function Get-SBPendingPaths([string]$BrainRoot) {
    $queue=Join-Path $BrainRoot '.runtime/access/pending-writes'
    @{queue=$queue;taskUpdates=(Join-Path $queue 'task-update');receipts=(Join-Path $BrainRoot '.runtime/access/pending-receipts')}
}
function Get-SBPendingHash($Request) {
    $copy=@{}+$Request
    $copy.Remove('sha256')
    Get-SBTextHash (ConvertTo-SBJson $copy)
}
function Resolve-SBPendingDossier([string]$BrainRoot,[string]$Repository) {
    $entities=@(Get-SBParaEntities $BrainRoot @())
    $areas=@($entities|Where-Object {(Test-SBRepoDossier $_) -and !$_.archived -and $_.status -eq 'active' -and $_.repository -ceq $Repository})
    if($areas.Count -ne 1){throw (New-SBError 'pending.invalid' @('repository'))}
    $dir=Resolve-SBParaPath $BrainRoot $areas[0].path
    $metadata=Read-SBJson (Join-Path $dir 'repository.json') $null
    if(!$metadata -or $metadata.identity -cne $Repository){throw (New-SBError 'pending.invalid' @('identity'))}
    $dir
}
function Assert-SBPendingFile([string]$RelativePath) {
    # Generated views, arbitrary attachments, configuration and PARA metadata are excluded.
    # decisions.json (#588) is written only as a whole file.save from decisions.ps1 and validated again when applied.
    if($RelativePath -cnotmatch '^(?:context\.md|memory\.md|decisions\.json|history/[a-zA-Z0-9][a-zA-Z0-9_-]*/report\.md)$'){
        throw (New-SBError 'pending.invalid' @('relativePath'))
    }
}
function Read-SBPendingTracker([string]$BrainRoot,[string]$Repository,[string]$Dossier) {
    # Capture one authoritative file without validating every related repository while queuing.
    # The normal tracker writer validates the complete graph before the transaction is applied.
    $metadata=Read-SBJson (Join-Path $Dossier 'repository.json') $null
    $declaration=$metadata.tracker
    if($declaration -isnot [Collections.IDictionary] -or $declaration.Count -ne 3 -or
       $declaration.location -ne 'dossier' -or $declaration.path -cne 'tracker.json' -or $declaration.schemaVersion -ne 1 -or !(Test-SBTrackerPolicy $BrainRoot)){
        throw (New-SBError 'pending.invalid' @('tracker declaration'))
    }
    $path=Resolve-SBParaPath $Dossier $declaration.path
    $hash=Get-SBFileHash $path
    $data=Read-SBJson $path $null
    if($data -isnot [Collections.IDictionary] -or $data['schemaVersion'] -ne 1 -or $data['repository'] -cne $Repository -or
       $data['tasks'] -isnot [array] -or $hash -eq 'absent' -or (Get-SBFileHash $path) -cne $hash){
        throw (New-SBError 'pending.invalid' @('tracker data'))
    }
    @{path=$path;data=$data;hash=$hash}
}
function Test-SBPendingCandidateValidationError($Failure) {
    foreach($code in @('tracker.dependency.missing','tracker.dependency.cycle','tracker.dependency.unmanaged',
                       'tracker.schema.invalid','tracker.related.schema','tracker.related.missing',
                       'tracker.related.declaration','tracker.related.identity','tracker.date.invalid',
                       'tracker.id.duplicate','tracker.identity.unmanaged')){
        if(Test-SBError $Failure $code){return $true}
    }
    $false
}
function Assert-SBPendingRequest($Request,[string]$Id) {
    if($Request -isnot [Collections.IDictionary]){throw (New-SBError 'pending.invalid' @('object'))}
    $keys=@('schemaVersion','id','repository','operation','arguments','expected','createdAt','origin','sha256')
    if(@($Request.Keys|Where-Object {$_ -cnotin $keys}).Count -or @($keys|Where-Object {!$Request.ContainsKey($_)}).Count){throw (New-SBError 'pending.invalid' @('fields'))}
    if($Request.schemaVersion -ne 1 -or $Id -cnotmatch '^[a-f0-9]{32}$' -or $Request.id -cne $Id -or
       !(Test-SBRepositoryIdentity $Request.repository) -or $Request.sha256 -cne (Get-SBPendingHash $Request)){
        throw (New-SBError 'pending.invalid' @('identity/hash'))
    }
    if($Request.arguments -isnot [Collections.IDictionary] -or $Request.expected -isnot [Collections.IDictionary]){throw (New-SBError 'pending.invalid' @('arguments'))}
    $allowed=switch($Request.operation){
        'task.status' {@('TaskId','Status','StateReason','Evidence','Executor')}
        'task.update' {@('TaskId','Status','StateReason','Priority','Execution','DependsOn','Stream','Awaiting','Requires','Evidence','Description','Acceptance','Decisions','Decision','Executor')}
        'task.new' {@('Title','Id','Description','Priority','Execution','DependsOn','Acceptance','ProvenanceReference','ProvenancePointer','Requires','Executor')}
        'file.save' {@('relativePath','content')}
        'file.append' {@('relativePath','content')}
        default {throw (New-SBError 'pending.invalid' @('operation'))}
    }
    if(@($Request.arguments.Keys|Where-Object {$_ -notin $allowed}).Count){throw (New-SBError 'pending.invalid' @('argument fields'))}
    if($Request.operation -like 'file.*'){
        Assert-SBPendingFile $Request.arguments.relativePath
        if($Request.arguments.content -isnot [string]){throw (New-SBError 'pending.invalid' @('content'))}
        if($Request.arguments.relativePath -ceq 'decisions.json' -and $Request.operation -ne 'file.save'){throw (New-SBError 'pending.invalid' @('decisions.json accepts only file.save'))}
        if($Request.operation -eq 'file.save' -and (!$Request.expected.ContainsKey('hash') -or $Request.expected.hash -notmatch '^(?:absent|[A-Fa-f0-9]{64})$')){throw (New-SBError 'pending.invalid' @('expected hash'))}
    }
    if($Request.operation -in @('task.status','task.update')){
        if(!$Request.arguments.ContainsKey('TaskId') -or !$Request.arguments.TaskId -or
           !$Request.expected.ContainsKey('taskHash') -or $Request.expected.taskHash -notmatch '^[A-Fa-f0-9]{64}$'){throw (New-SBError 'pending.invalid' @('task status'))}
        if($Request.operation -eq 'task.status' -and !$Request.arguments.ContainsKey('Status')){throw (New-SBError 'pending.invalid' @('status required'))}
        if(@($Request.arguments.Keys|Where-Object {$_ -notin @('TaskId','Executor')}).Count -lt 1){throw (New-SBError 'tracker.update.empty')}
        if($Request.arguments.ContainsKey('Status') -and $Request.arguments.Status -notin @('todo','in_progress','blocked','done','cancelled','unknown')){throw (New-SBError 'tracker.status.invalid' @($Request.arguments.Status))}
        if($Request.arguments.ContainsKey('Priority') -and $Request.arguments.Priority -cnotin @('P0','P1','P2','P3','P4')){throw (New-SBError 'tracker.priority.invalid')}
        if($Request.arguments.ContainsKey('Execution') -and $Request.arguments.Execution -cnotin @('autonomous','user_required','unspecified')){throw (New-SBError 'tracker.execution.invalid')}
    }
    if($Request.operation -eq 'task.new'){
        if(!$Request.arguments.Title -or !@($Request.arguments.Acceptance).Count -or !$Request.expected.ContainsKey('provenancePath') -or
           !$Request.expected.ContainsKey('provenanceHash') -or $Request.expected.provenanceHash -notmatch '^[A-Fa-f0-9]{64}$'){
            throw (New-SBError 'pending.invalid' @('new task'))
        }
        if($Request.arguments.ContainsKey('Priority') -and $Request.arguments.Priority -cnotin @('P0','P1','P2','P3','P4')){throw (New-SBError 'tracker.priority.invalid')}
        if($Request.arguments.Id -and [string]$Request.arguments.Id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{2,79}$'){throw (New-SBError 'tracker.id.invalid' @($Request.arguments.Id))}
        if([string]$Request.arguments.Title -notmatch '\p{L}'){throw (New-SBError 'tracker.title.invalid')}
    }
}

function Get-SBPendingContentHash($Request) {
    Get-SBTextHash (ConvertTo-SBJson @{repository=$Request.repository;operation=$Request.operation;arguments=$Request.arguments;expected=$Request.expected})
}
function Read-SBPendingIdempotent([string]$Path,[string]$Repository,[string]$RequestId,[string]$PreparedHash) {
    Assert-SBPlainPath $Path
    if(![IO.File]::Exists($Path)){return $null}
    $existing=Read-SBJson $Path $null
    Assert-SBPendingRequest $existing $RequestId
    if($existing.repository -cne $Repository -or (Get-SBPendingContentHash $existing) -cne $PreparedHash){throw (New-SBError 'pending.invalid' @('request ID collision'))}
    @{id=$RequestId;path=$Path;state='deferred';applied=$false;request=$existing;replayed=$true}
}
function New-SBPendingWrite {
    [CmdletBinding()]
    param([string]$BrainRoot,[string]$Repository,[string]$Operation,[hashtable]$Arguments,[hashtable]$Expected=@{},$Config,[string]$SessionId,[hashtable]$Diagnostics,[switch]$PrepareOnly,[switch]$StrictPreconditions,[string]$RequestId,[string]$PreparedHash,[switch]$NoCandidateCheck)
    $clock=if($null -ne $Diagnostics){[Diagnostics.Stopwatch]::StartNew()}else{$null}
    try {
    if(!$Config -or !(Test-SBSamePath $Config.brainRoot $BrainRoot)){throw (New-SBError 'pending.invalid' @('configuration root'))}
    $session=$null
    if($SessionId){$session=Assert-SBSession $Config $SessionId}
    $dir=Resolve-SBPendingDossier $BrainRoot $Repository
    if(!$RequestId){$RequestId=(New-SBId)}
    if($RequestId -cnotmatch '^[a-f0-9]{32}$'){throw (New-SBError 'pending.invalid' @('request ID'))}
    $pendingPaths=Get-SBPendingPaths $BrainRoot
    $idempotentPath=Join-Path $(if($Operation -eq 'task.update'){$pendingPaths.taskUpdates}else{$pendingPaths.queue}) ($RequestId+'.json')
    if(!$PrepareOnly -and $PreparedHash){
        $prior=Read-SBPendingIdempotent $idempotentPath $Repository $RequestId $PreparedHash
        if($prior){return $prior}
    }
    # The executor is captured at submission: a deferred write applied later by another process keeps who asked for it.
    if($Operation -like 'task.*' -and !$Arguments.ContainsKey('Executor')){
        $Arguments=@{}+$Arguments
        $Arguments.Executor=Resolve-SBExecutor -Client $(if($session){[string]$session.client}else{''})
    }
    if($Operation -eq 'task.update' -and $Arguments.ContainsKey('Status') -and
       !@($Arguments.Keys|Where-Object {$_ -notin @('TaskId','Status','StateReason','Evidence','Executor')}).Count){
        $Operation='task.status'
        $Arguments=@{}+$Arguments
        if($Arguments.ContainsKey('StateReason')){$Arguments.StateReason=([string]$Arguments.StateReason).Trim()}
    }
    if($Operation -in @('task.status','task.update')){
        $tracker=Read-SBPendingTracker $BrainRoot $Repository $dir
        $archiveTasks=@((Read-SBTrackerArchive $tracker.path $Repository).data.tasks)
        # #593: a #seq is resolved to the task ID at submission, so a deferred request names the same task when applied.
        $resolvedId=Resolve-SBTrackerTaskId ([string]$Arguments.TaskId) (@($tracker.data.tasks)+$archiveTasks)
        if($resolvedId -cne [string]$Arguments.TaskId){$Arguments=@{}+$Arguments;$Arguments.TaskId=$resolvedId}
        $task=@($tracker.data.tasks|Where-Object id -eq $Arguments.TaskId)
        if(!$task.Count){$task=@($archiveTasks|Where-Object id -eq $Arguments.TaskId)}
        if($task.Count -ne 1){throw (New-SBError 'tracker.task.notfound' @($Arguments.TaskId))}
        $Expected=@{taskHash=(Get-SBTextHash (ConvertTo-SBJson $task[0]))}
    }elseif($Operation -eq 'task.new'){
        $provenance=([string]$Arguments.ProvenanceReference -split '#',2)[0]
        $source=if([IO.Path]::IsPathFullyQualified($provenance)){$provenance}else{Join-Path $dir $provenance}
        $source=Resolve-SBParaPath $BrainRoot ([IO.Path]::GetRelativePath($BrainRoot,[IO.Path]::GetFullPath($source)))
        if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw (New-SBError 'tracker.provenance.missing' @($provenance))}
        $Arguments=@{}+$Arguments
        $Arguments.ProvenanceReference=[IO.Path]::GetRelativePath($dir,$source).Replace('\','/')
        $Expected=@{provenancePath=[IO.Path]::GetRelativePath($BrainRoot,$source).Replace('\','/');provenanceHash=(Get-SBFileHash $source)}
    }
    if($StrictPreconditions){
        if($Operation -eq 'task.new'){$Expected.trackerHash=(Read-SBPendingTracker $BrainRoot $Repository $dir).hash}
        if($Operation -eq 'file.append'){$Expected.hash=Get-SBFileHash (Resolve-SBParaPath $dir $Arguments.relativePath)}
    }
    $request=@{schemaVersion=1;id=$RequestId;repository=$Repository;operation=$Operation;arguments=$Arguments;expected=$Expected;createdAt=(Get-SBNow).ToString('o');origin=@{computer=[Environment]::MachineName;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;workstationId=$Config.workstationId;sessionId=$SessionId;client=$(if($session){$session.client}else{'knowledge CLI/API'})}}
    $request.sha256=Get-SBPendingHash $request
    Assert-SBPendingRequest $request $request.id
    # A batch (#595) validates every candidate together under the lock, once, instead of once per item here.
    if($Operation -eq 'task.update' -and !$NoCandidateCheck){
        try {
            [void](Update-SBTrackerTask -BrainRoot $BrainRoot -Identity $Repository -WorkingRepository $Repository @Arguments -WhatIf)
        } catch {
            $failure=$_
            $baseValid=$false
            try{Assert-SBTrackerWriteData $BrainRoot $Repository $tracker.data $tracker.path;$baseValid=$true}catch{
                # The request envelope and task hash are known even when the rest of the graph cannot be read.
                Write-Verbose $_.Exception.Message
            }
            if($baseValid){throw $failure}
        }
    }
    $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $request))
    if($bytes.Length -gt 2MB){throw (New-SBError 'pending.invalid' @('size > 2 MiB'))}
    $contentHash=Get-SBPendingContentHash $request
    if($PreparedHash -and $contentHash -cne $PreparedHash){throw (New-SBError 'pending.invalid' @('stale prepared request'))}
    if($PrepareOnly){return @{id=$request.id;request=$request;contentHash=$contentHash;applied=$false;state='preview'}}
    $paths=Get-SBPendingPaths $BrainRoot
    $queue=if($Operation -eq 'task.update'){$paths.taskUpdates}else{$paths.queue}
    Assert-SBPlainPath $queue
    [IO.Directory]::CreateDirectory($queue)|Out-Null
    $path=Join-Path $queue ($request.id+'.json')
    if($clock){$Diagnostics.prepareMs=$clock.Elapsed.TotalMilliseconds;$writeStart=$clock.Elapsed.TotalMilliseconds}
    # Each request has a private new file: no shared append, no writer/operation lock.
    try{$stream=[IO.FileStream]::new($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)}catch [IO.IOException]{
        if($PreparedHash){$prior=Read-SBPendingIdempotent $path $Repository $RequestId $PreparedHash;if($prior){return $prior}}
        throw
    }
    try{$stream.Write($bytes);$stream.Flush($true)}finally{$stream.Dispose()}
    if($clock){$Diagnostics.writeFlushMs=$clock.Elapsed.TotalMilliseconds-$writeStart;$readStart=$clock.Elapsed.TotalMilliseconds}
    if((Get-SBFileHash $path) -ne (Get-SBHash $bytes)){throw (New-SBError 'core.readback.destination')}
    if($clock){$Diagnostics.readbackMs=$clock.Elapsed.TotalMilliseconds-$readStart;$Diagnostics.requestBytes=$bytes.Length}
    @{id=$request.id;path=$path;state='deferred';applied=$false;request=$request}
    } finally {if($clock){$Diagnostics.submissionMs=$clock.Elapsed.TotalMilliseconds}}
}

function Read-SBPendingReceipt([string]$Path,[string]$RequestPath,[string]$Id,[hashtable]$VerifiedAncestors) {
    try{
        Assert-SBPlainPath $Path -VerifiedAncestors $VerifiedAncestors
        $receipt=Read-SBJson $Path $null
        if(!$receipt){return $null}
        $required=@('schemaVersion','id','state','requestHash','sourceHash','observedAt','result','error')
        if($receipt -isnot [Collections.IDictionary] -or @($required|Where-Object {!$receipt.ContainsKey($_)}).Count -or
           $receipt.schemaVersion -ne 1 -or $receipt.id -cne $Id -or $receipt.state -notin @('applied','conflict','invalid') -or
           $receipt.result -isnot [Collections.IDictionary] -or $receipt.sourceHash -ine (Get-SBFileHash $RequestPath)){
            return @{state='invalid-receipt';result=@{};error='pending.receipt.invalid'}
        }
        $receipt
    }catch{@{state='invalid-receipt';result=@{};error='pending.receipt.unreadable'}}
}
function Get-SBPendingWrites([string]$BrainRoot) {
    $paths=Get-SBPendingPaths $BrainRoot
    # Ancestor validation is shared only within this scan, using the Core batch API.
    # The queue, receipt directory and individual files are still checked on every item.
    $verified=@{}
    Assert-SBPlainPath $paths.queue -VerifiedAncestors $verified
    if(!(Test-Path -LiteralPath $paths.queue)){return}
    Assert-SBPlainPath $paths.taskUpdates -VerifiedAncestors $verified
    $files=@(Get-ChildItem -LiteralPath $paths.queue -Filter '*.json' -File)
    if(Test-Path -LiteralPath $paths.taskUpdates){
        $files+=@(Get-ChildItem -LiteralPath $paths.taskUpdates -Filter '*.json' -File)
    }
    foreach($file in @($files|Sort-Object Name)){
        $id=$file.BaseName
        if($id -cnotmatch '^[a-f0-9]{32}$'){continue}
        $receiptPath=Join-Path $paths.receipts ($id+'.json')
        Assert-SBPlainPath $paths.queue -VerifiedAncestors $verified
        if($file.DirectoryName -eq $paths.taskUpdates){Assert-SBPlainPath $paths.taskUpdates -VerifiedAncestors $verified}
        Assert-SBPlainPath $paths.receipts -VerifiedAncestors $verified
        Assert-SBPlainPath $file.FullName -VerifiedAncestors $verified
        Assert-SBPlainPath $receiptPath -VerifiedAncestors $verified
        $receipt=Read-SBPendingReceipt $receiptPath $file.FullName $id -VerifiedAncestors $verified
        $createdAt=$file.CreationTimeUtc.ToString('o')
        $headerRepository=$null
        if(!$receipt -and $file.Length -le 2MB){try{$header=Read-SBJson $file.FullName $null;if($header -and $header.ContainsKey('createdAt')){$createdAt=[DateTimeOffset]::Parse($header.createdAt).UtcDateTime.ToString('o')};if($header -and $header.ContainsKey('repository')){$headerRepository=[string]$header.repository}}catch { Write-Verbose $_.Exception.Message }}
        $repository=if($receipt -and $receipt.ContainsKey('repository')){$receipt.repository}else{$headerRepository}
        @{id=$id;repository=$repository;path=$file.FullName;state=$(if($receipt){$receipt.state}else{'deferred'});receipt=$receipt;receiptPath=$receiptPath;createdAt=$createdAt}
    }
}

function Get-SBPendingSubmitWaitMs {
    # Bounded wait of a submission drain: SECONDBRAIN_PENDING_WAIT_SECONDS (0-120), default 8 s.
    if($env:SECONDBRAIN_PENDING_WAIT_SECONDS -match '^\d{1,3}$'){return [Math]::Min([int]$env:SECONDBRAIN_PENDING_WAIT_SECONDS,120)*1000}
    8000
}

function Resolve-SBPendingDrainConfig($Summary,[string]$BrainRoot,$Config,[string]$ConfigPath) {
    # Returns the configuration to drain with, or $null after recording why it is unusable in the summary.
    if(!$Config){
        try{
            if(!$ConfigPath){$ConfigPath=Get-SBHostConfigPath $BrainRoot}
            $Config=Read-SBConfiguration $ConfigPath -ReadOnly -BrainRoot $BrainRoot
        }catch{$Summary.state='unconfigured';$Summary.errors+=@{code='pending.configuration';message=$_.Exception.Message};return $null}
    }
    if(!(Test-SBSamePath $Config.brainRoot $BrainRoot)){$Summary.state='unconfigured';$Summary.errors+=@{code='pending.configuration.root'};return $null}
    $Config
}

function Test-SBPendingRecoveryGate($Summary,[string]$BrainRoot,$Config) {
    # True when a transaction marker exists; the summary then says busy, unavailable or recovery-required.
    if(!(Get-SBPendingTransaction $BrainRoot)){return $false}
    # A marker can belong to a live transaction: report busy, never ask to recover it.
    $probe=$null
    try{
        $writerPath=Join-Path $Config.coordinationRoot 'writer.lock'
        if(Test-Path -LiteralPath $writerPath){$probe=[IO.File]::Open($writerPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        $Summary.state='recovery-required'
    }catch{if(Test-SBBusyError $_){$Summary.state='busy'}else{$Summary.state='unavailable';$Summary.errors+=@{code='pending.coordination.unavailable';message=$_.Exception.Message}}}
    finally{if($probe){$probe.Dispose()}}
    $true
}

function Get-SBPendingTaskPlan([string]$BrainRoot,$Request,[string]$Dossier) {
    # Plans a task.* request: state applied|conflict|invalid, operations for the journal and result keys for the receipt.
    $state='applied';$errorCode=$null;$result=@{};$ops=@()
    $target=Read-SBPendingTracker $BrainRoot $Request.repository $Dossier
    $before=$target.hash
    if($Request.operation -in @('task.status','task.update')){
        $task=@($target.data.tasks|Where-Object id -eq $Request.arguments.TaskId)
        if(!$task.Count){$task=@((Read-SBTrackerArchive $target.path $Request.repository).data.tasks|Where-Object id -eq $Request.arguments.TaskId)}
        if($task.Count -ne 1 -or (Get-SBTextHash (ConvertTo-SBJson $task[0])) -ine $Request.expected.taskHash){$state='conflict'}
        else{
            $arguments=@{}+$Request.arguments
            $updater=if($Request.operation -eq 'task.status'){'Set-SBTrackerTaskStatus'}else{'Update-SBTrackerTask'}
            try{$candidate=& $updater -BrainRoot $BrainRoot -Identity $Request.repository -WorkingRepository $Request.repository @arguments -WhatIf}
            catch{
                $failure=$_
                if(!(Test-SBPendingCandidateValidationError $failure)){throw}
                # If the current graph is broken, this throws before a terminal receipt is written.
                Assert-SBTrackerWriteData $BrainRoot $Request.repository $target.data $target.path
                $state='invalid';$errorCode=$failure.Exception.Message
            }
        }
    }else{
        $source=Resolve-SBParaPath $BrainRoot $Request.expected.provenancePath
        if(($Request.expected.ContainsKey('trackerHash') -and $before -ine $Request.expected.trackerHash) -or (Get-SBFileHash $source) -ine $Request.expected.provenanceHash -or
           ($Request.arguments.ContainsKey('Id') -and $Request.arguments.Id -and @($target.data.tasks|Where-Object id -eq $Request.arguments.Id).Count)){$state='conflict'}
        else{
            $arguments=@{}+$Request.arguments
            try{$candidate=New-SBTrackerTaskEntry -BrainRoot $BrainRoot -Identity $Request.repository -WorkingRepository $Request.repository @arguments -WhatIf}
            catch{
                # Same rule as task.update (#563): a validation error that no retry can fix (missing dependency, schema) is terminal and
                # becomes 'invalid', which -DiscardPending accepts; transient faults (I/O, lock, broken current graph) still rethrow.
                $failure=$_
                if(!(Test-SBPendingCandidateValidationError $failure)){throw}
                Assert-SBTrackerWriteData $BrainRoot $Request.repository $target.data $target.path
                $state='invalid';$errorCode=$failure.Exception.Message
            }
        }
    }
    if($state -eq 'applied'){
        $ops+=@{path=$target.path;expected=$before;bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $candidate.data))}
        $ops+=@($candidate.extraOperations)
        foreach($key in @('taskId','status','seq','title','closureAdvice')){if($candidate.ContainsKey($key)){$result[$key]=$candidate[$key]}}
    }
    @{state=$state;errorCode=$errorCode;result=$result;ops=$ops}
}

function Test-SBPendingDecisionContent($Request) {
    # decisions.json must be file.save with valid content for the request's repository (#588); file.append is refused.
    $script:SBPendingDecisionError=$null
    if($Request.operation -ne 'file.save'){$script:SBPendingDecisionError='decisions.json accepts only file.save';return $false}
    try{Assert-SBDecisionData ([string]$Request.arguments.content|ConvertFrom-Json -AsHashtable) $Request.repository;$true}
    catch{$script:SBPendingDecisionError=$_.Exception.Message;$false}
}
function Get-SBPendingFilePlan($Request,[string]$Dossier) {
    # Plans a file.* request: state applied|conflict, operations (file, memory view, history index) and result keys.
    $state='applied';$result=@{};$ops=@()
    $path=Resolve-SBParaPath $Dossier $Request.arguments.relativePath
    $before=Get-SBFileHash $path
    if(($Request.operation -eq 'file.save' -or $Request.expected.ContainsKey('hash')) -and $before -ine $Request.expected.hash){$state='conflict'}
    elseif($Request.arguments.relativePath -eq 'decisions.json' -and !(Test-SBPendingDecisionContent $Request)){
        # A decision file that breaks the contract is terminal: never applied, discardable with -DiscardPending.
        return @{state='invalid';errorCode=$script:SBPendingDecisionError;result=@{};ops=@()}
    }
    else{
        $text=[string]$Request.arguments.content
        if($Request.operation -eq 'file.append' -and $before -ne 'absent'){$text=(Read-SBText $path)+$text}
        $ops+=@{path=$path;expected=$before;bytes=[Text.Encoding]::UTF8.GetBytes($text)}
        if($Request.arguments.relativePath -eq 'memory.md'){
            $view=Join-Path $Dossier 'memory.agent.md'
            $ops+=@{path=$view;expected=(Get-SBFileHash $view);bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBAgentMemoryView $text))}
        }
        if($Request.arguments.relativePath -like 'history/*'){
            [IO.Directory]::CreateDirectory((Split-Path $path))|Out-Null
            $historyIndex=Join-Path $Dossier 'history/index.md'
            $ops+=@{path=$historyIndex;expected=(Get-SBFileHash $historyIndex);bytes=[Text.Encoding]::UTF8.GetBytes((Get-SBDossierHistoryIndex $Dossier))}
        }
        $result.relativePath=$Request.arguments.relativePath
    }
    @{state=$state;errorCode=$null;result=$result;ops=$ops}
}

function New-SBPendingReceiptOperation($Entry,$Request,[string]$State,$Result,$ErrorCode,$Config) {
    $repository=if($Request -and $Request.ContainsKey('repository')){$Request.repository}else{$null}
    $receipt=@{schemaVersion=1;id=$Entry.id;repository=$repository;state=$State;requestHash=$(if($Request -and $Request.ContainsKey('sha256')){$Request.sha256}else{Get-SBFileHash $Entry.path});sourceHash=(Get-SBFileHash $Entry.path);observedAt=(Get-SBNow).ToString('o');result=$Result;error=$ErrorCode;appliedBy=@{workstationId=$Config.workstationId;computer=[Environment]::MachineName}}
    @{path=$Entry.receiptPath;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $receipt))}
}

function Invoke-SBPendingWrites {
    [CmdletBinding()]
    param([string]$BrainRoot,$Config,[string]$ConfigPath,[string]$SessionId,[ValidateRange(1,100)][int]$Limit=10,[hashtable]$Diagnostics,[string]$RequestId,[ValidateRange(0,600000)][int]$WaitMs=0,[string]$Repository)
    # -Repository (#473): only the requests of that dossier are scanned, reported and integrated; without it the whole queue (workstation maintenance).
    $clock=if($null -ne $Diagnostics){[Diagnostics.Stopwatch]::StartNew()}else{$null}
    if($clock){$Diagnostics.lockAttemptMs=0.0;$Diagnostics.lockAttempts=0}
    try {
    if($RequestId -and $RequestId -cnotmatch '^[a-f0-9]{32}$'){throw (New-SBError 'pending.invalid' @('request ID'))}
    $summary=@{state='idle';applied=@();conflicts=@();errors=@();pending=0}
    try{$entries=@(Get-SBPendingWrites $BrainRoot)}catch{$summary.state='unavailable';$summary.errors+=@{code='pending.scan.failed';message=$_.Exception.Message};return $summary}
    finally{if($clock){$Diagnostics.scanMs=$clock.Elapsed.TotalMilliseconds}}
    if($RequestId){$entries=@($entries|Where-Object id -ceq $RequestId)}
    if($Repository){$entries=@($entries|Where-Object {$_.repository -ceq $Repository})}
    $todo=@($entries|Where-Object state -eq 'deferred'|Sort-Object createdAt,id)
    $summary.conflicts=@($entries|Where-Object state -in @('conflict','invalid','invalid-receipt')|ForEach-Object {@{id=$_.id;repository=$_.repository;state=$_.state;path=$_.path}})
    $summary.pending=$todo.Count
    if($clock){$Diagnostics.queueDepth=$entries.Count;$Diagnostics.deferredCount=$todo.Count}
    if(!$todo.Count){return $summary}
    $Config=Resolve-SBPendingDrainConfig $summary $BrainRoot $Config $ConfigPath
    if(!$Config){return $summary}
    if(Test-SBPendingRecoveryGate $summary $BrainRoot $Config){return $summary}
    foreach($entry in @($todo|Select-Object -First $Limit)){
        $scope=$null;$sourceLease=$null
        try{
            if($clock){$lockStart=$clock.Elapsed.TotalMilliseconds;$Diagnostics.lockAttempts++}
            # Startup flushes never wait (WaitMs 0); submissions and -FlushPending wait a bounded time so concurrent tasks do not leave requests deferred.
            try{$scope=Enter-SBOperation $Config -SessionId $SessionId -WaitMs $WaitMs}
            finally{if($clock){$Diagnostics.lockAttemptMs+=$clock.Elapsed.TotalMilliseconds-$lockStart}}
            # Another importer may have completed this request while we acquired the lock.
            if(Test-Path -LiteralPath $entry.receiptPath){$summary.pending--;continue}
            Assert-SBPlainPath $entry.path
            $sourceLease=[IO.FileStream]::new($entry.path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
            $request=$null;$state='applied';$result=@{};$errorCode=$null;$targetResolved=$false
            try{
                $file=Get-Item -LiteralPath $entry.path
                if($file.Length -gt 2MB){throw (New-SBError 'pending.invalid' @('size'))}
                $request=Read-SBJson $entry.path $null
                Assert-SBPendingRequest $request $entry.id
                if($request.operation -in @('task.status','task.update')){$targetResolved=$true}
                $dossier=Resolve-SBPendingDossier $BrainRoot $request.repository
                $targetResolved=$true
                $plan=if($request.operation -like 'task.*'){Get-SBPendingTaskPlan $BrainRoot $request $dossier}else{Get-SBPendingFilePlan $request $dossier}
                $state=$plan.state;$errorCode=$plan.errorCode;$result=$plan.result;$ops=@($plan.ops)
                if($state -eq 'conflict'){$errorCode='pending.conflict'}
            }catch [IO.IOException]{throw}
            catch{
                if(Test-SBWriteDeniedError $_){throw}
                if($targetResolved){throw}
                $state='invalid';$errorCode=$_.Exception.Message
            }
            [IO.Directory]::CreateDirectory((Split-Path $entry.receiptPath))|Out-Null
            $repository=if($request -and $request.ContainsKey('repository')){$request.repository}else{$null}
            $receiptOp=New-SBPendingReceiptOperation $entry $request $state $result $errorCode $Config
            if($state -eq 'applied'){
                foreach($op in $ops){[IO.Directory]::CreateDirectory((Split-Path $op.path))|Out-Null}
                # Data and receipt share the recovery journal: a replay cannot apply twice.
                [void](Invoke-SBParaTransaction -Operations @($ops+$receiptOp) -BackupRoot $Config.backupRoot -BrainRoot $BrainRoot)
                $summary.applied+=@{id=$entry.id;repository=$repository;operation=$request.operation}
            }else{
                Write-SBFile $entry.receiptPath $receiptOp.bytes 'absent' $Config.backupRoot|Out-Null
                $summary.conflicts+=@{id=$entry.id;repository=$repository;state=$state;code=$errorCode;path=$entry.path}
            }
            $summary.pending--
            $summary.state='processed'
        }catch{
            if(Test-SBBusyError $_){
                if($scope -and !$sourceLease){$summary.errors+=@{id=$entry.id;code='pending.request.in-use'};continue}
                $summary.state='busy';break
            }
            $summary.state='unavailable';$summary.errors+=@{id=$entry.id;code='pending.apply.failed';message=$_.Exception.Message}
            if(Get-SBPendingTransaction $BrainRoot){$summary.state='recovery-required';break}
        }finally{if($sourceLease){$sourceLease.Dispose()};Exit-SBOperation $scope}
    }
    $summary
    } finally {if($clock){$Diagnostics.drainMs=$clock.Elapsed.TotalMilliseconds}}
}

function Complete-SBPendingSubmission($Submission,$Config,[string]$SessionId,[hashtable]$Diagnostics,[switch]$OnlySubmission) {
    $clock=if($null -ne $Diagnostics){[Diagnostics.Stopwatch]::StartNew()}else{$null}
    try {
    $drainOptions=@{BrainRoot=$Config.brainRoot;Config=$Config;SessionId=$SessionId;Diagnostics=$Diagnostics;WaitMs=(Get-SBPendingSubmitWaitMs)}
    if($OnlySubmission){$drainOptions.RequestId=$Submission.id}
    elseif($Submission.request -and $Submission.request.repository){$drainOptions.Repository=[string]$Submission.request.repository}
    $drain=Invoke-SBPendingWrites @drainOptions
    $paths=Get-SBPendingPaths $Config.brainRoot
    $receipt=Read-SBPendingReceipt (Join-Path $paths.receipts ($Submission.id+'.json')) $Submission.path $Submission.id
    $result=@{requestId=$Submission.id;requestPath=$Submission.path;state='deferred';applied=$false;pendingWrites=$drain}
    if($receipt){
        $result.state=$receipt.state;$result.applied=($receipt.state -eq 'applied')
        foreach($key in $receipt.result.Keys){$result[$key]=$receipt.result[$key]}
        if($result.applied -and $receipt.result.ContainsKey('closureAdvice')){$result.closureAdvice=Get-SBClosureAdvice ''}
    }
    $result
    } finally {if($clock){$Diagnostics.responseMs=$clock.Elapsed.TotalMilliseconds}}
}

$script:SBTaskBatchFields=[ordered]@{taskId='TaskId';status='Status';stateReason='StateReason';priority='Priority';execution='Execution';dependsOn='DependsOn';stream='Stream';awaiting='Awaiting';decision='Decision';requires='Requires';description='Description';acceptance='Acceptance';evidence='Evidence';decisions='Decisions'}
$script:SBTaskBatchLimit=200
function Read-SBTaskBatchFile([string]$Path) {
    # #595: a JSON array of updates, or {"updates":[...]}; each item names taskId (ID or #seq) and the -UpdateTaskId fields in camelCase.
    # Evidence entries are "reference|outcome" strings or {reference,outcome} objects; decisions are {question,answer} objects.
    Assert-SBPlainPath $Path
    if((Get-Item -LiteralPath $Path).Length -gt 2MB){throw (New-SBError 'pending.invalid' @('size > 2 MiB'))}
    try{$data=ConvertFrom-Json -InputObject (Read-SBText $Path) -AsHashtable -DateKind String -NoEnumerate}catch{throw (New-SBError 'pending.batch.format')}
    if($data -is [Collections.IDictionary]){
        if($data.Count -ne 1 -or !$data.Contains('updates')){throw (New-SBError 'pending.batch.format')}
        $data=$data.updates
    }
    $list=@($data)
    if($null -eq $data -or !$list.Count){throw (New-SBError 'tracker.batch.empty')}
    if($list.Count -gt $script:SBTaskBatchLimit){throw (New-SBError 'pending.batch.size' @($script:SBTaskBatchLimit))}
    $items=@()
    for($i=0;$i -lt $list.Count;$i++){
        $entry=$list[$i]
        $label=if($entry -is [Collections.IDictionary] -and $entry.Contains('taskId')){[string]$entry.taskId}else{'?'}
        try{
            if($entry -isnot [Collections.IDictionary] -or !$entry.Contains('taskId') -or !$label){throw (New-SBError 'tracker.batch.shape')}
            $item=@{}
            foreach($key in $entry.Keys){
                $name=@($script:SBTaskBatchFields.Keys|Where-Object {$_ -ceq $key})
                if(!$name.Count){throw (New-SBError 'pending.batch.field' @($key,(@($script:SBTaskBatchFields.Keys) -join ', ')))}
                $item[$script:SBTaskBatchFields[$key]]=$entry[$key]
            }
            foreach($field in @('DependsOn','Requires','Acceptance')){if($item.ContainsKey($field)){$item[$field]=[string[]]@(@($item[$field])|ForEach-Object {[string]$_})}}
            if($item.ContainsKey('Evidence')){$item.Evidence=@(@($item.Evidence)|Where-Object {$_}|ForEach-Object {ConvertTo-SBTaskEvidence $_})}
            if($item.ContainsKey('Decisions')){$item.Decisions=@(ConvertTo-SBTaskDecisions @($item.Decisions))}
            if($item.Count -lt 2){throw (New-SBError 'tracker.update.empty')}
        }catch{throw (New-SBError 'tracker.batch.item' @(($i+1),$label,$_.Exception.Message))}
        $items+=,$item
    }
    ,$items
}
function New-SBPendingTaskBatch {
    # Prepares each batch item as a task.update request (resolved task ID, task hash, executor) without writing anything.
    [CmdletBinding()]
    param([string]$BrainRoot,[string]$Repository,[object[]]$Items=@(),$Config,[string]$SessionId)
    if(!$Items.Count){throw (New-SBError 'tracker.batch.empty')}
    if($Items.Count -gt $script:SBTaskBatchLimit){throw (New-SBError 'pending.batch.size' @($script:SBTaskBatchLimit))}
    $prepared=@()
    for($i=0;$i -lt $Items.Count;$i++){
        $item=$Items[$i]
        $label=if($item -is [Collections.IDictionary] -and $item.Contains('TaskId')){[string]$item.TaskId}else{'?'}
        try{
            if($item -isnot [Collections.IDictionary] -or !$label){throw (New-SBError 'tracker.batch.shape')}
            $arguments=@{};foreach($key in $item.Keys){if($key -cne 'Executor'){$arguments[$key]=$item[$key]}}
            if(@($arguments.Keys|Where-Object {$_ -ne 'TaskId'}).Count -lt 1){throw (New-SBError 'tracker.update.empty')}
            $prepared+=,(New-SBPendingWrite -BrainRoot $BrainRoot -Repository $Repository -Operation task.update -Arguments $arguments -Config $Config -SessionId $SessionId -PrepareOnly -NoCandidateCheck)
        }catch{throw (New-SBError 'tracker.batch.item' @(($i+1),$label,$_.Exception.Message))}
    }
    ,$prepared
}
function Invoke-SBPendingTaskBatch {
    # #595: N task updates from one process. Each item is prepared like -UpdateTaskId (request with task hash and executor), then all of them
    # are applied under one writer lock in one transaction: tracker, archive, ledger, the N request files and their N receipts.
    # Any refused item (validation, task hash conflict, duplicate) throws tracker.batch.item naming it, and nothing is written.
    # -Prepared takes the output of New-SBPendingTaskBatch (prepared earlier, without lock); otherwise -Items are prepared here.
    [CmdletBinding()]
    param([string]$BrainRoot,[string]$Repository,[object[]]$Items,[object[]]$Prepared,$Config,[string]$SessionId,[ValidateRange(0,600000)][int]$WaitMs=0)
    $prepared=if($PSBoundParameters.ContainsKey('Prepared')){@($Prepared)}else{@(New-SBPendingTaskBatch -BrainRoot $BrainRoot -Repository $Repository -Items @($Items) -Config $Config -SessionId $SessionId)}
    if(!$prepared.Count){throw (New-SBError 'tracker.batch.empty')}
    $scope=Enter-SBOperation $Config -SessionId $SessionId -WaitMs $WaitMs
    try{
        if(Get-SBPendingTransaction $BrainRoot){throw (New-SBError 'pending.batch.recovery')}
        $dossier=Resolve-SBPendingDossier $BrainRoot $Repository
        $tracker=Read-SBPendingTracker $BrainRoot $Repository $dossier
        $archiveTasks=@((Read-SBTrackerArchive $tracker.path $Repository).data.tasks)
        $paths=Get-SBPendingPaths $BrainRoot
        $requestOps=@();$entries=@()
        for($i=0;$i -lt $prepared.Count;$i++){
            $request=$prepared[$i].request
            $taskId=[string]$request.arguments.TaskId
            # Same check as a deferred update: the task must still be what it was when the request was prepared.
            $task=@($tracker.data.tasks|Where-Object id -eq $taskId)
            if(!$task.Count){$task=@($archiveTasks|Where-Object id -eq $taskId)}
            if($task.Count -ne 1 -or (Get-SBTextHash (ConvertTo-SBJson $task[0])) -ine $request.expected.taskHash){
                throw (New-SBError 'tracker.batch.item' @(($i+1),$taskId,(Get-SBMessage 'pending.conflict')))
            }
            $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $request))
            $queue=if($request.operation -eq 'task.update'){$paths.taskUpdates}else{$paths.queue}
            Assert-SBPlainPath $queue
            $path=Join-Path $queue ($request.id+'.json')
            $requestOps+=@{path=$path;expected='absent';bytes=$bytes}
            $entries+=,@{id=$request.id;path=$path;receiptPath=(Join-Path $paths.receipts ($request.id+'.json'));request=$request;sourceHash=(Get-SBHash $bytes)}
        }
        Assert-SBPlainPath $paths.receipts
        $batchItems=@($prepared|ForEach-Object {@{}+$_.request.arguments})
        $plan=Invoke-SBTrackerTaskBatch -BrainRoot $BrainRoot -Identity $Repository -WorkingRepository $Repository -Items $batchItems -ExpectedHash $tracker.hash -BackupRoot $Config.backupRoot -WhatIf
        $receiptOps=@();$items=@();$observedAt=(Get-SBNow).ToString('o')
        for($i=0;$i -lt $entries.Count;$i++){
            $entry=$entries[$i];$planned=$plan.items[$i]
            $result=@{};foreach($key in @('taskId','status','closureAdvice')){if($planned.ContainsKey($key)){$result[$key]=$planned[$key]}}
            $receipt=@{schemaVersion=1;id=$entry.id;repository=$Repository;state='applied';requestHash=$entry.request.sha256;sourceHash=$entry.sourceHash;observedAt=$observedAt;result=$result;error=$null;appliedBy=@{workstationId=$Config.workstationId;computer=[Environment]::MachineName};batch=@{index=($i+1);size=$entries.Count}}
            $receiptOps+=@{path=$entry.receiptPath;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $receipt))}
            $view=@{index=($i+1);requestId=$entry.id;requestPath=$entry.path;operation=$entry.request.operation}+$result
            $items+=,$view
        }
        $ops=@($plan.operations)+$requestOps+$receiptOps
        foreach($op in $ops){[IO.Directory]::CreateDirectory((Split-Path $op.path))|Out-Null}
        # Tracker, archive, ledger, requests and receipts share one recovery journal: a replay cannot apply part of the batch.
        [void](Invoke-SBParaTransaction -Operations $ops -BackupRoot $Config.backupRoot -BrainRoot $BrainRoot)
        $summary=@{repository=$Repository;state='applied';applied=$true;count=$items.Count;trackerHashBefore=$tracker.hash;trackerHash=(Get-SBFileHash $tracker.path);items=$items}
        if(@($items|Where-Object {$_.ContainsKey('closureAdvice')}).Count){$summary.closureAdvice=Get-SBClosureAdvice $dossier}
        $summary
    }finally{Exit-SBOperation $scope}
}

function Move-SBPendingConflict {
    # Retires a conflicting or invalid request: request and receipt move to access/pending-discarded/<id>/ with a note;
    # evidence is preserved, never deleted, and deferred or applied requests are refused.
    param([string]$BrainRoot,[string]$Id)
    if($Id -cnotmatch '^[a-f0-9]{32}$'){throw (New-SBError 'pending.invalid' @('request ID'))}
    $entry=@(Get-SBPendingWrites $BrainRoot|Where-Object id -ceq $Id)
    if($entry.Count -ne 1){throw (New-SBError 'pending.discard.notfound')}
    $entry=$entry[0]
    if($entry.state -notin @('conflict','invalid','invalid-receipt')){throw (New-SBError 'pending.discard.state' @($entry.state))}
    Assert-SBWriteGuard
    $paths=Get-SBPendingPaths $BrainRoot
    $target=Join-Path (Split-Path $paths.queue) ('pending-discarded/'+$Id)
    Assert-SBPlainPath $target
    [IO.Directory]::CreateDirectory($target)|Out-Null
    $requestHash=Get-SBFileHash $entry.path
    $note=@{schemaVersion=1;id=$Id;state=$entry.state;repository=$entry.repository;requestHash=$requestHash;discardedAt=(Get-SBNow).ToString('o')}
    [IO.File]::WriteAllText((Join-Path $target 'discarded.json'),(ConvertTo-SBJson $note),[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $entry.path -Destination (Join-Path $target ($Id+'.json'))
    if(Test-Path -LiteralPath $entry.receiptPath){Move-Item -LiteralPath $entry.receiptPath -Destination (Join-Path $target ($Id+'.receipt.json'))}
    @{id=$Id;state='discarded';previousState=$entry.state;archive=$target;requestHash=$requestHash}
}

function Format-SBPendingNotice($Summary) {
    Get-SBMessage 'pending.notice' @($Summary.applied.Count,$Summary.conflicts.Count,$Summary.pending,$Summary.state)
}
Export-ModuleMember -Function @('New-SBPendingWrite','Get-SBPendingWrites','Invoke-SBPendingWrites','Complete-SBPendingSubmission','Format-SBPendingNotice','Get-SBPendingContentHash','Move-SBPendingConflict','Read-SBTaskBatchFile','New-SBPendingTaskBatch','Invoke-SBPendingTaskBatch')
