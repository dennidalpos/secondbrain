#requires -Version 7.5
# Fixtures for categorized, incremental knowledge search (#344 / F7). Synthetic data only.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:kiChecks=0
function Assert-Ki($Condition,[string]$Message){if(!$Condition){throw ('FAIL KNOWLEDGE INDEX: '+$Message)};$script:kiChecks++}
$root=Join-Path (Get-SBTestRoot) ('kindex-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $root 'brain';$dossier=Join-Path $brain '02-areas/one';$repo='github.com/acme/one'
foreach($folder in @($dossier,(Join-Path $dossier 'topics/normative'),(Join-Path $dossier 'topics/policy'),(Join-Path $dossier 'history/batch-1'),(Join-Path $brain 'direttive/prompts'))){[void][IO.Directory]::CreateDirectory($folder)}
function Put([string]$rel,[string]$text){[IO.File]::WriteAllText((Join-Path $brain $rel),$text)}
Put '02-areas/one/para.json' (ConvertTo-SBJson @{schemaVersion=1;id='area-one';kind='area';title='one';status='active'})
Put '02-areas/one/repository.json' (ConvertTo-SBJson @{schemaVersion=1;identity=$repo})
Put '02-areas/one/brief.md' '# one'
Put '02-areas/one/context.md' "# Contesto`n## Stato corrente`nalpha context line`n"
Put '02-areas/one/memory.md' "# Memoria`n## Decisioni`n- alpha memory decision 1`n- alpha memory decision 2`n"
Put '02-areas/one/tracker.json' (ConvertTo-SBJson @{schemaVersion=1;repository=$repo;tasks=@(@{id='T1';title='alpha task'})})
Put '02-areas/one/topics/normative/law.md' "# Law`nalpha normative text`n"
Put '02-areas/one/topics/policy/rule.md' "# Rule`nalpha policy text`n"
Put '02-areas/one/topics/loose.md' "# Loose`nalpha uncategorized note`n"
Put '02-areas/one/history/batch-1/report.md' "# Report`nalpha report line`n"
Put 'direttive/prompts/P01.md' "# P01`nalpha prompt card`n"
Put 'direttive/prompts/README.md' "# Index`nalpha index must not be searched`n"
function Find([string[]]$Category=@(),[string]$Previous='',[int]$Offset=0,[int]$Limit=0){
    Find-SBKnowledge -BrainRoot $brain -Search 'alpha' -Repository $repo -Budget 0 -Limit $Limit -Offset $Offset -Category $Category -PreviousRevision $Previous
}
$all=Find
$byCat=@{};foreach($e in $all.extracts){$byCat[$e.category]=1+[int]$byCat[$e.category]}
Assert-Ki ($byCat['memoria'] -eq 2 -and $byCat['normative'] -eq 1 -and $byCat['policy'] -eq 1 -and $byCat['informazioni'] -eq 4 -and !$byCat.ContainsKey('prompt')) 'default search labels every extract by category and leaves prompts out'
foreach($pair in @(@('memoria',2),@('normative',1),@('policy',1),@('informazioni',4))){
    $r=Find @($pair[0])
    Assert-Ki ($r.count -eq $pair[1] -and @($r.extracts|Where-Object category -ne $pair[0]).Count -eq 0) ('category filter '+$pair[0])
}
$two=Find @('memoria','policy')
Assert-Ki ($two.count -eq 3) 'several categories combine'
$prompt=Find @('prompt')
Assert-Ki ($prompt.count -eq 1 -and $prompt.extracts[0].path -ceq 'direttive/prompts/P01.md' -and $prompt.extracts[0].category -ceq 'prompt') 'prompt category searches the cards only when requested (README excluded)'
Assert-Ki ((Find @('prompt','memoria')).count -eq 3) 'prompt category combines with dossier categories'
# Pagination: pages are disjoint and cover the whole result set.
$seen=@();$offset=0
do{$page=Find @() '' $offset 3;$seen+=@($page.extracts|ForEach-Object {$_.path+':'+$_.line});$offset=$page.nextOffset}while($page.hasMore)
Assert-Ki ($seen.Count -eq $all.count -and @($seen|Sort-Object -Unique).Count -eq $seen.Count) 'pagination returns each match once'
# PreviousRevision: nothing repeated while nothing searched changed.
Assert-Ki ($all.revision -match '^[a-f0-9]{64}$' -and !$all.unchanged) 'search returns a revision'
$same=Find @() $all.revision
Assert-Ki ($same.unchanged -and $same.count -eq 0 -and $same.extracts.Count -eq 0 -and $same.revision -ceq $all.revision -and $same.characters -eq 0) 'identical revision returns no repeated extracts'
Assert-Ki (!(Find @() $all.revision 3 3).unchanged) 'PreviousRevision is ignored on later pages'
Assert-Ki (!(Find @() ('0'*64)).unchanged -and (Find @() ('0'*64)).count -eq $all.count) 'unknown revision returns the full result'
Assert-Ki ((Find @('memoria')).revision -cne $all.revision) 'revision depends on categories'
Assert-Ki ((Find @('memoria') $all.revision).count -eq 2) 'revision of another scope does not suppress results'
Put '02-areas/one/topics/policy/rule.md' "# Rule`nalpha policy text changed`n"
$changed=Find @() $all.revision
Assert-Ki (!$changed.unchanged -and $changed.count -eq $all.count -and $changed.revision -cne $all.revision) 'a changed searched file invalidates the revision'
Assert-Ki ((Find @('memoria') (Find @('memoria')).revision).unchanged -and !(Find @('policy') $all.revision).unchanged) 'unchanged files keep their category revision stable'
# Measurement of the incremental/category effect on synthetic data.
$full=($all|ConvertTo-Json -Depth 8 -Compress).Length;$restricted=((Find @('memoria'))|ConvertTo-Json -Depth 8 -Compress).Length;$unchangedSize=((Find @() $changed.revision)|ConvertTo-Json -Depth 8 -Compress).Length
Assert-Ki ($restricted -lt $full -and $unchangedSize -lt $restricted) 'category and unchanged answers are smaller than the full result'
'SUCCESS KNOWLEDGE INDEX: '+$script:kiChecks+' checks; full='+$full+' chars, memoria='+$restricted+' chars, unchanged='+$unchangedSize+' chars; retained fixture '+$root
