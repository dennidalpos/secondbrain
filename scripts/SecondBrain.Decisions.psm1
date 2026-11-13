#requires -Version 7.5
# User decision records (asset contracts section 5, #588): dossier decisions.json, contract in config/decision.schema.json.
# Only the user answers: a recommendation, a default, a timeout, a delegate or text from observed content is never an answer,
# and there is no expiry. Writes go through decisions.ps1, which queues one file.save with the expected hash (journal, backup, receipt).
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'decision.invalid' = @{it='Decisione non valida: {0}';en='Invalid decision record: {0}'}
    'decision.notfound' = @{it='Nessuna decisione con ID {0} in questo dossier';en='No decision with ID {0} in this dossier'}
    'decision.state' = @{it='La decisione {0} e {1}: solo una decisione aperta si puo rispondere o ritirare';en='Decision {0} is {1}: only an open decision can be answered or withdrawn'}
    'decision.answer.required' = @{it='La risposta richiede esattamente uno fra -Option e -Text, dato dalla persona';en='An answer needs exactly one of -Option or -Text, given by the user'}
    'decision.answer.option' = @{it='L opzione {0} non e fra le opzioni della decisione {1}';en='Option {0} is not one of the options of decision {1}'}
    'decision.lesson.required' = @{it=('Una decisione durevole richiede -Lesson nella forma "Decision: ... '+[char]0x2014+' Reason: ..." per memory.md');en=('A durable decision needs -Lesson in the form "Decision: ... '+[char]0x2014+' Reason: ..." for memory.md')}
    'decision.supersedes' = @{it='La decisione {0} puo sostituire solo una decisione durevole con risposta di questo dossier';en='Decision {0} can only supersede an answered durable decision of this dossier'}
    'decision.link.invalid' = @{it='Collegamento del task alla decisione {0} non valido: {1}';en='Task link to decision {0} is not valid: {1}'}
}

$script:SBDecisionKinds=@('choice','confirm','approval')
$script:SBDecisionScopes=@('step','task','durable')
$script:SBDecisionStates=@('open','answered','withdrawn')
$script:SBDecisionThrough=@('structured-tool','text-fallback')

function Get-SBDecisionPath([string]$Dossier) { Join-Path $Dossier 'decisions.json' }

function Read-SBDecisions([string]$Dossier,[string]$Repository) {
    # Missing file: an empty record set for this repository. A present file must be valid.
    $path=Get-SBDecisionPath $Dossier
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){return @{data=[ordered]@{schemaVersion=1;repository=$Repository;decisions=@()};hash='absent';path=$path}}
    $data=Read-SBJson $path $null
    Assert-SBDecisionData $data $Repository
    @{data=$data;hash=(Get-SBFileHash $path);path=$path}
}

function Test-SBIsoTime($Value) {
    # ConvertFrom-Json turns ISO 8601 text into DateTime: both forms are a valid timestamp.
    if($Value -is [DateTime] -or $Value -is [DateTimeOffset]){return $true}
    if($Value -isnot [string] -or !$Value){return $false}
    $parsed=[DateTimeOffset]::MinValue
    [DateTimeOffset]::TryParse($Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)
}

