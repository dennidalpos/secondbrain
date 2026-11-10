#requires -Version 7.5
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.SetupStatus.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$passed=0
function Assert-Setup($Value,[string]$Message){if(!$Value){throw "FAIL SETUP-STATUS: $Message"};$script:passed++;"PASS SETUP-STATUS: $Message"}
function Set-Fixture([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$root=Join-Path (Get-SBTestRoot) ('secondbrain-setup-status-test-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root)|Out-Null
$repo=Join-Path $root 'repo'
[IO.Directory]::CreateDirectory((Join-Path $repo '.git/hooks'))|Out-Null
$settings=Join-Path $root 'claude-settings.json'
Set-Fixture $settings '{}'
Set-Fixture (Join-Path $root '.runtime/trace/ws/2026-01-01.jsonl') ('{"secret":"must not be read"}'+"`n"+'{"secret":"x"}'+"`n")
Set-Fixture (Join-Path $root '03-resources/authoritative-sources/entries/x/metadata.json') '{}'
$ides=@(@{name='Claude Code';adapter='claude-code';mcpConfigured=$false},@{name='VS Code';adapter='vscode';mcpConfigured=$true},@{name='Android Studio';adapter='android-studio';mcpConfigured=$false},@{name='Claude account instructions';adapter='manual';mcpConfigured=$false})
$bindings=@(@{path=$repo;identity='github.com/example/repo'})
$before=@(Get-ChildItem -LiteralPath $root -Recurse -File|ForEach-Object {$_.FullName+'|'+(Get-SBFileHash $_.FullName)})
$features=@(Get-SBSetupFeatureStatus -BrainRoot $root -HomeValue '' -SettingsPath $settings -Ides $ides -Bindings $bindings -Config @{})
$byId={param($id,$scope) @($features|Where-Object {$_.id -eq $id -and (!$scope -or $_.scope -eq $scope)})[0]}
Assert-Setup ((& $byId 'environment').state -eq 'available' -and (& $byId 'environment').recommended) 'SECONDBRAIN_HOME assente: funzione proposta'
Assert-Setup ((& $byId 'mcp' 'Claude Code').recommended -and (& $byId 'mcp' 'Claude Code').state -eq 'available') 'IDE senza MCP: abilitazione consigliata'
Assert-Setup ((& $byId 'mcp' 'VS Code').state -eq 'enabled' -and !(& $byId 'mcp' 'VS Code').recommended) 'IDE con MCP: gia abilitato, non consigliato'
Assert-Setup ((& $byId 'mcp' 'Android Studio').state -eq 'unsupported') 'IDE senza target MCP: non supportato'
Assert-Setup ((& $byId 'trace-hook').state -eq 'available') 'hook Trace proposto per Claude Code'
Assert-Setup ((& $byId 'resources-hook').recommended) 'hook risorse consigliato con registro fonti presente'
Assert-Setup ((& $byId 'publication-hook').state -eq 'unsupported') 'repository senza remote: hook di pubblicazione non proposto'
Assert-Setup ((& $byId 'task-launcher').state -eq 'available' -and !(& $byId 'task-launcher').recommended) 'lanciatore proposto ma non consigliato di default'
Assert-Setup (!(& $byId 'activity-register').recommended -and (& $byId 'activity-register').risk -eq 'high') 'registro attivita mai consigliato (rischio alto)'
Assert-Setup (@($features|Where-Object {$_.state -eq 'available' -and !$_.enableCommand}).Count -eq 0) 'ogni funzione disponibile ha un comando di anteprima'
$account=& $byId 'manual-directives'
Assert-Setup ($account.state -eq 'blocked' -and $account.recommended -and $account.enableCommand) 'istruzioni account senza osservazione: segnalate e consigliate'
$enabled=@(Get-SBSetupFeatureStatus -BrainRoot $root -HomeValue 'C:\x' -SettingsPath $settings -Ides @() -Bindings @() -Config @{activityLogEnabled=$true})
Assert-Setup ((@($enabled|Where-Object id -eq 'environment')[0]).state -eq 'enabled' -and (@($enabled|Where-Object id -eq 'activity-register')[0]).state -eq 'enabled') 'stato abilitato riconosciuto'
$usage=Get-SBTraceUsage $root
Assert-Setup ($usage.present -and $usage.events -eq 2 -and (ConvertTo-SBJson $usage) -notmatch 'secret') 'uso dal Trace: solo conteggi, nessun contenuto'
$after=@(Get-ChildItem -LiteralPath $root -Recurse -File|ForEach-Object {$_.FullName+'|'+(Get-SBFileHash $_.FullName)})
Assert-Setup (($before -join "`n") -ceq ($after -join "`n")) 'nessun file creato o modificato'
$state=Join-Path $root 'state'
$approved='Revisione 1.0 - testo approvato di prova'
Set-Fixture (Join-Path $state 'istruzioni-globali.md') $approved
$approvedHash=Get-SBTextHash $approved.Trim()
$accountIde=@(@{name='Claude account instructions';adapter='manual';mcpConfigured=$false})
$writeMap={param($hash) Set-Fixture (Join-Path $state 'ide-map.json') (ConvertTo-SBJson @{schemaVersion=1;ides=@(@{name='Claude account instructions';mode='manual';selected=$true;observedHash=$hash})})}
& $writeMap $approvedHash
$ok=@(Get-SBSetupFeatureStatus -BrainRoot $root -HomeValue 'x' -SettingsPath $settings -Ides $accountIde -Bindings @() -Config @{} -StateRoot $state|Where-Object id -eq 'manual-directives')[0]
Assert-Setup ($ok.state -eq 'enabled' -and !$ok.recommended) 'istruzioni account con hash osservato uguale: enabled, non consigliato'
& $writeMap ('0'*64)
$stale=@(Get-SBSetupFeatureStatus -BrainRoot $root -HomeValue 'x' -SettingsPath $settings -Ides $accountIde -Bindings @() -Config @{} -StateRoot $state|Where-Object id -eq 'manual-directives')[0]
Assert-Setup ($stale.state -eq 'blocked' -and $stale.recommended) 'istruzioni account con hash obsoleto: blocked e consigliato'
'SUCCESS SETUP-STATUS: '+$passed+' verifiche'
