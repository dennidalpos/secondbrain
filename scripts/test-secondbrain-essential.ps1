#requires -Version 7.5
# One shared synthetic brain; API tests own logic, CLI tests own process boundaries.
[CmdletBinding()]
param([string[]]$Groups=@('portable','trackers','workflows','pending'),[switch]$Extended)
$ErrorActionPreference='Stop'
# A comma-separated list arrives as one element through -File.
$Groups=@($Groups|ForEach-Object {$_ -split ','}|Where-Object {$_})
foreach($name in @('Core','Access','Host','Para','Tracker','Knowledge','Pending','Portable','Mcp','Publication')){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$name+'.psm1'))}
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
. (Join-Path $PSScriptRoot 'test-run-evidence.ps1')
$checks=0
$script:lastTick=[Diagnostics.Stopwatch]::StartNew()
function Check($Value,[string]$Message){if(!$Value){throw ('FAIL ESSENTIAL: '+$Message)};$script:checks++;if($env:SECONDBRAIN_TEST_TIMING){Add-Content -LiteralPath $env:SECONDBRAIN_TEST_TIMING -Value ("{0}`t{1}" -f $script:lastTick.ElapsedMilliseconds,$Message);$script:lastTick.Restart()};'PASS ESSENTIAL: '+$Message}
function Reject([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Check $caught $Message}
function Put([string]$Path,[string]$Text){[void][IO.Directory]::CreateDirectory((Split-Path $Path));[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Copy-SetupCatalog([string]$Root){
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1')
    $source=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    Put (Join-Path $Root 'config/prompt-catalog.schema.json') (Read-SBText (Join-Path $source 'config/prompt-catalog.schema.json'))
    $catalog=Read-SBJson (Join-Path $source 'direttive/prompts/catalog.json') @{}
    $catalog.prompts=@($catalog.prompts|Where-Object code -in 'SYS03','SYS04')
    $catalog.categories=@($catalog.categories|Where-Object id -in @($catalog.prompts.category))
    foreach($prompt in $catalog.prompts){
        $prompt.related=@($catalog.prompts|Where-Object id -ne $prompt.id|ForEach-Object id)
        foreach($folder in 'direttive/prompts','direttive/prompts/it'){
            $file=Join-Path $folder $prompt.file
            Put (Join-Path $Root $file) (Read-SBText (Join-Path $source $file))
        }
    }
    Put (Join-Path $Root 'direttive/prompts/catalog.json') (ConvertTo-SBJson $catalog)
    foreach($language in 'en','it'){
        $index=New-SBWorkflowIndex $Root $language
        Put (Join-Path $Root $index.path) $index.text
    }
}
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
    . (Join-Path $PSScriptRoot 'test-sandbox-roots.ps1')
    $package = New-SBMcpPackage -BrainRoot $brain -OutDir (Join-Path $brain '.runtime/package')
    Reject { New-SBMcpPackage -BrainRoot $brain -OutDir $package.PackageDir } 'MCP export refuses existing package'
    Reject { New-SBMcpPackage -BrainRoot $brain -OutDir (Join-Path $brain '.runtime/../outside') } 'MCP export refuses a destination outside runtime'
    $checksums = @(Get-Content -LiteralPath (Join-Path $package.PackageDir 'SHA256SUMS'))
    Check ($checksums.Count -eq $package.FileCount - 1) 'MCP export records a hash for every payload'
    foreach ($line in $checksums) {
        $hash,$relative = $line -split '  ',2
        Check ((Get-SBFileHash (Join-Path $package.PackageDir $relative)) -ceq $hash) ('MCP export checksum: '+$relative)
    }
    $desktop = [IO.Compression.ZipFile]::OpenRead((Join-Path $package.PackageDir 'claude/secondbrain.mcpb'))
    try {
        $reader = [IO.StreamReader]::new($desktop.GetEntry('manifest.json').Open())
        try { $manifestText = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $manifest = ConvertFrom-Json $manifestText
        Check ($desktop.Entries.Count -eq 2 -and $desktop.GetEntry($manifest.server.entry_point) -and
            $manifest.user_config.clone.required -and $manifest.server.mcp_config.args[1] -ceq '${user_config.clone}' -and
            !$manifestText.Contains($brain)) 'MCP Desktop bundle only uses the install-time clone path'
    } finally { $desktop.Dispose() }
    $packageReadme = Read-SBText (Join-Path $package.PackageDir 'README.md')
    Check ($packageReadme.Contains('code --add-mcp') -and $packageReadme.Contains('cursor://anysphere.cursor-deeplink/mcp/install') -and
        $packageReadme.Contains('.agents/mcp_config.json')) 'MCP export documents the import commands and project path'
    $savedAntigravityProfile=$env:USERPROFILE
    try {
        $env:USERPROFILE=Join-Path $fixture 'antigravity-profile'
        $sharedConfig=Join-Path $env:USERPROFILE '.gemini/config/mcp_config.json'
        $legacyConfig=Join-Path $env:USERPROFILE '.gemini/antigravity/mcp_config.json'
        $antigravityWorkspace=Join-Path $fixture 'antigravity-workspace'
        [void][IO.Directory]::CreateDirectory($antigravityWorkspace)
        $default=Get-SBMcpPairing -BrainRoot $brain -Target antigravity
        Check ($default.ConfigFile -eq $sharedConfig -and (Get-SBFileHash $sharedConfig) -eq 'absent') 'Antigravity fresh user preview selects the documented shared path'
        Put $legacyConfig '{"mcpServers":{}}'
        $legacy=Get-SBMcpPairing -BrainRoot $brain -Target antigravity
        Check ($legacy.ConfigFile -eq $legacyConfig) 'Antigravity legacy-only profile preserves its existing configuration path'
        Put $sharedConfig '{"mcpServers":{}}'
        $shared=Get-SBMcpPairing -BrainRoot $brain -Target antigravity
        Check ($shared.ConfigFile -eq $sharedConfig) 'Antigravity shared config takes precedence when both files exist'
        $project=Get-SBMcpPairing -BrainRoot $brain -Target antigravity -Scope project -WorkspacePath $antigravityWorkspace
        Check ($project.ConfigFile -eq (Join-Path $antigravityWorkspace '.agents/mcp_config.json') -and (Get-SBFileHash $project.ConfigFile) -eq 'absent') 'Antigravity project preview selects the documented workspace path'
    } finally { $env:USERPROFILE=$savedAntigravityProfile }
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
    Check ($LASTEXITCODE -eq 0 -and $messages[0].result.protocolVersion -eq '2025-03-26' -and $messages[1].result.tools.Count -eq 11) 'real MCP stdio negotiates and exposes eleven tools'
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
            $null = Set-SBMcpConfiguration -BrainRoot $brain -Target $target -ConfigFile $file -Scope user -ApproveAllTools -BackupRoot $cfg.backupRoot
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
        $oldProfile=$env:USERPROFILE;$oldBrain=$env:SECONDBRAIN_HOME;$oldState=$env:SECONDBRAIN_STATE_ROOT
        try{
            Copy-SetupCatalog $brain
            $env:USERPROFILE=Join-Path $runtime 'synthetic-profile'
            [void][IO.Directory]::CreateDirectory($env:USERPROFILE)
            $setupScript=Join-Path $brain 'scripts/secondbrain.ps1'
            $cursorConfig=Join-Path $env:USERPROFILE '.cursor/mcp.json'
            $setupPaths=Get-SBSetupPaths $brain
            $previewPaths=@($setupPaths.report,$setupPaths.selection,(Get-SBHostConfigPath $brain),$cursorConfig)
            $beforePreview=@($previewPaths|ForEach-Object {Get-SBFileHash $_})
            $readOnlyPreview=(& pwsh -NoProfile -File $setupScript -Setup -PreviewOnly -Roots $repo -Select $repo -McpTargets cursor)|ConvertFrom-Json -AsHashtable
            $afterPreview=@($previewPaths|ForEach-Object {Get-SBFileHash $_})
            Check ($LASTEXITCODE -eq 0 -and $readOnlyPreview.mode -eq 'single' -and !$readOnlyPreview.applied -and !$readOnlyPreview.confirmed -and !$readOnlyPreview.discovery.report -and $readOnlyPreview.activation.repositories.Count -eq 1 -and $readOnlyPreview.mcp.targets[0].ConfigFile -eq $cursorConfig -and ($beforePreview -join ',') -eq ($afterPreview -join ',')) 'read-only setup plans activation and MCP without writing discovery, selection or pairing files'
            $teamError=(& pwsh -NoProfile -File $setupScript -Setup -PreviewOnly -TeamRoot $repo -Language en 2>&1) -join "`n"
            Check ($LASTEXITCODE -eq 2 -and $teamError.Contains('reachable UNC root')) 'team preview rejects a local path'
            $allError=(& pwsh -NoProfile -File $setupScript -Setup -PreviewOnly -All -Roots $repo -Language en 2>&1) -join "`n"
            Check ($LASTEXITCODE -eq 2 -and $allError.Contains('use -AllIdes')) 'Setup rejects the removed -All (no silent binding to -AllIdes) with the next step'
            $personalRoot=Join-Path $fixture 'personal'
            $personalDossier=Join-Path $personalRoot '02-areas/Personal'
            foreach($file in 'para.json','repository.json','brief.md','context.md','memory.md','tracker.json','history/seed/report.md'){
                Put (Join-Path $personalDossier $file) (Read-SBText (Join-Path $dossier $file))
            }
            $personalContext=Join-Path $personalDossier 'context.md'
            $personalHash=Get-SBFileHash $personalContext
            $teamPreview=Invoke-SBSetup -BrainRoot $brain -PersonalRoot $personalRoot -PreviewOnly -Roots $repo -Select $repo
            $conflicts=@($teamPreview.dossierConflicts)
            Check ($conflicts.Count -eq 1 -and $conflicts[0].identity -eq $identity -and $conflicts[0].checkout -eq $repo -and $conflicts[0].personalDossier -eq $personalDossier -and $conflicts[0].teamDossier -eq $dossier -and (Get-SBFileHash $personalContext) -eq $personalHash -and (Get-SBFileHash $setupPaths.report) -eq $afterPreview[0]) 'team preview identifies both dossiers and the checkout without writing state'
            if($personalRoot -match '^(?<drive>[A-Za-z]):(?<tail>\\.*)$'){
                $loopback='\\localhost\'+$Matches.drive+'$'+$Matches.tail
                if([IO.Directory]::Exists($loopback)){
                    Put (Join-Path $personalRoot 'config/shared.json') (Read-SBText (Join-Path $brain 'config/shared.json'))
                    $teamCli=(& pwsh -NoProfile -File $setupScript -Setup -PreviewOnly -TeamRoot $loopback -Roots $repo -Select $repo -ApproveExistingBlocks)|ConvertFrom-Json -AsHashtable
                    Check ($LASTEXITCODE -eq 0 -and $teamCli.mode -eq 'team' -and $teamCli.dossierConflicts.Count -eq 1 -and (Test-SBSamePath $teamCli.dossierConflicts[0].teamDossier $personalDossier) -and ![IO.Directory]::Exists((Join-Path $personalRoot '.runtime'))) 'team CLI reports the conflict over loopback UNC without creating runtime'
                    $conflict=(& pwsh -NoProfile -File $setupScript -Setup -TeamRoot $loopback -Roots $repo -Select $repo -ApproveExistingBlocks -Yes -Apply -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
                    Check ($LASTEXITCODE -eq 1 -and $conflict.stage -eq 'dossier-conflict' -and !$conflict.applied -and $conflict.dossierConflicts.Count -eq 1 -and ![IO.Directory]::Exists((Join-Path $personalRoot '.runtime'))) 'team conflict stops activation before writes even with explicit confirmation'

                    $teamRepo=Join-Path $fixture 'team-repo'
                    [void][IO.Directory]::CreateDirectory($teamRepo)
                    Check ((Invoke-SBGit $teamRepo @('init','-q')).code -eq 0 -and (Invoke-SBGit $teamRepo @('remote','add','origin','https://github.com/test/team-fixture.git')).code -eq 0) 'team checkout has a separate synthetic identity'
                    try{
                        $env:SECONDBRAIN_STATE_ROOT=$null
                        $missingState=(& pwsh -NoProfile -File $setupScript -Setup -TeamRoot $loopback -Roots $teamRepo -Select $teamRepo -Yes -Apply -NoRegisterEnvironment -Language en 2>&1) -join [Environment]::NewLine
                    }finally{$env:SECONDBRAIN_STATE_ROOT=$oldState}
                    Check ($LASTEXITCODE -eq 2 -and $missingState.Contains('requires SECONDBRAIN_STATE_ROOT') -and ![IO.Directory]::Exists((Join-Path $personalRoot '.runtime'))) 'team activation refuses to keep workstation state on the share'
                    foreach($file in 'AGENTS.global_ide.md','workstation.template.md'){
                        Put (Join-Path $personalRoot ('direttive/'+$file)) (Read-SBText (Join-Path $brain ('direttive/'+$file)))
                    }
                    Put (Join-Path $personalRoot 'direttive/approved.json') (ConvertTo-SBJson $approval)
                    foreach($file in 'VERSION','config/tracker.schema.json','config/prompt-catalog.schema.json','scripts/mcp-server.ps1'){
                        Put (Join-Path $personalRoot $file) (Read-SBText (Join-Path $brain $file))
                    }
                    Copy-SetupCatalog $personalRoot
                    $env:SECONDBRAIN_STATE_ROOT=Join-Path $fixture 'team-state'
                    $fixtureProfile=$env:USERPROFILE
                    try{
                        $env:USERPROFILE=Join-Path $fixture 'team-profile'
                        [void][IO.Directory]::CreateDirectory($env:USERPROFILE)
                        $teamOutput=(('APPLICA'|& pwsh -NoProfile -File $setupScript -Setup -Interactive -TeamRoot $loopback -Roots $teamRepo -Select $teamRepo -McpTargets cursor -NoRegisterEnvironment) -join "`n")
                        $teamCode=$LASTEXITCODE
                        $team=$teamOutput.Substring($teamOutput.LastIndexOf("`n{`n")+1)|ConvertFrom-Json -AsHashtable
                        Check ($teamCode -eq 0 -and $team.applied -and $team.mode -eq 'team' -and $team.check.mode -eq 'sync' -and $team.check.filesAligned) ('one interactive command applies the team plan over loopback UNC: '+($team.check|ConvertTo-Json -Compress))
                        $teamMcp=Read-SBJson (Join-Path $env:USERPROFILE '.cursor/mcp.json') @{}
                        $teamServer=(Join-Path $loopback 'scripts/mcp-server.ps1').Replace('\','/')
                        Check ($team.mcp.complete -and $teamMcp.mcpServers.secondbrain.args -contains $teamServer) 'team MCP points to the authoritative root from the local profile'
                        $teamConfig=Read-SBConfiguration -BrainRoot $loopback -ReadOnly
                        $teamState=$teamConfig.localStateRoot
                        foreach($file in 'workstation.json','discovery.json','selection.json','setup-result.json','state.json','inventory.json','ide-map.json'){
                            Check ([IO.File]::Exists((Join-Path $teamState $file))) ('team workstation file stays local: '+$file)
                        }
                        $teamDossier=Join-Path $loopback $team.activation.repositories[0].dossier
                        Check ($teamState.StartsWith($env:SECONDBRAIN_STATE_ROOT) -and [IO.File]::Exists((Join-Path $teamDossier 'tracker.json')) -and [IO.File]::Exists((Join-Path $teamRepo 'AGENTS.md')) -and [IO.Directory]::Exists((Join-Path $loopback '.runtime/access/recovery')) -and ![IO.Directory]::Exists((Join-Path $loopback '.runtime/hosts'))) 'team share contains dossier and coordination while Setup keeps workstation files local'
                        $teamRepeat=(& pwsh -NoProfile -File $setupScript -Setup -TeamRoot $loopback -Roots $teamRepo -Select $teamRepo -Yes -Apply -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
                        Check ($LASTEXITCODE -eq 0 -and $teamRepeat.applied -and $teamRepeat.activation.repositories[0].dossier -eq $team.activation.repositories[0].dossier) 'team setup repeats with the existing binding'
                    }finally{$env:SECONDBRAIN_STATE_ROOT=$oldState;$env:USERPROFILE=$fixtureProfile}
                }
            }
            $preview=(& pwsh -NoProfile -File $setupScript -Setup -Roots $repo -Select $repo -McpTargets cursor -Yes -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
            Check ($LASTEXITCODE -eq 0 -and $preview.mcp.preview -and $preview.mcp.targets[0].ConfigFile -eq $cursorConfig -and !(Test-Path -LiteralPath $cursorConfig)) 'setup previews the MCP destination without pairing'
            $beforeRefusal=@($previewPaths|ForEach-Object {Get-SBFileHash $_})
            $interactiveOutput=(('skip'|& pwsh -NoProfile -File $setupScript -Setup -Roots $repo -Select $repo -McpTargets cursor -Yes -Interactive -Apply -NoRegisterEnvironment -Language en) -join "`n")
            $afterRefusal=@($previewPaths|ForEach-Object {Get-SBFileHash $_})
            $activationAt=$interactiveOutput.IndexOf('Workstation activation preview')
            $previewAt=$interactiveOutput.IndexOf('User-level MCP pairing preview')
            $resultAt=$interactiveOutput.IndexOf('"stage": "preview"')
            Check ($LASTEXITCODE -eq 0 -and $activationAt -ge 0 -and $previewAt -gt $activationAt -and $resultAt -gt $previewAt -and ($beforeRefusal -join ',') -eq ($afterRefusal -join ',')) 'interactive setup previews activation and MCP and leaves files untouched on refusal'
            $setupOutput=(('APPLICA'|& pwsh -NoProfile -File $setupScript -Setup -Roots $repo -Select $repo -McpTargets cursor -Interactive -NoRegisterEnvironment) -join "`n")
            $setup=$setupOutput.Substring($setupOutput.LastIndexOf("`n{`n")+1)|ConvertFrom-Json -AsHashtable
            Check ($LASTEXITCODE -eq 0 -and $setup.applied -and $setup.check.mode -eq 'sync' -and $setup.mcp.permissionConfigurationComplete -and [IO.File]::Exists($setup.setupReport)) 'setup applies sync, named approvals and a persistent report in an isolated profile'
            $repeat=(& pwsh -NoProfile -File $setupScript -Setup -Roots $repo -Select $repo -McpTargets cursor -Yes -Apply -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
            Check ($LASTEXITCODE -eq 0 -and $repeat.mcp.items[0].PermissionAction -eq 'unchanged') 'setup repeats with the same repository identity and MCP rules'
            $observationConfig=Read-SBConfiguration -BrainRoot $brain -ReadOnly
            $observationConfig.ides=@(@{id='fixture-cursor';name='Cursor';mode='manual';profile='fixture';accountAlias='fixture'})
            $observationPath=Join-Path $runtime 'mcp-observation.json'
            $evidence=Join-Path $runtime 'mcp-observation-evidence.txt'
            Put $evidence 'Synthetic loading and tool consent observation'
            $observation=@{ideId='fixture-cursor';workstationId=$hostId;profile='fixture';accountAlias='fixture';accountVerified=$true;sessionId='fixture-session';observedAt=[DateTimeOffset]::UtcNow.ToString('o');observedHash=(Get-SBTextHash (Get-SBPortableGlobal $brain).Trim());loadingVerified=$true;evidencePath=$evidence;evidenceSha256=(Get-SBFileHash $evidence)}
            Put $observationPath (ConvertTo-SBJson @{schemaVersion=1;observations=@($observation)})
            $check=Invoke-SBPortableSync -Config $observationConfig -Check -ObservationPath $observationPath
            Check (@((@($check.issues)+@($check.environment))|Where-Object {$_.kind -eq 'mcp-consent-unverified' -and $_.id -eq 'fixture-cursor'}).Count -eq 1 -and $check.liveLoadingVerified) 'MCP consent remains unverified when loading is observed without a popup result'
            foreach($outcome in 'popup-shown','no-popup','unknown'){
                $observation.mcpConsent=@{tool='get_prompt_home';outcome=$outcome}
                Put $observationPath (ConvertTo-SBJson @{schemaVersion=1;observations=@($observation)})
                $check=Invoke-SBPortableSync -Config $observationConfig -Check -ObservationPath $observationPath
                Check (('mcp-consent-unverified' -in (@($check.issues)+@($check.environment)).kind) -eq ($outcome -eq 'unknown')) ('MCP receipt checks the observed outcome: '+$outcome)
            }
            $observation.mcpConsent.outcome='no-popup'
            Put $observationPath (ConvertTo-SBJson @{schemaVersion=1;observations=@($observation)})
            Put $evidence 'Modified evidence'
            $check=Invoke-SBPortableSync -Config $observationConfig -Check -ObservationPath $observationPath
            Check ('mcp-consent-unverified' -in (@($check.issues)+@($check.environment)).kind) 'MCP consent cannot be verified with changed evidence'
            $legacyConfig=$repeat.activation.configuration
            $legacyHash=Get-SBFileHash $legacyConfig
            $env:SECONDBRAIN_STATE_ROOT=Join-Path $fixture 'external-state'
            $external=(& pwsh -NoProfile -File $setupScript -Setup -Roots $repo -Select $repo -Yes -Apply -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
            $externalCode=$LASTEXITCODE
            $local=Read-SBConfiguration -BrainRoot $brain -ReadOnly
            Check ($externalCode -eq 0 -and $external.applied -and $local.configPath -eq $external.activation.configuration -and $local.localStateRoot.StartsWith($env:SECONDBRAIN_STATE_ROOT) -and $local.runtimeRoot -ine $local.localStateRoot) 'external setup uses the workstation state root'
            Check ([IO.File]::Exists((Join-Path $local.localStateRoot 'ide-map.json')) -and [IO.File]::Exists($external.setupReport) -and (Get-SBFileHash $legacyConfig) -eq $legacyHash -and (Test-SBSamePath $local.coordinationRoot (Join-Path $brain '.runtime/access'))) 'local setup and IDE state are separate from legacy bytes and shared coordination'
            # Allowlist (#413): one validated repository per call with preview; repositories outside the list are not read or listed; Setup no longer takes -All.
            $allowRoot=Join-Path $fixture 'allow';$allowFile=Get-SBAllowlistPath $brain
            foreach($name in 'a','b'){
                $dir=Join-Path $allowRoot $name;[void][IO.Directory]::CreateDirectory($dir)
                [void](Invoke-SBGit $dir @('init','-q'));[void](Invoke-SBGit $dir @('remote','add','origin',('https://github.com/test/allow-'+$name+'.git')))
            }
            $allowA=Join-Path $allowRoot 'a'
            try{
                $addPreview=(& pwsh -NoProfile -File $setupScript -AddRepo $allowA -Customer Acme)|ConvertFrom-Json -AsHashtable
                Check ($LASTEXITCODE -eq 0 -and !$addPreview.applied -and $addPreview.entry.identity -ceq 'github.com/test/allow-a' -and $addPreview.entry.customer -ceq 'Acme' -and ![IO.File]::Exists($allowFile)) 'add-repo previews the entry without writing the allowlist'
                $addApply=(& pwsh -NoProfile -File $setupScript -AddRepo $allowA -Customer Acme -ApplyAdd -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
                $list=Read-SBAllowlist $brain
                Check ($LASTEXITCODE -eq 0 -and $addApply.applied -and $addApply.setup.applied -and @($list.repositories).Count -eq 1 -and $list.repositories[0].customer -ceq 'Acme') 'add-repo records the repository and activates it in one call'
                $found=Invoke-SBHostDiscovery -BrainRoot $brain -Roots @($allowRoot)
                Check (@($found.repositories|Where-Object {$_.kind -eq 'repository'}).Count -eq 1 -and @($found.repositories.identity) -contains 'github.com/test/allow-a' -and @($found.excluded|Where-Object {$_.reason -eq 'outside-allowlist'}).Count -eq 1) 'a repository outside the allowlist is neither read nor listed'
                # PowerShell would still bind the abbreviation -All to -AllIdes: the check is on the declared parameters.
                $allOut=@(& pwsh -NoProfile -File $setupScript -Setup -All 2>&1)
                Check ($LASTEXITCODE -eq 2 -and ($allOut -join ' ').Contains('-AllIdes') -and !(Get-Command Invoke-SBSetup).Parameters.ContainsKey('All')) 'setup rejects -All with a clear error instead of binding -AllIdes'
                # New project from scratch (#416): one command creates folder, git, allowlist, dossier, tracker seed, greenfield and customer.
                $newPath=Join-Path $allowRoot 'brandnew'
                $newPreview=(& pwsh -NoProfile -File $setupScript -NewProject $newPath -Remote 'https://github.com/test/brandnew.git' -Customer 'Acme')|ConvertFrom-Json -AsHashtable
                Check ($LASTEXITCODE -eq 0 -and !$newPreview.applied -and $newPreview.createFolder -and ![IO.Directory]::Exists($newPath)) 'new-project previews without creating anything'
                $newRaw=(& pwsh -NoProfile -File $setupScript -NewProject $newPath -Remote 'https://github.com/test/brandnew.git' -Customer 'Acme' -ApplyNew -NoRegisterEnvironment 2>&1|Out-String)
                $newCode=$LASTEXITCODE
                Check ($newCode -eq 0) ('new-project apply succeeds: '+$newRaw.Substring(0,[math]::Min(900,$newRaw.Length)))
                $newApplied=$newRaw|ConvertFrom-Json -AsHashtable
                $newDossier=Join-Path $brain $newApplied.dossier
                $newMeta=Read-SBJson (Join-Path $newDossier 'repository.json') $null
                $newTracker=Read-SBJson (Join-Path $newDossier 'tracker.json') $null
                Check ($newCode -eq 0 -and $newApplied.applied -and [IO.Directory]::Exists((Join-Path $newPath '.git')) -and $newMeta.identity -ceq 'github.com/test/brandnew' -and $newMeta.lifecycle -ceq 'greenfield' -and $newMeta.customer -ceq 'Acme' -and $newTracker.schemaVersion -eq 1 -and !$newTracker.tasks.Count -and [IO.File]::Exists((Join-Path $newDossier 'context.md')) -and [IO.File]::Exists((Join-Path $newDossier 'memory.md'))) ('new-project creates checkout, dossier, tracker seed, greenfield lifecycle and customer: '+$newCode+' '+($newMeta|ConvertTo-Json -Compress -Depth 3))
                $newParaCheck=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/para.ps1') -Check -ConfigPath $configPath 2>&1|Out-String)
                Check ($LASTEXITCODE -eq 0) ('the new dossier passes the PARA check: '+$newParaCheck.Substring(0,[math]::Min(500,$newParaCheck.Length)))
            }finally{if([IO.File]::Exists($allowFile)){[IO.File]::Delete($allowFile)}}
        }finally{$env:USERPROFILE=$oldProfile;$env:SECONDBRAIN_HOME=$oldBrain;$env:SECONDBRAIN_STATE_ROOT=$oldState}
    }
    $freshCheckout=Join-Path $fixture 'fresh'
    [void][IO.Directory]::CreateDirectory($freshCheckout)
    Check ((Invoke-SBGit $freshCheckout @('init','-q')).code -eq 0) 'fresh checkout initialized'
    Check ((Invoke-SBGit $freshCheckout @('remote','add','origin','https://github.com/test/fresh.git')).code -eq 0) 'fresh checkout has a synthetic identity'
    $freshReport=Join-Path $runtime 'fresh-discovery.json'
    $freshDiscovery=Invoke-SBHostDiscovery -BrainRoot $brain -Roots @($freshCheckout) -ReportPath $freshReport
    $freshSelection=Join-Path $runtime 'fresh-selection.json'
    Put $freshSelection (ConvertTo-SBJson @{schemaVersion=1;confirmed=$true;confirmation='synthetic greenfield bootstrap';reportPath=$freshReport;reportSha256=(Get-SBFileHash $freshReport);repositories=@(@{id=$freshDiscovery.repositories[0].id});ides=@()})
    $previousConfig=Read-SBText $configPath
    try {
        $activated=(& pwsh -NoProfile -File (Join-Path $brain 'scripts/secondbrain.ps1') -Activate -SelectionPath $freshSelection -Apply -NoRegisterEnvironment)|ConvertFrom-Json -AsHashtable
        Check ($LASTEXITCODE -eq 0 -and $activated.applied -and !$activated.repositories[0].trackerImportRequired) 'fresh CLI activation needs no tracker import'
        $freshDossier=Join-Path $brain $activated.repositories[0].dossier
        $freshTracker=Join-Path $freshDossier 'tracker.json'
        $freshMetadata=Read-SBJson (Join-Path $freshDossier 'repository.json') $null
        $seed=Read-SBJson $freshTracker $null
        Check ($freshMetadata.tracker.location -ceq 'dossier' -and $freshMetadata.tracker.path -ceq 'tracker.json' -and $freshMetadata.tracker.schemaVersion -eq 1 -and $seed.schemaVersion -eq 1 -and $seed.repository -ceq 'github.com/test/fresh' -and !$seed.tasks.Count) 'bootstrap declares and seeds the current schema directly'
        $seedHash=Get-SBFileHash $freshTracker
        $knowledge=Join-Path $brain 'scripts/knowledge.ps1'
        $lifecycle=(& pwsh -NoProfile -File $knowledge -ConfigPath $activated.configuration -CheckoutPath $freshCheckout -SetLifecycle greenfield)|ConvertFrom-Json -AsHashtable
        Check ($LASTEXITCODE -eq 0 -and $lifecycle.lifecycle -ceq 'greenfield') 'SYS13 entry point declares greenfield'
        $reopened=(& pwsh -NoProfile -File $knowledge -ConfigPath $activated.configuration -CheckoutPath $freshCheckout -Startup -NoRecovery)|ConvertFrom-Json -AsHashtable
        Check ($LASTEXITCODE -eq 0 -and $reopened.repository -ceq 'github.com/test/fresh' -and (Test-SBSamePath $reopened.taskSource $freshTracker) -and (Get-SBFileHash $freshTracker) -ceq $seedHash) 'separate CLI process reopens the declared greenfield tracker without rewriting it'
    } finally {Put $configPath $previousConfig}
}
if('trackers' -in $Groups){
    $metadataPath=Join-Path $dossier 'repository.json'
    $metadataBytes=Read-SBText $metadataPath
    $trackerBytes=Read-SBText $trackerPath
    $otherTrackerPath=Join-Path $otherDossier 'tracker.json'
    $otherTrackerBytes=Read-SBText $otherTrackerPath
    $metadata=Read-SBJson $metadataPath $null
    $metadata.lifecycle='greenfield'
    $alternative=Join-Path $repo 'legacy-tasks.json'
    Put $alternative '{"tasks":[{"id":"OLD","title":"Original source"}]}'
    $alternativeHash=Get-SBFileHash $alternative
    $resolve=@{BrainRoot=$brain;Identity=$identity;CheckoutPath=$repo;AllowedOwners=@()}
    $heldTracker=$trackerPath+'.retained'
    try {
        Put $metadataPath (ConvertTo-SBJson $metadata)
        Check ((Resolve-SBTracker @resolve).data.tasks[0].id -ceq 'T-1') 'greenfield resolves the declared tracker even with an old source nearby'
        [void]$metadata.Remove('tracker')
        Put $metadataPath (ConvertTo-SBJson $metadata)
        $metadataHash=Get-SBFileHash $metadataPath
        $currentHash=Get-SBFileHash $trackerPath
        $otherActive=Read-SBJson $otherTrackerPath $null
        $otherActive.tasks[0].status='todo'
        Put $otherTrackerPath (ConvertTo-SBJson $otherActive)
        $rows=@(Get-SBGlobalTasks -BrainRoot $brain -All)
        $unverified=@($rows|Where-Object status -eq 'unverified')
        Check ($unverified.Count -eq 1 -and $unverified[0].repository -ceq $identity -and $unverified[0].reasonCode -ceq 'tracker.greenfield.declaration.required' -and @($rows|Where-Object id -eq 'O-1').Count -eq 1) 'global tasks isolate a greenfield dossier without a declaration'
        $blocked=$null
        try{Resolve-SBTracker @resolve|Out-Null}catch{$blocked=$_}
        Check ((Test-SBError $blocked 'tracker.greenfield.declaration.required') -and (Get-SBFileHash $metadataPath) -ceq $metadataHash -and (Get-SBFileHash $trackerPath) -ceq $currentHash -and (Get-SBFileHash $alternative) -ceq $alternativeHash) 'ordinary lookup refuses the original source and preserves all bytes'
        $metadata.tracker=@{location='dossier';path='tracker.json';schemaVersion=1}
        Put $metadataPath (ConvertTo-SBJson $metadata)
        $metadataHash=Get-SBFileHash $metadataPath
        Move-Item -LiteralPath $trackerPath -Destination $heldTracker
        $blocked=$null
        try{Resolve-SBTracker @resolve|Out-Null}catch{$blocked=$_}
        Check ((Test-SBError $blocked 'tracker.declared.missing') -and !(Test-Path -LiteralPath $trackerPath) -and (Get-SBFileHash $heldTracker) -ceq $currentHash -and (Get-SBFileHash $metadataPath) -ceq $metadataHash -and (Get-SBFileHash $alternative) -ceq $alternativeHash) 'missing declared tracker fails without conversion or fallback'
        Move-Item -LiteralPath $heldTracker -Destination $trackerPath
        $obsolete=Read-SBJson $trackerPath $null
        $obsolete.schemaVersion=0
        Put $trackerPath (ConvertTo-SBJson $obsolete)
        $obsoleteHash=Get-SBFileHash $trackerPath
        $blocked=$null
        try{Resolve-SBTracker @resolve|Out-Null}catch{$blocked=$_}
        Check ((Test-SBError $blocked 'tracker.schema.version') -and (Get-SBFileHash $trackerPath) -ceq $obsoleteHash -and (Get-SBFileHash $metadataPath) -ceq $metadataHash -and (Get-SBFileHash $alternative) -ceq $alternativeHash) 'incompatible declared schema fails without changing the payload or alternate source'
    } finally {
        if(Test-Path -LiteralPath $heldTracker){Move-Item -LiteralPath $heldTracker -Destination $trackerPath}
        Put $metadataPath $metadataBytes
        Put $trackerPath $trackerBytes
        Put $otherTrackerPath $otherTrackerBytes
    }
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1} 'empty update rejected'
    foreach($field in @('Priority','Execution')){$bad=@{$field='invalid'};Reject {Update-SBTrackerTask @argsBase -TaskId T-1 @bad} ('invalid '+$field+' rejected')}
    $snapshot=Read-SBJson $trackerPath $null
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Priority P1)
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($task.priority -eq 'P1' -and $task.status -eq $snapshot.tasks[0].status -and $task.execution -eq $snapshot.tasks[0].execution) 'single update preserves omitted fields'
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1 -Priority P5} 'priority beyond P4 rejected'
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Priority P4)
    Check ((Read-SBJson $trackerPath $null).tasks[0].priority -eq 'P4') 'P4 priority accepted'
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Priority P1)
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Execution user_required -DependsOn @('T-2') -Stream urgent -StateReason 'synthetic')
    $task=(Read-SBJson $trackerPath $null).tasks[0]
    Check ($task.dependencies[0].id -eq 'T-2' -and $task.extensions.stream -eq 'urgent' -and $task.execution -eq 'user_required') 'combined metadata update'
    Reject {Update-SBTrackerTask @argsBase -TaskId T-1 -Requires 'gpu'} 'unknown required capability rejected'
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Requires 'computer-use;computer-use')
    Check ((@((Read-SBJson $trackerPath $null).tasks[0].extensions.requires) -join ';') -ceq 'computer-use') 'requires accepts the allowed capability, de-duplicated, also as a ;-separated string'
    [void](Update-SBTrackerTask @argsBase -TaskId T-1 -Requires @())
    Check (!(Read-SBJson $trackerPath $null).tasks[0].extensions.ContainsKey('requires')) 'empty requires clears the capability list'
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
    $empty=& (Get-Module SecondBrain.Knowledge) {New-SBStartupPackage -Record @{identity='github.com/test/empty'} -Tracker @{path=$null;source='absent';declared=$false} -TOC '# Empty' -ContextText '# Context' -MemoryText '# Memory' -Profile Slim -Budget 25000}
    Check ($empty.withinBudget -and $empty.parts.tasks.Contains('Nessun task selezionato.') -and !$empty.parts.tasks.Contains('Nessun task pronto.')) 'startup without selected tasks reports selection rather than claiming the tracker has no ready work'
    $default=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -Profile Slim
    Check ($default.budget -eq 25000) 'Slim API uses the shared 25000-character default'
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
    $padding=25000-[int]$startup.characters-$prefix.Length-1
    foreach($extra in @(-1,0,1)){
        Put $contextPath ($originalContext+$prefix+('x'*($padding+$extra))+"`n")
        $contextHash=Get-SBFileHash $contextPath
        $sized=Get-SBStartupContext -BrainRoot $brain -Dossier $dossier -Budget (Get-SBSlimStartupBudget) -Profile Slim
        Check ($sized.withinBudget -and $sized.uncompactedCharacters -eq (25000+$extra) -and $sized.compacted -eq ($extra -gt 0) -and (Get-SBFileHash $contextPath) -ceq $contextHash) ('Slim 25000-character boundary '+$extra)
    }
    $longSection=$prefix.TrimStart("`n")+('x'*($padding+1))+"`n"
    Check ($sized.parts.context.Contains('Keep bytes.') -and (!$sized.parts.context.Contains('Long example') -or $sized.parts.context.Contains($longSection)) -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $before) 'Slim preserves prioritized sections, whole blocks and source bytes'
    $mcpStartup=Invoke-SBMcpToolCall $brain 'get_startup_context' @{repository=$identity} | ConvertFrom-Json -AsHashtable
    Check ($mcpStartup.budget -eq 25000 -and $mcpStartup.compacted -and $mcpStartup.parts.context -ceq $sized.parts.context) 'MCP and CLI compose the same compacted startup'
    Put $contextPath $originalContext
    $candidatePath=Join-Path $brain '.runtime/candidate.json'
    $candidate=@{schemaVersion=1;repository=$identity;sources=@{};summaries=@{};openTaskIds=@((Read-SBJson $trackerPath $null).tasks|Where-Object status -notin @('done','cancelled')|ForEach-Object id);reviewed=$true;reviewNote='synthetic conservation test'}
    foreach($name in @('context.md','memory.md')){$candidate.sources[$name]=Get-SBFileHash (Join-Path $dossier $name);$candidate.summaries[$name]=Read-SBText (Join-Path $dossier $name)}
    $candidate.summaries['context.md']=$originalContext.Replace('Stato corrente','Current state').Replace('Vincoli','Constraints').Replace('Problemi aperti','Open issues').Replace('Prossimo passo','Next step')
    Check (@(Get-SBMissingContextSection $originalContext).Count -eq 0) 'Italian context remains valid'
    Check (@(Get-SBMissingContextSection ($candidate.summaries['context.md'].Replace('## Next step', "~~~markdown`n## Next step`n~~~"))).Count -eq 1) 'fenced headings do not satisfy context validation'
    Put $candidatePath (ConvertTo-SBJson $candidate)
    $preview=Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -CheckoutPath $repo
    Check (!$preview.applied -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $before) 'compaction preview preserves source'
    [void](Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -CheckoutPath $repo -Apply)
    Check ((Get-SBFileHash (Join-Path $dossier ('history/compaction/'+$before.ToLowerInvariant()+'/memory.md'))) -ceq $before) 'compaction preserves byte-exact original'
    Reject {Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $dossier -CandidatePath $candidatePath -BackupRoot $cfg.backupRoot -Budget 16000 -Apply} 'stale compaction candidate rejected'
}
if('workflows' -in $Groups){
    # Perimeter (#412): with project isolation active nothing reads or writes another repository's data, through knowledge.ps1, MCP tools and work.ps1.
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1')
    $knowledgeCli=Join-Path $brain 'scripts/knowledge.ps1';$workCli=Join-Path $brain 'scripts/work.ps1'
    Put $configPath (ConvertTo-SBJson $cfg)
    $otherIdentity='github.com/test/other';$marker='PERIMETER-MARKER-OTHER'
    $otherContext=Join-Path $otherDossier 'context.md';$otherContextBytes=Read-SBText $otherContext
    Put $otherContext ("# Other context`n`n## Stato corrente`n$marker`n")
    try{
        Check (Test-SBProjectIsolation $brain) 'project isolation is active by default'
        $cliTasks=(& pwsh -NoProfile -File $knowledgeCli -Tasks -ConfigPath $configPath -CheckoutPath $repo 2>&1|Out-String)
        Check ($LASTEXITCODE -eq 0 -and $cliTasks -match 'T-1' -and $cliTasks -notmatch 'O-1' -and $cliTasks -notmatch [regex]::Escape($otherIdentity)) 'knowledge tasks from a checkout list only that repository'
        $cliSearch=(& pwsh -NoProfile -File $knowledgeCli -Search $marker -ConfigPath $configPath -CheckoutPath $repo 2>&1|Out-String)
        Check (($cliSearch|ConvertFrom-Json).totalMatches -eq 0) 'knowledge search from a checkout never returns another repository data'
        foreach($flags in @(@('-Tasks','-All'),@('-Search',$marker,'-AllDossiers'))){
            $out=(& pwsh -NoProfile -File $knowledgeCli @flags -ConfigPath $configPath -CheckoutPath $repo 2>&1|Out-String)
            Check ($LASTEXITCODE -ne 0 -and $out -notmatch $marker -and $out -notmatch 'O-1') ('knowledge global view refused: '+($flags -join ' '))
        }
        # #434: a search run outside any checkout (no -CheckoutPath, working folder not a repository) has no project to scope to and is refused.
        # Outside the brain checkout: a folder inside it would resolve to SecondBrain's own Git identity.
        $noProject=Join-Path ([IO.Path]::GetTempPath()) ('sb-no-project-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($noProject)
        Push-Location $noProject
        try{$unscoped=(& pwsh -NoProfile -File $knowledgeCli -Search $marker -ConfigPath $configPath 2>&1|Out-String);$unscopedCode=$LASTEXITCODE}finally{Pop-Location;Remove-Item -LiteralPath $noProject -Force -Recurse -ErrorAction SilentlyContinue}
        Check ($unscopedCode -ne 0 -and $unscoped -notmatch [regex]::Escape($marker) -and $unscoped -notmatch 'O-1') 'knowledge search without a resolved project is refused by the isolation'
        foreach($case in @(@('get_ready_tasks',@{all=$true}),@('search_knowledge',@{query=$marker;allDossiers=$true}),@('search_knowledge',@{query=$marker}))){
            $leak=$null;$refused=$false
            try{$leak=Invoke-SBMcpToolCall $brain $case[0] $case[1]}catch{$refused=$true}
            $clean=[string]$leak -replace [regex]::Escape($marker),''
            $noHits=(!$leak -or $case[0] -ne 'search_knowledge' -or [int]($leak|ConvertFrom-Json -AsHashtable).totalMatches -eq 0)
            Check ($refused -or ($clean -notmatch 'O-1' -and $noHits)) ('MCP '+$case[0]+' does not cross the project perimeter: '+$(if($leak){([string]$leak).Substring(0,[math]::Min(300,([string]$leak).Length))}))
        }
        $env:SECONDBRAIN_RUNNER_REPOSITORY=$identity
        try{
            $foreignWork=(& pwsh -NoProfile -File $workCli -Repository $otherIdentity -Category work -Slug perimeter -Init -Task synthetic -ConfigPath $configPath 2>&1|Out-String)
            $foreignRoot=(Get-SBWorkEnvironment -BrainRoot $brain -HostId $hostId -Repository $otherIdentity -Category work -Slug perimeter).root
            Check ($LASTEXITCODE -ne 0 -and ![IO.Directory]::Exists($foreignRoot) -and $foreignWork -match 'runner|task') 'work.ps1 refuses to create a work folder for another repository in a scoped session'
            $ownWork=(& pwsh -NoProfile -File $workCli -Repository $identity -Category work -Slug perimeter -Init -Task synthetic -ConfigPath $configPath 2>&1|Out-String)
            Check ($LASTEXITCODE -eq 0) ('work.ps1 still serves the session repository: '+$ownWork)
        }finally{$env:SECONDBRAIN_RUNNER_REPOSITORY=$null}
    }finally{Put $otherContext $otherContextBytes}
}
if('workflows' -in $Groups){
    # Roadmap (#417): interventions of one repository from tracker history and git log, exportable as Markdown, without data of other repositories.
    $roadDossier=Join-Path $brain '02-areas/products/Roadmap';$roadRepo=Join-Path $fixture 'roadmap-checkout';$roadIdentity='github.com/test/roadmap'
    [void][IO.Directory]::CreateDirectory($roadRepo)
    Put (Join-Path $roadDossier 'para.json') (ConvertTo-SBJson @{schemaVersion=1;id='roadmap-area';kind='area';title='Roadmap';status='active'})
    Put (Join-Path $roadDossier 'brief.md') '# Synthetic roadmap'
    Put (Join-Path $roadDossier 'context.md') '# Roadmap context'
    Put (Join-Path $roadDossier 'memory.md') '# Roadmap memory'
    Put (Join-Path $roadDossier 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity=$roadIdentity;customer='Acme S.r.l.';tracker=@{location='dossier';path='tracker.json';schemaVersion=1}})
    Put (Join-Path $roadDossier 'history/2026-11-02-batch/report.md') 'Synthetic provenance'
    $roadHash=Get-SBTextHash 'Synthetic provenance'
    $roadTask=New-SBTrackerTask @{id='R-1';title='#001 — Roadmap task';status='done'} $roadIdentity 'fixture' 'history/2026-11-02-batch/report.md' $roadHash 'fixture'
    $roadTask.seq=1
    Put (Join-Path $roadDossier 'tracker.json') (ConvertTo-SBJson @{schemaVersion=1;repository=$roadIdentity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($roadTask);history=@(
        @{description='Chiusi #001 e #002, pubblicato su origin/main abc1234def (PR #12).';reference='history/2026-11-02-batch/report.md';sha256=$roadHash},
        @{description='Intervento senza data nel riferimento.';reference='history/misc/note.md';sha256=$roadHash});extensions=@{lastSeq=1}})
    [void](Invoke-SBGit $roadRepo @('init','-q'))
    Put (Join-Path $roadRepo 'a.txt') 'a'
    [void](Invoke-SBGit $roadRepo @('add','a.txt'))
    [void](Invoke-SBGit $roadRepo @('-c','user.name=Road Author','-c','user.email=road@example.invalid','commit','-qm','Synthetic roadmap commit'))
    $road=Get-SBRoadmap -BrainRoot $brain -Dossier $roadDossier -CheckoutPath $roadRepo
    $first=$road.interventions[0]
    Check ($road.repository -ceq $roadIdentity -and $road.customer -ceq 'Acme S.r.l.' -and $first.date -ceq '2026-11-02' -and ($first.tasks -join ',') -ceq '#001,#002' -and $first.commits -contains 'abc1234def' -and $first.pullRequests -contains '#12') 'roadmap extracts date, tasks, commit and pull request from history'
    Check (@($road.commits).Count -eq 1 -and $road.commits[0].author -ceq 'Road Author' -and $road.commits[0].subject -ceq 'Synthetic roadmap commit') 'roadmap lists the checkout git log with author'
    $markdown=ConvertTo-SBRoadmapMarkdown $road
    Check ($markdown.StartsWith('# Roadmap: '+$roadIdentity) -and $markdown.Contains('Acme S.r.l.') -and $markdown.Contains('2026-11-02') -and $markdown.Contains('Road Author')) 'roadmap exports as Markdown'
    Check (!$markdown.Contains('O-1') -and !$markdown.Contains('github.com/test/other') -and !$markdown.Contains($identity)) 'roadmap contains no data of other repositories'
    Check ((Get-SBRoadmap -BrainRoot $brain -Dossier $roadDossier -CheckoutPath $roadRepo -Since '2026-12-01').interventions.Count -eq 1) 'roadmap -Since keeps only undated interventions after the cut'
}
if('mcp-writes' -in $Groups){. (Join-Path $PSScriptRoot 'test-mcp-writes.ps1')}
if('pending' -in $Groups){
    . (Join-Path $PSScriptRoot 'test-mcp-write-smoke.ps1')
    $noRecoveryRequest=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation file.append -Arguments @{relativePath='memory.md';content="`nPending no-recovery fixture"} -Config $cfg
    $memoryBefore=Get-SBFileHash (Join-Path $dossier 'memory.md')
    $pureRead=Invoke-EssentialCli @('-Startup','-NoRecovery')
    Check ($pureRead.code -eq 0 -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $memoryBefore -and (Get-SBPendingWrites $brain|Where-Object id -eq $noRecoveryRequest.id).state -eq 'deferred') 'CLI NoRecovery preserves an authorized pending write without applying it'
    # #474: no read integrates queued writes, with or without -NoRecovery; only -FlushPending does, for the own dossier.
    foreach($readArgs in @(@('-Startup'),@('-Tasks'),@('-Search','memory'),@('-PendingWrites'),@('-Task','1'))){
        $readRun=Invoke-EssentialCli $readArgs
        Check ($readRun.code -eq 0 -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $memoryBefore -and (Get-SBPendingWrites $brain|Where-Object id -eq $noRecoveryRequest.id).state -eq 'deferred') ('#474: knowledge '+($readArgs -join ' ')+' leaves the dossier and the queue unchanged')
    }
    $mcpModule=Get-Module SecondBrain.Mcp
    $pureMcpDefault=& $mcpModule {param($root) Invoke-SBMcpMessage $root @{jsonrpc='2.0';id=30;method='tools/list';params=@{}}} $brain
    $pureTools=@(($pureMcpDefault|ConvertFrom-Json -AsHashtable).result.tools)
    Check ((Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $memoryBefore -and @($pureTools|Where-Object {!$_.annotations.readOnlyHint}).Count -eq 1 -and @($pureTools|Where-Object {!$_.annotations.readOnlyHint})[0].name -ceq 'submit_dossier_write') '#474: MCP lists tools without draining the queue; only submit_dossier_write is not read-only'
    $pureMcp=& $mcpModule {param($root) Invoke-SBMcpMessage $root @{jsonrpc='2.0';id=31;method='tools/list';params=@{_meta=@{noRecovery=$true}}}} $brain
    Check (($pureMcp|ConvertFrom-Json -AsHashtable).result.tools.Count -eq 11 -and (Get-SBFileHash (Join-Path $dossier 'memory.md')) -ceq $memoryBefore) 'MCP request NoRecovery lists tools without draining the queue'
    [void](Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg)
    Reject {New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';DependsOn=@('T-1')} -Config $cfg} 'invalid dependency graph rejected before queuing'
    $target=Join-Path $brain 'untracked.txt';Put $target 'original';$hash=Get-SBFileHash $target
    [void](Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('updated')) $hash $cfg.backupRoot)
    Check (@(Get-ChildItem $cfg.backupRoot -Filter '*.bin'|Where-Object {(Get-SBFileHash $_.FullName) -ceq $hash}).Count -gt 0) 'write preserves original backup bytes'
    Reject {Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('lost')) $hash $cfg.backupRoot} 'stale write hash rejected'
    $holder=Enter-SBOperation $cfg -WaitMs 0
    try{
        $first=New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Priority='P0';Stream='queued'} -Config $cfg
        $null = New-SBPendingWrite -BrainRoot $brain -Repository $identity -Operation task.update -Arguments @{TaskId='T-1';Priority='P3'} -Config $cfg
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
    # #473: recovery scoped to a dossier leaves another dossier's request untouched; without a scope the whole queue is still examined.
    $otherQueue=(& (Get-Module SecondBrain.Pending) {param($root) Get-SBPendingPaths $root} $brain)
    $otherId=[guid]::NewGuid().ToString('N');$otherRequest=Join-Path $otherQueue.queue ($otherId+'.json')
    Put $otherRequest ('{"schemaVersion":1,"id":"'+$otherId+'","repository":"github.com/test/other","operation":"file.append","arguments":{},"expected":{},"createdAt":"2026-11-11T00:00:00.0000000Z","origin":{},"sha256":"x"}')
    $otherHash=Get-SBFileHash $otherRequest
    $scoped=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg -Repository $identity
    Check ($scoped.pending -eq 0 -and !@($scoped.conflicts|Where-Object {$_.repository -cne $identity}).Count -and !$scoped.applied.Count -and !(Test-Path -LiteralPath (Join-Path $otherQueue.receipts ($otherId+'.json'))) -and (Get-SBFileHash $otherRequest) -ceq $otherHash) 'recovery scoped to a dossier leaves another dossier request untouched'
    $unscoped=Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
    Check (@($unscoped.conflicts|Where-Object id -ceq $otherId).Count -eq 1) 'recovery without a dossier scope still examines the whole queue'
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
    $distribution=Join-Path $fixture 'distribution';[void][IO.Directory]::CreateDirectory($distribution)
    [void](Invoke-SBGit $distribution @('init','-q'))
    foreach($name in @('AGENTS.md','CLAUDE.md','GEMINI.md')){Put (Join-Path $distribution $name) '# Synthetic public instructions'}
    [void](Invoke-SBGit $distribution @('add','--','AGENTS.md','CLAUDE.md','GEMINI.md'))
    $checker=Join-Path $PSScriptRoot 'check-distribution.ps1'
    $checkOutput=@(& pwsh -NoProfile -File $checker -RepositoryPath $distribution 2>&1)
    Check ($LASTEXITCODE -eq 0) 'distribution accepts public IDE instruction pointers'
    foreach($para in @('01-projects','02-areas','03-resources','04-archives')){Put (Join-Path $distribution ($para+'/README.md')) '# Synthetic PARA readme'}
    [void](Invoke-SBGit $distribution @('add','-f','--','01-projects/README.md','02-areas/README.md','03-resources/README.md','04-archives/README.md'))
    $checkOutput=@(& pwsh -NoProfile -File $checker -RepositoryPath $distribution 2>&1)
    Check ($LASTEXITCODE -eq 0) 'distribution accepts the four tracked PARA READMEs'
    Put (Join-Path $distribution '02-areas/private.md') '# Synthetic private dossier'
    Put (Join-Path $distribution 'notes.md') '# Unapproved root document'
    [void](Invoke-SBGit $distribution @('add','--','02-areas/private.md','notes.md'))
    $checkOutput=@(& pwsh -NoProfile -File $checker -RepositoryPath $distribution 2>&1)
    Check ($LASTEXITCODE -eq 1 -and ($checkOutput -join "`n").Contains('02-areas/private.md') -and ($checkOutput -join "`n").Contains('notes.md')) 'distribution still rejects private dossiers and arbitrary root files'
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
    # Tracked policy (#420): a reset of .runtime does not change the outcome; legacy policy migrates once.
    $trackedPolicy=Get-SBTrackedPublicationPolicyPath $brain
    Put (Join-Path $brain '.runtime/publication/policy.json') (ConvertTo-SBJson @{schemaVersion=1;allowances=@();binaryReviews=@()})
    Check ($null -eq (Resolve-SBPublicationPolicyPath $brain $null)) 'legacy local policy is no longer read as a fallback'
    Check ((Move-SBPublicationPolicy $brain).state -eq 'ready') 'legacy local policy is offered for migration'
    Check ((Move-SBPublicationPolicy $brain -Apply).state -eq 'migrated' -and (Test-Path -LiteralPath $trackedPolicy)) 'legacy local policy migrates to the tracked file'
    Check ((Move-SBPublicationPolicy $brain).state -eq 'tracked-exists') 'migration does not overwrite an existing tracked policy'
    Check ((Resolve-SBPublicationPolicyPath $brain $null) -eq $trackedPolicy) 'default policy is the tracked file'
    $withRuntime=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath (Resolve-SBPublicationPolicyPath $brain $null) -MaxTextBytes 400
    Remove-Item -LiteralPath (Join-Path $brain '.runtime/publication/policy.json') -Force
    $resetRuntime=Test-SBPublication -BrainRoot $brain -RepositoryPath $repo -PolicyPath (Resolve-SBPublicationPolicyPath $brain $null) -MaxTextBytes 400
    Check ($withRuntime.ready -eq $resetRuntime.ready -and @($withRuntime.incomplete).Count -eq @($resetRuntime.incomplete).Count) 'resetting .runtime leaves the publication outcome unchanged'
    # Computer use without a person (#455): capability table, Codex opt-in plan/apply on a fixture file, runner preflight.
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ComputerUse.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'SecondBrain.TaskRunner.psm1') -Force
    $cuTable=@(Get-SBComputerUseCapabilities)
    Check (@($cuTable|Where-Object {$_.ide -eq 'Codex' -and $_.unattended -eq 'opt-in-config' -and $_.mechanism -like '*always_allowed_app_ids*'}).Count -eq 1 -and @($cuTable|Where-Object {$_.ide -eq 'Claude Code'})[0].unattended -eq 'interactive-only') 'capability table: only Codex has a documented opt-in, Claude Code is interactive-only'
    $cuCodex=Join-Path $brain 'computer-use/codex/config.toml'
    $cuOriginal="# user config`n[mcp_servers.x]`ncommand = `"x`"`n"
    Put $cuCodex $cuOriginal
    $cuPlan=Get-SBCodexComputerUsePlan $cuOriginal @('Contoso.App_1!App','C:\Tools\a.exe;Contoso.App_1!App')
    Check ($cuPlan.status -eq 'changed' -and @($cuPlan.added).Count -eq 2 -and $cuPlan.text.StartsWith($cuOriginal.TrimEnd()) -and $cuPlan.text -match "(?m)^\[computer_use\.windows\]\r?\nalways_allowed_app_ids = \['Contoso\.App_1!App', 'C:\\Tools\\a\.exe'\]") 'Codex plan appends the table, keeps other bytes and de-duplicates the app IDs'
    $cuMerge=Get-SBCodexComputerUsePlan $cuPlan.text @('New.App')
    Check ($cuMerge.status -eq 'changed' -and @($cuMerge.ids).Count -eq 3 -and @($cuMerge.existing).Count -eq 2 -and (Get-SBCodexComputerUsePlan $cuPlan.text @('New.App')).text.Contains("[mcp_servers.x]")) 'Codex plan only adds to an existing list and never removes'
    Check ((Get-SBCodexComputerUsePlan $cuPlan.text @('Contoso.App_1!App')).status -eq 'unchanged') 'Codex plan is unchanged when every app is already allowed'
    $cuEmptyTable=Get-SBCodexComputerUsePlan "[computer_use.windows]`nother = 1`n`n[next]`nk = 1`n" @('A.B')
    Check ($cuEmptyTable.text -match "(?s)\[computer_use\.windows\]\r?\nother = 1\r?\nalways_allowed_app_ids = \['A\.B'\]\r?\n\r?\n\[next\]") 'Codex plan inserts the key inside an existing table, before the next one'
    Reject {Get-SBCodexComputerUsePlan "[computer_use.windows]`nalways_allowed_app_ids = [`n 'a',`n]`n" @('b')} 'Codex plan refuses a multi-line array'
    Reject {Get-SBCodexComputerUsePlan "computer_use.windows.always_allowed_app_ids = ['a']`n" @('b')} 'Codex plan refuses a dotted-key form'
    Reject {Get-SBCodexComputerUsePlan $cuOriginal @("bad'quote")} 'Codex plan refuses a quote in an app ID'
    $cuPreview=Set-SBCodexComputerUseApps -BrainRoot $brain -AppIds @('Contoso.App_1!App') -ConfigPath $cuCodex
    Check (!$cuPreview.applied -and $cuPreview.status -eq 'changed' -and (Read-SBText $cuCodex) -ceq $cuOriginal) 'Codex preview writes nothing'
    Reject {Set-SBCodexComputerUseApps -BrainRoot $brain -AppIds @('Contoso.App_1!App') -ConfigPath $cuCodex -Apply} 'Codex apply without the preview hash is refused'
    Reject {Set-SBCodexComputerUseApps -BrainRoot $brain -AppIds @('Contoso.App_1!App') -ConfigPath $cuCodex -Apply -PreviewSha256 ('0'*64)} 'Codex apply with a stale preview hash is refused'
    Reject {Get-SBCodexComputerUsePlan $cuOriginal @('bad id;;')} 'Codex plan refuses whitespace inside an app ID'
    $cuMissing=$false;try{[void](Set-SBCodexComputerUseApps -BrainRoot $brain -AppIds @('Contoso.App_1!App') -ConfigPath $cuCodex -Apply)}catch{$cuMissing=(Test-SBError $_.Exception 'computeruse.apply.hash.missing')}
    Check ($cuMissing -and $cuPreview.applyCommand -like "*-Apply -PreviewSha256 $($cuPreview.previewSha256)*") 'Codex apply without a hash reports it as missing and the preview prints the apply command'
    Check (!(Test-SBAgentUnattendedComputerUse 'codex' $cuCodex)) 'preflight: Codex without the setting is not unattended'
    $cuApplied=Set-SBCodexComputerUseApps -BrainRoot $brain -AppIds @('Contoso.App_1!App') -ConfigPath $cuCodex -Apply -PreviewSha256 $cuPreview.previewSha256
    Check ($cuApplied.applied -and (Read-SBText $cuCodex).Contains("always_allowed_app_ids = ['Contoso.App_1!App']") -and (Read-SBText $cuCodex).StartsWith('# user config')) 'Codex apply writes the previewed text'
    Check ((Test-SBAgentUnattendedComputerUse 'C:\tools\codex.cmd' $cuCodex) -and !(Test-SBAgentUnattendedComputerUse 'claude' $cuCodex) -and !(Test-SBAgentUnattendedComputerUse 'unknown-agent' $cuCodex) -and !(Test-SBAgentUnattendedComputerUse '' $cuCodex)) 'preflight: only an agent with a documented opt-in and a present setting runs computer-use tasks unattended'
    $cuTask=[pscustomobject]@{id='CU';seq=1;status='todo';priority='P2';execution='autonomous';extensions=[pscustomobject]@{requires=@('computer-use')}}
    Check ((Get-SBRunnerExclusionReason $cuTask) -ceq 'requires:computer-use' -and $null -eq (Get-SBRunnerExclusionReason $cuTask -AllowComputerUse) -and (Select-SBRunnableTasks @($cuTask) 5).Count -eq 0 -and (Select-SBRunnableTasks @($cuTask) 5 -AllowComputerUse).Count -eq 1) 'runner: a computer-use task is excluded unless the preflight allows it'
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
    try{
        Assert-SBTestGitEnvironment;Check $true 'isolated Git environment is effective'
        # #527: the wrapper lives in a conforming tmp container whose MANIFEST.json passes the .runtime ownership check.
        $wrapperDir=Split-Path $env:GIT_CONFIG_GLOBAL;$container=Split-Path $wrapperDir
        $brainRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
        $relativeContainer=[IO.Path]::GetRelativePath((Join-Path $brainRoot '.runtime'),$container).Replace('\','/')
        Check ($relativeContainer -cmatch '^hosts/[^/]+/repos/tests-[0-9a-f]{8}/tmp/\d{8}-git-env$') 'Git wrapper container follows hosts/<id>/repos/<repo>/tmp/<yyyyMMdd>-<slug>'
        $parts=$relativeContainer -split '/'
        $entry=@{path=$relativeContainer;host=$parts[1];repo=$parts[3];area=$parts[4]}
        $ownership=Get-SBRuntimeOwnership $brainRoot @($entry) @()
        Check ($ownership.owned -eq 1 -and $ownership.outOfSchemaCount -eq 0) 'Git wrapper container manifest passes the ownership check'
    }finally{Exit-SBTestGitEnvironment $nested}
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
