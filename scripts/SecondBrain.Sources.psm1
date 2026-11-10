#requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'sources.reason.http' = @{ it = 'Risposta HTTP {0} non verificabile'; en = 'HTTP {0} response could not be verified' }
    'sources.reason.access-challenge' = @{ it = 'Accesso alla fonte soggetto a verifica'; en = 'Source access requires a challenge' }
    'sources.reason.unverifiable' = @{ it = 'Fonte non verificabile'; en = 'Source could not be verified' }
    'sources.reason.converter-unavailable' = @{ it = 'Convertitore non disponibile'; en = 'Converter unavailable' }
    'sources.reason.conversion-timeout' = @{ it = 'Tempo della conversione scaduto'; en = 'Conversion timed out' }
    'sources.reason.scanned-empty-or-incomplete' = @{ it = 'Trascrizione vuota o incompleta'; en = 'Transcript empty or incomplete' }
    'sources.redirect.limit' = @{ it = 'Limite dei reindirizzamenti raggiunto'; en = 'Redirect limit reached' }
    'sources.http' = @{ it = 'Risposta HTTP {0}'; en = 'HTTP response {0}' }
    'sources.download.large' = @{ it = 'Download oltre il limite di dimensione'; en = 'Download exceeds size limit' }
    'sources.access.challenge' = @{ it = 'Verifica di accesso richiesta dalla fonte'; en = 'Source access challenge required' }
    'sources.path.outside' = @{ it = 'Percorso fonte fuori perimetro'; en = 'Source path outside scope' }
    'sources.index.invalid' = @{ it = 'Indice PARA assente o non valido'; en = 'PARA index missing or invalid' }
    'sources.resource.unresolved' = @{ it = 'Risorsa resource-authoritative-sources non risolvibile'; en = 'Resource resource-authoritative-sources cannot be resolved' }
    'sources.resource.metadata' = @{ it = 'Metadati della risorsa fonti divergenti'; en = 'Source resource metadata diverge' }
    'sources.domains.invalid' = @{ it = 'Ambiti del registro non validi'; en = 'Invalid registry domains' }
    'sources.card.invalid' = @{ it = 'Scheda fonte non valida: {0}'; en = 'Invalid source card: {0}' }
    'sources.id.diverged' = @{ it = 'Identificatore fonte duplicato o divergente'; en = 'Duplicate or diverging source identifier' }
    'sources.domain.unknown' = @{ it = 'Ambito sconosciuto: {0}'; en = 'Unknown domain: {0}' }
    'sources.endpoint.duplicate' = @{ it = 'Endpoint duplicato'; en = 'Duplicate endpoint' }
    'sources.endpoint.canonical' = @{ it = 'Occorre un solo endpoint canonico'; en = 'Exactly one canonical endpoint is required' }
    'sources.linked.unresolved' = @{ it = 'Fonte collegata non risolvibile'; en = 'Linked source cannot be resolved' }
    'sources.endpoint.https' = @{ it = 'Endpoint HTTPS non ammesso'; en = 'HTTPS endpoint not allowed' }
    'sources.address.nonpublic' = @{ it = 'Indirizzo di rete non pubblico'; en = 'Non-public network address' }
    'sources.dns.nonpublic' = @{ it = 'Risoluzione DNS non pubblica'; en = 'Non-public DNS resolution' }
    'sources.payload.empty' = @{ it = 'Payload vuoto o oltre limite'; en = 'Empty payload or over the limit' }
    'sources.format.pdf' = @{ it = 'Formato PDF non valido'; en = 'Invalid PDF format' }
    'sources.format.docx' = @{ it = 'Formato DOCX non valido'; en = 'Invalid DOCX format' }
    'sources.content.unverifiable' = @{ it = 'Contenuto atteso non verificabile'; en = 'Expected content cannot be verified' }
    'sources.original.name' = @{ it = 'Nome originale non valido'; en = 'Invalid original name' }
    'sources.version.duplicate' = @{ it = 'Versione duplicata'; en = 'Duplicate version' }
    'sources.manifest.invalid' = @{ it = 'Manifest versione non valido: {0}'; en = 'Invalid version manifest: {0}' }
    'sources.version.noprimaries' = @{ it = 'Versione senza originali'; en = 'Version without originals' }
    'sources.original.invalid' = @{ it = 'Originale versione non valido o duplicato'; en = 'Invalid or duplicate version original' }
    'sources.original.hash' = @{ it = 'Hash originale divergente: {0}'; en = 'Original hash diverges: {0}' }
    'sources.fingerprint.diverged' = @{ it = 'Fingerprint versione divergente'; en = 'Version fingerprint diverges' }
    'sources.transcript.hash' = @{ it = 'Hash trascrizione divergente'; en = 'Transcript hash diverges' }
    'sources.transcript.altHash' = @{ it = 'Hash trascrizione alternativa divergente'; en = 'Alternative transcript hash diverges' }
    'sources.transcript.revision' = @{ it = 'Revisione della trascrizione non verificabile'; en = 'Transcript revision cannot be verified' }
    'sources.version.unverified' = @{ it = 'Versione accettata non verificata'; en = 'Accepted version not verified' }
    'sources.applicability.invalid' = @{ it = 'Scheda di applicabilita non valida'; en = 'Invalid applicability card' }
    'sources.applicability.identity' = @{ it = 'Identita scheda fonti divergente'; en = 'Source card identity diverges' }
    'sources.product.duplicate' = @{ it = 'Fonte duplicata nella scheda del prodotto'; en = 'Duplicate source in the product card' }
    'sources.product.unresolved' = @{ it = 'Fonte del prodotto non risolvibile'; en = 'Product source cannot be resolved' }
    'sources.product.version' = @{ it = 'Versione del prodotto non risolvibile'; en = 'Product version cannot be resolved' }
    'sources.resource.archived' = @{ it = 'Risorsa archiviata: acquisizione non consentita'; en = 'Archived resource: acquisition not allowed' }
    'sources.unregistered' = @{ it = 'Fonte non registrata'; en = 'Source not registered' }
    'sources.reference.only' = @{ it = 'Fonte utilizzabile solo come riferimento'; en = 'Source usable as reference only' }
    'sources.endpoint.none' = @{ it = 'Nessun endpoint acquisibile'; en = 'No acquirable endpoint' }
    'sources.original.modified' = @{ it = 'Originale esistente modificato: acquisizione invariata non verificabile'; en = 'Existing original modified: unchanged acquisition cannot be verified' }
    'sources.transcript.modified' = @{ it = 'Trascrizione esistente modificata'; en = 'Existing transcript modified' }
    'sources.version.incomplete' = @{ it = 'Versione incompleta gia presente: preservata per revisione'; en = 'Incomplete version already present: preserved for review' }
    'sources.converter.unavailable' = @{ it = 'Rapporto convertitore non disponibile'; en = 'Converter report unavailable' }
}