function Assert-SBDecisionRecord($Record) {
    # One record; throws decision.invalid naming the first rule broken.
    $fail={param($why) throw (New-SBError 'decision.invalid' @($why))}
    if($Record -isnot [Collections.IDictionary]){& $fail 'record is not an object'}
    $allowed=@('id','kind','question','options','context','asked','answer','scope','status','supersedes','withdrawn')
    $extra=@($Record.Keys|Where-Object {$_ -cnotin $allowed})
    if($extra.Count){& $fail ('unknown fields: '+($extra -join ','))}
    if([string]$Record['id'] -cnotmatch '^dec-[0-9a-f]{8}$'){& $fail 'id must be dec- plus 8 lowercase hex digits'}
    if($Record['kind'] -cnotin $script:SBDecisionKinds){& $fail ($Record.id+': kind')}
    $question=[string]$Record['question']
    if(!$question.Trim() -or $question.Length -gt 400 -or $question -match '[\r\n]'){& $fail ($Record.id+': question must be one sentence on one line')}
    $options=@($Record['options'])
    if($options.Count -lt 2 -or $options.Count -gt 4){& $fail ($Record.id+': 2 to 4 options')}
    $ids=@{};$recommended=0;$index=0
    foreach($option in $options){
        if($option -isnot [Collections.IDictionary] -or @($option.Keys|Where-Object {$_ -cnotin @('id','label','description','recommended')}).Count){& $fail ($Record.id+': option fields')}
        if([string]$option['id'] -cnotmatch '^[a-z0-9][a-z0-9-]{0,31}$' -or $ids.ContainsKey([string]$option.id)){& $fail ($Record.id+': option ids unique, lowercase')}
        if(![string]$option['label'] -or ![string]$option['description']){& $fail ($Record.id+': option label and description')}
        $ids[[string]$option.id]=$true
        if($option.Contains('recommended')){
            if($option.recommended -isnot [bool]){& $fail ($Record.id+': recommended is a boolean')}
            if($option.recommended){$recommended++;if($index -ne 0){& $fail ($Record.id+': the recommended option is listed first')}}
        }
        $index++
    }
    if($recommended -gt 1){& $fail ($Record.id+': at most one recommended option')}
    $context=$Record['context']
    if($context -isnot [Collections.IDictionary] -or @($context.Keys|Where-Object {$_ -cnotin @('taskId','workflowRun','step','assets','evidence')}).Count){& $fail ($Record.id+': context fields')}
    $asked=$Record['asked']
    if($asked -isnot [Collections.IDictionary] -or @($asked.Keys|Where-Object {$_ -cnotin @('at','through','by')}).Count -or !(Test-SBIsoTime $asked['at']) -or $asked['through'] -cnotin $script:SBDecisionThrough -or ![string]$asked['by']){& $fail ($Record.id+': asked needs at, through (structured-tool|text-fallback) and by')}
    if($Record['scope'] -cnotin $script:SBDecisionScopes){& $fail ($Record.id+': scope')}
    if($Record['scope'] -ceq 'step'){& $fail ($Record.id+': step decisions live in the workflow run state, not in decisions.json')}
    $status=$Record['status']
    if($status -cnotin $script:SBDecisionStates){& $fail ($Record.id+': status open, answered or withdrawn')}
    $answer=if($Record.Contains('answer')){$Record.answer}else{$null}
    if($status -eq 'answered'){
        if($answer -isnot [Collections.IDictionary] -or @($answer.Keys|Where-Object {$_ -cnotin @('optionId','text','by','at')}).Count){& $fail ($Record.id+': answer fields')}
        $hasOption=$answer.Contains('optionId') -and [string]$answer.optionId
        $hasText=$answer.Contains('text') -and ([string]$answer.text).Trim()
        if($hasOption -eq $hasText){& $fail ($Record.id+': answer has exactly one of optionId or text')}
        if($hasOption -and !$ids.ContainsKey([string]$answer.optionId)){& $fail ($Record.id+': answer option is not listed')}
        # Only the user answers (#588): any other author, including a timeout or a recommendation, is refused.
        if($answer['by'] -cne 'user'){& $fail ($Record.id+': only the user answers (answer.by = user)')}
        if(!(Test-SBIsoTime $answer['at'])){& $fail ($Record.id+': answer.at')}
    }elseif($null -ne $answer){& $fail ($Record.id+': only an answered decision has an answer')}
    $withdrawn=if($Record.Contains('withdrawn')){$Record.withdrawn}else{$null}
    if($status -eq 'withdrawn'){
        if($withdrawn -isnot [Collections.IDictionary] -or !(Test-SBIsoTime $withdrawn['at']) -or ![string]$withdrawn['reason'] -or @($withdrawn.Keys|Where-Object {$_ -cnotin @('at','reason')}).Count){& $fail ($Record.id+': withdrawn needs at and reason')}
    }elseif($null -ne $withdrawn){& $fail ($Record.id+': only a withdrawn decision has withdrawn')}
    if($Record.Contains('supersedes') -and $null -ne $Record.supersedes -and [string]$Record.supersedes -cnotmatch '^dec-[0-9a-f]{8}$'){& $fail ($Record.id+': supersedes')}
}

function Assert-SBDecisionData($Data,[string]$Repository) {
    if($Data -isnot [Collections.IDictionary] -or $Data['schemaVersion'] -ne 1 -or @($Data.Keys|Where-Object {$_ -cnotin @('schemaVersion','repository','decisions')}).Count){throw (New-SBError 'decision.invalid' @('decisions.json root'))}
    if($Repository -and $Data['repository'] -cne $Repository){throw (New-SBError 'decision.invalid' @('repository'))}
    $seen=@{}
    foreach($record in @($Data['decisions'])){
        if($null -eq $record){continue}
        Assert-SBDecisionRecord $record
        if($seen.ContainsKey($record.id)){throw (New-SBError 'decision.invalid' @('duplicate id '+$record.id))}
        $seen[$record.id]=$record
    }
    foreach($record in $seen.Values){
        if($record.Contains('supersedes') -and $record.supersedes){
            $old=$seen[[string]$record.supersedes]
            if(!$old -or $old.scope -ne 'durable' -or $old.status -ne 'answered' -or $record.scope -ne 'durable'){throw (New-SBError 'decision.supersedes' @($record.supersedes))}
        }
    }
}

function Find-SBDecision($Data,[string]$Id) {
    $match=@(@($Data.decisions)|Where-Object {$_ -and $_.id -ceq $Id})
    if($match.Count -ne 1){throw (New-SBError 'decision.notfound' @($Id))}
    $match[0]
}

function New-SBDecisionId($Data) {
    do{$id='dec-'+(New-SBId).Substring(0,8)}while(@(@($Data.decisions)|Where-Object {$_ -and $_.id -ceq $id}).Count)
    $id
}

