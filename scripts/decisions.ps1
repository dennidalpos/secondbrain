#requires -Version 7.5
<#
.SYNOPSIS
User decision records of the working repository's dossier (decisions.json, asset contracts section 5).
.DESCRIPTION
-List (default) reads; -Open, -Answer and -Withdraw write. Every write validates the whole file against the contract
(config/decision.schema.json, rules in SecondBrain.Decisions.psm1) and is queued as one file.save with the expected hash,
so it is journaled, backed up and never overwrites a newer file. -WhatIf prints the plan and the new content hash without queuing.
Only the user answers: -Answer takes exactly one -Option or -Text and records answer.by=user. There is no default, no
recommendation-as-answer and no timeout: an unanswered decision stays open. A durable answer also needs -Lesson
("Decision: ... <em dash> Reason: ..."), appended to memory.md with the decision ID.
.EXAMPLE
pwsh -NoProfile -File scripts/decisions.ps1 -Open -Kind choice -Question "Which lock key?" -OptionsJson '[{"id":"dossier","label":"Per dossier","description":"...","recommended":true},{"id":"global","label":"Global","description":"..."}]' -Scope task -TaskId TASK-476 -Through structured-tool
.EXAMPLE
pwsh -NoProfile -File scripts/decisions.ps1 -Answer dec-0a1b2c3d -Option dossier
#>
[CmdletBinding(DefaultParameterSetName='List')]
param(
    [Parameter(ParameterSetName='List')][switch]$List,
    [Parameter(ParameterSetName='List')][ValidateSet('open','answered','withdrawn')][string]$Status,
    [Parameter(ParameterSetName='List')][string]$Id,
    [Parameter(Mandatory,ParameterSetName='Open')][switch]$Open,
    [Parameter(Mandatory,ParameterSetName='Open')][ValidateSet('choice','confirm','approval')][string]$Kind,
    [Parameter(Mandatory,ParameterSetName='Open')][string]$Question,
    [Parameter(Mandatory,ParameterSetName='Open')][string]$OptionsJson,
    [Parameter(Mandatory,ParameterSetName='Open')][ValidateSet('task','durable')][string]$Scope,
    [Parameter(Mandatory,ParameterSetName='Open')][ValidateSet('structured-tool','text-fallback')][string]$Through,
    [Parameter(ParameterSetName='Open')][string]$AskedBy='agent',
    [Parameter(ParameterSetName='Open')][string[]]$Evidence=@(),
    [Parameter(ParameterSetName='Open')][string]$Supersedes,
    [Parameter(ParameterSetName='Open')][Parameter(ParameterSetName='List')][string]$TaskId,
    [Parameter(Mandatory,ParameterSetName='Answer')][ValidatePattern('^dec-[0-9a-f]{8}$')][string]$Answer,
    [Parameter(ParameterSetName='Answer')][string]$Option,
    [Parameter(ParameterSetName='Answer')][string]$Text,
    [Parameter(ParameterSetName='Answer')][string]$Lesson,
    [Parameter(Mandatory,ParameterSetName='Withdraw')][ValidatePattern('^dec-[0-9a-f]{8}$')][string]$Withdraw,
    [Parameter(Mandatory,ParameterSetName='Withdraw')][string]$Reason,
    [string]$CheckoutPath,[string]$ConfigPath,[string]$SessionId,[switch]$WhatIf)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; break }
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Pending.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Decisions.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1')
Add-SBMessages @{
    'decisionscli.repository' = @{it='Repository in lavoro non risolvibile: eseguire dal checkout o indicare -CheckoutPath';en='Working repository not resolvable: run from the checkout or give -CheckoutPath'}
    'decisionscli.options' = @{it='-OptionsJson deve essere un array JSON di 2-4 oggetti {id,label,description,recommended?}';en='-OptionsJson must be a JSON array of 2 to 4 {id,label,description,recommended?} objects'}
}
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$lock=$null
$write=$PSCmdlet.ParameterSetName -ne 'List'
try{
    # Writes are queued (like knowledge.ps1 buffered writes), so the session itself only reads.
    $config=Read-SBConfiguration $ConfigPath -ReadOnly;$lock=Enter-SBOperation $config $SessionId -ReadOnly
    $working=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
    if(!$working){throw (New-SBError 'decisionscli.repository')}
    Assert-SBRunnerReadScope -Repository $working -Write:$write
    $dossier=Join-Path $brain (Resolve-SBWorkingDossier $brain $working)
    $set=Read-SBDecisions $dossier $working
    if(!$write){
        $items=Get-SBDecisionList $set.data -Status $Status -TaskId $TaskId -Id $Id
        ConvertTo-SBJson ([ordered]@{repository=$working;hash=$set.hash;decisions=@($items)})
        exit 0
    }
    $memoryLine=$null
    switch($PSCmdlet.ParameterSetName){
        'Open' {
            $options=$null
            try{$options=@($OptionsJson|ConvertFrom-Json -AsHashtable)}catch{throw (New-SBError 'decisionscli.options')}
            if($options.Count -eq 1 -and $options[0] -is [Collections.IList]){$options=@($options[0])}
            $change=New-SBDecisionRecord -Data $set.data -Kind $Kind -Question $Question -Options $options -Scope $Scope -Through $Through -AskedBy $AskedBy -TaskId $TaskId -Evidence $Evidence -Supersedes $Supersedes
        }
        'Answer' {
            $record=Find-SBDecision $set.data $Answer
            if($record.scope -eq 'durable'){
                if(!(Test-SBDecisionLesson $Lesson)){throw (New-SBError 'decision.lesson.required')}
                $memoryLine='- '+$Lesson.Trim()+' ('+$Answer+')'+"`n"
            }
            $change=Set-SBDecisionAnswer -Data $set.data -Id $Answer -Option $Option -Text $Text
        }
        'Withdraw' {$change=Set-SBDecisionWithdrawn -Data $set.data -Id $Withdraw -Reason $Reason}
    }
    $content=ConvertTo-SBJson $change.data
    $plan=[ordered]@{repository=$working;operation='file.save';relativePath='decisions.json';expectedHash=$set.hash;contentHash=(Get-SBTextHash $content);record=$change.record}
    if($memoryLine){$plan.memoryAppend=$memoryLine.TrimEnd()}
    if($WhatIf){$plan.preview=$true;ConvertTo-SBJson $plan;exit 0}
    $submission=New-SBPendingWrite -BrainRoot $brain -Repository $working -Operation file.save -Arguments @{relativePath='decisions.json';content=$content} -Expected @{hash=$set.hash} -Config $config -SessionId $SessionId
    $result=Complete-SBPendingSubmission $submission $config $SessionId
    $output=[ordered]@{repository=$working;decision=$change.record;requestId=$result.requestId;state=$result.state;applied=$result.applied}
    if($memoryLine -and $result.applied){
        $memory=New-SBPendingWrite -BrainRoot $brain -Repository $working -Operation file.append -Arguments @{relativePath='memory.md';content=$memoryLine} -Config $config -SessionId $SessionId
        $memoryResult=Complete-SBPendingSubmission $memory $config $SessionId
        $output.memory=[ordered]@{requestId=$memoryResult.requestId;state=$memoryResult.state;applied=$memoryResult.applied}
    }
    ConvertTo-SBJson $output
    # Same exit contract as knowledge.ps1: 0 applied, 5 accepted but not applied yet (deferred or conflict).
    if(!$result.applied){exit 5}
    exit 0
}catch{
    if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }
    if(Test-SBBusyError $_){Write-Output $_.Exception.Message;exit 3}
    Write-Error $_ -ErrorAction Continue;exit 2
}finally{Exit-SBOperation $lock}
