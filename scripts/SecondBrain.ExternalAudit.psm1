#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'audit.limit.snapshot' = @{ it = 'Snapshot non atomico fra richieste; nessuna prova di assenza da errori HTTP.'; en = 'Non-atomic snapshot across requests; HTTP errors do not prove absence.' }
    'audit.limit.wiki' = @{ it = 'Wiki abilitate: contenuto non acquisito; fork elencati senza scansione dei loro contenuti.'; en = 'Enabled wikis: content not collected; forks listed without scanning their content.' }
    'audit.limit.scope' = @{ it = 'Nessuna scansione di cloni, cache, allegati, Actions o copie esterne. Corpi e titoli conservati solo come hash e lunghezze.'; en = 'Clones, caches, attachments, Actions and external copies are not scanned. Bodies and titles retained only as hashes and lengths.' }
    'audit.reason.pagination_cycle_or_limit' = @{ it = 'Ciclo o limite di paginazione raggiunto'; en = 'Pagination cycle or limit reached' }
    'audit.reason.unsafe_pagination_link' = @{ it = 'Collegamento di paginazione non sicuro'; en = 'Unsafe pagination link' }
    'audit.reason.expected_array' = @{ it = 'Risposta attesa come elenco'; en = 'Expected an array response' }
    'audit.reason.expected_object' = @{ it = 'Risposta attesa come oggetto'; en = 'Expected an object response' }
    'audit.reason.ambiguous_pagination_link' = @{ it = 'Collegamento di paginazione ambiguo'; en = 'Ambiguous pagination link' }
    'audit.reason.invalid_pagination_link' = @{ it = 'Collegamento di paginazione non valido'; en = 'Invalid pagination link' }
    'audit.reason.invalid_response_or_transport' = @{ it = 'Risposta o trasporto non verificabile'; en = 'Response or transport could not be verified' }
    'audit.reason.repository_identity_changed' = @{ it = 'Identita del repository cambiata'; en = 'Repository identity changed' }
    'audit.reason.repository_unavailable' = @{ it = 'Repository non disponibile'; en = 'Repository unavailable' }
    'audit.reason.repository_metadata' = @{ it = 'Stato ricavato dai metadati del repository'; en = 'State obtained from repository metadata' }
    'audit.reason.wiki_content_not_collected' = @{ it = 'Contenuto della wiki non acquisito'; en = 'Wiki content not collected' }
    'audit.reason.rate_limited' = @{ it = 'Limite API raggiunto'; en = 'API rate limit reached' }
    'audit.reason.authentication_required' = @{ it = 'Autenticazione richiesta'; en = 'Authentication required' }
    'audit.reason.transport_or_authentication' = @{ it = 'Trasporto o autenticazione non riusciti'; en = 'Transport or authentication failed' }
    'audit.reason.timeout' = @{ it = 'Tempo della richiesta scaduto'; en = 'Request timed out' }
    'audit.reason.invalid_json' = @{ it = 'Risposta JSON non valida'; en = 'Invalid JSON response' }
    'audit.reason.http' = @{ it = 'Risposta HTTP {0} non verificabile'; en = 'HTTP {0} response could not be verified' }
    'audit.identity' = @{ it = 'Identita audit non ammessa; questo adattatore usa soltanto GitHub'; en = 'Audit identity not allowed; this adapter only uses GitHub' }
    'audit.api.item' = @{ it = 'Elemento API non valido'; en = 'Invalid API item' }
    'audit.scope' = @{ it = 'Perimetro audit vuoto o duplicato'; en = 'Audit scope empty or duplicated' }
    'audit.pr.number' = @{ it = 'Numero PR non valido'; en = 'Invalid PR number' }
}

function Assert-SBAuditIdentity([string]$Identity,[string[]]$AllowedOwners) {
    if($Identity -cnotmatch '^github\.com/([a-z0-9][a-z0-9-]*)/([a-z0-9_.-]+)$' -or ($AllowedOwners.Count -and $Matches[1] -notin $AllowedOwners) -or $Matches[2] -in @('.','..')){throw (New-SBError 'audit.identity')}
}

