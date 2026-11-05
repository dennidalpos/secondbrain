#requires -Version 7.5
# One shared synthetic brain; API tests own logic, CLI tests own process boundaries.
[CmdletBinding()]
param([string[]]$Groups=@('portable','trackers','workflows','pending'),[switch]$Extended)
$ErrorActionPreference='Stop'
foreach($name in @('Core','Access','Host','Para','Tracker','Knowledge','Pending','Portable','Mcp','Publication')){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$name+'.psm1'))}
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
. (Join-Path $PSScriptRoot 'test-run-evidence.ps1')
$checks=0
function Check($Value,[string]$Message){if(!$Value){throw ('FAIL ESSENTIAL: '+$Message)};$script:checks++;'PASS ESSENTIAL: '+$Message}
function Reject([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Check $caught $Message}
function Put([string]$Path,[string]$Text){[void][IO.Directory]::CreateDirectory((Split-Path $Path));[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$fixture=Join-Path (Get-SBTestRoot) ('e-'+[guid]::NewGuid().ToString('N').Substring(0,6))
$brain=Join-Path $fixture 'b';$repo=Join-Path $fixture 'r';$identity='github.com/test/essential'
$dossier=Join-Path $brain '02-areas/products/Essential';$trackerPath=Join-Path $dossier 'tracker.json'
foreach($path in @((Join-Path $brain 'scripts'),$repo)){[void][IO.Directory]::CreateDirectory($path)}
Get-ChildItem -LiteralPath $PSScriptRoot -File|Where-Object {$_.Name -notlike 'test-*'}|Copy-Item -Destination (Join-Path $brain 'scripts')
Put (Join-Path $brain 'VERSION') '1.0.0'
Put (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')})
Put (Join-Path $brain 'config/tracker.schema.json') (Read-SBText (Join-Path $PSScriptRoot '../config/tracker.schema.json'))
Put (Join-Path $brain 'direttive/AGENTS.global_ide.md') "# Synthetic`nRevisione 1.0 — 2026-11-04."
Put (Join-Path $brain 'direttive/workstation.template.md') '<!-- secondbrain:tracker-contract:1 -->'
$approval=@{authorization='synthetic test fixture';files=@{}}
foreach($name in @('AGENTS.global_ide.md','workstation.template.md')){$approval.files['direttive/'+$name]=Get-SBFileHash (Join-Path $brain ('direttive/'+$name))}
Put (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson $approval)
Put (Join-Path $dossier 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='essential-area';kind='area';title='Essential';status='active'})
Put (Join-Path $dossier 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity=$identity;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
Put (Join-Path $dossier 'context.md') "# Context`n`n## Stato corrente`nSynthetic current state.`n`n## Vincoli`nKeep bytes.`n`n## Problemi aperti`nT-1.`n`n## Prossimo passo`nT-1.`n"
Put (Join-Path $dossier 'memory.md') "# Memory`n`n## Decisions`n- Decisione: preserve data — Motivo: synthetic test.`n`n## Events (storico)`nHistorical detail.`n"
Put (Join-Path $dossier 'brief.md') '# Synthetic'
Put (Join-Path $dossier 'history/seed/report.md') 'Synthetic provenance'
$tasks=@(foreach($seq in @(1,2)){$task=New-SBTrackerTask @{id=('T-'+$seq);title=('Task '+$seq);status='todo'} $identity 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture';$task.seq=$seq;$task.title=('#00'+$seq+' — Task '+$seq);$task})
Put $trackerPath (ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=$tasks;history=@();extensions=@{lastSeq=2}})
$otherDossier=Join-Path $brain '02-areas/products/Other'
Put (Join-Path $otherDossier 'brief.md') '# Synthetic other repository'
Put (Join-Path $otherDossier 'context.md') '# Other context'
Put (Join-Path $otherDossier 'memory.md') '# Other memory'
Put (Join-Path $otherDossier 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='other-area';kind='area';title='Other';status='active'})
Put (Join-Path $otherDossier 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/other';tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
$otherTask=New-SBTrackerTask @{id='O-1';title='Other';status='done'} 'github.com/test/other' 'fixture' 'history/seed/report.md' (Get-SBTextHash 'Synthetic provenance') 'fixture'
$otherTask.seq=1;$otherTask.title='#001 — Other'
Put (Join-Path $otherDossier 'tracker.json') (ConvertTo-SBJson @{schemaVersion=1;repository='github.com/test/other';updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($otherTask);history=@();extensions=@{lastSeq=1}})
& git -C $repo init -q
if($LASTEXITCODE){throw 'Git fixture init failed'}
& git -C $repo remote add origin 'https://github.com/test/essential.git'
if($LASTEXITCODE){throw 'Git fixture remote failed'}
Check ((& git -C $repo rev-parse --show-toplevel).Replace('\','/') -ceq $repo.Replace('\','/')) 'Git fixture is isolated'
$hostId=Get-SBHostId;$runtime=Join-Path $brain ('.runtime/hosts/'+$hostId);$configPath=Join-Path $runtime 'workstation.json'
$cfg=@{schemaVersion=1;mode='portable';brainRoot=$brain;workstationId=$hostId;runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');repositoryRoot=$brain;coordinationRoot=(Join-Path $brain '.runtime/access');bindings=@(@{identity=$identity;path=$repo;remoteIdentity=$identity});ides=@();sessionTimeoutMinutes=30;lockWaitMs=1000;configPath=$configPath}
Put $configPath (ConvertTo-SBJson $cfg)
$argsBase=@{BrainRoot=$brain;Identity=$identity;WorkingRepository=$identity}
function Invoke-EssentialCli([string[]]$Arguments){$out=@(& pwsh -NoProfile -File (Join-Path $brain 'scripts/knowledge.ps1') -ConfigPath $configPath -CheckoutPath $repo @Arguments 2>&1);@{code=$LASTEXITCODE;text=($out -join "`n")}}

if('portable' -in $Groups){
    $portableModule=Get-Module SecondBrain.Portable
    foreach($case in @(@('',1,$false),@('git version 2.41.9',0,$false),@('unrecognized',0,$false),@('git version 2.42.0',0,$true),@('git version 2.56.0.windows.4',0,$true),@('git version 2.56.0',1,$false))){
        $result=& $portableModule {param($text,$code) Test-SBGitRequirement $text $code} $case[0] $case[1]
        Check ($result.ok -eq $case[2]) ('Git requirement: '+$case[0]+'/'+$case[1])
    }
    $preflight=& $portableModule {param($root) Test-SBSetupPreflight $root} $brain
    Check (@($preflight|Where-Object name -eq 'git')[0].ok) 'installed Git satisfies real preflight'
    $approved=Join-Path $brain 'direttive/workstation.template.md'
    $original=Read-SBText $approved;Put $approved 'unapproved'
    Check (!(Test-SBApproval $brain)) 'changed directives cannot be distributed'
    Put $approved $original
    Check (Test-SBApproval $brain) 'matching approval hashes accepted'
    $discoveryPath=Join-Path $brain '.runtime/discovery.json'
    $discovery=Invoke-SBHostDiscovery -BrainRoot $brain -Roots @($repo) -ReportPath $discoveryPath
    $selectionPath=Join-Path $brain '.runtime/selection.json'
    $selection=@{schemaVersion=1;confirmed=$false;confirmation='fixture';reportPath=$discoveryPath;reportSha256=(Get-SBFileHash $discoveryPath);repositories=@(@{id=$discovery.repositories[0].id});ides=@()}
    Put $selectionPath (ConvertTo-SBJson $selection)
    Reject {Invoke-SBHostActivation $brain $selectionPath -Apply} 'activation without confirmation rejected'
    $selection.confirmed=$true;Put $selectionPath (ConvertTo-SBJson $selection)
    $one=Invoke-SBHostActivation $brain $selectionPath -Apply
    $two=Invoke-SBHostActivation $brain $selectionPath -Apply
    Check ($one.applied -and $two.applied -and (Read-SBJson $one.configuration $null).bindings.Count -eq 1) 'activation is idempotent on one synthetic checkout'
    $decisionMemory=Join-Path $dossier 'memory.md';$decisionOriginal=Read-SBText $decisionMemory
    Put $decisionMemory ($decisionOriginal+"`n## Decisione old`n<!-- sb:decision id=old state=superseded supersededBy=new -->`nSuperseded detail.`n")
    $decisionConfig=Read-SBConfiguration $one.configuration -ReadOnly
    $decisionConfig.brainRoot=$brain
    $decisionCheck=Invoke-SBPortableSync $decisionConfig -Check -Repository $identity
    Check (@($decisionCheck.warnings|Where-Object kind -eq 'decisions-inactive').Count -eq 1 -and (Get-SBFileHash $decisionMemory) -ceq (Get-SBTextHash ($decisionOriginal+"`n## Decisione old`n<!-- sb:decision id=old state=superseded supersededBy=new -->`nSuperseded detail.`n"))) 'Check reports inactive decision identities without rewriting their sources'
    Put $decisionMemory $decisionOriginal
    # Restore the synthetic runtime model used by the following boundary tests.
    Put $configPath (ConvertTo-SBJson $cfg)
    # In-process activation uses the loaded module's root for its registry.
    # Reconcile only this synthetic registry with the copied CLI's root.
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/access.ps1') -Reconcile -ConfigPath $configPath|Out-Null
    if($LASTEXITCODE){throw 'Synthetic registry reconciliation failed'}
    $wire=@('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}','{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}') -join "`n"
    $out=@($wire|& pwsh -NoProfile -File (Join-Path $brain 'scripts/mcp-server.ps1') -BrainRoot $brain -ConfigPath $configPath)
    $messages=@($out|ForEach-Object {$_|ConvertFrom-Json -AsHashtable})
    Check ($LASTEXITCODE -eq 0 -and $messages[0].result.protocolVersion -eq '2025-03-26' -and $messages[1].result.tools.Count -eq 8) 'real MCP stdio negotiates and exposes eight tools'
    if($Extended){
        $candidate=Join-Path $runtime 'directive-proposal'
        Put (Join-Path $candidate 'README.md') '# Synthetic proposal'
        Put (Join-Path $candidate 'AGENTS.repo.managed.md') 'Synthetic shared repository directive. [Official docs](https://example.invalid/home/guide)'
        $relative=[IO.Path]::GetRelativePath($brain,$dossier)
        Put (Join-Path $candidate "$relative/AGENTS.managed.md") 'Synthetic repository-specific directive.'
        $approvalScript=Join-Path $brain 'scripts/approve-revision.ps1'
        $proposal=(& pwsh -NoProfile -File $approvalScript -ProposalPath $candidate -ConfigPath $configPath -Preview)|ConvertFrom-Json -AsHashtable
        Check ($LASTEXITCODE -eq 0 -and $proposal.changes.Count -eq 2 -and !(Test-Path (Join-Path $dossier 'AGENTS.managed.md'))) 'directive preview reports both changes without applying them'
        & pwsh -NoProfile -File $approvalScript -ProposalPath $candidate -ConfigPath $configPath -ExpectedProposalHash $proposal.proposalHash -Authorization 'synthetic proposal' | Out-Null
        Check ($LASTEXITCODE -eq 0 -and (Test-SBApproval $brain)) 'reviewed directive hashes are applied together'
        $publicApproval=Read-SBJson (Join-Path $brain 'direttive/approved.json') @{}
        $privateApproval=Read-SBJson (Join-Path $brain '.runtime/directive-approvals.json') @{}
        Check (@($publicApproval.files.Keys|Where-Object {$_ -like '02-areas/*'}).Count -eq 0 -and $privateApproval.files.ContainsKey($relative.Replace('\','/')+'/AGENTS.managed.md')) 'dossier directive approvals remain outside the public manifest'
        $generated=& $portableModule {param($root,$dir) New-SBPortableRepositoryBody (Get-SBApprovedDirectiveRevision $root) $root $dir} $brain $dossier
        Check ($generated.Contains('https://example.invalid/home/guide') -and $generated.Contains('Synthetic repository-specific directive.')) 'shared and specific Markdown with public URLs feed the managed block'
        Put (Join-Path $dossier 'AGENTS.managed.md') 'Unapproved edit'
        Reject {& $portableModule {param($root,$dir) New-SBPortableRepositoryBody (Get-SBApprovedDirectiveRevision $root) $root $dir} $brain $dossier} 'unapproved repository edit cannot be distributed'
        Put (Join-Path $dossier 'AGENTS.managed.md') 'Synthetic repository-specific directive.'
        $cursor=Join-Path $runtime 'cursor/mcp.json'
        $cursorPlan=Get-SBMcpPairing -BrainRoot $brain -Target cursor -Scope user -ConfigFile $cursor -ApproveAllTools
        Check ((Test-SBSamePath $cursorPlan.ConfigFile $cursor) -and (Test-SBSamePath $cursorPlan.PermissionPlan.path (Join-Path (Split-Path $cursor) 'permissions.json'))) 'Cursor configuration and policy overrides stay inside the fixture before writing'
        $mcp=Set-SBMcpConfiguration -BrainRoot $brain -Target cursor -Scope user -ConfigFile $cursor -BackupRoot $cfg.backupRoot -ApproveAllTools
        $rules=(Read-SBJson (Join-Path (Split-Path $cursor) 'permissions.json') @{}).mcpAllowlist
        Check ($mcp.PermissionAction -eq 'applied' -and !$mcp.ClientSessionVerified -and $rules.Count -eq 8 -and $rules -contains 'secondbrain:check_publication') 'all-tool pairing approves eight exact names and separates live verification'
        $again=Set-SBMcpConfiguration -BrainRoot $brain -Target cursor -Scope user -ConfigFile $cursor -BackupRoot $cfg.backupRoot -ApproveAllTools
        Check ($again.Action -eq 'unchanged' -and $again.PermissionAction -eq 'unchanged') 'all-tool pairing can be repeated without drift'
        foreach($target in @('codex','claude-code')){
            $file=Join-Path $runtime ($target+'/'+$(if($target -eq 'codex'){'config.toml'}else{'.claude.json'}))
            $pair=Get-SBMcpPairing -BrainRoot $brain -Target $target -ConfigFile $file -Scope user -ApproveAllTools
            Check (Test-SBSamePath $pair.ConfigFile $file) ($target+' configuration override stays inside the fixture before writing')
            if($target -eq 'codex'){
                Put $file ("[mcp_servers.secondbrain]`ncommand = `"pwsh`"`nargs = "+(ConvertTo-Json -InputObject @($pair.ServerDefinition.args) -Compress)+"`n")
            }else{
                Put $file (ConvertTo-SBJson @{mcpServers=@{secondbrain=$pair.ServerDefinition}})
                Put $pair.PermissionPlan.path (ConvertTo-SBJson @{permissions=@{deny=@('mcp__other__write');ask=@('mcp__secondbrain__check_publication')}})
            }
            $installed=Set-SBMcpConfiguration -BrainRoot $brain -Target $target -ConfigFile $file -Scope user -ApproveAllTools -BackupRoot $cfg.backupRoot
            if($target -eq 'codex'){
                $text=Read-SBText $file
                Check ([regex]::Matches($text,'approval_mode = "approve"').Count -eq 8 -and $text.Contains('default_tools_approval_mode = "prompt"')) 'Codex approves all eight names and retains the default for future tools'
            }else{
                $policy=(Read-SBJson $pair.PermissionPlan.path @{}).permissions
                Check ($policy.allow.Count -eq 8 -and !$policy.ask.Count -and $policy.deny -contains 'mcp__other__write') 'custom Claude profile approves eight tools and preserves deny rules'
            }
            $repeat=Set-SBMcpConfiguration -BrainRoot $brain -Target $target -ConfigFile $file -Scope user -ApproveAllTools -BackupRoot $cfg.backupRoot
            Check ($repeat.PermissionAction -eq 'unchanged') ($target+' all-tool policy is idempotent')
        }
        $oldProfile=$env:USERPROFILE;$oldBrain=$env:SECONDBRAIN_HOME
        try{
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../direttive/prompts') -Destination (Join-Path $brain 'direttive/prompts') -Recurse
            Put (Join-Path $brain 'config/prompt-catalog.schema.json') (Read-SBText (Join-Path $PSScriptRoot '../config/prompt-catalog.schema.json'))
            $env:USERPROFILE=Join-Path $runtime 'synthetic-profile'
            [void][IO.Directory]::CreateDirectory($env:USERPROFILE)
            $setupScript=Join-Path $brain 'scripts/secondbrain.ps1'
            $setup=(& pwsh -NoProfile -File $setupScript -Setup -Roots $repo -Select $repo -McpTargets cursor -Yes -Apply -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
            Check ($LASTEXITCODE -eq 0 -and $setup.applied -and $setup.check.mode -eq 'sync' -and $setup.mcp.permissionConfigurationComplete -and [IO.File]::Exists($setup.setupReport)) 'setup applies sync, named approvals and a persistent report in an isolated profile'
            $repeat=(& pwsh -NoProfile -File $setupScript -Setup -Roots $repo -Select $repo -McpTargets cursor -Yes -Apply -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
            Check ($LASTEXITCODE -eq 0 -and $repeat.mcp.items[0].PermissionAction -eq 'unchanged') 'setup repeats with the same repository identity and MCP rules'
        }finally{$env:USERPROFILE=$oldProfile;$env:SECONDBRAIN_HOME=$oldBrain}
    }
}
if('trackers' -in $Groups){
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1} 'empty update rejected'
    foreach($field in @('Priority','Execution')){$bad=@{$field='invalid'};Reject {Update-SBTrackerTask @argsBase -TaskId T-1 @bad} ('invalid '+$field+' rejected')}
    $snapshot=Read-SBJson $trackerPath $null
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Priority P1)
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($task.priority -eq 'P1' -and $task.status -eq $snapshot.tasks[0].status -and $task.execution -eq $snapshot.tasks[0].execution) 'single update preserves omitted fields'
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Execution user_required -DependsOn @('T-2') -Stream urgent -StateReason 'synthetic')
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($task.dependencies[0].id -eq 'T-2' -and $task.extensions.stream -eq 'urgent' -and $task.execution -eq 'user_required') 'combined metadata update'
    $before=Get-SBFileHash $trackerPath
    Reject {Update-SBTrackerTask @argsBase -TaskId T-2 -DependsOn T-1} 'cyclic dependency rejected'
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1 -DependsOn missing} 'missing dependency rejected'
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1 -DependsOn 'github.com/test/missing#T-2'} 'unmanaged repository dependency rejected'
    Reject {Update-SBTrackerTask -BrainRoot $brain -Identity $identity -WorkingRepository 'github.com/test/foreign' -TaskId T-1 -Priority P0} 'foreign tracker write rejected'
    Check ((Get-SBFileHash $trackerPath) -ceq $before) 'rejected updates preserve tracker bytes'
    $closed=Update-SBTrackerTask @argsBase -TaskId T-2 -Status done
    $closedDetail=Get-SBTaskDetail -BrainRoot $brain -Dossier $dossier -Task '#002'
    Check ($closed.ContainsKey('closureAdvice') -and $closedDetail.source -eq 'archive' -and $closedDetail.task.status -eq 'done' -and (Read-SBJson $trackerPath $null).tasks.Count -eq 1) 'closure advice and complete archived record'
    [void](Update-SBTrackerTask @argsBase -TaskId T-2 -Status todo)
    Check ((Get-SBTaskDetail -BrainRoot $brain -Dossier $dossier -Task '#002').source -eq 'tracker') 'reopening preserves task number and restores the active record'
    [void](Update-SBTrackerTask @argsBase -TaskId T-2 -Status done)
    $meta=Update-SBTrackerTask @argsBase -TaskId T-2 -Priority P2
    Check (!$meta.ContainsKey('closureAdvice')) 'metadata update on done task does not produce closure advice'
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -DependsOn ($identity+'#T-2;github.com/test/other#O-1'))
    Check ((Read-SBJson $trackerPath $null).tasks[0].dependencies.Count -eq 2) 'semicolon-separated qualified dependencies preserve managed repository identities'
    $archivePreview=Move-SBTerminalTrackerTasks -BrainRoot $brain -Identity 'github.com/test/other'
    Check (!$archivePreview.applied -and $archivePreview.taskIds -contains 'O-1' -and !(Test-Path (Join-Path $otherDossier 'history/tracker-archive.json'))) 'terminal migration preview leaves the archive absent'
    [void](Move-SBTerminalTrackerTasks -BrainRoot $brain -Identity 'github.com/test/other' -Apply)
    Check (@(Get-SBGlobalTasks -BrainRoot $brain -Repository $identity -ReadyOnly).id -contains 'T-1') 'archived local and cross-repository dependencies satisfy readiness'
    [void](Set-SBTrackerTaskStatus -BrainRoot $brain -Identity 'github.com/test/other' -TaskId O-1 -Status cancelled)
    Check (@(Get-SBGlobalTasks -BrainRoot $brain -Repository $identity -ReadyOnly).id -notcontains 'T-1') 'cancelled historical tasks do not satisfy dependencies'
    [void](Set-SBTrackerTaskStatus -BrainRoot $brain -Identity 'github.com/test/other' -TaskId O-1 -Status done)
    $cli=Invoke-EssentialCli @('-UpdateTaskId','T-1','-DependsOn','','-Stream','','-Priority','P2')
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($cli.code -eq 0 -and !$task.dependencies.Count -and !$task.extensions.ContainsKey('stream') -and $task.priority -eq 'P2') ('CLI clears explicit empty metadata: '+$cli.text)
    $cli=Invoke-EssentialCli @('-UpdateTaskId','T-1')
    Check ($cli.code -ne 0) 'CLI rejects update without fields'
    $cli=Invoke-EssentialCli @('-Tasks')
    Check ($cli.code -eq 0 -and @($cli.text|ConvertFrom-Json).Count -eq 1) 'CLI lists only open local tasks'
}
if('workflows' -in $Groups){
    $empty=& (Get-Module SecondBrain.Knowledge) {New-SBStartupPackage -Record @{identity='github.com/test/empty'} -Tracker @{path=$null;source='absent';declared=$false} -TOC '# Empty' -ContextText '# Context' -MemoryText '# Memory' -Profile Slim -Budget 30000}
    Check ($empty.withinBudget -and $empty.parts.tasks.Contains('Nessun task selezionato.') -and !$empty.parts.tasks.Contains('Nessun task pronto.')) 'startup without selected tasks reports selection rather than claiming the tracker has no ready work'
    $default=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -Profile Slim
    Check ($default.budget -eq 30000) 'Slim API uses the shared 30000-character default'
    $repeat=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -Profile Slim -PreviousRevision $default.revision
    Check (!$repeat.changed -and !$repeat.parts.Count -and $repeat.characters -eq 0 -and $repeat.sourceCharacters -eq $default.characters) 'unchanged startup revision returns metadata without repeating parts'
    $repeatCli=Invoke-EssentialCli @('-Startup','-NoRecovery','-PreviousRevision',$default.revision)
    Check ($repeatCli.code -eq 0 -and !($repeatCli.text|ConvertFrom-Json).changed) 'CLI forwards previous startup revision without persistence'
    $repeatMcp=Invoke-SBMcpToolCall $brain 'get_startup_context' @{repository=$identity;previousRevision=$default.revision} | ConvertFrom-Json -AsHashtable
    Check (!$repeatMcp.changed -and !$repeatMcp.parts.Count) 'MCP forwards previous startup revision without repeating parts'
    Check ((Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -Profile Slim -Budget 29999 -PreviousRevision $default.revision).changed) 'changed startup budget invalidates previous revision'
    $startup=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -CheckoutPath $repo -Budget 20000 -Profile Slim
    Check ($startup.withinBudget -and !$startup.parts.memory.Contains('Historical detail') -and $startup.omittedParts.Count -gt 0) 'Slim omits history without truncating source'
    $before=Get-SBFileHash (Join-Path $dossier 'memory.md')
    $under=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -CheckoutPath $repo -Budget 1 -Profile Slim
    Check (!$under.withinBudget -and $under.minimumCharacters -gt 1) 'unworkable explicit budget reports its minimum'
    $contextPath=Join-Path $dossier 'context.md';$originalContext=Read-SBText $contextPath
    $prefix="`n## Long example`n"
    $padding=30000-[int]$startup.characters-$prefix.Length-1
    foreach($extra in @(-1,0,1)){
        Put $contextPath ($originalContext+$prefix+('x'*($padding+$extra))+"`n")
        $contextHash=Get-SBFileHash $contextPath
        $sized=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -Budget (Get-SBSlimStartupBudget) -Profile Slim
        Check ($sized.withinBudget -and $sized.uncompactedCharacters -eq (30000+$extra) -and $sized.compacted -eq ($extra -gt 0) -and (Get-SBFileHash $contextPath) -ceq $contextHash) ('Slim 30000-character boundary '+$extra)
    }
    $longSection=$prefix.TrimStart("`n")+('x'*($padding+1))+"`n"
    Check ($sized.parts.context.Contains('Keep bytes.') -and (!$sized.parts.context.Contains('Long example') -or $sized.parts.context.Contains($longSection)) -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $before) 'Slim preserves prioritized sections, whole blocks and source bytes'
    $mcpStartup=Invoke-SBMcpToolCall $brain 'get_startup_context' @{repository=$identity} | ConvertFrom-Json -AsHashtable
    Check ($mcpStartup.budget -eq 30000 -and $mcpStartup.compacted -and $mcpStartup.parts.context -ceq $sized.parts.context) 'MCP and CLI compose the same compacted startup'
    Put $contextPath $originalContext
    $candidatePath=Join-Path $brain '.runtime/candidate.json'
    $candidate=@{schemaVersion=1;repository=$identity;sources=@{};summaries=@{};openTaskIds=@((Read-SBJson $trackerPath $null).tasks|Where-Object status -notin @('done','cancelled')|ForEach-Object id);reviewed=$true;reviewNote='synthetic conservation test'}
    foreach($name in @('context.md','memory.md')){$candidate.sources[$name]=Get-SBFileHash (Join-Path $dossier $name);$candidate.summaries[$name]=Read-SBText (Join-Path $dossier $name)}
    Put $candidatePath (ConvertTo-SBJson $candidate)
    $preview=Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -CheckoutPath $repo
    Check (!$preview.applied -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $before) 'compaction preview preserves source'
    [void](Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -CheckoutPath $repo -Apply)
    Check ((Get-SBFileHash (Join-Path $dossier ('history/compaction/'+$before.ToLowerInvariant()+'/memory.md'))) -ceq $before) 'compaction preserves byte-exact original'
    Reject {Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -Apply} 'stale compaction candidate rejected'
}
if('pending' -in $Groups){
    $noRecoveryRequest=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="`nPending no-recovery fixture"} -Config $cfg
    $memoryBefore=Get-SBFileHash (Join-Path $dossier 'memory.md')
    $pureRead=Invoke-EssentialCli @('-Startup','-NoRecovery')
    Check ($pureRead.code -eq 0 -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $memoryBefore -and (Get-SBPendingWrites $brain|Where-Object id -eq $noRecoveryRequest.id).state -eq 'deferred') 'CLI NoRecovery preserves an authorized pending write without applying it'
    $mcpModule=Get-Module SecondBrain.Mcp
    $pureMcp=& $mcpModule {param($root) Invoke-SBMcpMessage $root @{jsonrpc='2.0';id=31;method='tools/list';params=@{_meta=@{noRecovery=$true}}}} $brain
    Check (($pureMcp|ConvertFrom-Json -AsHashtable).result.tools.Count -eq 8 -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $memoryBefore) 'MCP request NoRecovery lists tools without draining the queue'
    [void](Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg)
    Reject {New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';DependsOn=@('T-1')} -Config $cfg} 'invalid dependency graph rejected before queuing'
    $target=Join-Path $brain 'untracked.txt';Put $target 'original';$hash=Get-SBFileHash $target
    [void](Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('updated')) $hash $cfg.backupRoot)
    Check (@(Get-ChildItem $cfg.backupRoot -Filter '*.bin'|Where-Object {(Get-SBFileHash $_.FullName) -ceq $hash}).Count -gt 0) 'write preserves original backup bytes'
    Reject {Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('lost')) $hash $cfg.backupRoot} 'stale write hash rejected'
    $holder=Enter-SBOperation $cfg -WaitMs 0
    try{
        $first=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Priority='P0';Stream='queued'} -Config $cfg
        $second=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Priority='P3'} -Config $cfg
        $deferred=Complete-SBPendingSubmission $first $cfg
        Check (!$deferred.applied -and $deferred.state -eq 'deferred') 'busy writer preserves durable request without applying'
    }finally{Exit-SBOperation $holder}
    $drain=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($drain.applied.Count -eq 1 -and $drain.conflicts.Count -eq 1 -and $task.priority -eq 'P0') 'first queued update applies and stale concurrent update conflicts'
    $after=Get-SBFileHash $trackerPath
    [void](Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg)
    Check ((Get-SBFileHash $trackerPath) -ceq $after) 'replay applies no duplicate update'
    $receipt=@(Get-SBPendingWrites $brain|Where-Object id -eq $first.id)[0].receipt
    Check ($receipt.state -eq 'applied' -and $receipt.result.taskId -eq 'T-1') 'receipt identifies atomically applied task'
    $legacy=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.status -Arguments @{TaskId='T-1';Status='in_progress'} -Config $cfg
    Check ((Complete-SBPendingSubmission $legacy $cfg).applied) 'existing task.status request remains supported'
    $compatible=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Status='todo'} -Config $cfg
    $legacyQueue=Split-Path $compatible.path
    Check ($compatible.request.operation -ceq 'task.status' -and (Split-Path $legacyQueue -Leaf) -ceq 'pending-writes') 'status-only producer preserves the legacy wire format and queue'
    Check ((Complete-SBPendingSubmission $compatible $cfg).applied) 'compatible status request applies'

    $graphPath=if(@((Read-SBJson $trackerPath $null).tasks|Where-Object id -eq 'T-2').Count){$trackerPath}else{Join-Path $dossier 'history/tracker-archive.json'}
    $healthy=Read-SBText $graphPath
    $broken=$healthy|ConvertFrom-Json -AsHashtable -DateKind String
    @($broken.tasks|Where-Object id -eq 'T-2')[0].dependencies=@(@{id='MISSING-FIXTURE'})
    Put $graphPath (ConvertTo-SBJson $broken)
    $repairable=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Stream='after-repair';Priority='P2'} -Config $cfg
    Check ((Split-Path (Split-Path $repairable.path) -Leaf) -ceq 'task-update' -and
        $repairable.id -notin @(Get-ChildItem -LiteralPath $legacyQueue -Filter '*.json' -File | ForEach-Object BaseName)) 'legacy nonrecursive consumer cannot see extended request'
    $response=Complete-SBPendingSubmission $repairable $cfg
    Check ($response.state -eq 'deferred' -and $response.pendingWrites.errors.Count -eq 1) 'preexisting broken graph leaves a durable request without terminal receipt'
    Put $graphPath $healthy
    Check ((Complete-SBPendingSubmission $repairable $cfg).applied -and (Read-SBJson $trackerPath $null).tasks[0].extensions.stream -eq 'after-repair') 'repair allows the original request to apply'
    $after=Get-SBFileHash $trackerPath
    Check ((Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg).applied.Count -eq 0 -and (Get-SBFileHash $trackerPath) -ceq $after) 'repair replay applies once'

    $oldUpdate=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Stream='legacy-location'} -Config $cfg
    Move-Item -LiteralPath $oldUpdate.path -Destination (Join-Path $legacyQueue ($oldUpdate.id+'.json'))
    Check ((Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg).applied.id -eq $oldUpdate.id) 'upgraded consumer integrates earlier task.update from the legacy directory'
    [void](Update-SBTrackerTask @argsBase -TaskId T-2 -Status done)
    $metadata=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-2';Priority='P1'} -Config $cfg
    $response=Complete-SBPendingSubmission $metadata $cfg
    Check ($response.applied -and !$response.ContainsKey('closureAdvice')) 'queued metadata on a done task emits no closure signal'
}
if('audit2' -in $Groups){
    $target=Join-Path $brain 'denied.txt';Put $target 'updated'
    [IO.File]::SetAttributes($target,[IO.FileAttributes]::ReadOnly)
    try{
        $denied=$null;try{Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('denied')) (Get-SBFileHash $target) $cfg.backupRoot|Out-Null}catch{$denied=$_}
        Check ($denied -and (Test-SBError $denied 'core.write.denied') -and (Read-SBText $target) -ceq 'updated') 'access denied preserves destination and stable error code'
    }finally{[IO.File]::SetAttributes($target,[IO.FileAttributes]::Normal)}
    Reject {Assert-SBCentralDataPath $brain (Join-Path $fixture 'outside')} 'runtime path escape rejected'
    $outside=Join-Path $fixture 'outside';[void][IO.Directory]::CreateDirectory($outside)
    $junction=Join-Path $brain '.runtime/junction'
    New-Item -ItemType Junction -Path $junction -Target $outside|Out-Null
    Reject {Assert-SBCentralDataPath $brain (Join-Path $junction 'payload')} 'junction escape rejected'
    $tx=Join-Path $brain 'transaction.txt';Put $tx 'before'
    $manifest=Invoke-SBParaTransaction @(@{path=$tx;expected=(Get-SBFileHash $tx);bytes=[Text.Encoding]::UTF8.GetBytes('after')}) $cfg.backupRoot $brain
    [void](Restore-SBParaTransaction $manifest $brain $cfg.backupRoot)
    Check ((Read-SBText $tx) -ceq 'before') 'transaction rollback recovers original bytes'
    Put $tx 'changed';Reject {Restore-SBParaTransaction $manifest $brain $cfg.backupRoot} 'rollback refuses changed destination'
    $clean=@(Test-SBPublicationText 'Public synthetic documentation.' 'README.md' 'working')
    $privateText='token=gh'+'p_'+('x'*36)
    $private=@(Test-SBPublicationText $privateText 'README.md' 'working')
    Check (!$clean.Count -and $private.Count -gt 0) 'publication distinguishes public prose and private attribution fixture'
    Put (Join-Path $repo 'README.md') 'Public synthetic documentation.'
    Put (Join-Path $repo 'big.txt') ('safe public text '*100)
    & git -C $repo -c user.name=Fixture -c user.email=fixture@example.invalid add README.md big.txt
    & git -C $repo -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm base
    if($LASTEXITCODE){throw 'Synthetic publication commit failed'}
    $oid=(& git -C $repo hash-object big.txt).Trim()
    foreach($case in @(@($oid,0),@(('0'*40),1))){
        $policy=Join-Path $brain '.runtime/publication/size-policy.json'
        Put $policy (ConvertTo-SBJson @{schemaVersion=1;allowances=@();binaryReviews=@(@{path='big.txt';sha256=('0'*64);gitBlob=$case[0];reviewed=$true;reason='synthetic review'})})
        $pub=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy -MaxTextBytes 400
        Check (@($pub.incomplete|Where-Object {$_.surface -eq 'history' -and $_.reason -eq 'size-limit'}).Count -eq $case[1]) 'reviewed historical blob is bound to the exact object'
    }
    Put (Join-Path $repo 'README.md') $privateText
    & git -C $repo add README.md
    $pub=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    Check (!$pub.ready -and @($pub.findings|Where-Object {$_.rule -eq 'credential' -and $_.surface -eq 'index'}).Count -gt 0 -and !(ConvertTo-SBJson $pub).Contains($privateText)) 'real staged private fixture blocks publication without leaking its value'

    $base=(Invoke-SBGit $repo @('rev-parse','HEAD')).output
    $historyCommit=(Invoke-SBGit $repo @('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit-tree',(Invoke-SBGit $repo @('write-tree')).output,'-p',$base,'-m','Synthetic divergent history')).output
    Check ($historyCommit -match '^[a-f0-9]{40,64}$') 'created divergent history without changing HEAD'
    Put (Join-Path $repo 'README.md') 'Public synthetic documentation.'
    [void](Invoke-SBGit $repo @('add','README.md'))
    $baselinePath=Get-SBPublicationBaselinePath $brain $repo
    $initial=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -Initial -MaxHistoryBlobs 0
    Check (!$initial.complete -and !(Test-Path -LiteralPath $baselinePath)) 'incomplete initial scan cannot persist a baseline'
    Put $baselinePath (ConvertTo-SBJson @{schemaVersion=1;headCommit=$base;authorized=$true})
    $legacyHash=Get-SBFileHash $baselinePath
    Check (!(Test-SBPublication -BrainRoot $brain -RepositoryPath $repo).incremental) 'legacy baseline is ignored'
    $initial=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -Initial
    Check ($initial.ready -and (Get-SBFileHash $baselinePath) -ne $legacyHash) 'complete clean scan saves a new baseline'
    $cleanHash=Get-SBFileHash $baselinePath
    Check ((Test-SBPublication -BrainRoot $brain -RepositoryPath $repo).incremental) 'unchanged history reuses the verified baseline'
    Put (Join-Path $repo 'untracked.txt') $privateText
    $withLocalFile=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    Check ($withLocalFile.incremental -and !$withLocalFile.ready) 'history reuse still scans working files'
    Put (Join-Path $repo 'untracked.txt') 'Public synthetic documentation.'

    Check ((Invoke-SBGit $repo @('update-ref','refs/heads/divergent',$historyCommit)).code -eq 0) 'created divergent branch'
    $blocked=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -Initial
    Check (!$blocked.ready -and (Get-SBFileHash $baselinePath) -ceq $cleanHash) 'history finding cannot replace a clean baseline'
    $blocked=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    Check (!$blocked.incremental -and @($blocked.findings|Where-Object surface -eq history).Count -gt 0 -and (Invoke-SBGit $repo @('rev-parse','HEAD')).output -ceq $base) 'divergent branch is checked at unchanged HEAD'
    Check ((Invoke-SBGit $repo @('tag','audit-tag',$historyCommit)).code -eq 0) 'created tag for divergent history'
    Check ((Invoke-SBGit $repo @('update-ref','-d','refs/heads/divergent')).code -eq 0) 'kept divergent history reachable only via tag'
    $blocked=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    $historyFinding=@($blocked.findings|Where-Object surface -eq history)[0]
    Check (!$blocked.ready -and $historyFinding.path -ceq 'README.md') 'tag-only history is checked'
    Put $policy (ConvertTo-SBJson @{schemaVersion=1;allowances=@(@{rule=$historyFinding.rule;path=$historyFinding.path;fingerprint=$historyFinding.fingerprint;reason='synthetic review'})})
    Check ((Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy -Initial).ready) 'reviewed history can seed a baseline'
    $reviewed=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy
    Check ($reviewed.incremental -and @($reviewed.findings|Where-Object {$_.surface -eq 'history' -and $_.reviewed}).Count -gt 0) 'history reuse retains reviewed findings'
    Put $policy (ConvertTo-SBJson @{schemaVersion=1;allowances=@()})
    $blocked=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy
    Check (!$blocked.ready -and !$blocked.incremental) 'policy change invalidates history coverage'
    Check ((Invoke-SBGit $repo @('tag','-d','audit-tag')).code -eq 0) 'removed the publishable tag from the fixture'
    Check ((Invoke-SBGit $repo @('update-ref','refs/audit/private',$historyCommit)).code -eq 0) 'created a nonstandard local ref'
    $pub=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    Check ($pub.ready -and 'refs/audit/private' -cin $pub.excludedRefs) 'ordinary audit reports excluded local ref'

    $remote=Join-Path $fixture 'pub.git'
    Check ((Invoke-SBGit $fixture @('init','--bare',$remote)).code -eq 0) 'initialized local push remote'
    [void](Install-SBPublicationHook -RepositoryPath $repo -BrainRoot $brain -Apply)
    $savedBrain=$env:SECONDBRAIN_HOME
    $savedSkip=$env:SECONDBRAIN_SKIP_PRE_PUSH
    try {
        $env:SECONDBRAIN_HOME=$brain
        $env:SECONDBRAIN_SKIP_PRE_PUSH=$null
        $push=Invoke-SBGit $repo @('push',$remote,'HEAD:refs/heads/clean') 30000
        Check ($push.code -eq 0) ('clean push through hook: '+$push.error)
        foreach($source in @('refs/audit/private',$historyCommit)){
            $push=Invoke-SBGit $repo @('push',$remote,($source+':refs/heads/blocked')) 30000
            Check ($push.code -ne 0 -and $push.error -match 'SEC07.*codice 1') ('hook blocks explicit push source '+$source)
        }
        $push=Invoke-SBGit $repo @('push',$remote,':refs/heads/clean') 30000
        Check ($push.code -eq 0) ('hook accepts a deletion record: '+$push.error)
    } finally {
        $env:SECONDBRAIN_HOME=$savedBrain
        $env:SECONDBRAIN_SKIP_PRE_PUSH=$savedSkip
    }

    $secretOid=(Invoke-SBGit $repo @('rev-parse',($historyCommit+':README.md'))).output
    $aliasPaths=@('copy-a.txt',"copy-b`n.txt")
    $treeInput=($aliasPaths | ForEach-Object {"100644 blob $secretOid`t$_`0"}) -join ''
    $treeInput+="100644 blob $oid`tlarge-a.bin`0100644 blob $oid`tlarge-b.bin`0"
    $aliasTree=Invoke-SBGit $repo @('mktree','-z') -InputText $treeInput
    Check ($aliasTree.code -eq 0) 'created a tree with one blob at two historical paths'
    $parentTree=Invoke-SBGit $repo @('mktree','-z') -InputText ("100644 blob $secretOid`t"+$aliasPaths[0]+"`0")
    $commitCommand=@('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit-tree')
    $aliasParent=Invoke-SBGit $repo ($commitCommand+@($parentTree.output,'-p',$base,'-m','First historical name'))
    Check ($parentTree.code -eq 0 -and $aliasParent.code -eq 0) 'created a parent with only the first name'
    $aliasCommit=Invoke-SBGit $repo ($commitCommand+@($aliasTree.output,'-p',$aliasParent.output,'-p',$base,'-m','Historical path aliases'))
    Check ($aliasCommit.code -eq 0 -and (Invoke-SBGit $repo @('update-ref','refs/heads/aliases',$aliasCommit.output)).code -eq 0) 'second name is introduced only by a merge'
    $scan=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo
    $aliases=@($scan.findings|Where-Object {$_.surface -eq 'history' -and $_.rule -eq 'credential'})
    Check ($aliases.Count -eq 2 -and @($aliases|Where-Object path -CIn $aliasPaths).Count -eq 2) 'history retains exact distinct paths, including a newline'
    $reviews=@($aliases | ForEach-Object {@{rule=$_.rule;path=$_.path;fingerprint=$_.fingerprint;reason='synthetic path review'}})
    Put $policy (ConvertTo-SBJson @{schemaVersion=1;allowances=@($reviews[0])})
    $scan=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy
    Check (!$scan.ready -and $scan.complete -and @($scan.findings|Where-Object {!$_.reviewed}).path -ceq $reviews[1].path) 'reviewing one path leaves the other historical path blocked'
    Put $policy (ConvertTo-SBJson @{schemaVersion=1;allowances=$reviews})
    Check ((Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy -Initial).ready) 'reviewing both paths permits a verified history baseline'
    $sizeReviews=@('big.txt','large-a.bin' | ForEach-Object {
        @{path=$_;gitBlob=$oid;sha256=(Get-SBFileHash (Join-Path $repo 'big.txt'));reviewed=$true;reason='synthetic path review'}
    })
    Put $policy (ConvertTo-SBJson @{schemaVersion=1;allowances=$reviews;binaryReviews=$sizeReviews})
    $scan=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy -MaxTextBytes 400
    Check (!$scan.complete -and @($scan.incomplete|Where-Object surface -eq history).path -ceq 'large-b.bin') 'size review for one alias cannot cover the other'
    $scan=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy -PushObjectIds @($secretOid)
    Check (!$scan.ready -and @($scan.findings|Where-Object {!$_.reviewed}).path -ceq ('(object '+$secretOid+')')) 'path reviews cannot authorize an explicitly pushed bare blob'
    Check ((Invoke-SBGit $repo @('update-ref','-d','refs/heads/aliases')).code -eq 0) 'removed alias commit from the scanned refs'
    $treeTag=Invoke-SBGit $repo @('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','tag','-am','Synthetic tree tag','aliases-tree',$aliasTree.output)
    Check ($treeTag.code -eq 0) 'created annotated tag pointing directly to the alias tree'
    $scan=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath $policy
    Check ($scan.ready -and @($scan.findings|Where-Object {$_.surface -eq 'history' -and $_.reviewed}).Count -eq 2) 'annotated tree tags retain both path-specific reviews'
}
if('git-environment' -in $Groups){
    $runner=Join-Path $PSScriptRoot 'test-secondbrain.ps1'
    Reject {& $runner -Quick -Full} 'Quick and Full cannot be combined'
    Reject {& $runner -Quick -Only portable} 'Quick and Only cannot be combined'
    Reject {& $runner -Full -Only quick} 'Full and Only cannot be combined'
    Reject {& $runner -Only @()} 'empty Only cannot pass without running a suite'

    $before=@{};foreach($name in @('GIT_CONFIG_COUNT','GIT_CONFIG_GLOBAL','GIT_TEMPLATE_DIR')){$before[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
    $nested=Enter-SBTestGitEnvironment
    try{Assert-SBTestGitEnvironment;Check $true 'isolated Git environment is effective'}finally{Exit-SBTestGitEnvironment $nested}
    foreach($name in $before.Keys){Check ([Environment]::GetEnvironmentVariable($name,'Process') -ceq $before[$name]) ('Git environment restored: '+$name)}
    $relative=(('long-payload-segment-'+('x'*24)+'/')*5)+'payload.bin'
    $payload=Join-Path $repo $relative
    $expectedBytes=[byte[]](0,13,10,26,65,127,128,195,169,255,10,0)
    Check ($payload.Length -gt 260) 'tracked payload exceeds MAX_PATH in the central fixture'
    [void][IO.Directory]::CreateDirectory((Split-Path $payload))
    [IO.File]::WriteAllBytes($payload,$expectedBytes)
    Check ((Invoke-SBGit $repo @('-c','core.autocrlf=false','add','--',$relative)).code -eq 0) 'Git adds the long tracked path'
    Check ((Invoke-SBGit $repo @('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','Synthetic long path')).code -eq 0) 'Git commits the long tracked path'
    $blob=Invoke-SBGit $repo @('rev-parse',('HEAD:'+$relative))
    Check ($blob.code -eq 0) 'long tracked path resolves to a committed blob'
    $actual=Read-SBGitBlobs $repo @(@{Oid=$blob.output;Skip=$false})
    Check (!$actual.Missing -and [Linq.Enumerable]::SequenceEqual[byte]($expectedBytes,$actual.Bytes)) 'Git blob bytes match the original long-path payload'

    $run=New-SBTestRun ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) 'Only' @{}
    Check ($run.parent -and (Split-Path $run.directory) -eq (Split-Path $env:SECONDBRAIN_TEST_ROOT)) 'nested run is a sibling with parent evidence'
    $run.inputsBefore=Get-SBTestInputSnapshot $run.brainRoot
    Complete-SBTestRun $run $true 1 @() $false
    Check ((Read-SBJson $run.report $null).status -eq 'passed' -and (Test-Path $run.directory)) 'nested report is durable and fixtures retained'
}
'SUCCESS ESSENTIAL: '+$checks+' behavioral checks; retained fixture: '+$fixture
