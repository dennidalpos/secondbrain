#requires -Version 7.5
[CmdletBinding()]
param([string]$PythonPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sources.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$passed=0
function Assert-Source($Value,[string]$Message){if(!$Value){throw "FAIL SOURCE: $Message"};$script:passed++;"PASS SOURCE: $Message"}
function Throws-Source([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Assert-Source $caught $Message}
function Assert-SourceError([scriptblock]$Action,[string]$Code,[string]$Message){$caught=$false;$detail='nessun errore';try{& $Action|Out-Null}catch{$caught=Test-SBError $_ $Code;$detail=$_.Exception.Message};Assert-Source $caught ($Message+' ('+$Code+')'+$(if(!$caught){': '+$detail}))}
function Put-Source([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$root=Join-Path (Get-SBTestRoot) ('secondbrain-sources-test-'+[guid]::NewGuid().ToString('N'))
$success=$false
try {
    [IO.Directory]::CreateDirectory($root)|Out-Null
    foreach($name in @('source.schema.json','source-applicability.schema.json','source-decisions.schema.json')){Put-Source (Join-Path $root ('config/'+$name)) (Read-SBText (Join-Path $PSScriptRoot ('../config/'+$name)))}
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
    # #478: originals are not in Git. A missing original is reported as restorable, never as an error; Restore writes it only when the downloaded SHA-256 equals the manifest.
    Remove-Item -LiteralPath $original
    Assert-Source (@(Get-SBSourceChecks (Read-SBSourceRegistry $root) $config|Where-Object kind -eq 'original-missing').Count -eq 1) 'originale assente segnalato come ripristinabile, non come errore'
    $script:sourceHtml=$script:sourceHtml.Replace('12.345,67','98.765,43')
    $badRestore=Restore-SBSourceOriginals $config (Read-SBSourceRegistry $root) $transport
    Assert-Source (@($badRestore.restored).Count -eq 0 -and @($badRestore.failed).Count -eq 1 -and $badRestore.failed[0].reason -ceq 'hash-mismatch' -and !(Test-Path -LiteralPath $original)) 'ripristino con contenuto diverso rifiutato senza scrivere'
    $script:sourceHtml=$savedHtml
    $goodRestore=Restore-SBSourceOriginals $config (Read-SBSourceRegistry $root) $transport
    Assert-Source (@($goodRestore.restored).Count -eq 1 -and (Get-SBFileHash $original) -ceq $manifest.artifacts[0].sha256) 'ripristino con hash uguale al manifest riscrive l originale'
    Assert-Source (@(Get-SBSourceChecks (Read-SBSourceRegistry $root) $config|Where-Object kind -eq 'original-missing').Count -eq 0 -and @((Restore-SBSourceOriginals $config (Read-SBSourceRegistry $root) $transport).restored).Count -eq 0) 'originali presenti: nessun ripristino e nessun rilievo'
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
    # #439: mapping-outdated applies only to normative sources pinned to a version other than the accepted one.
    $reg=@{kind='regulation';acceptedVersion='v2'};$dec=@{kind='decision';acceptedVersion='v2'};$guide=@{kind='guideline';acceptedVersion='v2'}
    Assert-Source (Test-SBMappingOutdated @{versionId='v1'} $reg) 'mappatura a versione precedente di un regolamento produce mapping-outdated'
    Assert-Source (Test-SBMappingOutdated @{versionId='v1'} $dec) 'mappatura a versione precedente di una decisione produce mapping-outdated'
    Assert-Source (!(Test-SBMappingOutdated @{versionId='v2'} $reg)) 'mappatura aggiornata non produce il rilievo'
    Assert-Source (!(Test-SBMappingOutdated @{versionId='v1'} $guide)) 'fonte non normativa non produce il rilievo'
    Assert-Source (!(Test-SBMappingOutdated @{versionId=$null} $reg) -and !(Test-SBMappingOutdated @{versionId='v1'} @{kind='regulation';acceptedVersion=$null})) 'senza versione o senza versione accettata nessun rilievo'
    # #489: declared types derive from kind; normative and legal cards need a non-global jurisdiction, an official id and effective dates.
    Assert-Source ((Get-SBSourceCategory 'regulation') -ceq 'normative' -and (Get-SBSourceCategory 'decision') -ceq 'legal' -and (Get-SBSourceCategory 'dependency') -ceq 'product' -and (Get-SBSourceCategory 'license') -ceq 'product' -and (Get-SBSourceCategory 'runbook') -ceq 'product' -and (Get-SBSourceCategory 'guideline') -ceq 'reference' -and (Get-SBSourceCategory 'dataset') -ceq 'reference') 'categoria normativa, legale, prodotto o riferimento derivata dal tipo'
    $schemaPath=Join-Path $root 'config/source.schema.json'
    $law=@{schemaVersion=1;id='fixture-law';title='Fixture law';kind='regulation';issuer='Fixture';domains=@('security');jurisdictions=@('IT');language='it';officialId='1/2026';edition='GU 1/2026';publicationDate='2026-01-01';rights=@{status='public-reusable';reference='https://example.com/license';notes='Fixture'};endpoints=@(@{id='canonical';url='https://example.com/law';format='html';role='canonical';allowedHosts=@('example.com');expectedText='Articolo'});versions=@();acceptedVersion=$null;relatedSources=@();effectiveDates=@();notes=@()}
    Assert-Source (!(Test-Json -Json (ConvertTo-SBJson $law) -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) 'regolamento senza date di efficacia rifiutato dallo schema'
    $law.effectiveDates=@(@{provision='Entrata in vigore';date=$null;status='requires-verification';reference='GU 1/2026'})
    Assert-Source (Test-Json -Json (ConvertTo-SBJson $law) -SchemaFile $schemaPath -ErrorAction SilentlyContinue) 'regolamento con giurisdizione, identificativo e data dichiarata valido'
    $law.jurisdictions=@('Global')
    Assert-Source (!(Test-Json -Json (ConvertTo-SBJson $law) -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) 'regolamento con giurisdizione Global rifiutato'
    $law.jurisdictions=@('IT');$law.officialId=$null
    Assert-Source (!(Test-Json -Json (ConvertTo-SBJson $law) -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) 'regolamento senza identificativo ufficiale rifiutato'
    $law.officialId='1/2026'
    $product=$law.Clone();$product.kind='license';$product.jurisdictions=@('Global');$product.officialId=$null;$product.effectiveDates=@()
    Assert-Source (Test-Json -Json (ConvertTo-SBJson $product) -SchemaFile $schemaPath -ErrorAction SilentlyContinue) 'fonte di prodotto (licenza) senza obblighi normativi valida'
    $lawPath=Join-Path $registryPath 'entries/fixture-law/metadata.json'
    $law.effectiveDates=@();Put-Source $lawPath (ConvertTo-SBJson $law)
    Assert-SourceError {Read-SBSourceRegistry $root} 'sources.card.invalid' 'registro rifiuta la scheda normativa incompleta'
    $law.effectiveDates=@(@{provision='Entrata in vigore';date=$null;status='requires-verification';reference='GU 1/2026'});Put-Source $lawPath (ConvertTo-SBJson $law)
    $registry=Read-SBSourceRegistry $root
    Assert-Source (@(Get-SBSourceChecks $registry $config|Where-Object {$_.kind -eq 'effective-date-unverified' -and $_.sourceId -eq 'fixture-law'}).Count -eq 1) 'data di efficacia da verificare segnalata'
    Assert-SourceError {Add-SBSourceEffectiveDate $config $registry 'fixture-law' 'Applicazione' '' 'verified' 'GU 1/2026'} 'sources.effective.input' 'data verified senza giorno rifiutata'
    Assert-SourceError {Add-SBSourceEffectiveDate $config $registry 'fixture-law' 'Entrata in vigore' '2026-01-16' 'verified' 'GU 1/2026'} 'sources.effective.duplicate' 'disposizione gia registrata rifiutata'
    $added=Add-SBSourceEffectiveDate $config $registry 'fixture-law' 'Applicazione' '2026-02-01' 'verified' 'GU 1/2026, art. 2'
    $registry=Read-SBSourceRegistry $root;$lawCard=@($registry.sources|Where-Object id -eq 'fixture-law')[0]
    Assert-Source ($added.effectiveDates -eq 2 -and @($lawCard.effectiveDates|Where-Object {$_.provision -eq 'Applicazione' -and $_.status -eq 'verified' -and $_.date -eq '2026-02-01'}).Count -eq 1) 'data di efficacia aggiunta tramite comando con scheda validata'
    $catalogView=Read-SBJson (Join-Path $registryPath 'catalog.json') $null
    Assert-Source (@($catalogView.sources|Where-Object {$_.id -eq 'fixture-law' -and $_.category -eq 'normative'}).Count -eq 1 -and !@(Get-SBSourceChecks $registry $config|Where-Object kind -eq 'index-drift').Count) 'indice rigenerato con la categoria dopo la scrittura'
    # #490: candidates are accepted or rejected by command, with the decision appended to decisions.json.
    function Set-SourceExtracted($Registry,[string]$VersionId){
        $versionRoot=Join-Path (@($Registry.sources|Where-Object id -eq 'fixture-law')[0]._root) ('versions/'+$VersionId)
        Put-Source (Join-Path $versionRoot 'transcript.md') ('# Fixture '+$VersionId)
        $m=Read-SBJson (Join-Path $versionRoot 'manifest.json') $null
        $m.transcription=@{status='extracted';path='transcript.md';sha256=(Get-SBFileHash (Join-Path $versionRoot 'transcript.md'));diagnostics=@{status='extracted'}}
        Put-Source (Join-Path $versionRoot 'manifest.json') (ConvertTo-SBJson $m)
    }
    $review=@{scope='Fixture review';structure=$true;numbersAndTables=$true;citedPassages=$true}
    $v1=(Invoke-SBSourceCollect $config $registry 'fixture-law' $null $transport).versionId
    $registry=Read-SBSourceRegistry $root
    Assert-SourceError {Invoke-SBSourceDecision $config $registry 'fixture-law' $v1 'reject' '' 'Fixture'} 'sources.decision.input' 'decisione senza motivo rifiutata'
    Assert-SourceError {Invoke-SBSourceDecision $config $registry 'fixture-law' 'missing-version' 'reject' 'Fixture' 'Fixture'} 'sources.decision.version' 'versione non registrata rifiutata'
    Assert-SourceError {Invoke-SBSourceDecision $config $registry 'fixture-law' $v1 'known-variant' 'Fixture' 'Fixture'} 'sources.decision.variant' 'variante nota su candidata rifiutata'
    Assert-SourceError {Invoke-SBSourceDecision $config $registry 'fixture-law' $v1 'accept' 'Fixture' 'Fixture'} 'sources.decision.review' 'accettazione di candidata senza revisione rifiutata'
    Assert-SourceError {Invoke-SBSourceDecision $config $registry 'fixture-law' $v1 'accept' 'Fixture' 'Fixture' $review} 'sources.decision.transcript' 'accettazione senza trascrizione estratta rifiutata'
    Set-SourceExtracted $registry $v1
    $accepted=Invoke-SBSourceDecision $config $registry 'fixture-law' $v1 'accept' 'Fixture accepted' 'Fixture reviewer' $review
    $registry=Read-SBSourceRegistry $root;$lawCard=@($registry.sources|Where-Object id -eq 'fixture-law')[0]
    $lawRoot=$lawCard._root
    Assert-Source ($accepted.acceptedVersion -ceq $v1 -and $lawCard.acceptedVersion -ceq $v1 -and @($lawCard.versions|Where-Object {$_.id -ceq $v1 -and $_.reviewStatus -eq 'verified'}).Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $lawRoot ('versions/'+$v1+'/review.json')))) 'candidata accettata con revisione scritta e versione verificata'
    $lawIssues=@(Get-SBSourceChecks $registry $config|Where-Object sourceId -eq 'fixture-law')
    Assert-Source (!@($lawIssues|Where-Object kind -in @('candidate-pending','review-pending')).Count) 'versione accettata non resta pendente e supera la verifica della revisione'
    Assert-SourceError {Invoke-SBSourceDecision $config $registry 'fixture-law' $v1 'accept' 'Fixture' 'Fixture'} 'sources.decision.accepted' 'versione gia accettata non riaccettata'
    Assert-SourceError {Invoke-SBSourceDecision $config $registry 'fixture-law' $v1 'reject' 'Fixture' 'Fixture'} 'sources.decision.reject' 'versione accettata non rifiutabile'
    $script:sourceHtml=$savedHtml.Replace('12.345,67','11.111,11')
    $v2=(Invoke-SBSourceCollect $config $registry 'fixture-law' $null $transport).versionId
    $registry=Read-SBSourceRegistry $root
    Assert-Source (@(Get-SBSourceChecks $registry $config|Where-Object {$_.kind -eq 'candidate-pending' -and $_.versionId -ceq $v2}).Count -eq 1) 'nuova candidata pendente'
    $rejected=Invoke-SBSourceDecision $config $registry 'fixture-law' $v2 'reject' 'Fixture rejected' 'Fixture reviewer'
    $registry=Read-SBSourceRegistry $root;$lawCard=@($registry.sources|Where-Object id -eq 'fixture-law')[0]
    Assert-Source ($rejected.cardChanged -and @($lawCard.versions|Where-Object {$_.id -ceq $v2 -and $_.reviewStatus -eq 'rejected'}).Count -eq 1 -and $lawCard.acceptedVersion -ceq $v1 -and !@(Get-SBSourceChecks $registry $config|Where-Object {$_.kind -eq 'candidate-pending' -and $_.sourceId -eq 'fixture-law'}).Count) 'candidata rifiutata non piu pendente, versione accettata invariata'
    Assert-SourceError {Invoke-SBSourceDecision $config $registry 'fixture-law' $v2 'reject' 'Fixture' 'Fixture'} 'sources.decision.reject' 'versione gia rifiutata non rifiutata due volte'
    Assert-Source ((Invoke-SBSourceCollect $config $registry 'fixture-law' $null $transport).status -eq 'unchanged' -and @((Read-SBSourceRegistry $root).sources|Where-Object id -eq 'fixture-law')[0].versions.Count -eq 2) 'contenuto gia rifiutato non ricrea una candidata'
    $log=Read-SBJson (Join-Path $lawRoot 'decisions.json') $null
    Assert-Source ($log.sourceId -eq 'fixture-law' -and @($log.decisions).Count -eq 2 -and $log.decisions[0].decision -eq 'accept' -and $null -eq $log.decisions[0].previousAcceptedVersion -and $log.decisions[1].decision -eq 'reject' -and $log.decisions[1].reason -eq 'Fixture rejected' -and $log.decisions[1].fingerprint -match '^[A-F0-9]{64}$') 'storico delle decisioni conservato con motivo, autore e impronta'
    # Known variant: a verified fingerprint the live endpoint returns again is not reported as changed; any other fingerprint still is.
    $v1Fingerprint=(Read-SBJson (Join-Path $lawRoot ('versions/'+$v1+'/manifest.json')) $null).fingerprint
    $hashBefore=$lawCard._hash
    $report=@{schemaVersion=1;checkedAt=[DateTimeOffset]::UtcNow.ToString('o');complete=$true;sources=@(@{sourceId='fixture-law';configurationHash=$lawCard._hash;status='changed';complete=$true;fingerprint=$v1Fingerprint;endpoints=@();errors=@()})}
    Put-Source (Join-Path $config.runtimeRoot 'sources/latest.json') (ConvertTo-SBJson $report)
    Assert-Source (@(Get-SBSourceChecks $registry $config|Where-Object {$_.kind -eq 'changed' -and $_.sourceId -eq 'fixture-law'}).Count -eq 1) 'variazione segnalata prima della decisione'
    $variant=Invoke-SBSourceDecision $config $registry 'fixture-law' $v1 'known-variant' 'Fixture cosmetic' 'Fixture reviewer'
    $registry=Read-SBSourceRegistry $root;$lawCard=@($registry.sources|Where-Object id -eq 'fixture-law')[0]
    Assert-Source (!$variant.cardChanged -and $lawCard._hash -ceq $hashBefore -and !@(Get-SBSourceChecks $registry $config|Where-Object {$_.kind -in @('changed','verification-stale') -and $_.sourceId -eq 'fixture-law'}).Count) 'variante nota non segnalata e rapporto ancora valido'
    $report.sources[0].fingerprint='0'*64;Put-Source (Join-Path $config.runtimeRoot 'sources/latest.json') (ConvertTo-SBJson $report)
    Assert-Source (@(Get-SBSourceChecks $registry $config|Where-Object {$_.kind -eq 'changed' -and $_.sourceId -eq 'fixture-law'}).Count -eq 1) 'impronta diversa dalla variante nota ancora segnalata'
    Put-Source (Join-Path $lawRoot 'decisions.json') '{"schemaVersion":1,"sourceId":"fixture-law","decisions":[]}'
    Assert-SourceError {Read-SBSourceRegistry $root} 'sources.decisions.invalid' 'registro delle decisioni non valido rifiutato'
    Put-Source (Join-Path $lawRoot 'decisions.json') (ConvertTo-SBJson $log)
    # #439: mapping-outdated end to end through Get-SBSourceChecks with a product mapping pinned to an older accepted version.
    $script:sourceHtml=$savedHtml.Replace('12.345,67','22.222,22')
    $registry=Read-SBSourceRegistry $root
    $v3=(Invoke-SBSourceCollect $config $registry 'fixture-law' $null $transport).versionId
    $registry=Read-SBSourceRegistry $root;Set-SourceExtracted $registry $v3
    $accepted=Invoke-SBSourceDecision $config $registry 'fixture-law' $v3 'accept' 'Fixture new edition' 'Fixture reviewer' $review
    Assert-Source ((Read-SBJson (Join-Path $lawRoot 'decisions.json') $null).decisions[-1].previousAcceptedVersion -ceq $v1) 'accettazione registra la versione accettata precedente'
    $script:sourceHtml=$savedHtml
    $mapping.sources=@(@{sourceId='fixture-law';versionId=$v1;applicability='applicable';rationale='Fixture';implementation='unverified';requirements=@();evidence=@();tasks=@()})
    Put-Source (Join-Path $areaPath 'authoritative-sources.json') (ConvertTo-SBJson $mapping)
    $outdated=@(Get-SBSourceChecks (Read-SBSourceRegistry $root) $config -IncludeDossiers|Where-Object kind -eq 'mapping-outdated')
    Assert-Source ($outdated.Count -eq 1 -and $outdated[0].areaId -eq 'area-fixture' -and $outdated[0].versionId -ceq $v1 -and $outdated[0].currentVersionId -ceq $v3) 'mappatura di prodotto a versione precedente produce mapping-outdated nel controllo'
    $mapping.sources[0].versionId=$v3;Put-Source (Join-Path $areaPath 'authoritative-sources.json') (ConvertTo-SBJson $mapping)
    Assert-Source (!@(Get-SBSourceChecks (Read-SBSourceRegistry $root) $config -IncludeDossiers|Where-Object kind -eq 'mapping-outdated').Count) 'mappatura aggiornata alla versione accettata senza rilievo'
    if($PythonPath){
        # -B: no bytecode cache in scripts/.
        & $PythonPath -B (Join-Path $PSScriptRoot 'test-source-convert.py') -v
        Assert-Source ($LASTEXITCODE -eq 0) 'conversione HTML PDF DOCX CSV JSON e scansione'
    }else{'SKIP SOURCE: convertitore dedicato assente; suite conversione richiesta nel collaudo di acquisizione'}
    $success=$true
    "SUCCESS SOURCE: $passed verifiche; runtime=$($PSVersionTable.PSVersion)"
}finally{
    if($success){
        $resolved=[IO.Path]::GetFullPath($root);$null = [IO.Path]::GetFullPath((Get-SBTestRoot)).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar

        Write-Output ('Fixture conservata: '+$resolved)
    }else{"Fixture fonti conservata: $root"}
}
