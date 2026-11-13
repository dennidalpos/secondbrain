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
    'sources.decisions.invalid' = @{ it = 'Registro delle decisioni non valido: {0}; ripristinarlo dal backup o da Git'; en = 'Invalid decision log: {0}; restore it from the backup or from Git' }
    'sources.decision.input' = @{ it = 'Decisione senza motivo o autore: indicare -Reason e -DecidedBy'; en = 'Decision without reason or author: pass -Reason and -DecidedBy' }
    'sources.decision.version' = @{ it = 'Versione {0} non registrata nella scheda: usare un id di versions'; en = 'Version {0} is not registered in the card: use an id from versions' }
    'sources.decision.reject' = @{ it = 'Si rifiuta solo una versione candidate o incomplete non accettata'; en = 'Only a candidate or incomplete version that is not accepted can be rejected' }
    'sources.decision.variant' = @{ it = 'Una variante nota deve essere una versione verified'; en = 'A known variant must be a verified version' }
    'sources.decision.accepted' = @{ it = 'La versione e gia quella accettata'; en = 'The version is already the accepted one' }
    'sources.decision.accept' = @{ it = 'Si accetta solo una versione verified o candidate'; en = 'Only a verified or candidate version can be accepted' }
    'sources.decision.review' = @{ it = 'Accettare una candidata richiede -ReviewScope e le tre conferme di revisione'; en = 'Accepting a candidate requires -ReviewScope and the three review confirmations' }
    'sources.decision.transcript' = @{ it = 'Candidata senza trascrizione estratta: ricollezionare o rifiutare'; en = 'Candidate without an extracted transcript: collect again or reject' }
    'sources.effective.input' = @{ it = 'Data di efficacia non valida: verified richiede una data yyyy-MM-dd, sempre provision e reference'; en = 'Invalid effective date: verified requires a yyyy-MM-dd date, provision and reference are always required' }
    'sources.proposal.unrecognized' = @{ it = 'Riferimento non riconosciuto o ambiguo: {0}'; en = 'Reference not recognised or ambiguous: {0}' }
    'sources.proposal.origin' = @{ it = 'Fonte di origine del riferimento non indicata o non registrata: usare -SourceId'; en = 'Origin source of the reference missing or not registered: pass -SourceId' }
    'sources.effective.duplicate' = @{ it = 'Data di efficacia gia registrata per questa disposizione'; en = 'Effective date already registered for this provision' }
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
            # #490: decisions live beside the card, outside its hash, so a recorded decision does not invalidate the probe report.
            $decisionsPath=Join-Path $dir.FullName 'decisions.json'
            $source['_decisionsPath']=$decisionsPath;$source['_decisionsHash']=Get-SBFileHash $decisionsPath;$source['_decisions']=@()
            if($source._decisionsHash -cne 'absent'){
                $decisionsText=Read-SBText $decisionsPath
                if(!(Test-Json -Json $decisionsText -SchemaFile (Join-Path $BrainRoot 'config/source-decisions.schema.json') -ErrorAction SilentlyContinue)){throw (New-SBError 'sources.decisions.invalid' @($dir.Name))}
                $log=$decisionsText|ConvertFrom-Json -AsHashtable -DateKind String
                if($log.sourceId -cne $source.id){throw (New-SBError 'sources.decisions.invalid' @($dir.Name))}
                $source['_decisions']=@($log.decisions)
            }
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
    @{schemaVersion=1;checkedAt=(Get-SBNow).ToString('o');sources=$results;complete=(@($results|Where-Object { !$_.complete -and $_.status -ne 'reference-only'}).Count -eq 0)}
}
function Save-SBSourceReport($Config,$Report) {
    $dir=Join-Path $Config.runtimeRoot 'sources/reports';Assert-SBPlainPath $dir
    $id=(Get-SBNow).ToString('yyyyMMddTHHmmssfffffffZ')+'-'+(New-SBId).Substring(0,8)
    $text=ConvertTo-SBJson $Report
    Write-SBFile (Join-Path $dir ($id+'.json')) ([Text.Encoding]::UTF8.GetBytes($text)) 'absent' $Config.backupRoot|Out-Null
    $latest=Join-Path $Config.runtimeRoot 'sources/latest.json'
    Assert-SBWriteGuard
    Write-SBAccessMetadata $latest $Report
    # Reports are retained regardless of age. Only an explicitly requested cleanup may remove them.
    Join-Path $dir ($id+'.json')
}
function Get-SBSourceCategory([string]$Kind) {
    # #489: the declared type derives from kind. Normative and legal cards must declare a non-global jurisdiction,
    # an official identifier and at least one effective date (source.schema.json); product covers dependencies, licences and runbooks.
    if($Kind -ceq 'regulation'){return 'normative'}
    if($Kind -ceq 'decision'){return 'legal'}
    if($Kind -cin @('dependency','license','runbook')){return 'product'}
    'reference'
}
function Get-SBSourceCatalog($Registry) {
    $entries=@($Registry.sources|ForEach-Object {@{id=$_.id;title=$_.title;kind=$_.kind;category=(Get-SBSourceCategory $_.kind);domains=$_.domains;acceptedVersion=$_.acceptedVersion;versions=$_.versions;path='entries/'+$_.id+'/metadata.json';metadataSha256=$_._hash}})
    $catalog=@{schemaVersion=1;resourceId='resource-authoritative-sources';sources=$entries}
    $lines=@('# Registro comune delle fonti autorevoli','','Indice generato dalle schede. Le guide sono consultive; le prescrizioni comuni seguono il processo di approvazione delle direttive.','','| Fonte | Categoria | Tipo | Ambiti | Versione accettata |','|---|---|---|---|---|')
    foreach($entry in $entries){$lines+='| ['+$entry.title.Replace('|','\|')+']('+ $entry.path +') | '+$entry.category+' | '+$entry.kind+' | '+($entry.domains -join ', ')+' | '+$(if($entry.acceptedVersion){$entry.acceptedVersion}else{'da revisionare / riferimento'})+' |'}
    @{json=ConvertTo-SBJson $catalog;markdown=($lines -join "`n")+"`n"}
}
function Write-SBSourceIndex($Config,[string]$BrainRoot) {
    # Rebuilds catalog.json and README.md from a fresh read, so card hashes in the index match what was just written.
    # The views are generated in full: a dirty tracked copy is backed up (-BackupDirty), so several decisions fit in one commit.
    $registry=Read-SBSourceRegistry $BrainRoot
    $catalog=Get-SBSourceCatalog $registry
    foreach($view in @(@{name='catalog.json';text=$catalog.json},@{name='README.md';text=$catalog.markdown})){
        $path=Join-Path $registry.root $view.name
        if((Get-SBFileHash $path) -cne (Get-SBTextHash $view.text)){Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($view.text)) (Get-SBFileHash $path) $Config.backupRoot -BackupDirty|Out-Null}
    }
    $registry
}
function Get-SBSourceCardData($Source) {
    $data=@{};foreach($key in $Source.Keys){if(!$key.StartsWith('_',[StringComparison]::Ordinal)){$data[$key]=$Source[$key]}}
    $data
}
function Write-SBSourceCard($Config,$Registry,$Source) {
    $text=ConvertTo-SBJson (Get-SBSourceCardData $Source)
    if(!(Test-Json -Json $text -SchemaFile (Join-Path $Registry.brainRoot 'config/source.schema.json') -ErrorAction SilentlyContinue)){throw (New-SBError 'sources.card.invalid' @($Source.id))}
    Write-SBFile $Source._path ([Text.Encoding]::UTF8.GetBytes($text)) $Source._hash $Config.backupRoot|Out-Null
}
function Invoke-SBSourceDecision($Config,$Registry,[string]$SourceId,[string]$VersionId,[ValidateSet('accept','reject','known-variant')][string]$Decision,[string]$Reason,[string]$DecidedBy,[hashtable]$Review) {
    # #490: closes a version without hand edits. reject: a candidate stops being pending; accept: a verified version becomes
    # accepted, or a candidate with an extracted transcript after an attested review; known-variant: a verified version whose
    # fingerprint the live endpoint may return again is not reported as changed. Every decision is appended to decisions.json.
    if($Registry.archived){throw (New-SBError 'sources.resource.archived')}
    if([string]::IsNullOrWhiteSpace($Reason) -or [string]::IsNullOrWhiteSpace($DecidedBy)){throw (New-SBError 'sources.decision.input')}
    $sources=@($Registry.sources|Where-Object id -ceq $SourceId)
    if($sources.Count -ne 1){throw (New-SBError 'sources.unregistered')}
    $source=$sources[0]
    $entries=@($source.versions|Where-Object id -ceq $VersionId)
    if($entries.Count -ne 1){throw (New-SBError 'sources.decision.version' @($VersionId))}
    $version=$entries[0]
    $versionRoot=Get-SBSourceChild $source._root ('versions/'+$VersionId)
    $manifest=Read-SBJson (Join-Path $versionRoot 'manifest.json') $null
    if(!$manifest -or $manifest.schemaVersion -ne 1 -or $manifest.sourceId -cne $source.id -or $manifest.versionId -cne $VersionId){throw (New-SBError 'sources.manifest.invalid' @($source.id))}
    $previous=$source.acceptedVersion;$cardChanged=$false;$reviewRecord=$null
    if($Decision -eq 'reject'){
        if($VersionId -ceq $source.acceptedVersion -or $version.reviewStatus -notin @('candidate','incomplete')){throw (New-SBError 'sources.decision.reject')}
        $version.reviewStatus='rejected';$cardChanged=$true
    }elseif($Decision -eq 'known-variant'){
        if($version.reviewStatus -ne 'verified'){throw (New-SBError 'sources.decision.variant')}
    }else{
        if($VersionId -ceq $source.acceptedVersion){throw (New-SBError 'sources.decision.accepted')}
        if($version.reviewStatus -eq 'candidate'){
            if(!$Review -or $Review.structure -ne $true -or $Review.numbersAndTables -ne $true -or $Review.citedPassages -ne $true -or [string]::IsNullOrWhiteSpace([string]$Review.scope)){throw (New-SBError 'sources.decision.review')}
            if($manifest.transcription.status -ne 'extracted' -or !$manifest.transcription.sha256){throw (New-SBError 'sources.decision.transcript')}
            $reviewRecord=@{schemaVersion=1;reviewer=$DecidedBy;reviewedAt=(Get-SBNow).ToString('o');fingerprint=$manifest.fingerprint;transcriptSha256=$manifest.transcription.sha256;structure=$true;numbersAndTables=$true;citedPassages=$true;scope=[string]$Review.scope;corrections=@();limitations=@('Verification qualifies transcription of the acquired edition only. It does not establish legal currency, completeness of regulatory obligations or product compliance.')}
            $version.reviewStatus='verified'
        }elseif($version.reviewStatus -ne 'verified'){throw (New-SBError 'sources.decision.accept')}
        $source.acceptedVersion=$VersionId;$cardChanged=$true
    }
    $record=@{decision=$Decision;versionId=$VersionId;fingerprint=$manifest.fingerprint;reason=$Reason;decidedBy=$DecidedBy;decidedAt=(Get-SBNow).ToString('o')}
    if($Decision -eq 'accept'){$record['previousAcceptedVersion']=$previous}
    $log=@{schemaVersion=1;sourceId=$source.id;decisions=@($source._decisions)+@($record)}
    $logText=ConvertTo-SBJson $log
    if(!(Test-Json -Json $logText -SchemaFile (Join-Path $Registry.brainRoot 'config/source-decisions.schema.json') -ErrorAction SilentlyContinue)){throw (New-SBError 'sources.decisions.invalid' @($source.id))}
    if($reviewRecord){$reviewPath=Join-Path $versionRoot 'review.json';Write-SBFile $reviewPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $reviewRecord))) (Get-SBFileHash $reviewPath) $Config.backupRoot|Out-Null}
    if($cardChanged){Write-SBSourceCard $Config $Registry $source}
    Write-SBFile $source._decisionsPath ([Text.Encoding]::UTF8.GetBytes($logText)) $source._decisionsHash $Config.backupRoot|Out-Null
    if($cardChanged){$null=Write-SBSourceIndex $Config $Registry.brainRoot}
    @{sourceId=$source.id;versionId=$VersionId;decision=$Decision;acceptedVersion=$source.acceptedVersion;cardChanged=$cardChanged}
}
function Add-SBSourceEffectiveDate($Config,$Registry,[string]$SourceId,[string]$Provision,[string]$Date,[ValidateSet('verified','requires-verification')][string]$Status,[string]$Reference) {
    # #489: normative and legal cards need effective dates; an unknown date is declared as requires-verification with a null date, never guessed.
    if($Registry.archived){throw (New-SBError 'sources.resource.archived')}
    if([string]::IsNullOrWhiteSpace($Provision) -or [string]::IsNullOrWhiteSpace($Reference) -or ($Date -and $Date -notmatch '^\d{4}-\d{2}-\d{2}$') -or ($Status -eq 'verified' -and !$Date)){throw (New-SBError 'sources.effective.input')}
    $sources=@($Registry.sources|Where-Object id -ceq $SourceId)
    if($sources.Count -ne 1){throw (New-SBError 'sources.unregistered')}
    $source=$sources[0]
    $existing=@($source.effectiveDates|Where-Object provision -ceq $Provision)
    $entry=@{provision=$Provision;date=$(if($Date){$Date}else{$null});status=$Status;reference=$Reference}
    if($existing.Count){
        # A provision still marked requires-verification is resolved in place once its date is verified; any other repeat is a duplicate.
        if($existing.Count -ne 1 -or $existing[0].status -ne 'requires-verification' -or $Status -ne 'verified'){throw (New-SBError 'sources.effective.duplicate')}
        $source.effectiveDates=@($source.effectiveDates|ForEach-Object{if($_.provision -ceq $Provision){$entry}else{$_}})
    } else {
        $source.effectiveDates=@($source.effectiveDates)+@($entry)
    }
    Write-SBSourceCard $Config $Registry $source
    $null=Write-SBSourceIndex $Config $Registry.brainRoot
    @{sourceId=$source.id;effectiveDates=$source.effectiveDates.Count}
}
function Test-SBMappingOutdated($Reference,$Source) {
    # A product mapping pinned to a version older than the accepted one, for normative sources (regulations and decisions) only.
    [bool]($Reference.versionId -and $Source.acceptedVersion -and $Source.kind -in @('regulation','decision') -and $Reference.versionId -cne $Source.acceptedVersion)
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
                $originalHash=Get-SBFileHash (Get-SBSourceChild $root $artifact.path)
                if($originalHash -ceq 'absent'){$issues.Add(@{kind='original-missing';sourceId=$source.id;versionId=$version.id;path=$artifact.path})}
                elseif($originalHash -cne $artifact.sha256){throw (New-SBError 'sources.original.hash' @($source.id))}
            }
            if((Get-SBSourceFingerprint $manifest.artifacts) -cne $manifest.fingerprint){throw (New-SBError 'sources.fingerprint.diverged')}
            if($manifest.transcription.path -and (Get-SBFileHash (Get-SBSourceChild $root $manifest.transcription.path)) -cne $manifest.transcription.sha256){throw (New-SBError 'sources.transcript.hash')}
            if($manifest.ContainsKey('alternatives')){foreach($alternative in $manifest.alternatives){if((Get-SBFileHash (Get-SBSourceChild $root $alternative.path)) -cne $alternative.sha256){throw (New-SBError 'sources.transcript.altHash')}}}
            if($version.reviewStatus -eq 'verified'){
                $review=Read-SBJson (Join-Path $root 'review.json') $null
                if(!$review -or !$review.reviewer -or !$review.reviewedAt -or $review.fingerprint -cne $manifest.fingerprint -or $review.transcriptSha256 -cne $manifest.transcription.sha256 -or !$review.structure -or !$review.numbersAndTables -or !$review.citedPassages -or $manifest.transcription.status -ne 'extracted'){throw (New-SBError 'sources.transcript.revision')}
            }
            elseif($version.reviewStatus -ne 'rejected' -and $version.id -cne $source.acceptedVersion){$issues.Add(@{kind='candidate-pending';sourceId=$source.id;versionId=$version.id})}
        }
        if((Get-SBSourceCategory $source.kind) -in @('normative','legal')){
            foreach($date in @($source.effectiveDates|Where-Object status -eq 'requires-verification')){$issues.Add(@{kind='effective-date-unverified';sourceId=$source.id;provision=$date.provision})}
        }
        if($source.acceptedVersion -and (!$versionIds.ContainsKey($source.acceptedVersion) -or @($source.versions|Where-Object { $_.id -ceq $source.acceptedVersion -and $_.reviewStatus -eq 'verified'}).Count -ne 1)){throw (New-SBError 'sources.version.unverified')}
        if($source.rights.status -ne 'reference-only' -and !$source.acceptedVersion){$issues.Add(@{kind='review-pending';sourceId=$source.id})}
        $checks=@(if($latest){$latest.sources|Where-Object sourceId -eq $source.id})
        if($source.endpoints.Count -and (!$checks.Count -or $checks[0].configurationHash -cne $source._hash -or [DateTimeOffset]::Parse($latest.checkedAt) -lt (Get-SBNow).AddDays(-14))){$issues.Add(@{kind='verification-stale';sourceId=$source.id})}
        elseif($checks.Count -and $checks[0].status -notin @('unchanged','reference-only')){
            # A live fingerprint recorded as a known variant of a verified version is not a change to review again.
            $fingerprint=if($checks[0].ContainsKey('fingerprint')){[string]$checks[0].fingerprint}else{''}
            $verified=@($source.versions|Where-Object reviewStatus -eq 'verified'|ForEach-Object {$_.id})
            $known=$checks[0].status -eq 'changed' -and $fingerprint -and @($source._decisions|Where-Object {$_.decision -eq 'known-variant' -and $_.fingerprint -ceq $fingerprint -and $_.versionId -cin $verified}).Count
            if(!$known){$issues.Add(@{kind=$checks[0].status;sourceId=$source.id})}
        }
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
                if(Test-SBMappingOutdated $ref $target[0]){$issues.Add(@{kind='mapping-outdated';areaId=$entity.id;sourceId=$ref.sourceId;versionId=$ref.versionId;currentVersionId=$target[0].acceptedVersion})}
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
            foreach($artifact in $existing.artifacts){$currentHash=Get-SBFileHash (Get-SBSourceChild $versionRoot $artifact.path);if($currentHash -cne 'absent' -and $currentHash -cne $artifact.sha256){throw (New-SBError 'sources.original.modified')}}
            if($existing.transcription.path -and (Get-SBFileHash (Get-SBSourceChild $versionRoot $existing.transcription.path)) -cne $existing.transcription.sha256){throw (New-SBError 'sources.transcript.modified')}
            return @{sourceId=$SourceId;versionId=$version.id;status='unchanged'}
        }
    }
    $versionId=(Get-SBNow).ToString('yyyyMMdd')+'-'+$fingerprint.Substring(0,16).ToLowerInvariant()
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
        $workRoot=Join-Path $Config.runtimeRoot ('sources/work/'+(New-SBId))
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
    $manifest=@{schemaVersion=1;sourceId=$SourceId;versionId=$versionId;edition=$source.edition;publicationDate=$source.publicationDate;language=$source.language;acquiredAt=(Get-SBNow).ToString('o');fingerprint=$fingerprint;configurationHash=$source._hash;artifacts=$artifacts;transcription=@{status=$result.status;path=$(if(Test-Path -LiteralPath $transcript){'transcript.md'}else{$null});sha256=$(if(Test-Path -LiteralPath $transcript){Get-SBFileHash $transcript}else{$null});diagnostics=$result}}
    Write-SBFile (Join-Path $versionRoot 'manifest.json') ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $manifest))) 'absent' $Config.backupRoot|Out-Null
    $source.versions+=@{id=$versionId;reviewStatus='candidate'}
    Write-SBFile $source._path ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson (Get-SBSourceCardData $source)))) $source._hash $Config.backupRoot|Out-Null
    @{sourceId=$SourceId;versionId=$versionId;status=$result.status}
}
function Restore-SBSourceOriginals($Config,$Registry,[scriptblock]$Transport) {
    # #478: originals are not in Git. Every missing original of a public-reusable source is downloaded again from its endpoint and written only if its SHA-256 equals the manifest; a different content is reported, never written.
    $restored=@();$failed=@()
    foreach($source in @($Registry.sources|Where-Object {$_.rights.status -eq 'public-reusable'})){
        foreach($version in $source.versions){
            $root=Get-SBSourceChild $source._root ('versions/'+$version.id)
            $manifest=Read-SBJson (Join-Path $root 'manifest.json') $null
            if(!$manifest){continue}
            foreach($artifact in $manifest.artifacts){
                $target=Get-SBSourceChild $root $artifact.path
                if((Get-SBFileHash $target) -cne 'absent'){continue}
                $item=@{sourceId=$source.id;versionId=$version.id;path=$artifact.path}
                $endpoint=@($source.endpoints|Where-Object id -ceq $artifact.endpointId)
                if($endpoint.Count -ne 1){$failed+=$item+@{reason='endpoint-missing'};continue}
                try{
                    $download=Get-SBSourceContent $endpoint[0] $Transport
                    if($download.sha256 -cne $artifact.sha256){$failed+=$item+@{reason='hash-mismatch'};continue}
                    [IO.Directory]::CreateDirectory((Split-Path $target))|Out-Null
                    Write-SBFile $target $download.bytes 'absent' $Config.backupRoot|Out-Null
                    $restored+=$item
                }catch{$failed+=$item+@{reason=$_.Exception.Message}}
            }
        }
    }
    @{restored=$restored;failed=$failed}
}
$script:SBReferenceMonths=@{gennaio=1;febbraio=2;marzo=3;aprile=4;maggio=5;giugno=6;luglio=7;agosto=8;settembre=9;ottobre=10;novembre=11;dicembre=12;january=1;february=2;march=3;april=4;may=5;june=6;july=7;august=8;september=9;october=10;november=11;december=12}
function ConvertTo-SBReferenceDate([string]$Day,[string]$Month,[string]$Year) {
    $m=0;$lower=$Month.ToLowerInvariant()
    if($Month -match '^\d{1,2}$'){$m=[int]$Month}elseif($script:SBReferenceMonths.ContainsKey($lower)){$m=$script:SBReferenceMonths[$lower]}
    $d=[int]$Day;$y=[int]$Year
    if($y -lt 1 -or $m -lt 1 -or $m -gt 12 -or $d -lt 1 -or $d -gt [DateTime]::DaysInMonth($y,$m)){return $null}
    '{0:0000}-{1:00}-{2:00}' -f $y,$m,$d
}
function Get-SBTextReferences([string]$Text,[switch]$StructuredOnly) {
    # #438: citations of other acts in a text. Kinds: eli, celex, oj (EU Official Journal), gu (Gazzetta Ufficiale), number (YYYY/N, "n. N del <date> <year>").
    # Each citation has a display `reference` that this function recognises again and `ids` that identify the same act in other spellings. Detection only: nothing is resolved or downloaded.
    $found=[ordered]@{};$covered=[Collections.Generic.List[int[]]]::new()
    function Add-Citation($Match,[string]$Kind,[string]$Reference,[string[]]$Ids) {
        $covered.Add(@($Match.Index,($Match.Index+$Match.Length)))
        if(!$found.Contains($Reference)){$found[$Reference]=@{kind=$Kind;reference=$Reference;ids=@($Ids)}}else{$found[$Reference].ids=@(@($found[$Reference].ids)+$Ids|Select-Object -Unique)}
    }
    function Get-NumberIds([string]$Year,[string]$Number) {
        $n=[string][int]$Number;$y=[string][int]$Year
        @("n:$y/$n","n:$n/$y")
    }
    function Test-Covered($Match) {
        foreach($span in $covered){if($Match.Index -lt $span[1] -and ($Match.Index+$Match.Length) -gt $span[0]){return $true}}
        $false
    }
    foreach($m in [regex]::Matches($Text,'(?i)\beli/id/(\d{4})/(\d{2})/(\d{2})/([0-9A-Z]{5,14})(?:/[a-z]+)?(?![0-9A-Za-z])')){
        $date=ConvertTo-SBReferenceDate $m.Groups[3].Value $m.Groups[2].Value $m.Groups[1].Value
        if(!$date){continue}
        $id=$m.Groups[4].Value.ToUpperInvariant()
        Add-Citation $m 'eli' ('eli/id/'+($date -replace '-','/')+'/'+$id) @('eli:id/'+$date+'/'+$id)
    }
    foreach($m in [regex]::Matches($Text,'(?i)\beli/((?:reg|dir|dec)(?:_impl|_del)?|recomm|resol|opin)/(\d{4})/(\d{1,4})(?![0-9])')){
        $type=$m.Groups[1].Value.ToLowerInvariant();$year=$m.Groups[2].Value;$number=[string][int]$m.Groups[3].Value
        $ids=@('eli:'+$type+'/'+$year+'/'+$number)
        if($type -match '^(reg|dir|dec)'){$ids+=Get-NumberIds $year $number}
        Add-Citation $m 'eli' ('eli/'+$type+'/'+$year+'/'+$number) $ids
    }
    foreach($pattern in @('(?<![0-9A-Za-z])([0-9])((?:19|20)\d{2})([A-Z])(\d{4})(?:-\d{8})?(?![0-9A-Za-z])','(?i)celex\W{0,3}([0-9])((?:19|20)\d{2})([A-Z])(\d{4})(?:-\d{8})?(?![0-9A-Za-z])')){
        foreach($m in [regex]::Matches($Text,$pattern)){
            if(Test-Covered $m){continue}
            $sector=$m.Groups[1].Value;$year=$m.Groups[2].Value;$letter=$m.Groups[3].Value.ToUpperInvariant();$number=$m.Groups[4].Value
            $celex=$sector+$year+$letter+$number
            $ids=@('celex:'+$celex)
            if($sector -in @('0','3') -and $letter -in @('R','L','D')){$ids+=Get-NumberIds $year $number}
            Add-Citation $m 'celex' ('CELEX:'+$celex) $ids
        }
    }
    foreach($m in [regex]::Matches($Text,'(?i)\b(?:OJ|GU(?:UE)?)\s+([LC])\s*(\d{1,4})\s*(?:,|del)?\s*(\d{1,2})[./](\d{1,2})[./](\d{4})')){
        $date=ConvertTo-SBReferenceDate $m.Groups[3].Value $m.Groups[4].Value $m.Groups[5].Value
        if(!$date){continue}
        $series=$m.Groups[1].Value.ToUpperInvariant();$issue=[string][int]$m.Groups[2].Value
        $parts=$date -split '-'
        Add-Citation $m 'oj' ('OJ '+$series+' '+$issue+', '+$parts[2]+'.'+$parts[1]+'.'+$parts[0]) @('oj:'+$series+$issue+'/'+$date)
    }
    $dateAlternatives='(?:(?<d>\d{1,2})\s+(?<mo>\p{L}+)\s+(?<y>\d{4})|(?<d>\d{1,2})[./-](?<mo>\d{1,2})[./-](?<y>\d{4}))'
    $gu='(?:Gazzetta\s+Ufficiale(?:\s+della\s+Repubblica(?:\s+italiana)?)?|G\.\s?U\.|GU)'
    foreach($pattern in @("(?i)\b$gu(?:\s*[-,]?\s*Serie\s+Generale)?\s*,?\s*n\.?\s*(?<n>\d{1,4})\s+del\s+$dateAlternatives","(?i)\b$gu(?:\s*[-,]?\s*Serie\s+Generale)?\s*,?\s*$dateAlternatives\s*,?\s*n\.?\s*(?<n>\d{1,4})")){
        foreach($m in [regex]::Matches($Text,$pattern)){
            if(Test-Covered $m){continue}
            $date=ConvertTo-SBReferenceDate $m.Groups['d'].Value $m.Groups['mo'].Value $m.Groups['y'].Value
            if(!$date){continue}
            $issue=[string][int]$m.Groups['n'].Value;$parts=$date -split '-'
            Add-Citation $m 'gu' ('GU n. '+$issue+' del '+$parts[2]+'.'+$parts[1]+'.'+$parts[0]) @('gu:'+$date+'#'+$issue)
        }
    }
    if(!$StructuredOnly){
        foreach($m in [regex]::Matches($Text,'(?<![\d/])(\d{4})/(\d{1,4})(?![\d/])')){
            if(Test-Covered $m){continue}
            Add-Citation $m 'number' ($m.Groups[1].Value+'/'+$m.Groups[2].Value) (Get-NumberIds $m.Groups[1].Value $m.Groups[2].Value)
        }
        foreach($m in [regex]::Matches($Text,'(?i)\bn\.?\s*(\d{1,4})\s+del\s+\d{1,2}\s+\p{L}+\s+(\d{4})')){
            if(Test-Covered $m){continue}
            Add-Citation $m 'number' ($m.Groups[2].Value+'/'+$m.Groups[1].Value) (Get-NumberIds $m.Groups[2].Value $m.Groups[1].Value)
        }
    }
    @($found.Values)
}
function Get-SBSourceReferenceIds($Source) {
    # Spellings under which a registered source can be cited: its official identifier, plus ELI and CELEX found in its endpoint addresses.
    $ids=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if($Source.officialId){foreach($ref in Get-SBTextReferences ([string]$Source.officialId)){foreach($id in $ref.ids){[void]$ids.Add($id)}}}
    foreach($endpoint in @($Source.endpoints)){foreach($ref in Get-SBTextReferences ([string]$endpoint.url) -StructuredOnly){foreach($id in $ref.ids){[void]$ids.Add($id)}}}
    ,$ids
}
function Find-SBSourceReferences($Registry,$Source) {
    # Citations (ELI, CELEX, Official Journal, Gazzetta Ufficiale, official numbers) found in the accepted, else latest, transcript. Unresolved ones are returned for the review queue; nothing is downloaded.
    $version=if($Source.acceptedVersion){@($Source.versions|Where-Object id -ceq $Source.acceptedVersion)[0]}elseif($Source.versions.Count){@($Source.versions|Sort-Object id)[-1]}else{$null}
    $citations=@()
    if($version){
        $versionRoot=Get-SBSourceChild $Source._root ('versions/'+$version.id)
        $manifest=Read-SBJson (Join-Path $versionRoot 'manifest.json') $null
        if($manifest -and $manifest.transcription.path){$citations=@(Get-SBTextReferences (Read-SBText (Get-SBSourceChild $versionRoot $manifest.transcription.path)))}
    }
    $resolved=[Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    $own=Get-SBSourceReferenceIds $Source
    $others=@($Registry.sources|Where-Object {$_.id -cne $Source.id}|ForEach-Object {@{id=$_.id;known=(Get-SBSourceReferenceIds $_)}})
    $unresolved=@();$detail=@()
    foreach($citation in $citations){
        if(@($citation.ids|Where-Object {$own.Contains($_)}).Count){continue}
        $hits=@($others|Where-Object {$known=$_.known;@($citation.ids|Where-Object {$known.Contains($_)}).Count})
        if($hits.Count){foreach($hit in $hits){[void]$resolved.Add($hit.id)}}else{$unresolved+=$citation.reference;$detail+=@{kind=$citation.kind;reference=$citation.reference}}
    }
    @{sourceId=$Source.id;resolved=@($resolved);unresolved=@($unresolved);unresolvedDetail=@($detail)}
}
function Get-SBSourceCardProposal($Registry,[string]$Reference,[string]$OriginId) {
    # #438: proposes the card (metadata.json content) for a citation that is not in the registry. Read-only: no write, no network, no download.
    # The proposal is always reference-only, so Invoke-SBSourceCollect refuses it until a person verifies the rights and registers an endpoint.
    $citations=@(Get-SBTextReferences $Reference)
    if(!$citations.Count -and $Reference -match '^\s*(\d{1,4})/(\d{4})\s*$'){$citations=@(@{kind='number';reference=($Matches[2]+'/'+$Matches[1]);ids=@("n:$([int]$Matches[2])/$([int]$Matches[1])","n:$([int]$Matches[1])/$([int]$Matches[2])")})}
    if($citations.Count -ne 1){throw (New-SBError 'sources.proposal.unrecognized' @($Reference))}
    $citation=$citations[0]
    $hits=@($Registry.sources|Where-Object {$known=Get-SBSourceReferenceIds $_;@($citation.ids|Where-Object {$known.Contains($_)}).Count})
    if($hits.Count){return @{status='registered';reference=$citation.reference;sourceIds=@($hits|ForEach-Object {$_.id})}}
    $origins=@($Registry.sources|Where-Object id -ceq $OriginId)
    if($origins.Count -ne 1){throw (New-SBError 'sources.proposal.origin')}
    $origin=$origins[0]
    $first=[string]$citation.ids[0];$kind='regulation';$location=$null;$issuer='Da verificare';$jurisdictions=@($origin.jurisdictions|Where-Object {$_ -cne 'Global'})
    if(!$jurisdictions.Count){$jurisdictions=@('unverified')}
    if($first -match '^eli:id/(\d{4})-(\d{2})-(\d{2})/(.+)$'){$slug='it-eli-'+$Matches[1]+'-'+$Matches[2]+'-'+$Matches[3]+'-'+$Matches[4].ToLowerInvariant();$jurisdictions=@('IT');$issuer='Repubblica italiana'}
    elseif($first -match '^eli:([a-z_]+)/(\d{4})/(\d+)$'){
        $type=$Matches[1];$slug='eu-'+($type -replace '_','-')+'-'+$Matches[2]+'-'+$Matches[3];$jurisdictions=@('EU');$issuer='Unione europea'
        if($type -match '^dec'){$kind='decision'}
        $location='https://eur-lex.europa.eu/eli/'+$type+'/'+$Matches[2]+'/'+$Matches[3]+'/oj'
    }
    elseif($first -match '^celex:([0-9])(\d{4})([A-Z])(\d{4})$'){
        $sector=$Matches[1];$letter=$Matches[3];$celex=$Matches[1]+$Matches[2]+$Matches[3]+$Matches[4]
        $names=@{R='reg';L='dir';D='dec'}
        $slug=if($sector -in @('0','3') -and $names.ContainsKey($letter)){'eu-'+$names[$letter]+'-'+$Matches[2]+'-'+[int]$Matches[4]}else{'celex-'+$celex.ToLowerInvariant()}
        if($letter -ceq 'D'){$kind='decision'}
        $jurisdictions=@('EU');$issuer='Unione europea'
        $location='https://eur-lex.europa.eu/legal-content/IT/TXT/?uri=CELEX:'+$celex
    }
    elseif($first -match '^oj:([LC])(\d+)/(\d{4})-(\d{2})-(\d{2})$'){$slug='eu-oj-'+$Matches[1].ToLowerInvariant()+$Matches[2]+'-'+$Matches[3]+'-'+$Matches[4]+'-'+$Matches[5];$jurisdictions=@('EU');$issuer='Unione europea'}
    elseif($first -match '^gu:(\d{4})-(\d{2})-(\d{2})#(\d+)$'){$slug='it-gu-'+$Matches[1]+'-'+$Matches[2]+'-'+$Matches[3]+'-n'+$Matches[4];$jurisdictions=@('IT');$issuer='Repubblica italiana'}
    elseif($first -match '^n:(\d+)/(\d+)$'){$slug='ref-'+$citation.reference.Replace('/','-')}
    else{throw (New-SBError 'sources.proposal.unrecognized' @($Reference))}
    $slug=($slug -replace '[^a-z0-9-]','-').Trim('-')
    $id=$slug;$suffix=2
    while(@($Registry.sources|Where-Object id -ceq $id).Count){$id=$slug+'-'+$suffix;$suffix++}
    $card=[ordered]@{
        schemaVersion=1;id=$id;title=('Riferimento da verificare: '+$citation.reference);kind=$kind;issuer=$issuer
        domains=@($origin.domains);jurisdictions=@($jurisdictions);language=$origin.language
        officialId=$citation.reference;edition='da-verificare';publicationDate=$null
        rights=@{status='reference-only';reference='Condizioni di riutilizzo da verificare';notes='Proposta: nessun download finche le condizioni di riutilizzo non sono verificate.'}
        endpoints=@();versions=@();acceptedVersion=$null
        relatedSources=@(@{id=$origin.id;relation='related'})
        effectiveDates=@(@{provision='Entrata in vigore';date=$null;status='requires-verification';reference='Da verificare'})
        notes=@('Proposta da riferimento in coda: '+$citation.reference+' (citato da '+$origin.id+')')
    }
    if(!(Test-Json -Json (ConvertTo-SBJson $card) -SchemaFile (Join-Path $Registry.brainRoot 'config/source.schema.json') -ErrorAction SilentlyContinue)){throw (New-SBError 'sources.card.invalid' @($id))}
    @{status='proposed';reference=$citation.reference;referenceKind=$citation.kind;origin=$origin.id;card=$card;suggestedLocation=$location;downloaded=$false
        toVerify=@('title','kind','issuer','jurisdictions','officialId','edition','rights','effectiveDates','endpoints')}
}
function Get-SBSourceCardProposals($Registry,[string]$Reference,[string]$OriginId) {
    # One proposal for -Reference (origin from the queue item, else -SourceId), or one per distinct unresolved reference in normative-queue.json.
    $queuePath=Join-Path $Registry.root 'normative-queue.json'
    $queue=Read-SBJson $queuePath $null
    $items=@(if($queue){@($queue.items)|Where-Object {$_.kind -eq 'unresolved-reference'}})
    $proposals=@();$registered=@();$skipped=@()
    if($Reference){
        $spelled=@(Get-SBTextReferences $Reference);$canonical=if($spelled.Count -eq 1){$spelled[0].reference}else{$Reference}
        $origin=if($OriginId){$OriginId}else{@($items|Where-Object reference -ceq $canonical|ForEach-Object {$_.sourceId})|Select-Object -First 1}
        $proposal=Get-SBSourceCardProposal $Registry $Reference ([string]$origin)
        if($proposal.status -eq 'registered'){$registered+=$proposal}else{$proposals+=$proposal}
    }else{
        foreach($group in @($items|Group-Object reference|Sort-Object Name)){
            $origins=@($group.Group|ForEach-Object {$_.sourceId}|Select-Object -Unique)
            try{$proposal=Get-SBSourceCardProposal $Registry $group.Name $origins[0]}catch{$skipped+=@{reference=$group.Name;reason=$_.Exception.Message};continue}
            if($proposal.status -eq 'registered'){$registered+=$proposal;continue}
            $proposal.alsoCitedBy=@($origins|Select-Object -Skip 1)
            $proposals+=$proposal
        }
    }
    @{schemaVersion=1;proposals=@($proposals);registered=@($registered);skipped=@($skipped)}
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
            foreach($item in $found.unresolvedDetail){$queue[$id+'|'+$item.reference]=@{kind='unresolved-reference';sourceId=$id;reference=$item.reference;referenceKind=$item.kind}}
        }
        $frontier=@($next|Select-Object -Unique)
    }
    if($frontier.Count -and $depth -gt $MaxDepth){foreach($id in $frontier|Where-Object {!$included.Contains($_)}){$queue['depth:'+$id]=@{kind='depth-limit';sourceId=$id}}}
    @{sources=@($included.Keys);depths=$included;queue=@($queue.Keys|Sort-Object|ForEach-Object {$queue[$_]})}
}
Export-ModuleMember -Function @(
    'Get-SBSourceCategory',
    'Write-SBSourceIndex',
    'Invoke-SBSourceDecision',
    'Add-SBSourceEffectiveDate',
    'Test-SBMappingOutdated',
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
    'Restore-SBSourceOriginals',
    'Find-SBSourceReferences',
    'Get-SBTextReferences',
    'Get-SBSourceCardProposal',
    'Get-SBSourceCardProposals',
    'Get-SBSourceClosure'
)