function New-SBDecisionRecord {
    # Opens a decision. A recommended option is only a flag: the record stays open until the user answers.
    param($Data,[ValidateSet('choice','confirm','approval')][string]$Kind,[string]$Question,$Options,[ValidateSet('task','durable')][string]$Scope,
        [ValidateSet('structured-tool','text-fallback')][string]$Through,[string]$AskedBy,[string]$TaskId,[string[]]$Evidence=@(),[string]$Supersedes)
    $context=[ordered]@{}
    if($TaskId){$context.taskId=$TaskId}
    if(@($Evidence|Where-Object {$_}).Count){$context.evidence=@($Evidence|Where-Object {$_})}
    $record=[ordered]@{id=(New-SBDecisionId $Data);kind=$Kind;question=$Question.Trim();options=@($Options);context=$context
        asked=[ordered]@{at=(Get-SBNow).ToString('o');through=$Through;by=$AskedBy};scope=$Scope;status='open'}
    if($Supersedes){$record.supersedes=$Supersedes}
    $next=[ordered]@{schemaVersion=1;repository=$Data.repository;decisions=@(@($Data.decisions|Where-Object {$_})+@($record))}
    Assert-SBDecisionData $next $Data.repository
    @{data=$next;record=$record}
}

function Set-SBDecisionAnswer {
    # Records the user's answer: exactly one option ID or free text. There is no default and no timeout path.
    param($Data,[string]$Id,[string]$Option,[string]$Text)
    $record=Find-SBDecision $Data $Id
    if($record.status -ne 'open'){throw (New-SBError 'decision.state' @($Id,$record.status))}
    $hasOption=[bool]$Option;$hasText=[bool]([string]$Text).Trim()
    if($hasOption -eq $hasText){throw (New-SBError 'decision.answer.required')}
    if($hasOption -and !@(@($record.options)|Where-Object {$_.id -ceq $Option}).Count){throw (New-SBError 'decision.answer.option' @($Option,$Id))}
    $answer=[ordered]@{by='user';at=(Get-SBNow).ToString('o')}
    if($hasOption){$answer.optionId=$Option}else{$answer.text=$Text.Trim()}
    $record.status='answered';$record.answer=$answer
    Assert-SBDecisionData $Data $Data.repository
    @{data=$Data;record=$record}
}

function Set-SBDecisionWithdrawn {
    param($Data,[string]$Id,[string]$Reason)
    $record=Find-SBDecision $Data $Id
    if($record.status -ne 'open'){throw (New-SBError 'decision.state' @($Id,$record.status))}
    $record.status='withdrawn';$record.withdrawn=[ordered]@{at=(Get-SBNow).ToString('o');reason=$Reason.Trim()}
    Assert-SBDecisionData $Data $Data.repository
    @{data=$Data;record=$record}
}

function Get-SBDecisionList {
    param($Data,[string]$Status,[string]$TaskId,[string]$Id)
    @(@($Data.decisions)|Where-Object {$_ -and (!$Status -or $_.status -eq $Status) -and (!$Id -or $_.id -ceq $Id) -and (!$TaskId -or ($_.context.Contains('taskId') -and $_.context.taskId -eq $TaskId))})
}

function Assert-SBDecisionLink([string]$Dossier,[string]$Repository,[string]$DecisionId,[string]$TaskId,[string]$Awaiting) {
    # A task that waits on a decision (extensions.decision) points at an open task or durable decision of its own dossier,
    # with awaiting=owner-consent; a decision tied to another task is refused.
    if($DecisionId -cnotmatch '^dec-[0-9a-f]{8}$'){throw (New-SBError 'decision.link.invalid' @($DecisionId,'not a dec- ID'))}
    if($Awaiting -cne 'owner-consent'){throw (New-SBError 'decision.link.invalid' @($DecisionId,'the task must have awaiting=owner-consent'))}
    $set=Read-SBDecisions $Dossier $Repository
    $record=$null;try{$record=Find-SBDecision $set.data $DecisionId}catch{throw (New-SBError 'decision.link.invalid' @($DecisionId,'not found in decisions.json'))}
    if($record.status -ne 'open'){throw (New-SBError 'decision.link.invalid' @($DecisionId,'the decision is '+$record.status))}
    if($record.context.Contains('taskId') -and $record.context.taskId -and $record.context.taskId -cne $TaskId){throw (New-SBError 'decision.link.invalid' @($DecisionId,'it belongs to '+$record.context.taskId))}
}

function Test-SBDecisionLesson([string]$Lesson) {
    # "Decision: ... <em dash U+2014> Reason: ...", the memory line format of the common directives.
    $Lesson -cmatch ('^Decision: .+ '+[char]0x2014+' Reason: .+$') -and $Lesson -notmatch '[\r\n]'
}

Export-ModuleMember -Function @('Get-SBDecisionPath','Read-SBDecisions','Assert-SBDecisionData','Assert-SBDecisionRecord','Find-SBDecision','New-SBDecisionRecord','Set-SBDecisionAnswer','Set-SBDecisionWithdrawn','Get-SBDecisionList','Assert-SBDecisionLink','Test-SBDecisionLesson')
