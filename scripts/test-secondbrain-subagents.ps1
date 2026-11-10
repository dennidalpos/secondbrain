#requires -Version 7.5
# Behavioral fixtures for subagent definitions (F8). Synthetic data only; no real dossier is touched.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Subagents.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Activity.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:subChecks=0
function Assert-Sub($Condition,[string]$Message){if(!$Condition){throw ('FAIL SUBAGENTS: '+$Message)};$script:subChecks++}
function Reject-Sub([scriptblock]$Action,[string]$Message){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Assert-Sub $rejected $Message}
$root=Join-Path (Get-SBTestRoot) ('subagents-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $root 'brain';$dossier=Join-Path $brain '02-areas/one';$backups=Join-Path $brain '.runtime/backups';$out=Join-Path $brain '.runtime/export'
[void][IO.Directory]::CreateDirectory($dossier)
$repo='github.com/acme/one'
function New-Def([string]$name,[string[]]$tools=@('get_task','search_knowledge'),[bool]$write=$false){
    [ordered]@{schemaVersion=1;name=$name;description='Reads tasks and searches knowledge.';role='You are a read-only reviewer.';context='Start from the tracker task; cite sources.';permissions=[ordered]@{tools=$tools;write=$write}}
}
function Save-Def($def,[string]$file){
    $dir=Join-Path $dossier 'subagents';[void][IO.Directory]::CreateDirectory($dir)
    [IO.File]::WriteAllText((Join-Path $dir $file),(ConvertTo-SBJson $def))
}
$readParent=@{tools=@((Get-SBSubagentTools).read);write=$false}
# Definition format.
Assert-Sub (Test-SBSubagentDefinition (New-Def 'reviewer')) 'valid definition accepted'
$cases=@(
    @{n='unknown field';f={$d=New-Def 'a';$d.token='x';$d}},
    @{n='bad name';f={New-Def 'Bad Name'}},
    @{n='unknown tool';f={New-Def 'a' @('rm_rf')}},
    @{n='duplicate tool';f={New-Def 'a' @('get_task','get_task')}},
    @{n='write tool without write flag';f={New-Def 'a' @('submit_dossier_write') $false}},
    @{n='permission field';f={$d=New-Def 'a';$d.permissions.permit='yes';$d}},
    @{n='empty role';f={$d=New-Def 'a';$d.role=' ';$d}},
    @{n='schema version';f={$d=New-Def 'a';$d.schemaVersion=2;$d}})
foreach($case in $cases){
    $def=& $case.f
    Reject-Sub { Test-SBSubagentDefinition $def } ('rejected: '+$case.n)
}
# Inherited permissions: never beyond the parent, never trimmed silently.
$perm=Resolve-SBSubagentPermissions (New-Def 'reviewer') $readParent
Assert-Sub ($perm.tools.Count -eq 2 -and !$perm.write -and $perm.inherited) 'effective permissions within the parent'
Reject-Sub { Resolve-SBSubagentPermissions (New-Def 'a' @('check_publication')) $readParent } 'tool beyond the parent is rejected'
Reject-Sub { Resolve-SBSubagentPermissions (New-Def 'a' @('get_task','submit_dossier_write') $true) $readParent } 'write tool beyond a read-only parent is rejected'
Reject-Sub { Resolve-SBSubagentPermissions (New-Def 'a' @('get_task') $true) $readParent } 'write flag beyond a read-only parent is rejected'
$writeParent=@{tools=@((Get-SBSubagentTools).read+(Get-SBSubagentTools).write);write=$true}
$w=Resolve-SBSubagentPermissions (New-Def 'w' @('preview_dossier_write','submit_dossier_write') $true) $writeParent
Assert-Sub ($w.write -and $w.writeAuthorization -ceq 'parent-reviewed-mcp-write') 'write stays bound to the parent reviewed write path'
Reject-Sub { Resolve-SBSubagentPermissions (New-Def 'a') @{tools=@('get_task')} } 'malformed parent is rejected'
# Dossier asset reading.
Assert-Sub (@(Read-SBSubagentDefinitions $dossier).Count -eq 0) 'no definitions yields an empty list'
Save-Def (New-Def 'reviewer') 'reviewer.json'
Save-Def (New-Def 'planner' @('get_ready_tasks','get_task')) 'planner.json'
$entries=@(Read-SBSubagentDefinitions $dossier)
Assert-Sub ($entries.Count -eq 2 -and $entries[0].definition.name -ceq 'planner') 'definitions are read in name order'
Save-Def (New-Def 'other') 'mismatch.json'
Reject-Sub { Read-SBSubagentDefinitions $dossier } 'file name must match the definition name'
Remove-Item (Join-Path $dossier 'subagents/mismatch.json')
[IO.File]::WriteAllText((Join-Path $dossier 'subagents/notes.txt'),'x')
Reject-Sub { Read-SBSubagentDefinitions $dossier } 'foreign file in the asset folder is rejected'
Remove-Item (Join-Path $dossier 'subagents/notes.txt')
# Export through adapters.
$preview=Export-SBSubagents $dossier 'claude-code' $readParent $out $backups
Assert-Sub ($preview.state -eq 'preview' -and $preview.count -eq 2 -and !(Test-Path $out)) 'export preview writes nothing'
$applied=Export-SBSubagents $dossier 'claude-code' $readParent $out $backups -Apply
$md=Get-Content -LiteralPath (Join-Path $out '.claude/agents/reviewer.md') -Raw
Assert-Sub ($applied.state -eq 'applied' -and $md.StartsWith("---`nname: reviewer`n") -and $md.Contains('tools: mcp__secondbrain__get_task, mcp__secondbrain__search_knowledge') -and !$md.Contains('submit_dossier_write')) 'claude-code export lists only the allowed MCP tools'
Assert-Sub ((Export-SBSubagents $dossier 'claude-code' $readParent $out $backups -Apply).state -eq 'unchanged') 'export is idempotent'
$codex=Export-SBSubagents $dossier 'codex' $readParent $out $backups -Apply
$json=Read-SBJson (Join-Path $out 'subagents/reviewer.codex.json') $null
Assert-Sub ($codex.state -eq 'applied' -and $json.permissions.write -eq $false -and !$codex.files[0].liveVerified) 'other clients get the normalized definition, not live-verified'
Reject-Sub { Export-SBSubagents $dossier 'claude-code' @{tools=@('get_task');write=$false} $out $backups } 'export fails when a definition exceeds the parent'
Reject-Sub { Export-SBSubagents $dossier 'nonexistent' $readParent $out $backups } 'unknown client rejected'
# Register: subagent jobs reference the parent session.
$log=Join-Path $dossier 'history/activity/report.md'
$config=@{activityLogEnabled=$true}
$when='2026-11-07T10:00:00Z'
$parentRec=@{schemaVersion=1;eventId=(Get-SBTextHash 'p').Substring(0,32).ToLowerInvariant();user='SYNTH\ada';repository=$repo;taskId='T-1';session='parent-1';when=$when;where='C:\work\one';computer='PC1';outcome='started';detail='parent job'}
$child=New-SBSubagentActivityRecord $repo 'SYNTH\ada' 'PC1' 'T-1' 'parent-1' 'reviewer' 'child-1' '2026-11-07T10:05:00Z' 'completed' 'reviewed task'
Reject-Sub { Add-SBActivityRecords $dossier @($child) $backups $config -Apply } 'child record without a known parent is rejected'
Assert-Sub (!(Test-Path $log)) 'rejected child leaves no log'
Assert-Sub ((Add-SBActivityRecords $dossier @($parentRec,$child) $backups $config -Apply).added -eq 2) 'parent and child append together'
$read=Read-SBActivityLog $dossier
Assert-Sub ($read.records[1].parent -ceq 'parent-1' -and $read.records[1].agent -ceq 'reviewer') 'child record keeps parent and agent'
Assert-Sub ((Add-SBActivityRecords $dossier @($child) $backups $config -Apply).state -eq 'unchanged') 'child append is idempotent'
$mutations=@({param($r) $r.Remove('agent')},{param($r) $r.parent=$r.session},{param($r) $r.agent='Bad Agent'},{param($r) $r.parent='bad parent!'},{param($r) $r.source='trace'})
foreach($mutate in $mutations){
    $bad=@{}+$child;$bad.eventId=(Get-SBTextHash ([guid]::NewGuid().ToString())).Substring(0,32).ToLowerInvariant();& $mutate $bad|Out-Null
    Reject-Sub { Test-SBActivityRecord $bad } 'invalid subagent record rejected'
}
$orphan=New-SBSubagentActivityRecord $repo 'SYNTH\ada' 'PC1' 'T-1' 'other-repo-parent' 'reviewer' 'child-2' '2026-11-07T11:00:00Z' 'started' 'x'
Reject-Sub { Add-SBActivityRecords $dossier @($orphan) $backups $config -Apply } 'unknown parent session is rejected on append'
'SUCCESS SUBAGENTS: '+$script:subChecks+' checks; retained fixture '+$root
