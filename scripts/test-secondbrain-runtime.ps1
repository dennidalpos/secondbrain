#requires -Version 7.5
# .runtime layout: folder names, migration plan/apply, regenerable targets, protected areas. Synthetic fixture only.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:runtimeChecks=0
function Assert-Runtime($Condition,[string]$Message){if(!$Condition){throw 'FAIL RUNTIME: '+$Message};$script:runtimeChecks++;'PASS RUNTIME: '+$Message}
$stamp=Get-Date -Format 'yyyyMMdd'
$root=Join-Path (Get-SBTestRoot) ('fixture-'+$stamp+'-runtime-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$brain=Join-Path $root 'brain';$runtime=Join-Path $brain '.runtime'
$hostId='ws-0123456789abcdef';$segment='demo-0a1b2c3d'
function New-Dir([string]$Relative,[string]$File='data.txt'){$p=Join-Path $runtime $Relative;[IO.Directory]::CreateDirectory($p)|Out-Null;if($File){[IO.File]::WriteAllText((Join-Path $p $File),'x')};$p}
function Set-Old([string]$Path){Get-ChildItem -LiteralPath $Path -Recurse -Force|ForEach-Object {$_.LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-3)};(Get-Item -LiteralPath $Path).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-3)}
# Folder names.
$d=[DateTime]::new(2026,11,5)
Assert-Runtime ((ConvertTo-SBRuntimeFolderName 'work-20261103-lotto-241' $d) -ceq '20261103-lotto-241') 'prefisso di categoria rimosso'
Assert-Runtime ((ConvertTo-SBRuntimeFolderName '20261104-work-20261104-lotto-299' $d) -ceq '20261104-lotto-299') 'data e prefisso duplicati rimossi'
Assert-Runtime ((ConvertTo-SBRuntimeFolderName 'Cartella Strana!' $d) -ceq '20261105-cartella-strana') 'nome libero normalizzato con la data di scrittura'
Assert-Runtime ((ConvertTo-SBRuntimeFolderName 'report-20261104-mem04-b948e421' $d) -cmatch '^20261104-mem04-b948e421$') 'report con hash conservato'
# Nested path validation.
Assert-Runtime ((Get-SBRuntimeWorkPath $brain $hostId 'github.com/o/demo' 'work' 'prova' $d) -match 'repos[\\/]demo-[0-9a-f]{8}[\\/]work[\\/]20261105-prova$') 'percorso annidato work'
$rejected=$false;try{Get-SBRuntimeWorkPath $brain $hostId 'github.com/o/demo' 'altro' 'prova' $d|Out-Null}catch{$rejected=$true}
Assert-Runtime $rejected 'categoria sconosciuta rifiutata'
# Fixture .runtime.
New-Dir 'access' 'writer.lock'|Out-Null
New-Dir 'work-20261103-uno'|Out-Null;New-Dir 'evidence-20261103-due'|Out-Null;New-Dir 'report-20261103-tre'|Out-Null
New-Dir 'backup-20261103-install-abc'|Out-Null;New-Dir 'backup/mcp-pairing' 'a.bin'|Out-Null
New-Dir 'fixture-20261103-vecchia'|Out-Null;New-Dir 'tmp-20261103-vecchia'|Out-Null;New-Dir 'vuota' $null|Out-Null
New-Dir 'mcp-handshake' 'handshake-1.json'|Out-Null
[IO.File]::WriteAllText((Join-Path $runtime 'fast-run.log'),'log')
New-Dir ('hosts/'+$hostId+'/evidence-20261105-host') 'e.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/demo/work/work-20261103-dup') 'w.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/work/20261104-work-20261104-doppio') 'w.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/work/20261104-ok') 'w.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/work/work-20261104-dup') 'w.txt'|Out-Null
New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/work/20261104-dup') 'w.txt'|Out-Null
foreach($n in 1..7){New-Dir ('hosts/'+$hostId+'/repos/'+$segment+'/fixture/2026110'+$n+'-f'+$n) 'f.txt'|Out-Null}
foreach($p in Get-ChildItem -LiteralPath $runtime -Directory -Force){Set-Old $p.FullName}
(Get-Item -LiteralPath (Join-Path $runtime 'fast-run.log')).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-3)
foreach($p in Get-ChildItem -LiteralPath (Join-Path $runtime 'hosts') -Recurse -Directory -Force){Set-Old $p.FullName}
# Migration plan: preview changes nothing.
$plan=Get-SBRuntimeMigrationPlan $brain $hostId $segment 10
$kinds=@($plan.moves|ForEach-Object {$_.kind}|Sort-Object -Unique)
Assert-Runtime (Test-Path -LiteralPath (Join-Path $runtime 'work-20261103-uno')) 'anteprima: nessuna cartella spostata'
foreach($k in 'flat-work','flat-evidence','flat-report','install-backup','backup-merge','log','host-evidence','merge-segment','rename'){Assert-Runtime ($k -in $kinds) ('piano contiene '+$k)}
Assert-Runtime (!@($plan.moves|Where-Object {$_.fromRelative -like 'fixture-*' -or $_.fromRelative -like 'tmp-*'})) 'fixture e tmp piatte non migrate (si rimuovono come rigenerabili)'
$destinations=@($plan.moves|ForEach-Object {$_.to.ToLowerInvariant()})
Assert-Runtime ($destinations.Count -eq @($destinations|Sort-Object -Unique).Count) 'destinazioni uniche (collisioni risolte con suffisso)'
Assert-Runtime (@($plan.moves|Where-Object {$_.toRelative -like '*20261104-dup-2'}).Count -eq 1) 'collisione di nome risolta'
# Recently written folders are skipped.
$fresh=New-Dir 'work-20261105-appena';$freshPlan=Get-SBRuntimeMigrationPlan $brain $hostId $segment 10
Assert-Runtime (@($freshPlan.skipped|Where-Object {$_.from -eq 'work-20261105-appena'}).Count -eq 1) 'cartella appena scritta saltata'
Remove-Item -LiteralPath $fresh -Recurse -Force
# Apply.
$result=Invoke-SBRuntimeMigration $brain $plan
Assert-Runtime ($result.failed.Count -eq 0) 'migrazione senza errori'
$target=Join-Path $runtime ('hosts/'+$hostId+'/repos/'+$segment)
Assert-Runtime (Test-Path -LiteralPath (Join-Path $target 'work/20261103-uno/data.txt')) 'work piatta nel layout annidato'
Assert-Runtime (Test-Path -LiteralPath (Join-Path $target 'evidence/20261103-due/MANIFEST.json')) 'MANIFEST.json scritto per evidence'
$manifest=Get-Content -LiteralPath (Join-Path $target 'work/20261103-uno/MANIFEST.json') -Raw|ConvertFrom-Json
Assert-Runtime ($manifest.status -eq 'migrated' -and $manifest.category -eq 'work' -and $manifest.created -eq '2026-11-03') 'manifest con categoria, data e stato'
Assert-Runtime (Test-Path -LiteralPath (Join-Path $runtime ('hosts/'+$hostId+'/install-backups/20261103-install-abc'))) 'backup di installazione riordinato'
Assert-Runtime ((Test-Path -LiteralPath (Join-Path $runtime 'backups/mcp-pairing/a.bin')) -and !(Test-Path -LiteralPath (Join-Path $runtime 'backup'))) 'backup/ unito in backups/ e rimosso'
Assert-Runtime ((Test-Path -LiteralPath (Join-Path $runtime 'logs/fast-run.log')) -and !(Test-Path -LiteralPath (Join-Path $runtime 'fast-run.log'))) 'log spostato in logs/'
Assert-Runtime (!(Test-Path -LiteralPath (Join-Path $runtime ('hosts/'+$hostId+'/repos/demo')))) 'segmento duplicato svuotato e rimosso'
Assert-Runtime (Test-Path -LiteralPath (Join-Path $target 'work/20261103-dup/w.txt')) 'segmento duplicato unito'
Assert-Runtime (Test-Path -LiteralPath (Join-Path $runtime 'access/writer.lock')) 'access/ intatto'
Assert-Runtime (!@((Get-SBRuntimeMigrationPlan $brain $hostId $segment 0).moves)) 'seconda esecuzione: nulla da spostare'
# Regenerable targets.
$targets=Get-SBRegenerableRuntimeTargets $brain @() 5 0
$byKind=@($targets.targets|Group-Object kind|ForEach-Object {$_.Name+'='+$_.Count})
Assert-Runtime (@($targets.targets|Where-Object kind -eq 'fixture-flat').Count -eq 2) 'fixture e tmp piatte tra i rigenerabili'
Assert-Runtime (@($targets.targets|Where-Object kind -eq 'nested-fixture').Count -eq 2) 'fixture annidate oltre le ultime 5'
Assert-Runtime (@($targets.targets|Where-Object kind -eq 'handshake-reports').Count -eq 1 -and @($targets.targets|Where-Object kind -eq 'empty-folder').Count -eq 1) 'handshake e cartelle vuote rigenerabili'
Assert-Runtime (!@($targets.targets|Where-Object {$_.relative -match '^(access|hosts/[^/]+/repos/[^/]+/(work|evidence|report))'})) 'access, work, evidence e report mai rigenerabili'
$recent=Get-SBRegenerableRuntimeTargets $brain @() 5 10080
Assert-Runtime (@($recent.targets).Count -eq 0 -and @($recent.skipped).Count -gt 0) 'cartelle recenti saltate'
foreach($t in $targets.targets){Remove-SBRuntimeTree $t.path $brain}
Assert-Runtime (!(Test-Path -LiteralPath (Join-Path $runtime 'fixture-20261103-vecchia')) -and (Test-Path -LiteralPath (Join-Path $target 'work/20261103-uno'))) 'rimozione limitata ai rigenerabili'
"SUCCESS RUNTIME: $script:runtimeChecks checks"