function Get-SBSourceChild([string]$Root,[string]$Relative) {
    if(!$Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)|:'){throw (New-SBError 'sources.path.outside')}
    $base=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $full=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if(!$full.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'sources.path.outside')}
    Assert-SBPlainPath $full
    $full
}
function Resolve-SBSourceRegistry([string]$BrainRoot) {
    $index=Read-SBJson (Join-Path $BrainRoot 'para-index.json') $null
    if(!$index -or $index.schemaVersion -ne 1){throw (New-SBError 'sources.index.invalid')}
    $items=@($index.entities|Where-Object id -eq 'resource-authoritative-sources')
    if($items.Count -ne 1 -or $items[0].kind -ne 'resource'){throw (New-SBError 'sources.resource.unresolved')}
    $root=Get-SBSourceChild $BrainRoot $items[0].path
    $meta=Read-SBJson (Join-Path $root 'para.json') $null
    if(!$meta -or $meta.id -ne $items[0].id -or $meta.kind -ne 'resource' -or $meta.schemaVersion -ne 1){throw (New-SBError 'sources.resource.metadata')}
    @{root=$root;archived=([bool]$items[0].archived -or $items[0].path.StartsWith('04-archives/',[StringComparison]::Ordinal) -or $meta.status -ne 'active');relativePath=$items[0].path}
}
function Read-SBSourceRegistry([string]$BrainRoot) {
    $resolved=Resolve-SBSourceRegistry $BrainRoot
    $schema=Join-Path $BrainRoot 'config/source.schema.json'
    $domains=Read-SBJson (Join-Path $resolved.root 'domains.json') $null
    if(!$domains -or $domains.schemaVersion -ne 1 -or !$domains.domains.Count){throw (New-SBError 'sources.domains.invalid')}
    $sources=@();$seen=@{}
    $entries=Join-Path $resolved.root 'entries'
    if(Test-Path -LiteralPath $entries){
        foreach($dir in Get-ChildItem -LiteralPath $entries -Directory|Sort-Object Name){
            Assert-SBPlainPath $dir.FullName
            $path=Join-Path $dir.FullName 'metadata.json'
            $text=Read-SBText $path
            if(!(Test-Json -Json $text -SchemaFile $schema -ErrorAction SilentlyContinue)){throw (New-SBError 'sources.card.invalid' @($dir.Name))}
            $source=$text|ConvertFrom-Json -AsHashtable -DateKind String
            if($source.id -cne $dir.Name -or $seen.ContainsKey($source.id)){throw (New-SBError 'sources.id.diverged')}
            $seen[$source.id]=$true
            foreach($domain in $source.domains){if($domain -notin @($domains.domains.id)){throw (New-SBError 'sources.domain.unknown' @($domain))}}
            $endpointIds=@{}
            foreach($endpoint in $source.endpoints){
                if($endpointIds.ContainsKey($endpoint.id)){throw (New-SBError 'sources.endpoint.duplicate')}
                $endpointIds[$endpoint.id]=$true
                Assert-SBSourceUri $endpoint.url $endpoint.allowedHosts -SkipDns
            }
            if($source.endpoints.Count -and @($source.endpoints|Where-Object role -eq 'canonical').Count -ne 1){throw (New-SBError 'sources.endpoint.canonical')}
            $source['_path']=$path;$source['_hash']=Get-SBFileHash $path
            $source['_root']=$dir.FullName
            $sources+=,$source
        }
    }
    foreach($source in $sources){foreach($related in $source.relatedSources){if(!$seen.ContainsKey($related.id)){throw (New-SBError 'sources.linked.unresolved')}}}
    @{root=$resolved.root;relativePath=$resolved.relativePath;archived=$resolved.archived;domains=$domains;sources=$sources;brainRoot=$BrainRoot}
}
function Test-SBPublicAddress([Net.IPAddress]$Address) {
    if($Address.IsIPv4MappedToIPv6){$Address=$Address.MapToIPv4()}
    if([Net.IPAddress]::IsLoopback($Address)){return $false}
    $b=$Address.GetAddressBytes()
    if($b.Length -eq 4){
        return !($b[0] -in @(0,10,127) -or $b[0] -ge 224 -or ($b[0] -eq 169 -and $b[1] -eq 254) -or ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) -or ($b[0] -eq 192 -and $b[1] -in @(0,168)) -or ($b[0] -eq 100 -and $b[1] -ge 64 -and $b[1] -le 127))
    }
    return !($Address.IsIPv6LinkLocal -or $Address.IsIPv6SiteLocal -or $Address.IsIPv6Multicast -or ($b[0] -band 254) -eq 252 -or $Address.Equals([Net.IPAddress]::IPv6Any))
}
function Assert-SBSourceUri([string]$Url,[string[]]$AllowedHosts,[switch]$SkipDns) {
    $uri=$null
    if(![Uri]::TryCreate($Url,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'https' -or !$uri.IsDefaultPort -or $uri.UserInfo -or $uri.Fragment -or $uri.Host -notin $AllowedHosts -or $uri.Query -match '(?i)(?:[?&])(?:token|password|secret|api_?key)='){throw (New-SBError 'sources.endpoint.https')}
    $ip=$null
    if([Net.IPAddress]::TryParse($uri.DnsSafeHost,[ref]$ip)){
        if(!(Test-SBPublicAddress $ip)){throw (New-SBError 'sources.address.nonpublic')}
    } elseif(!$SkipDns){
        $addresses=@([Net.Dns]::GetHostAddresses($uri.DnsSafeHost))
        if(!$addresses.Count -or @($addresses|Where-Object {!(Test-SBPublicAddress $_)}).Count){throw (New-SBError 'sources.dns.nonpublic')}
    }
}
function Get-SBSourceContent([hashtable]$Endpoint,[scriptblock]$Transport) {
    Assert-SBSourceUri $Endpoint.url $Endpoint.allowedHosts -SkipDns:([bool]$Transport)
    if($Transport){$result=& $Transport $Endpoint}
    else {
        $handler=[Net.Http.HttpClientHandler]::new();$handler.AllowAutoRedirect=$false
        $handler.UseCookies=$false;$handler.UseDefaultCredentials=$false
        $client=[Net.Http.HttpClient]::new($handler)
        $client.DefaultRequestHeaders.UserAgent.ParseAdd('SecondBrain-Sources/1.0 (+local authoritative-source registry)')
        $cancel=[Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(30))
        $url=$Endpoint.url;$result=$null
        try {
            for($redirect=0;$redirect -le 5;$redirect++){
                Assert-SBSourceUri $url $Endpoint.allowedHosts
                $request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get,$url)
                $response=$null
                try {
                    $response=$client.SendAsync($request,[Net.Http.HttpCompletionOption]::ResponseHeadersRead,$cancel.Token).GetAwaiter().GetResult()
                    $code=[int]$response.StatusCode
                    if($code -in @(301,302,303,307,308)){
                        if(!$response.Headers.Location -or $redirect -eq 5){throw (New-SBError 'sources.redirect.limit')}
                        $url=[Uri]::new([Uri]$url,$response.Headers.Location).AbsoluteUri
                        Assert-SBSourceUri $url $Endpoint.allowedHosts
                        continue
                    }
                    if($code -ne 200){$failure=New-SBError 'sources.http' @($code);$failure.Data['httpStatus']=$code;throw $failure}
                    $max=50MB
                    if($response.Content.Headers.ContentLength -gt $max){throw (New-SBError 'sources.download.large')}
                    $sourceStream=$response.Content.ReadAsStreamAsync($cancel.Token).GetAwaiter().GetResult()
                    $output=[IO.MemoryStream]::new();$buffer=[byte[]]::new(65536)
                    try {
                        while(($read=$sourceStream.ReadAsync($buffer,0,$buffer.Length,$cancel.Token).GetAwaiter().GetResult()) -gt 0){
                            if($output.Length+$read -gt $max){throw (New-SBError 'sources.download.large')}
                            $output.Write($buffer,0,$read)
                        }
                        $result=@{bytes=$output.ToArray();finalUrl=$url;httpStatus=$code;contentType=[string]$response.Content.Headers.ContentType;etag=[string]$response.Headers.ETag;lastModified=[string]$response.Content.Headers.LastModified}
                    } finally {$sourceStream.Dispose();$output.Dispose()}
                    break
                } finally {if($response){$response.Dispose()};$request.Dispose()}
            }
        } finally {$cancel.Dispose();$client.Dispose()}
    }
    if(!$result -or !$result.bytes -or $result.bytes.Length -gt 50MB){throw (New-SBError 'sources.payload.empty')}
    Assert-SBSourceUri $result.finalUrl $Endpoint.allowedHosts -SkipDns:([bool]$Transport)
    $text=[Text.Encoding]::UTF8.GetString($result.bytes)
    if($Endpoint.format -eq 'pdf' -and !$text.StartsWith('%PDF-',[StringComparison]::Ordinal)){throw (New-SBError 'sources.format.pdf')}
    if($Endpoint.format -eq 'docx' -and !($result.bytes[0] -eq 80 -and $result.bytes[1] -eq 75)){throw (New-SBError 'sources.format.docx')}
    if($Endpoint.format -in @('html','text','json','csv')){
        if($text -match '(?i)<title>\s*(?:just a moment|access denied|captcha|javascript is disabled)' -or $text -match '(?i)verify that you.re not a robot'){throw (New-SBError 'sources.access.challenge')}
        if($Endpoint.expectedText -and $text -notmatch $Endpoint.expectedText){throw (New-SBError 'sources.content.unverifiable')}
        if($Endpoint.format -eq 'json'){$null=$text|ConvertFrom-Json -AsHashtable -DateKind String}
    }
    $result['sha256']=Get-SBHash $result.bytes
    # HTML: executable content and whitespace alone do not count as changes.
    $relevant=if($Endpoint.format -eq 'html'){
        $clean=[regex]::Replace($text,'(?is)<(script|style|noscript)\b[^>]*>.*?</\1>|<!--.*?-->',' ')
        [regex]::Replace([Net.WebUtility]::HtmlDecode([regex]::Replace($clean,'<[^>]+>',' ')),'\s+',' ').Trim()
    }else{$null}
    $result['contentHash']=if($null -ne $relevant){Get-SBTextHash $relevant}else{$result.sha256}
    $result
}
function Get-SBSourceFingerprint($Artifacts) {
    Get-SBTextHash ((@($Artifacts|Sort-Object endpointId|ForEach-Object {$_.endpointId+':'+$_.contentHash})) -join "`n")
}
function Get-SBSourceOriginalName($Endpoint) {
    $name=if($Endpoint.ContainsKey('fileName')){$Endpoint.fileName}else{$Endpoint.id+'.'+$(if($Endpoint.format -eq 'text'){'txt'}else{$Endpoint.format})}
    if($name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,100}$'){throw (New-SBError 'sources.original.name')}
    $name
}
function Invoke-SBSourceProbe($Registry,[scriptblock]$Transport) {
    $results=@()
    foreach($source in $Registry.sources){
        $items=@();$errors=@()
        foreach($ep in $source.endpoints){
            try {
                $download=Get-SBSourceContent $ep $Transport
                $items+=@{endpointId=$ep.id;url=$download.finalUrl;sha256=$download.sha256;contentHash=$download.contentHash;etag=$download.etag;lastModified=$download.lastModified}
            } catch {
                $reason='unverifiable'
                if(Test-SBError $_ 'sources.http'){
                    $failure=$_.Exception;while(!$failure.Data.Contains('httpStatus') -and $failure.InnerException){$failure=$failure.InnerException}
                    if($failure.Data.Contains('httpStatus')){$reason='http-'+$failure.Data['httpStatus']}
                }elseif(Test-SBError $_ 'sources.access.challenge'){$reason='access-challenge'}
                $errors+=Add-SBReportDiagnostic @{endpointId=$ep.id;reason=$reason} 'sources'
            }
        }
        $fingerprint=if($items.Count -and !$errors.Count){Get-SBSourceFingerprint $items}else{$null}
        $baseline=$null
        if($source.versions.Count){
            $last=if($source.acceptedVersion){@($source.versions|Where-Object id -ceq $source.acceptedVersion)[0]}else{@($source.versions|Sort-Object id)[-1]}
            $baseline=Read-SBJson (Get-SBSourceChild $source._root ('versions/'+$last.id+'/manifest.json')) $null
        }
        $status=if(!$source.endpoints.Count){'reference-only'}elseif($errors.Count){if($items.Count){'partial'}else{'unverifiable'}}elseif(!$baseline){'unbaselined'}elseif($baseline.fingerprint -ceq $fingerprint){'unchanged'}else{'changed'}
        $results+=@{sourceId=$source.id;configurationHash=$source._hash;status=$status;complete=(!$errors.Count -and $source.endpoints.Count -gt 0);fingerprint=$fingerprint;endpoints=$items;errors=$errors}
    }
    @{schemaVersion=1;checkedAt=[DateTimeOffset]::UtcNow.ToString('o');sources=$results;complete=(@($results|Where-Object { !$_.complete -and $_.status -ne 'reference-only'}).Count -eq 0)}
}
function Save-SBSourceReport($Config,$Report) {
    $dir=Join-Path $Config.runtimeRoot 'sources/reports';Assert-SBPlainPath $dir
    $id=[DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    $text=ConvertTo-SBJson $Report
    Write-SBFile (Join-Path $dir ($id+'.json')) ([Text.Encoding]::UTF8.GetBytes($text)) 'absent' $Config.backupRoot|Out-Null
    $latest=Join-Path $Config.runtimeRoot 'sources/latest.json'
    Assert-SBWriteGuard
    Write-SBAccessMetadata $latest $Report
    # Reports are retained regardless of age. Only an explicitly requested cleanup may remove them.
    Join-Path $dir ($id+'.json')
}
function Get-SBSourceCatalog($Registry) {
    $entries=@($Registry.sources|ForEach-Object {@{id=$_.id;title=$_.title;kind=$_.kind;domains=$_.domains;acceptedVersion=$_.acceptedVersion;versions=$_.versions;path='entries/'+$_.id+'/metadata.json';metadataSha256=$_._hash}})
    $catalog=@{schemaVersion=1;resourceId='resource-authoritative-sources';sources=$entries}
    $lines=@('# Registro comune delle fonti autorevoli','','Indice generato dalle schede. Le guide sono consultive; le prescrizioni comuni seguono il processo di approvazione delle direttive.','','| Fonte | Tipo | Ambiti | Versione accettata |','|---|---|---|---|')
    foreach($entry in $entries){$lines+='| ['+$entry.title.Replace('|','\|')+']('+ $entry.path +') | '+$entry.kind+' | '+($entry.domains -join ', ')+' | '+$(if($entry.acceptedVersion){$entry.acceptedVersion}else{'da revisionare / riferimento'})+' |'}
    @{json=ConvertTo-SBJson $catalog;markdown=($lines -join "`n")+"`n"}
}
function Get-SBSourceChecks($Registry,$Config,[switch]$IncludeDossiers) {
    $issues=[Collections.Generic.List[object]]::new()
    $latest=Read-SBJson (Join-Path $Config.runtimeRoot 'sources/latest.json') $null
    foreach($source in $Registry.sources){
        $versionIds=@{}
        foreach($version in $source.versions){
            if($versionIds.ContainsKey($version.id)){throw (New-SBError 'sources.version.duplicate')};$versionIds[$version.id]=$true
            $root=Get-SBSourceChild $source._root ('versions/'+$version.id)
            $manifest=Read-SBJson (Join-Path $root 'manifest.json') $null
            if(!$manifest -or $manifest.schemaVersion -ne 1 -or $manifest.sourceId -cne $source.id -or $manifest.versionId -cne $version.id){throw (New-SBError 'sources.manifest.invalid' @($source.id))}
            if(!$manifest.artifacts.Count){throw (New-SBError 'sources.version.noprimaries')}
            $artifactIds=@{}
            foreach($artifact in $manifest.artifacts){
                if($artifactIds.ContainsKey($artifact.endpointId) -or $artifact.path -notmatch '^originals/[a-zA-Z0-9][a-zA-Z0-9_.-]{0,100}$' -or $artifact.sha256 -notmatch '^[A-F0-9]{64}$' -or $artifact.contentHash -notmatch '^[A-F0-9]{64}$'){throw (New-SBError 'sources.original.invalid')}
                $artifactIds[$artifact.endpointId]=$true
                if((Get-SBFileHash (Get-SBSourceChild $root $artifact.path)) -cne $artifact.sha256){throw (New-SBError 'sources.original.hash' @($source.id))}
            }
            if((Get-SBSourceFingerprint $manifest.artifacts) -cne $manifest.fingerprint){throw (New-SBError 'sources.fingerprint.diverged')}
            if($manifest.transcription.path -and (Get-SBFileHash (Get-SBSourceChild $root $manifest.transcription.path)) -cne $manifest.transcription.sha256){throw (New-SBError 'sources.transcript.hash')}
            if($manifest.ContainsKey('alternatives')){foreach($alternative in $manifest.alternatives){if((Get-SBFileHash (Get-SBSourceChild $root $alternative.path)) -cne $alternative.sha256){throw (New-SBError 'sources.transcript.altHash')}}}
            if($version.reviewStatus -eq 'verified'){
                $review=Read-SBJson (Join-Path $root 'review.json') $null
                if(!$review -or !$review.reviewer -or !$review.reviewedAt -or $review.fingerprint -cne $manifest.fingerprint -or $review.transcriptSha256 -cne $manifest.transcription.sha256 -or !$review.structure -or !$review.numbersAndTables -or !$review.citedPassages -or $manifest.transcription.status -ne 'extracted'){throw (New-SBError 'sources.transcript.revision')}
            }
            elseif($version.id -cne $source.acceptedVersion){$issues.Add(@{kind='candidate-pending';sourceId=$source.id;versionId=$version.id})}
        }
        if($source.acceptedVersion -and (!$versionIds.ContainsKey($source.acceptedVersion) -or @($source.versions|Where-Object { $_.id -ceq $source.acceptedVersion -and $_.reviewStatus -eq 'verified'}).Count -ne 1)){throw (New-SBError 'sources.version.unverified')}
        if($source.rights.status -ne 'reference-only' -and !$source.acceptedVersion){$issues.Add(@{kind='review-pending';sourceId=$source.id})}
        $checks=@(if($latest){$latest.sources|Where-Object sourceId -eq $source.id})
        if($source.endpoints.Count -and (!$checks.Count -or $checks[0].configurationHash -cne $source._hash -or [DateTimeOffset]::Parse($latest.checkedAt) -lt [DateTimeOffset]::UtcNow.AddDays(-14))){$issues.Add(@{kind='verification-stale';sourceId=$source.id})}
        elseif($checks.Count -and $checks[0].status -notin @('unchanged','reference-only')){$issues.Add(@{kind=$checks[0].status;sourceId=$source.id})}
    }
    $catalog=Get-SBSourceCatalog $Registry
    foreach($view in @(@{name='catalog.json';text=$catalog.json},@{name='README.md';text=$catalog.markdown})){
        if((Get-SBFileHash (Join-Path $Registry.root $view.name)) -cne (Get-SBTextHash $view.text)){$issues.Add(@{kind='index-drift';path=$view.name})}
    }
    if($IncludeDossiers){
        $index=Read-SBJson (Join-Path $Registry.brainRoot 'para-index.json') $null
        foreach($entity in $index.entities|Where-Object {(Test-SBRepoDossier $_) -and !$_.archived -and $_.status -eq 'active'}){
            $root=Get-SBSourceChild $Registry.brainRoot $entity.path
            if(!(Test-Path -LiteralPath (Join-Path $root 'repository.json'))){continue}
            $path=Join-Path $root 'authoritative-sources.json';$map=Read-SBJson $path $null
            if(!$map){$issues.Add(@{kind='mapping-missing';areaId=$entity.id});continue}
            if(!(Test-Json -Json (Read-SBText $path) -SchemaFile (Join-Path $Registry.brainRoot 'config/source-applicability.schema.json') -ErrorAction SilentlyContinue) -or $map.areaId -cne $entity.id){throw (New-SBError 'sources.applicability.invalid')}
            $repo=Read-SBJson (Join-Path $root 'repository.json') $null
            if($map.repository -cne $repo.identity){throw (New-SBError 'sources.applicability.identity')}
            $ids=@{}
            foreach($ref in $map.sources){
                if($ids.ContainsKey($ref.sourceId)){throw (New-SBError 'sources.product.duplicate')};$ids[$ref.sourceId]=$true
                $target=@($Registry.sources|Where-Object id -ceq $ref.sourceId)
                if($target.Count -ne 1){throw (New-SBError 'sources.product.unresolved')}
                if($ref.versionId -and @($target[0].versions|Where-Object id -ceq $ref.versionId).Count -ne 1){throw (New-SBError 'sources.product.version')}
                if($ref.applicability -eq 'unassessed'){$issues.Add(@{kind='applicability-unassessed';areaId=$entity.id;sourceId=$ref.sourceId})}
                if($ref.versionId -and $target[0].acceptedVersion -and $target[0].kind -in @('regulation','decision') -and $ref.versionId -cne $target[0].acceptedVersion){$issues.Add(@{kind='mapping-outdated';areaId=$entity.id;sourceId=$ref.sourceId;versionId=$ref.versionId;currentVersionId=$target[0].acceptedVersion})}
            }
        }
    }
    @($issues.ToArray())
}
function Invoke-SBSourceCollect($Config,$Registry,[string]$SourceId,[string]$PythonPath,[scriptblock]$Transport) {
    if($Registry.archived){throw (New-SBError 'sources.resource.archived')}
    $sources=@($Registry.sources|Where-Object id -ceq $SourceId)
    if($sources.Count -ne 1){throw (New-SBError 'sources.unregistered')}
    $source=$sources[0]
    if($source.rights.status -ne 'public-reusable'){throw (New-SBError 'sources.reference.only')}
    $downloads=@();$artifacts=@()
    foreach($endpoint in $source.endpoints){
        $download=Get-SBSourceContent $endpoint $Transport
        $downloads+=@{endpoint=$endpoint;download=$download}
        $artifacts+=@{endpointId=$endpoint.id;path='originals/'+(Get-SBSourceOriginalName $endpoint);sha256=$download.sha256;contentHash=$download.contentHash;url=$download.finalUrl;contentType=$download.contentType}
    }
    if(!$artifacts.Count){throw (New-SBError 'sources.endpoint.none')}
    $fingerprint=Get-SBSourceFingerprint $artifacts
    foreach($version in $source.versions){
        $existing=Read-SBJson (Get-SBSourceChild $source._root ('versions/'+$version.id+'/manifest.json')) $null
        if($existing -and $existing.fingerprint -ceq $fingerprint){
            $versionRoot=Get-SBSourceChild $source._root ('versions/'+$version.id)
            foreach($artifact in $existing.artifacts){if((Get-SBFileHash (Get-SBSourceChild $versionRoot $artifact.path)) -cne $artifact.sha256){throw (New-SBError 'sources.original.modified')}}
            if($existing.transcription.path -and (Get-SBFileHash (Get-SBSourceChild $versionRoot $existing.transcription.path)) -cne $existing.transcription.sha256){throw (New-SBError 'sources.transcript.modified')}
            return @{sourceId=$SourceId;versionId=$version.id;status='unchanged'}
        }
    }
    $versionId=[DateTimeOffset]::UtcNow.ToString('yyyyMMdd')+'-'+$fingerprint.Substring(0,16).ToLowerInvariant()
    $versionRoot=Get-SBSourceChild $source._root ('versions/'+$versionId)
    if(Test-Path -LiteralPath $versionRoot){throw (New-SBError 'sources.version.incomplete')}
    foreach($item in $downloads){
        $artifact=@($artifacts|Where-Object endpointId -eq $item.endpoint.id)[0]
        Write-SBFile (Get-SBSourceChild $versionRoot $artifact.path) $item.download.bytes 'absent' $Config.backupRoot|Out-Null
    }
    $canonical=@($downloads|Where-Object {$_.endpoint.role -eq 'canonical'})[0]
    $original=Get-SBSourceChild $versionRoot ('originals/'+(Get-SBSourceOriginalName $canonical.endpoint))
    $transcript=Join-Path $versionRoot 'transcript.md';$diagnostics=Join-Path $versionRoot 'conversion.json'
    $converter=Join-Path $PSScriptRoot 'source-convert.py'
    $result=@{status='unavailable';reason='converter-unavailable'}
    if($PythonPath -and (Test-Path -LiteralPath $PythonPath)){
        $layout=if($canonical.endpoint.ContainsKey('layout')){$canonical.endpoint.layout}else{'single'}
        $start=[Diagnostics.ProcessStartInfo]::new($PythonPath)
        $workRoot=Join-Path $Config.runtimeRoot ('sources/work/'+[guid]::NewGuid().ToString('N'))
        foreach($name in @('TEMP','TMP','TMPDIR','PIP_CACHE_DIR','PYTHONPYCACHEPREFIX')){
            $directory=Join-Path $workRoot $name
            [IO.Directory]::CreateDirectory($directory)|Out-Null;$start.Environment[$name]=$directory
        }
        $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        foreach($arg in @('-B',$converter,'--input',$original,'--format',$canonical.endpoint.format,'--layout',$layout,'--output',$transcript,'--report',$diagnostics)){$start.ArgumentList.Add($arg)}
        $process=[Diagnostics.Process]::Start($start)
        try{
            $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
            if(!$process.WaitForExit(120000)){$process.Kill($true);$result=@{status='incomplete';reason='conversion-timeout'}}
            else{$null=$out.GetAwaiter().GetResult();$null=$err.GetAwaiter().GetResult()}
        }finally{$process.Dispose()}
        if(Test-Path -LiteralPath $diagnostics){$result=Read-SBJson $diagnostics $null}
        if(!$result){throw (New-SBError 'sources.converter.unavailable')}
    }
    [void](Add-SBReportDiagnostic $result 'sources')
    if(Test-Path -LiteralPath $transcript){
        $previousHash=Get-SBFileHash $transcript
        $prefix=@(('# Trascrizione della fonte: '+$source.title),'',('Ente: '+$source.issuer),('Fonte originale: '+$canonical.download.finalUrl),('SHA-256 originale: '+$canonical.download.sha256),('Riutilizzo: '+$source.rights.notes),('Condizioni: '+$source.rights.reference),'','Conversione locale di formato; revisione separata dalla estrazione. Non costituisce una dichiarazione di vigenza o conformita.','','---','') -join "`n"
        if($source.ContainsKey('dataset')){$prefix+="`nMetadati del dataset:`n"+(ConvertTo-SBJson $source.dataset)+"`n---`n"}
        Write-SBFile $transcript ([Text.Encoding]::UTF8.GetBytes($prefix+"`n"+(Read-SBText $transcript))) $previousHash $Config.backupRoot|Out-Null
    }
    $manifest=@{schemaVersion=1;sourceId=$SourceId;versionId=$versionId;edition=$source.edition;publicationDate=$source.publicationDate;language=$source.language;acquiredAt=[DateTimeOffset]::UtcNow.ToString('o');fingerprint=$fingerprint;configurationHash=$source._hash;artifacts=$artifacts;transcription=@{status=$result.status;path=$(if(Test-Path -LiteralPath $transcript){'transcript.md'}else{$null});sha256=$(if(Test-Path -LiteralPath $transcript){Get-SBFileHash $transcript}else{$null});diagnostics=$result}}
    Write-SBFile (Join-Path $versionRoot 'manifest.json') ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $manifest))) 'absent' $Config.backupRoot|Out-Null
    $source.versions+=@{id=$versionId;reviewStatus='candidate'}
    $path=$source._path;$hash=$source._hash
    $data=@{};foreach($key in $source.Keys){if(!$key.StartsWith('_',[StringComparison]::Ordinal)){$data[$key]=$source[$key]}}
    Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $data))) $hash $Config.backupRoot|Out-Null
    @{sourceId=$SourceId;versionId=$versionId;status=$result.status}
}
function Find-SBSourceReferences($Registry,$Source) {
    # Heuristic: official numbers (YYYY/N or N/YYYY, "n. N del <date> <year>") found in the accepted, else latest, transcript.
    $version=if($Source.acceptedVersion){@($Source.versions|Where-Object id -ceq $Source.acceptedVersion)[0]}elseif($Source.versions.Count){@($Source.versions|Sort-Object id)[-1]}else{$null}
    $resolved=[Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal);$tokens=[Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    if($version){
        $versionRoot=Get-SBSourceChild $Source._root ('versions/'+$version.id)
        $manifest=Read-SBJson (Join-Path $versionRoot 'manifest.json') $null
        if($manifest -and $manifest.transcription.path){
            $text=Read-SBText (Get-SBSourceChild $versionRoot $manifest.transcription.path)
            foreach($m in [regex]::Matches($text,'(?<![\d/])(\d{4})/(\d{1,4})(?![\d/])')){[void]$tokens.Add($m.Groups[1].Value+'/'+$m.Groups[2].Value)}
            foreach($m in [regex]::Matches($text,'(?i)\bn\.?\s*(\d{1,4})\s+del\s+\d{1,2}\s+\p{L}+\s+(\d{4})')){[void]$tokens.Add($m.Groups[1].Value+'/'+$m.Groups[2].Value)}
        }
    }
    $unresolved=@()
    foreach($token in $tokens){
        $parts=$token -split '/'
        $pattern='(?<![\d/])'+[regex]::Escape($token)+'(?![\d/])|(?<![\d/])'+[regex]::Escape($parts[1]+'/'+$parts[0])+'(?![\d/])'
        $hits=@($Registry.sources|Where-Object {$_.id -cne $Source.id -and $_.officialId -and $_.officialId -match $pattern})
        if($hits.Count){foreach($hit in $hits){[void]$resolved.Add($hit.id)}}elseif($token -ne ($Source.officialId -replace '^.*?(\d{4}/\d+).*$','$1')){$unresolved+=$token}
    }
    @{sourceId=$Source.id;resolved=@($resolved);unresolved=@($unresolved)}
}
function Get-SBSourceClosure($Registry,[string[]]$Seeds,[ValidateRange(0,10)][int]$MaxDepth=3,[ValidateRange(1,500)][int]$MaxSources=50) {
    $included=[ordered]@{};$queue=@{};$frontier=@($Seeds|Where-Object {$_})
    $byId=@{};foreach($source in $Registry.sources){$byId[$source.id]=$source}
    for($depth=0;$depth -le $MaxDepth -and $frontier.Count;$depth++){
        $next=@()
        foreach($id in $frontier){
            if($included.Contains($id) -or !$byId.ContainsKey($id)){continue}
            if($included.Count -ge $MaxSources){$queue['limit:'+$id]=@{kind='limit-reached';sourceId=$id};continue}
            $included[$id]=$depth
            $found=Find-SBSourceReferences $Registry $byId[$id]
            $next+=@($byId[$id].relatedSources|ForEach-Object {$_.id})+@($found.resolved)
            foreach($token in $found.unresolved){$queue[$id+'|'+$token]=@{kind='unresolved-reference';sourceId=$id;reference=$token}}
        }
        $frontier=@($next|Select-Object -Unique)
    }
    if($frontier.Count -and $depth -gt $MaxDepth){foreach($id in $frontier|Where-Object {!$included.Contains($_)}){$queue['depth:'+$id]=@{kind='depth-limit';sourceId=$id}}}
    @{sources=@($included.Keys);depths=$included;queue=@($queue.Keys|Sort-Object|ForEach-Object {$queue[$_]})}
}
Export-ModuleMember -Function @(
    'Get-SBSourceChild',
    'Read-SBSourceRegistry',
    'Test-SBPublicAddress',
    'Assert-SBSourceUri',
    'Get-SBSourceContent',
    'Invoke-SBSourceProbe',
    'Save-SBSourceReport',
    'Get-SBSourceCatalog',
    'Get-SBSourceChecks',
    'Invoke-SBSourceCollect',
    'Find-SBSourceReferences',
    'Get-SBSourceClosure'
)