function Invoke-SBAuditRequest([string]$Url) {
    # Keep stdout/stderr in memory: errors must never expose bodies or credentials.
    $start=[Diagnostics.ProcessStartInfo]::new('gh')
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($arg in @('api','--hostname','github.com','--method','GET','--include','-H','Accept: application/vnd.github+json','-H','X-GitHub-Api-Version: 2022-11-28',$Url)){$start.ArgumentList.Add($arg)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        [void]$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(!$process.WaitForExit(60000)){$process.Kill($true);$process.WaitForExit();return @{statusCode=0;headers=@{};body=$null;bodySha256=$null;errorKind='timeout'}}
        $raw=$stdout.GetAwaiter().GetResult();[void]$stderr.GetAwaiter().GetResult()
        $match=[regex]::Match($raw,'\AHTTP/\S+\s+(\d{3})[^\r\n]*\r?\n(?<headers>.*?)\r?\n\r?\n(?<body>.*)\z',[Text.RegularExpressions.RegexOptions]::Singleline)
        if(!$match.Success){return @{statusCode=0;headers=@{};body=$null;bodySha256=$null;errorKind='transport_or_authentication'}}
        $headers=@{}
        foreach($line in $match.Groups['headers'].Value -split '\r?\n'){if($line -match '^([^:]+):\s*(.*)$'){$headers[$Matches[1].ToLowerInvariant()]=$Matches[2]}}
        $body=$match.Groups['body'].Value;$data=$null;$errorKind=$null
        try{$data=ConvertFrom-Json -InputObject $body -AsHashtable -NoEnumerate}catch{$errorKind='invalid_json'}
        @{statusCode=[int]$match.Groups[1].Value;headers=$headers;body=$data;bodySha256=Get-SBTextHash $body;errorKind=$errorKind}
    } catch { @{statusCode=0;headers=@{};body=$null;bodySha256=$null;errorKind='transport_or_authentication'} }
    finally {$process.Dispose()}
}

function Get-SBAuditItem($Item,[string]$Kind) {
    if($Item -isnot [System.Collections.IDictionary]){throw (New-SBError 'audit.api.item')}
    $result=@{kind=$Kind}
    foreach($key in @('id','number','state','created_at','updated_at','submitted_at','sha','name','full_name')){
        if($Item.Contains($key)){$result[$key]=$Item[$key]}
    }
    if($Item.Contains('html_url')){
        $url=[uri]::new([string]$Item.html_url,[UriKind]::Absolute)
        if($url.Scheme -eq 'https' -and $url.Host -eq 'github.com' -and !$url.UserInfo -and !$url.Query -and $url.IsDefaultPort){$result.url=$url.AbsoluteUri}
    }
    foreach($key in @('title','body','message')){
        if($Item.Contains($key)){
            $value=[string]$Item[$key]
            $result[$key+'Sha256']=Get-SBTextHash $value;$result[$key+'Characters']=$value.Length
        }
    }
    if($Item.Contains('commit') -and $Item.commit -is [System.Collections.IDictionary] -and $Item.commit.Contains('sha')){$result.commitSha=$Item.commit.sha}
    $result
}

