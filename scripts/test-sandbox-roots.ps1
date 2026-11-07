# Included by the essential portable group; all data belongs to its synthetic brain.
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sandbox.psm1')
$out=Join-Path $cfg.runtimeRoot ('repos/'+(Get-SBRuntimeRepoSegment $identity)+'/work/20261107-sandbox')
$fakeSession='a'*32
Put (Join-Path $out 'MANIFEST.json') (ConvertTo-SBJson @{schemaVersion=1;category='work';status='open';hostId=$cfg.workstationId;
    repository=(Get-SBRuntimeRepoSegment $identity);sessionId=$fakeSession;owner=@{user=$env:USERNAME;computer=$env:COMPUTERNAME}})
function Sandbox-Snapshot {
    $state=@{}
    foreach($file in Get-ChildItem -LiteralPath $brain -Recurse -File -Force){$state[$file.FullName]=Get-SBFileHash $file.FullName}
    ConvertTo-SBJson $state
}
$before=Sandbox-Snapshot
$codex=Get-SBSandboxPlan $cfg $identity $repo codex $out
$claude=Get-SBSandboxPlan $cfg $identity $repo claude-code $out
Check ($before -ceq (Sandbox-Snapshot)) 'sandbox preview performs no writes'
Check ($codex.status -eq 'supported' -and $codex.roots.Count -eq 4 -and @($codex.roots|Where-Object shared).Count -eq 2) 'sandbox roots disclose shared coordination and backups'
Check (@($codex.roots.path|Where-Object {$_ -in @($brain,(Join-Path $brain '.runtime'),$cfg.runtimeRoot,$otherDossier)}).Count -eq 0) 'sandbox roots exclude whole brain, runtime and other dossier'
Check ($codex.arguments[4] -eq '--config' -and $codex.arguments[5].StartsWith('sandbox_workspace_write.writable_roots=')) 'Codex uses native workspace-write override arguments'
$settings=ConvertFrom-Json $claude.files[0].text -AsHashtable
Check ($settings.permissions.additionalDirectories.Count -eq 4 -and $settings.permissions.allow.Count -eq 4 -and
    @($settings.permissions.allow|Where-Object {$_ -notmatch '^Edit\(//[a-z]/.+/\*\*\)$'}).Count -eq 0) 'Claude emits normalized absolute Windows Edit rules and additional directories'
