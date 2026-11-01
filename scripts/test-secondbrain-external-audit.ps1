#requires -Version 7.5
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ExternalAudit.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
$script:auditChecks=0
function Assert-Audit($Condition,[string]$Message){if(!$Condition){throw 'FAIL AUDIT: '+$Message};$script:auditChecks++;'PASS AUDIT: '+$Message}
function Response-Audit($Body,[int]$Code=200,$Headers=@{}){@{statusCode=$Code;headers=$Headers;body=$Body;bodySha256=Get-SBTextHash (ConvertTo-SBJson $Body);errorKind=$null}}
function Resource-Audit([scriptblock]$Request,[int]$MaxPages=1000){Get-SBAuditResource 'https://api.github.com/repos/test/repo/issues?per_page=100' 'issues' $true @{halted=$false;reason=$null} $Request $MaxPages}

$base='https://api.github.com/repos/test/repo'
$seen=[Collections.Generic.List[string]]::new()
$request={param($url)
    $seen.Add($url)
    switch -Exact ($url) {
        $base {Response-Audit @{full_name='test/repo';has_wiki=$false;has_issues=$true;forks_count=0}}
        ($base+'/issues?state=all&per_page=100') {Response-Audit @(@{id=1;number=1;body='SECRET-SENTINEL';title='SECRET-SENTINEL';html_url='https://github.com/test/repo/issues/1'},@{id=2;pull_request=@{}}) 200 @{link=('<'+$base+'/issues?state=all&per_page=100&page=2>; rel="next"')}}
        ($base+'/issues?state=all&per_page=100&page=2') {Response-Audit @(@{id=3;number=3;body='seconda pagina'})}
        ($base+'/pulls?state=all&per_page=100') {Response-Audit @(@{id=4;number=2;body='PR'})}
        ($base+'/pulls/2/reviews?per_page=100') {Response-Audit @(@{id=5;body='review';state='APPROVED'}) 200 @{link=('<'+$base+'/pulls/2/reviews?per_page=100&page=2>; rel="next"')}}
        ($base+'/pulls/2/reviews?per_page=100&page=2') {Response-Audit @(@{id=6;body='review 2'})}
        default {Response-Audit @()}
    }
}.GetNewClosure()
$audit=Invoke-SBGitHubAudit @('github.com/test/repo') @('test') $request
$repo=$audit.repositories[0]
Assert-Audit ($audit.complete -and $repo.complete -and !$audit.remoteMutation) 'copertura completa con Wiki disabilitata, sole letture'
Assert-Audit ($repo.resources.issues.count -eq 2 -and $repo.resources.issues.pages.Count -eq 2) 'pagination Link completa, PR escluse dalle issue'
Assert-Audit ($repo.resources.reviews.count -eq 2 -and $repo.resources.reviews.requests[0].pages.Count -eq 2) 'review paginate per ogni PR'
Assert-Audit ($repo.resources.issueComments.count -eq 0 -and $repo.resources.issueComments.complete) 'zero elementi solo dopo risposta completa'
Assert-Audit ($repo.resources.wiki.status -eq 'disabled' -and $repo.resources.wiki.count -eq 0) 'Wiki disabilitata distinta da non verificata'
Assert-Audit ($repo.resources.forks.complete -and $repo.resources.branches.complete -and $repo.resources.tags.complete) 'fork branch tag censiti separatamente'
$serialized=ConvertTo-SBJson $audit
Assert-Audit (!$serialized.Contains('SECRET-SENTINEL') -and $repo.resources.issues.items[0].bodySha256 -eq (Get-SBTextHash 'SECRET-SENTINEL')) 'corpi e titoli ridotti a hash senza segreti'
Assert-Audit ($repo.resources.issues.pages[0].httpStatus -eq 200 -and $repo.resources.issues.pages[0].requestedAt -and $repo.resources.issues.pages[0].bodySha256) 'timestamp HTTP URL e hash per pagina'
Assert-Audit ($seen.Count -eq 11) 'nessuna richiesta a endpoint non previsti'