function Get-SBAuditResource([string]$Url,[string]$Kind,[bool]$Collection,$Context,[scriptblock]$Request,[int]$MaxPages=1000) {
    $resource=@{url=$Url;startedAt=(Get-SBNow).ToString('o');finishedAt=$null;status='unverified';complete=$false;count=$null;observedCount=0;pages=@();items=@();reason=$null}
    $initial=[uri]$Url;$next=$Url;$seen=@{};$data=$null
    try {
        while($next){
            if($Context.halted){$resource.status='not_attempted';$resource.reason=$Context.reason;break}
            if($seen.ContainsKey($next) -or $resource.pages.Count -ge $MaxPages){$resource.reason='pagination_cycle_or_limit';break}
            $uri=[uri]$next
            if($uri.Scheme -ne 'https' -or $uri.Host -ne 'api.github.com' -or !$uri.IsDefaultPort -or $uri.UserInfo -or $uri.Fragment -or $uri.AbsolutePath -ne $initial.AbsolutePath -or ($uri.Query -and $uri.Query -notmatch '^\?(?:(?:page|per_page)=[0-9]+|state=(?:all|open|closed))(?:&(?:(?:page|per_page)=[0-9]+|state=(?:all|open|closed)))*$')){$resource.reason='unsafe_pagination_link';break}
            $seen[$next]=$true;$at=(Get-SBNow).ToString('o')
            $response=& $Request $next
            $code=[int]$response.statusCode;$headers=$response.headers
            $page=@{url=$next;requestedAt=$at;finishedAt=(Get-SBNow).ToString('o');httpStatus=$code;bodySha256=$response.bodySha256;items=$null}
            $resource.pages+=@($page)
            if($code -ne 200){
                $resource.status=switch($code){401{'authentication_required'}403{'access_denied'}404{'not_found_or_inaccessible'}429{'rate_limited'}default{'unverified'}}
                $message=if($response.body -is [System.Collections.IDictionary] -and $response.body.Contains('message')){[string]$response.body.message}else{''}
                if($code -eq 429 -or ($code -eq 403 -and (($headers.ContainsKey('x-ratelimit-remaining') -and $headers['x-ratelimit-remaining'] -eq '0') -or $headers.ContainsKey('retry-after') -or $message -match '(?i)rate limit|secondary rate'))){$resource.status='rate_limited'}
                $resource.reason=if($response.errorKind){$response.errorKind}else{'http_'+$code}
                if($resource.status -in @('rate_limited','authentication_required') -or $response.errorKind -eq 'transport_or_authentication'){$Context.halted=$true;$Context.reason=$resource.status}
                break
            }
            if($response.errorKind){$resource.reason=$response.errorKind;break}
            $data=$response.body
            if($Collection){
                if($data -isnot [array]){$resource.reason='expected_array';break}
                $page.items=$data.Count
                foreach($item in $data){
                    if($Kind -eq 'issues' -and $item.Contains('pull_request')){continue}
                    $resource.items+=@(Get-SBAuditItem $item $Kind)
                }
            }else{
                if($data -isnot [System.Collections.IDictionary]){$resource.reason='expected_object';break}
                $page.items=1
            }
            $next=$null
            if($Collection -and $headers.ContainsKey('link')){
                $links=@([regex]::Matches([string]$headers.link,'<([^>]+)>;\s*rel="next"'))
                if($links.Count -gt 1){$resource.reason='ambiguous_pagination_link';break}
                if($links.Count -eq 1){$next=$links[0].Groups[1].Value}
                elseif([string]$headers.link -match 'rel="next"'){$resource.reason='invalid_pagination_link';break}
            }
            if(!$next){$resource.complete=$true;$resource.status='accessible';$resource.count=if($Collection){$resource.items.Count}else{1}}
        }
    } catch {$resource.status='unverified';$resource.complete=$false;$resource.reason='invalid_response_or_transport'}
    $resource.observedCount=$resource.items.Count
    if(!$resource.complete -and $resource.observedCount -gt 0){$resource.status='partial'}
    $resource.finishedAt=(Get-SBNow).ToString('o')
    [void](Add-SBReportDiagnostic $resource 'audit')
    @{resource=$resource;data=$(if(!$Collection -and $resource.complete){$data}else{$null})}
}

