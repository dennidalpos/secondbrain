#requires -Version 7.5
[CmdletBinding()]
param([string]$PythonPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sources.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$passed=0
function Assert-Source($Value,[string]$Message){if(!$Value){throw "FAIL SOURCE: $Message"};$script:passed++;"PASS SOURCE: $Message"}
function Throws-Source([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Assert-Source $caught $Message}
function Put-Source([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$root=Join-Path (Get-SBTestRoot) ('secondbrain-sources-test-'+[guid]::NewGuid().ToString('N'))
$success=$false
try {
    [IO.Directory]::CreateDirectory($root)|Out-Null
    foreach($name in @('source.schema.json','source-applicability.schema.json')){Put-Source (Join-Path $root ('config/'+$name)) (Read-SBText (Join-Path $PSScriptRoot ('../config/'+$name)))}
    $registryPath=Join-Path $root '03-resources/authoritative-sources'
    Put-Source (Join-Path $root 'para-index.json') (ConvertTo-SBJson @{schemaVersion=1;entities=@(@{id='resource-authoritative-sources';kind='resource';path='03-resources/authoritative-sources';archived=$false})})
    Put-Source (Join-Path $registryPath 'para.json') (ConvertTo-SBJson @{id='resource-authoritative-sources';kind='resource';schemaVersion=1;status='active'})
    Put-Source (Join-Path $registryPath 'domains.json') (ConvertTo-SBJson @{schemaVersion=1;domains=@(@{id='security';title='Security'})})
    $config=@{brainRoot=$root;runtimeRoot=(Join-Path $root 'runtime');backupRoot=(Join-Path $root 'backup');configPath=(Join-Path $root '.runtime/hosts/fixture/workstation.json')}
    $source=@{schemaVersion=1;id='fixture';title='Fixture';kind='guideline';issuer='Fixture';domains=@('security');jurisdictions=@('Global');language='it';officialId=$null;rights=@{status='public-reusable';reference='https://example.com/license';notes='Fixture'};endpoints=@(@{id='canonical';url='https://example.com/document';format='html';role='canonical';allowedHosts=@('example.com');expectedText='Articolo'});versions=@();acceptedVersion=$null;relatedSources=@();effectiveDates=@();notes=@()}
    $metadata=Join-Path $registryPath 'entries/fixture/metadata.json'
    $source.edition='Fixture v1';$source.publicationDate=$null
    Put-Source $metadata (ConvertTo-SBJson $source)
    $registry=Read-SBSourceRegistry $root
    Assert-Source ($registry.sources.Count -eq 1) 'registro risolto da identita PARA'
    Throws-Source {Get-SBSourceChild $root '../outside'} 'path traversal rifiutato'
    Throws-Source {Get-SBSourceChild $root (Get-SBTestRoot)} 'percorso assoluto rifiutato'
    Throws-Source {Get-SBSourceChild $root 'originals/document:stream'} 'stream alternativo NTFS rifiutato'
    foreach($url in @('http://example.com/doc','https://user:password@example.com/doc','https://evil.example/doc','https://example.com:444/doc','https://example.com/doc?token=secret')){Throws-Source {Assert-SBSourceUri $url @('example.com') -SkipDns} 'schema/credenziali/host/porta/token non ammessi'}
    foreach($address in @('127.0.0.1','10.0.0.1','169.254.169.254','172.16.0.1','192.168.0.1','100.64.0.1','::1','fc00::1','::ffff:127.0.0.1')){Assert-Source (!(Test-SBPublicAddress ([Net.IPAddress]::Parse($address)))) ('indirizzo privato rifiutato '+$address)}
    Assert-Source (Test-SBPublicAddress ([Net.IPAddress]::Parse('8.8.8.8'))) 'indirizzo pubblico riconosciuto'
    $script:sourceHtml='<html><body><h1>Articolo 1</h1><p>Importo 12.345,67; codice 000123.</p><table><tr><th>Valore</th></tr><tr><td>0.00000000000000001</td></tr></table></body></html>'
    $transport={param($ep) @{bytes=[Text.Encoding]::UTF8.GetBytes($script:sourceHtml);finalUrl=$ep.url;httpStatus=200;contentType='text/html';etag='fixture';lastModified=''}}
    $download=Get-SBSourceContent $source.endpoints[0] $transport
    Assert-Source ($download.sha256.Length -eq 64) 'download calcola hash dei byte'
    $baseHash=$download.contentHash
    $script:sourceHtml=$script:sourceHtml.Replace('<body>','<body><script>changed 123</script>')
    Assert-Source ((Get-SBSourceContent $source.endpoints[0] $transport).contentHash -ceq $baseHash) 'script HTML esclusi dal confronto pertinente'
    Throws-Source {Get-SBSourceContent $source.endpoints[0] {param($ep) @{bytes=[Text.Encoding]::UTF8.GetBytes('Articolo');finalUrl='https://evil.example/';httpStatus=200;contentType='text/html';etag='';lastModified=''}}} 'redirect a host estraneo rifiutato'
    $savedHtml=$script:sourceHtml;$script:sourceHtml='<title>JavaScript is disabled</title>verify that you are not a robot'
    Throws-Source {Get-SBSourceContent $source.endpoints[0] $transport} 'challenge non diventa documento'
    $script:sourceHtml='wrong content'
    Throws-Source {Get-SBSourceContent $source.endpoints[0] $transport} 'contenuto atteso assente rifiutato'
    $script:sourceHtml=$savedHtml
    $probe=Invoke-SBSourceProbe $registry $transport
    Assert-Source ($probe.complete -and $probe.sources[0].status -eq 'unbaselined') 'fonte senza baseline distinta da invariata'
    foreach($code in @(401,403,404,429,500)){
        $script:sourceStatus=$code
        $p=Invoke-SBSourceProbe $registry {param($ep) $failure=New-SBError 'sources.http' @($script:sourceStatus);$failure.Data['httpStatus']=$script:sourceStatus;throw $failure}
        Assert-Source (!$p.complete -and $p.sources[0].status -eq 'unverifiable' -and $p.sources[0].errors[0].reason -eq ('http-'+$code) -and $p.sources[0].errors[0].code -eq 'sources.reason.http' -and $p.sources[0].errors[0].message.Contains([string]$code)) ('HTTP '+$code+' non diventa assenza o successo')
    }
    $p=Invoke-SBSourceProbe $registry {throw [TimeoutException]::new('secret must not be logged')}
    Assert-Source (!$p.complete -and (ConvertTo-SBJson $p) -notmatch 'secret must') 'timeout sanificato e copertura incompleta'
    $source.endpoints+=@{id='secondary';url='https://example.com/second';format='html';role='original';allowedHosts=@('example.com');expectedText='Articolo'}
    Put-Source $metadata (ConvertTo-SBJson $source);$registry=Read-SBSourceRegistry $root
    $p=Invoke-SBSourceProbe $registry {param($ep) if($ep.id -eq 'secondary'){throw 'http-403'};& $transport $ep}
    Assert-Source (!$p.complete -and $p.sources[0].status -eq 'partial') 'copertura parziale preservata'
    $source.endpoints=@($source.endpoints[0]);Put-Source $metadata (ConvertTo-SBJson $source);$registry=Read-SBSourceRegistry $root
    if(!$PythonPath){
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1') -Force
        $localPath=Get-SBHostConfigPath ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))
        if(Test-Path -LiteralPath $localPath){
            $local=Read-SBConfiguration $localPath -ReadOnly
            $candidate=if($local.ContainsKey('sourcePythonPath')){$local.sourcePythonPath}else{Join-Path $local.runtimeRoot 'sources/python/Scripts/python.exe'}
            if(Test-Path -LiteralPath $candidate){$PythonPath=$candidate}
        }
    }
    $collected=Invoke-SBSourceCollect $config $registry 'fixture' $PythonPath $transport
    Assert-Source ($collected.versionId -and $collected.status -in @('extracted','unavailable')) 'raccolta conserva originali e versione candidata'
    $registry=Read-SBSourceRegistry $root
    Assert-Source (!$registry.sources[0].acceptedVersion -and $registry.sources[0].versions[0].reviewStatus -eq 'candidate') 'raccolta non adotta regole o versioni'
    $again=Invoke-SBSourceCollect $config $registry 'fixture' $PythonPath $transport
    Assert-Source ($again.status -eq 'unchanged' -and (Read-SBSourceRegistry $root).sources[0].versions.Count -eq 1) 'riesecuzione non duplica versioni'
    Assert-Source ((Invoke-SBSourceProbe $registry $transport).sources[0].status -eq 'unchanged') 'confronto con baseline candidata invariata'
    $script:sourceHtml=$script:sourceHtml.Replace('12.345,67','98.765,43')
    Assert-Source ((Invoke-SBSourceProbe $registry $transport).sources[0].status -eq 'changed') 'variazione contenuto rilevata'
    $script:sourceHtml=$savedHtml
    $catalog=Get-SBSourceCatalog $registry
    Put-Source (Join-Path $registryPath 'catalog.json') $catalog.json;Put-Source (Join-Path $registryPath 'README.md') $catalog.markdown
    $before=@{};foreach($f in Get-ChildItem $root -File -Recurse){$before[$f.FullName]=@((Get-SBFileHash $f.FullName),$f.LastWriteTimeUtc.Ticks)}
    $issues=@(Get-SBSourceChecks $registry $config)
    foreach($f in Get-ChildItem $root -File -Recurse){Assert-Source ($before.ContainsKey($f.FullName) -and $before[$f.FullName][0] -ceq (Get-SBFileHash $f.FullName) -and $before[$f.FullName][1] -eq $f.LastWriteTimeUtc.Ticks) 'Check preserva byte e timestamp'}
    Assert-Source (@($issues|Where-Object kind -eq 'candidate-pending').Count -eq 1) 'candidata pendente segnalata'
    $manifestPath=Join-Path $registry.sources[0]._root ('versions/'+$collected.versionId+'/manifest.json')
    $manifest=Read-SBJson $manifestPath $null
    if($collected.status -eq 'unavailable'){
        Assert-Source ($manifest.transcription.diagnostics.code -eq 'sources.reason.converter-unavailable' -and $manifest.transcription.diagnostics.message) 'converter diagnostics persist a stable code and localized message'
    }
    if($manifest.transcription.path){
        $text=Read-SBText (Join-Path (Split-Path $manifestPath) $manifest.transcription.path)
        Assert-Source ($text -match '(?m)^Ente: ' -and $text -match '(?m)^---$') 'preambolo di provenienza separato dal testo originale'
    }
    $original=Get-SBSourceChild (Split-Path $manifestPath) $manifest.artifacts[0].path
    $originalBytes=[IO.File]::ReadAllBytes($original);[IO.File]::AppendAllText($original,'changed')
    Throws-Source {Get-SBSourceChecks $registry $config} 'hash originale discordante rifiutato'
    Throws-Source {Invoke-SBSourceCollect $config $registry 'fixture' $PythonPath $transport} 'raccolta ripetuta non nasconde originale modificato'
    [IO.File]::WriteAllBytes($original,$originalBytes)
    $source=Read-SBJson $metadata $null;$source.acceptedVersion=$collected.versionId;Put-Source $metadata (ConvertTo-SBJson $source)
    Throws-Source {Get-SBSourceChecks (Read-SBSourceRegistry $root) $config} 'accettazione senza revisione rifiutata'
    $source.acceptedVersion=$null;$source.rights.status='reference-only';Put-Source $metadata (ConvertTo-SBJson $source)
    Throws-Source {Invoke-SBSourceCollect $config (Read-SBSourceRegistry $root) 'fixture' $PythonPath $transport} 'licenza restrittiva impedisce acquisizione'
    $source.rights.status='public-reusable';Put-Source $metadata (ConvertTo-SBJson $source)
    $source.domains=@('unknown');Put-Source $metadata (ConvertTo-SBJson $source)
    Throws-Source {Read-SBSourceRegistry $root} 'ambito sconosciuto rifiutato'
    $source.domains=@('security');Put-Source $metadata (ConvertTo-SBJson $source)
    $source.relatedSources=@(@{id='missing';relation='related'});Put-Source $metadata (ConvertTo-SBJson $source)
    Throws-Source {Read-SBSourceRegistry $root} 'riferimento a fonte mancante rifiutato'
    $source.relatedSources=@();Put-Source $metadata (ConvertTo-SBJson $source)
    Save-SBSourceReport $config (Invoke-SBSourceProbe (Read-SBSourceRegistry $root) $transport)|Out-Null
    Assert-Source (Test-Path -LiteralPath (Join-Path $config.runtimeRoot 'sources/latest.json')) 'rapporto salvato soltanto nel runtime'
    $freshRegistry=Read-SBSourceRegistry $root
    $freshIssues=@(Get-SBSourceChecks $freshRegistry $config)
    Assert-Source (!@($freshIssues|Where-Object kind -eq 'verification-stale').Count) 'rapporto fresco legato alla scheda corrente'
    $reportPath=Join-Path $config.runtimeRoot 'sources/latest.json'
    $stale=Read-SBJson $reportPath $null;$stale.checkedAt=[DateTimeOffset]::UtcNow.AddDays(-15).ToString('o')
    Put-Source $reportPath (ConvertTo-SBJson $stale)
    Assert-Source (@(Get-SBSourceChecks $freshRegistry $config|Where-Object kind -eq 'verification-stale').Count -eq 1) 'verifica piu vecchia di 14 giorni segnalata'
    $reportsDir=Join-Path $config.runtimeRoot 'sources/reports'
    $oldReport=Join-Path $reportsDir '20000101T0000000000000Z-aaaaaaaa.json'
    $userReport=Join-Path $reportsDir 'user-report.json'
    Put-Source $oldReport '{}';Put-Source $userReport '{}'
    (Get-Item -LiteralPath $oldReport).LastWriteTimeUtc=[datetime]::UtcNow.AddDays(-100)
    (Get-Item -LiteralPath $userReport).LastWriteTimeUtc=[datetime]::UtcNow.AddDays(-100)
    $sourceHashBefore=Get-SBFileHash $metadata
    Save-SBSourceReport $config (Invoke-SBSourceProbe $freshRegistry $transport)|Out-Null
    Assert-Source ((Test-Path -LiteralPath $oldReport) -and (Test-Path -LiteralPath $userReport)) 'rapporti vecchi conservati fino alla pulizia esplicita'
    Assert-Source ((Get-SBFileHash $metadata) -ceq $sourceHashBefore) 'salvataggio periodico non modifica il corpus'
    $changedSource=Read-SBJson $metadata $null;$changedSource.notes+= 'Metadata changed'
    Put-Source $metadata (ConvertTo-SBJson $changedSource)
    Assert-Source (@(Get-SBSourceChecks (Read-SBSourceRegistry $root) $config|Where-Object kind -eq 'verification-stale').Count -eq 1) 'scheda cambiata invalida rapporto precedente'
    $areaPath=Join-Path $root '02-areas/products/Fixture'
    Put-Source (Join-Path $areaPath 'repository.json') (ConvertTo-SBJson @{schemaVersion=1;identity='github.com/test/fixture'})
    $index=Read-SBJson (Join-Path $root 'para-index.json') $null
    $index.entities+=@{id='area-fixture';kind='area';path='02-areas/products/Fixture';archived=$false;status='active'}
    Put-Source (Join-Path $root 'para-index.json') (ConvertTo-SBJson $index)
    Assert-Source (@(Get-SBSourceChecks (Read-SBSourceRegistry $root) $config -IncludeDossiers|Where-Object kind -eq 'mapping-missing').Count -eq 1) 'dossier attivo senza scheda segnalato'
    $mapping=@{schemaVersion=1;areaId='area-fixture';repository='github.com/test/fixture';assessedAt=[DateTimeOffset]::UtcNow.ToString('o');assessment='Fixture';sources=@(@{sourceId='missing';versionId=$null;applicability='unassessed';rationale='Fixture';implementation='unverified';requirements=@();evidence=@();tasks=@()});census=@{status='complete';reference='fixture'};residualTasks=@()}
    Put-Source (Join-Path $areaPath 'authoritative-sources.json') (ConvertTo-SBJson $mapping)
    Throws-Source {Get-SBSourceChecks (Read-SBSourceRegistry $root) $config -IncludeDossiers} 'fonte sconosciuta nella scheda del prodotto rifiutata'
    if($PythonPath){
        # -B: nessuna cache bytecode in scripts/
        & $PythonPath -B (Join-Path $PSScriptRoot 'test-source-convert.py') -v
        Assert-Source ($LASTEXITCODE -eq 0) 'conversione HTML PDF DOCX CSV JSON e scansione'
    }else{'SKIP SOURCE: convertitore dedicato assente; suite conversione richiesta nel collaudo di acquisizione'}
    $success=$true
    "SUCCESS SOURCE: $passed verifiche; runtime=$($PSVersionTable.PSVersion)"
}finally{
    if($success){
        $resolved=[IO.Path]::GetFullPath($root);$allowed=[IO.Path]::GetFullPath((Get-SBTestRoot)).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar

        Write-Output ('Fixture conservata: '+$resolved)
    }else{"Fixture fonti conservata: $root"}
}
