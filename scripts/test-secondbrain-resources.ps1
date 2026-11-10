#requires -Version 7.5
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sources.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Resources.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$passed=0
function Assert-Res($Value,[string]$Message){if(!$Value){throw "FAIL RESOURCES: $Message"};$script:passed++;"PASS RESOURCES: $Message"}
function Set-Res([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$root=Join-Path (Get-SBTestRoot) ('secondbrain-resources-test-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root)|Out-Null
foreach($name in @('source.schema.json','source-applicability.schema.json')){Set-Res (Join-Path $root ('config/'+$name)) (Read-SBText (Join-Path $PSScriptRoot ('../config/'+$name)))}
$registryPath=Join-Path $root '03-resources/authoritative-sources'
Set-Res (Join-Path $root 'para-index.json') (ConvertTo-SBJson @{schemaVersion=1;entities=@(@{id='resource-authoritative-sources';kind='resource';path='03-resources/authoritative-sources';archived=$false})})
Set-Res (Join-Path $registryPath 'para.json') (ConvertTo-SBJson @{id='resource-authoritative-sources';kind='resource';schemaVersion=1;status='active';title='Fonti'})
Set-Res (Join-Path $registryPath 'brief.md') "brief`n"
Set-Res (Join-Path $registryPath 'domains.json') (ConvertTo-SBJson @{schemaVersion=1;domains=@(@{id='privacy';title='Privacy'})})
Set-Res (Join-Path $root '03-resources/notes/para.json') (ConvertTo-SBJson @{id='resource-notes';kind='resource';schemaVersion=1;status='active'})
$config=@{brainRoot=$root;runtimeRoot=(Join-Path $root 'runtime');backupRoot=(Join-Path $root 'backup');configPath=(Join-Path $root '.runtime/hosts/fixture/workstation.json')}
function New-Card([string]$Id,[string]$OfficialId,[string]$Kind,$Related){
    @{schemaVersion=1;id=$Id;title=$Id;kind=$Kind;issuer='Fixture';domains=@('privacy');jurisdictions=@('EU');language='it';officialId=$OfficialId;edition='v1';publicationDate=$null;rights=@{status='public-reusable';reference='https://example.com/license';notes='Fixture'};endpoints=@(@{id='canonical';url='https://example.com/'+$Id;format='html';role='canonical';allowedHosts=@('example.com');expectedText='Articolo'});versions=@();acceptedVersion=$null;relatedSources=@($Related);effectiveDates=@();notes=@()}
}
Set-Res (Join-Path $registryPath 'entries/law-a/metadata.json') (ConvertTo-SBJson (New-Card 'law-a' 'Regolamento (UE) 2016/679' 'regulation' @()))
Set-Res (Join-Path $registryPath 'entries/law-b/metadata.json') (ConvertTo-SBJson (New-Card 'law-b' 'Regolamento (UE) 2022/2065' 'regulation' @(@{id='law-a';relation='related'})))
$registry=Read-SBSourceRegistry $root
# Layout, control files and index
$folders=@(Get-SBResourceFolders $root)
Assert-Res ($folders.Count -eq 2) 'cartelle risorsa elencate (autoritative-sources, notes)'
$issues=@(Get-SBResourceChecks $root)
Assert-Res (@($issues|Where-Object kind -eq 'layout-missing').Count -eq 1) 'brief.md mancante segnalato'
Assert-Res (@($issues|Where-Object kind -eq 'control-missing').Count -eq 2) 'CONTROL.json mancante segnalato'
$written=@(Update-SBResourceViews $config)
Assert-Res ($written.Count -eq 4) 'CONTROL.json e INDEX.md scritti per ogni risorsa'
Assert-Res (@(Update-SBResourceViews $config).Count -eq 0) 'aggiornamento idempotente'
Assert-Res (@(Get-SBResourceChecks $root|Where-Object kind -in @('control-missing','control-drift','index-drift')).Count -eq 0) 'controllo coerente dopo l aggiornamento'
$control=Read-SBJson (Join-Path $registryPath 'CONTROL.json') $null
Assert-Res (@($control.files|Where-Object path -eq 'CONTROL.json').Count -eq 0) 'CONTROL.json non include se stesso'
Set-Res (Join-Path $registryPath 'brief.md') "modified`n"
Assert-Res (@(Get-SBResourceChecks $root|Where-Object {$_.kind -eq 'control-drift' -and $_.resource -eq 'authoritative-sources' -and $_.changed -eq 1}).Count -eq 1) 'modifica di un file rilevata dal controllo'
# Sync: collect, preservation, closure
$script:html='<html><body>Articolo 1. Vedi anche il regolamento 2016/679 e la direttiva 2099/12.</body></html>'
$transport={param($ep) @{bytes=[Text.Encoding]::UTF8.GetBytes($script:html+$ep.url);finalUrl=$ep.url;httpStatus=200;contentType='text/html';etag='';lastModified=''}}
$result=Invoke-SBResourceSync $config $registry $null 3 10 $transport
Assert-Res ($result.complete -and @($result.collected).Count -eq 2) 'Sync raccoglie le fonti senza baseline come candidate'
$registry=Read-SBSourceRegistry $root
Assert-Res (@($registry.sources|ForEach-Object {$_.versions}).Count -eq 2 -and !@($registry.sources|Where-Object acceptedVersion).Count) 'versioni candidate, nessuna accettata automaticamente'
# No converter in the fixture: provide transcripts so that reference detection has text to read.
foreach($source in $registry.sources){
    $versionRoot=Join-Path $source._root ('versions/'+$source.versions[0].id)
    Set-Res (Join-Path $versionRoot 'transcript.md') 'Articolo 1. Vedi anche il regolamento 2016/679 e la direttiva 2099/12.'
    $manifest=Read-SBJson (Join-Path $versionRoot 'manifest.json') $null
    $manifest.transcription.path='transcript.md'
    Set-Res (Join-Path $versionRoot 'manifest.json') (ConvertTo-SBJson $manifest)
}
$registry=Read-SBSourceRegistry $root
$firstVersions=@($registry.sources|ForEach-Object {$_.versions[0].id})
$again=Invoke-SBResourceSync $config $registry $null 3 10 $transport
Assert-Res (@($again.collected).Count -eq 0) 'seconda sincronizzazione senza cambi non crea versioni'
$script:html=$script:html.Replace('Articolo 1.','Articolo 1 bis.')
$registry=Read-SBSourceRegistry $root
$changed=Invoke-SBResourceSync $config $registry $null 3 10 $transport
$registry=Read-SBSourceRegistry $root
Assert-Res (@($changed.collected).Count -eq 2 -and @($registry.sources|ForEach-Object {$_.versions}).Count -eq 4) 'cambio di una fonte crea una nuova versione'
foreach($id in $firstVersions){Assert-Res (@($registry.sources|ForEach-Object {$_.versions}|Where-Object id -ceq $id).Count -eq 1) ('versione precedente preservata '+$id)}
$queue=Read-SBJson (Join-Path $registryPath 'normative-queue.json') $null
Assert-Res (@($queue.items|Where-Object {$_.kind -eq 'unresolved-reference' -and $_.reference -eq '2099/12'}).Count -ge 1) 'riferimento non risolto messo in coda di revisione'
$a=@($registry.sources|Where-Object id -eq 'law-b')[0]
$refs=Find-SBSourceReferences $registry $a
Assert-Res ('law-a' -in $refs.resolved) 'riferimento risolto verso scheda del registro'
$closure=Get-SBSourceClosure $registry @('law-b') 3 10
Assert-Res ('law-a' -in $closure.sources -and 'law-b' -in $closure.sources) 'chiusura segue relatedSources'
$limited=Get-SBSourceClosure $registry @('law-b') 3 1
Assert-Res ($limited.sources.Count -eq 1 -and @($limited.queue|Where-Object kind -eq 'limit-reached').Count -ge 1) 'limite di fonti registrato in coda'
Assert-Res (!(Test-SBResourceStale $config) ) 'report recente non e obsoleto'
Assert-Res (@(Get-SBResourceChecks $root|Where-Object kind -in @('control-missing','control-drift','index-drift')).Count -eq 0) 'viste coerenti dopo Sync'
'SUCCESS RESOURCES: '+$passed+' verifiche'