function Invoke-SBGitHubAudit([string[]]$Identities,[string[]]$AllowedOwners,[scriptblock]$Request=${function:Invoke-SBAuditRequest}) {
    foreach($identity in $Identities){Assert-SBAuditIdentity $identity $AllowedOwners}
    if(!$Identities.Count -or @($Identities|Sort-Object -Unique).Count -ne $Identities.Count){throw (New-SBError 'audit.scope')}
    $audit=@{schemaVersion=1;kind='github-readonly-audit';startedAt=(Get-SBNow).ToString('o');finishedAt=$null;apiVersion='2022-11-28';remoteMutation=$false;repositories=@();complete=$false;limits=@((Get-SBMessage 'audit.limit.snapshot'),(Get-SBMessage 'audit.limit.wiki'),(Get-SBMessage 'audit.limit.scope'))}
    $context=@{halted=$false;reason=$null}
    foreach($identity in $Identities){
        $slug=$identity.Substring(11);$base='https://api.github.com/repos/'+$slug
        $repo=@{identity=$identity;startedAt=(Get-SBNow).ToString('o');finishedAt=$null;resources=@{};metadata=$null;complete=$false}
        $info=Get-SBAuditResource $base 'repository' $false $context $Request
        $repo.resources.repository=$info.resource
        $endpoints=[ordered]@{issues='issues?state=all&per_page=100';pullRequests='pulls?state=all&per_page=100';issueComments='issues/comments?per_page=100';reviewComments='pulls/comments?per_page=100';branches='branches?per_page=100';tags='tags?per_page=100';forks='forks?per_page=100'}
        if($info.resource.complete){
            if([string]$info.data.full_name -ine $slug){$repo.resources.repository.complete=$false;$repo.resources.repository.reason='repository_identity_changed'}
            else{
                $repo.metadata=@{}
                foreach($key in @('full_name','visibility','default_branch','has_wiki','has_issues','archived','fork','forks_count')){if($info.data.Contains($key)){$repo.metadata[$key]=$info.data[$key]}}
            }
        }
        foreach($entry in $endpoints.GetEnumerator()){
            $url=$base+'/'+$entry.Value
            if($repo.metadata){$repo.resources[$entry.Key]=(Get-SBAuditResource $url $entry.Key $true $context $Request).resource}
            else{$repo.resources[$entry.Key]=@{url=$url;status='not_attempted';complete=$false;count=$null;observedCount=0;pages=@();items=@();reason='repository_unavailable'}}
        }
        $reviews=@{url=$base+'/pulls/{number}/reviews';startedAt=(Get-SBNow).ToString('o');status='accessible';complete=$repo.resources.pullRequests.complete;count=$null;observedCount=0;requests=@();items=@()}
        foreach($pull in $repo.resources.pullRequests.items){
            if(!$pull.ContainsKey('number') -or [string]$pull.number -notmatch '^[1-9][0-9]*$'){throw (New-SBError 'audit.pr.number')}
            $review=(Get-SBAuditResource ($base+'/pulls/'+$pull.number+'/reviews?per_page=100') 'reviews' $true $context $Request).resource
            $review.pullRequestNumber=$pull.number;$reviews.requests+=@($review);$reviews.items+=@($review.items)
            if(!$review.complete){$reviews.complete=$false}
        }
        $reviews.observedCount=$reviews.items.Count
        if($reviews.complete){$reviews.count=$reviews.observedCount}else{$reviews.status='partial'}
        $reviews.finishedAt=(Get-SBNow).ToString('o');$repo.resources.reviews=$reviews
        $disabled=$repo.metadata -and $repo.metadata.ContainsKey('has_wiki') -and !$repo.metadata.has_wiki
        $repo.resources.wiki=@{url=('https://github.com/'+$slug+'/wiki');status=$(if($disabled){'disabled'}else{'unverified'});complete=[bool]$disabled;count=$(if($disabled){0}else{$null});observedAt=(Get-SBNow).ToString('o');reason=$(if($disabled){'repository_metadata'}else{'wiki_content_not_collected'})}
        foreach($diagnostic in $repo.resources.Values){
            if($diagnostic.ContainsKey('reason')){[void](Add-SBReportDiagnostic $diagnostic 'audit')}
        }
        $repo.complete=@($repo.resources.Values|Where-Object {!$_.complete}).Count -eq 0
        $repo.finishedAt=(Get-SBNow).ToString('o');$audit.repositories+=@($repo)
    }
    $audit.complete=@($audit.repositories|Where-Object {!$_.complete}).Count -eq 0
    $audit.finishedAt=(Get-SBNow).ToString('o');$audit
}

Export-ModuleMember -Function Assert-SBAuditIdentity,Invoke-SBAuditRequest,Get-SBAuditResource,Invoke-SBGitHubAudit