Reject {Set-SBSandboxConfiguration $cfg $identity $repo codex $out 'wrong-hash' $fakeSession} 'sandbox apply rejects absent/stale approval'
Reject {Set-SBSandboxConfiguration $cfg $identity $repo codex $out $codex.planHash ('b'*32)} 'sandbox apply refuses another session work folder'
Reject {Get-SBSandboxPlan $cfg $identity $repo codex (Join-Path $brain '.runtime/outside')} 'sandbox export refuses destination outside repository work'
$foreign=Get-SBSandboxPlan $cfg $identity $repo cursor $out
Check ($foreign.status -eq 'unsupported' -and !$foreign.files.Count) 'unsupported IDE has an explicit result and no configuration'
$uncCfg=$cfg.Clone();$uncCfg.backupRoot='\\server\share\backups'
$unc=Get-SBSandboxPlan $uncCfg $identity $repo claude-code $out
Check ($unc.status -eq 'unsupported' -and $unc.reason -eq 'unc-or-rule-metacharacters') 'Claude UNC directory remains unsupported'
$broadCfg=$cfg.Clone();$broadCfg.backupRoot=Join-Path $brain '.runtime'
Reject {Get-SBSandboxPlan $broadCfg $identity $repo codex $out} 'sandbox refuses a backup root that would expose the whole runtime'
$applied=Set-SBSandboxConfiguration $cfg $identity $repo codex $out $codex.planHash $fakeSession
Check ($applied.applied -and !$applied.clientSessionVerified -and (Test-Path (Join-Path $out 'codex-config.toml'))) 'sandbox apply exports only optional configuration'
$native=Read-SBJson (Join-Path $out 'codex-arguments.json') $null
Check ($native.workingDirectory -eq $repo -and $native.arguments[5] -ceq $codex.arguments[5]) 'exported Codex arguments preserve exact paths'
$claude=Get-SBSandboxPlan $cfg $identity $repo claude-code $out
[void](Set-SBSandboxConfiguration $cfg $identity $repo claude-code $out $claude.planHash $fakeSession)
$claudeFile=Join-Path $out 'claude-settings.json'
$original=Read-SBText $claudeFile
Put $claudeFile '{"permissions":{"deny":["Edit(secret)"]},"theme":"synthetic"}'
$changedHash=Get-SBFileHash $claudeFile
Reject {Set-SBSandboxConfiguration $cfg $identity $repo claude-code $out $claude.planHash $fakeSession} 'changed destination invalidates sandbox preview'
$claude=Get-SBSandboxPlan $cfg $identity $repo claude-code $out
[void](Set-SBSandboxConfiguration $cfg $identity $repo claude-code $out $claude.planHash $fakeSession)
$backups=@(Get-ChildItem -LiteralPath $cfg.backupRoot -Filter *.bin|Where-Object {(Get-SBFileHash $_.FullName) -ceq $changedHash})
Check ($backups.Count -eq 1 -and (Read-SBText $claudeFile) -ceq $original) 'sandbox replacement preserves verified original backup'
# Exercise a dossier transaction and inspect every file mutation, including journals.
$beforeFiles=@{}
foreach($file in Get-ChildItem -LiteralPath $brain -Recurse -File -Force){$beforeFiles[$file.FullName]=Get-SBFileHash $file.FullName}
$target=Join-Path $dossier 'sandbox-test.md'
[void](Invoke-SBParaTransaction @(@{path=$target;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes('scoped')}) $cfg.backupRoot $brain)
$outside=@(foreach($file in Get-ChildItem -LiteralPath $brain -Recurse -File -Force){
    if(!$beforeFiles.ContainsKey($file.FullName) -or $beforeFiles[$file.FullName] -cne (Get-SBFileHash $file.FullName)){
        $within=@($codex.roots|Where-Object {$file.FullName.StartsWith($_.path.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)})
        if(!$within.Count){$file.FullName}
    }
})
Check (!$outside.Count -and (Read-SBText $target) -eq 'scoped') 'dossier transaction writes stay within declared roots'
# A failed new transaction keeps its marker in access; old markers remain recoverable.
$legacy=Join-Path $brain '.runtime/para-transaction.json'
Put $legacy '{"manifest":"synthetic-pending"}'
$legacyHash=Get-SBFileHash $legacy
Check ((Get-SBTransactionMarkerPath $brain) -eq $legacy -and (Get-SBPendingTransaction $brain).marker -eq $legacy) 'legacy incomplete marker is still detected'
$blocked=Get-SBSandboxPlan $cfg $identity $repo codex $out
Check ($blocked.status -eq 'unsupported' -and $blocked.reason -eq 'legacy-transaction-requires-recovery') 'legacy recovery blocks minimal-root export without altering marker'
$current=Join-Path $brain '.runtime/access/para-transaction.json'
Put $current '{"manifest":"other-pending"}'
Reject {Get-SBTransactionMarkerPath $brain} 'two markers fail closed without replacement'
Check ((Get-SBFileHash $legacy) -eq $legacyHash -and (Test-Path $current)) 'conflicting markers remain intact'
# Synthetic markers cannot affect subsequent cases: keep them under a separate brain.
$markerBrain=Join-Path $fixture 'marker-brain'
[void][IO.Directory]::CreateDirectory((Join-Path $markerBrain '.runtime/access'))
[IO.File]::Move($legacy,(Join-Path $markerBrain '.runtime/para-transaction.json'))
[IO.File]::Move($current,(Join-Path $markerBrain '.runtime/access/para-transaction.json'))