foreach($case in @(@(401,'authentication_required'),@(403,'access_denied'),@(404,'not_found_or_inaccessible'),@(429,'rate_limited'))){
    $code=$case[0];$request={param($url) Response-Audit @{message='SECRET-SENTINEL'} $code}.GetNewClosure()
    $r=(Resource-Audit $request).resource
    Assert-Audit (!$r.complete -and $null -eq $r.count -and $r.status -eq $case[1]) ('HTTP '+$code+' non diventa zero o assenza')
}
$ctx=@{halted=$false;reason=$null}
$r=Get-SBAuditResource ($base+'/issues?per_page=100') 'issues' $true $ctx {param($url) Response-Audit @{message='secondary rate limit'} 403}
Assert-Audit ($ctx.halted -and $r.resource.status -eq 'rate_limited') 'limite secondario arresta audit senza retry'
$calls=[Collections.Generic.List[string]]::new()
$request={param($url) $calls.Add($url); Response-Audit @{message='SECRET-SENTINEL'} 401}.GetNewClosure()
$a=Invoke-SBGitHubAudit @('github.com/test/repo','github.com/test/other') @('test') $request
Assert-Audit ($calls.Count -eq 1 -and $a.repositories[1].resources.repository.status -eq 'not_attempted') 'autenticazione mancante ferma richieste successive'
$request={param($url) if($url -eq $base){Response-Audit @{full_name='test/repo';has_wiki=$true}}else{Response-Audit @()}}.GetNewClosure()
$a=Invoke-SBGitHubAudit @('github.com/test/repo') @('test') $request
Assert-Audit (!$a.complete -and $a.repositories[0].resources.wiki.status -eq 'unverified' -and $null -eq $a.repositories[0].resources.wiki.count) 'Wiki abilitata mai presentata come vuota'
foreach($link in @('https://evil.test/page?per_page=100','https://user:pass@api.github.com/repos/test/repo/issues?per_page=100','https://api.github.com/repos/other/repo/issues?per_page=100','https://api.github.com/repos/test/repo/issues?token=SECRET%20VALUE','https://api.github.com/repos/test/repo/issues?token=secret')){
    $request={param($url) Response-Audit @(@{id=1}) 200 @{link=('<'+$link+'>; rel="next"')}}.GetNewClosure()
    $r=(Resource-Audit $request).resource
    Assert-Audit (!$r.complete -and $r.pages.Count -eq 1 -and $r.reason -eq 'unsafe_pagination_link') 'pagination fuori confine o credenziali rifiutate prima della richiesta'
}
$request={param($url) Response-Audit @() 200 @{link=('<'+$url+'>; rel="next"')}}
$r=(Resource-Audit $request).resource
Assert-Audit (!$r.complete -and $r.reason -eq 'pagination_cycle_or_limit') 'ciclo pagination rifiutato'
$request={param($url) Response-Audit @() 200 @{link=('<'+$url+'&page=2>; rel="next"')}}
$r=(Resource-Audit $request 1).resource
Assert-Audit (!$r.complete -and $r.reason -eq 'pagination_cycle_or_limit') 'limite pagine non diventa completamento'
$request={param($url) if($url -match 'page=2'){Response-Audit @{message='denied'} 403}else{Response-Audit @(@{id=1}) 200 @{link=('<'+$url+'&page=2>; rel="next"')}}}
$r=(Resource-Audit $request).resource
Assert-Audit (!$r.complete -and $r.status -eq 'partial' -and $r.observedCount -eq 1 -and $null -eq $r.count) 'errore a pagina successiva conserva parziali senza totale falso'
$r=(Resource-Audit {param($url) Response-Audit @{message='object'}}).resource
Assert-Audit (!$r.complete -and $r.reason -eq 'expected_array') 'payload di tipo errato non interpretato come elenco'
$r=(Resource-Audit {param($url) throw 'SECRET-SENTINEL'}).resource
Assert-Audit (!$r.complete -and !(ConvertTo-SBJson $r).Contains('SECRET-SENTINEL')) 'eccezioni trasporto sanificate'
$request={param($url) if($url -eq $base){Response-Audit @{full_name='other/repo';has_wiki=$false}}else{throw 'unexpected'}}.GetNewClosure()
$a=Invoke-SBGitHubAudit @('github.com/test/repo') @('test') $request
Assert-Audit (!$a.complete -and !$a.repositories[0].metadata -and $a.repositories[0].resources.repository.reason -eq 'repository_identity_changed') 'redirect identita non amplia perimetro'
foreach($identity in @('github.com/other/repo','github.com/test/../repo','github.com/test/repo?secret=1')){
    $caught=$false;try{Invoke-SBGitHubAudit @($identity) @('test') {throw 'no network'}|Out-Null}catch{$caught=$true}
    Assert-Audit $caught 'owner e identita invalidi rifiutati prima della rete'
}
$caught=$false;try{Invoke-SBGitHubAudit @('github.com/test/repo','github.com/test/repo') @('test') {throw 'no network'}|Out-Null}catch{$caught=$true}
Assert-Audit $caught 'identita duplicate rifiutate'
'SUCCESS AUDIT: '+$script:auditChecks+' verifiche senza rete'
