#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'publication.reason.binary-review-required' = @{ it = 'Revisionare il contenuto binario'; en = 'Binary content review required' }
    'publication.reason.size-limit' = @{ it = 'Limite di dimensione raggiunto'; en = 'Size limit reached' }
    'publication.reason.binary-or-size-limit' = @{ it = 'Contenuto binario o limite di dimensione'; en = 'Binary content or size limit' }
    'publication.reason.unreadable' = @{ it = 'Contenuto non leggibile'; en = 'Content unreadable' }
    'publication.reason.blob-limit' = @{ it = 'Limite di blob raggiunto'; en = 'Blob limit reached' }
    'publication.reason.history-unavailable' = @{ it = 'Storia Git non disponibile'; en = 'Git history unavailable' }
    'publication.reason.history-paths-unavailable' = @{ it = 'Percorsi storici Git non verificabili'; en = 'Git history paths could not be verified' }
    'publication.reason.history-limited' = @{ it = 'Storia Git parziale o modificata da graft'; en = 'Git history is shallow or modified by grafts' }
    'publication.reason.index-unmerged' = @{ it = 'Indice Git con conflitti'; en = 'Git index has unresolved conflicts' }
    'publication.reason.status-unavailable' = @{ it = 'Stato Git non disponibile'; en = 'Git status unavailable' }
    'publication.hook.checkout' = @{ it = 'Checkout Git richiesto per installare lʼhook pre-push'; en = 'Git checkout required to install the pre-push hook' }
    'publication.checkout' = @{ it = 'Checkout Git richiesto'; en = 'Git checkout required' }
    'publication.policy' = @{ it = 'Policy pubblicazione non valida'; en = 'Invalid publication policy' }
    'publication.inventory' = @{ it = 'Inventario Git non leggibile'; en = 'Git inventory not readable' }
    'publication.index' = @{ it = 'Indice Git non leggibile'; en = 'Git index not readable' }
    'publication.capture.metadata' = @{ it = 'Metadati di acquisizione incompleti'; en = 'Incomplete capture metadata' }
    'publication.capture.png' = @{ it = 'Acquisizione PNG richiesta'; en = 'PNG capture required' }
    'publication.capture.review' = @{ it = 'Acquisizione reale e privacy richiedono revisione esplicita'; en = 'Real capture and privacy require explicit review' }
    'publication.asset.name' = @{ it = 'Nome asset PNG non valido'; en = 'Invalid PNG asset name' }
    'publication.asset.root' = @{ it = 'Radice checkout Git richiesta per esportare asset'; en = 'Git checkout root required to export assets' }
    'publication.asset.repository' = @{ it = 'Repository dellʼasset divergente'; en = 'Asset repository mismatch' }
    'publication.capture.changed' = @{ it = 'Cattura modificata dopo la revisione'; en = 'Capture changed after review' }
    'publication.png.truncated' = @{ it = 'PNG troncato'; en = 'Truncated PNG' }
    'publication.png.chunk' = @{ it = 'Chunk PNG non valido'; en = 'Invalid PNG chunk' }
    'publication.png.structure' = @{ it = 'Struttura PNG non valida'; en = 'Invalid PNG structure' }
    'publication.hook.custom' = @{ it = 'Hook pre-push personalizzato preesistente trovato in {0}. Usare -Force per sovrascrivere.'; en = 'Existing custom pre-push hook found in {0}. Use -Force to overwrite.' }
    'publication.hook.foreign' = @{ it = 'Hook pre-push non creato da SecondBrain, rimozione rifiutata: {0}'; en = 'Pre-push hook not created by SecondBrain, removal refused: {0}' }
}

$script:SBPublicationRuleCache=$null
function Get-SBPublicationRules {
    # Build rules and regexes once per process (IgnoreCase, like the -match operator).
    if($script:SBPublicationRuleCache){return $script:SBPublicationRuleCache}
    $script:SBPublicationRuleCache=@(
        @{id='credential';severity='error';pattern='(?i)(?:gh[pousr]_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|(?:api[_-]?key|password|token)\s*[:=]\s*["''][^"''\r\n]{12,}["''])'},
        @{id='host-path';severity='error';pattern='(?i)(?:[A-Z]:[\\/](?:Users|GITHUB)[\\/]|/(?:Users|home)/[^/\s\(\)\[\]]+(?=/|$))'},
        @{id='personal-email';severity='review';pattern='\b[A-Za-z0-9._%+-]+@(?!example\.(?:com|org|net)\b|[^\s@]*\.invalid\b|users\.noreply\.github\.com\b)[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'}
    )|ForEach-Object {$_.regex=[regex]::new($_.pattern,[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant, Compiled');$_}
    $script:SBPublicationRuleCache
}
function ConvertTo-SBBlobText([byte[]]$Bytes) {
    # Match process-stream decoding: UTF-8 with BOM detection (including UTF-16/32).
    $utf8=[Text.UTF8Encoding]::new($false)
    if($Bytes.Length -and $Bytes[0] -notin 0x00,0xEF,0xFE,0xFF){return $utf8.GetString($Bytes)}
    $reader=[IO.StreamReader]::new([IO.MemoryStream]::new($Bytes),$utf8,$true)
    try{$reader.ReadToEnd()}finally{$reader.Dispose()}
}
function Test-SBPublicationText([string]$Text,[string]$Path,[string]$Surface,$Allowances=@()) {
    $lines=$Text.Split("`n")
    foreach($rule in Get-SBPublicationRules){
        for($i=0;$i -lt $lines.Count;$i++){
            if($rule.regex.IsMatch($lines[$i])){
                $fingerprint=Get-SBTextHash ($rule.id+'|'+$Path+'|'+$lines[$i])
                $allow=@($Allowances|Where-Object {$_.rule -eq $rule.id -and $_.path -ceq $Path -and $_.fingerprint -eq $fingerprint -and $_.reason})
                @{rule=$rule.id;severity=$rule.severity;path=$Path;surface=$Surface;line=($i+1);fingerprint=$fingerprint;reviewed=($allow.Count -eq 1)}
            }
        }
    }
}
function Get-SBTrackedPublicationPolicyPath([string]$BrainRoot) {Join-Path $BrainRoot 'config/publication-policy.json'}
function Resolve-SBPublicationPolicyPath([string]$BrainRoot,[string]$PolicyPath) {
    # Without explicit -PolicyPath the tracked policy (config/publication-policy.json) wins, so a reset of .runtime does not change the outcome;
    # the legacy local policy is read only while no tracked file exists (CLI and MCP return the same outcome).
    if($PolicyPath){return $PolicyPath}
    $tracked=Get-SBTrackedPublicationPolicyPath $BrainRoot
    if(Test-Path -LiteralPath $tracked -PathType Leaf){return $tracked}
    $legacy=Join-Path $BrainRoot '.runtime/publication/policy.json'
    if(Test-Path -LiteralPath $legacy -PathType Leaf){return $legacy}
    return $null
}
function Move-SBPublicationPolicy([string]$BrainRoot,[switch]$Apply) {
    # Copies the legacy local policy to the tracked file; the legacy file stays in place.
    $legacy=Join-Path $BrainRoot '.runtime/publication/policy.json';$tracked=Get-SBTrackedPublicationPolicyPath $BrainRoot
    $state=if(!(Test-Path -LiteralPath $legacy -PathType Leaf)){'no-legacy'}elseif(Test-Path -LiteralPath $tracked -PathType Leaf){'tracked-exists'}else{'ready'}
    if($state -eq 'ready'){
        $policy=Read-SBJson (Assert-SBCentralDataPath $BrainRoot $legacy) $null
        if(!$policy -or $policy.schemaVersion -ne 1){throw (New-SBError 'publication.policy')}
        if($Apply){Write-SBFile $tracked ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $policy))) (Get-SBFileHash $tracked) (Join-Path $BrainRoot '.runtime/backups/publication')|Out-Null;$state='migrated'}
    }
    @{state=$state;applied=($state -eq 'migrated');source=$legacy;destination=$tracked}
}
function Get-SBPublicationBaselinePath([string]$BrainRoot,[string]$RepositoryRoot) {
    $key=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\','/').ToLowerInvariant().Replace('\','/')
    $id=(Get-SBHash ([Text.Encoding]::UTF8.GetBytes($key))).ToLowerInvariant().Substring(0,16)
    Join-Path $BrainRoot ('.runtime/publication/baseline-'+$id+'.json')
}
function Read-SBPublicationBaseline([string]$BrainRoot,[string]$RepositoryRoot) {
    $file=Get-SBPublicationBaselinePath $BrainRoot $RepositoryRoot
    Assert-SBPlainPath $file
    try { Read-SBJson $file $null } catch { $null }
}
function Set-SBPublicationHistoryPaths([string]$Root,[string[]]$Roots,$ObjectInfo,$Entries) {
    # Root commits introduce their entire tree. Every later path is introduced by a change against a parent.
    # Use raw NUL-delimited diffs, including merge parents, because rev-list names only one path per object.
    $commits=@($ObjectInfo.Keys | Where-Object { $ObjectInfo[$_].type -eq 'commit' })
    if($commits.Count){
        $diff=Invoke-SBGit $Root @('--no-replace-objects','diff-tree','--stdin','--root','--diff-merges=separate','-r','--raw','-z',
            '--no-commit-id','--no-renames','--no-abbrev','--no-relative','--ignore-submodules=none') 120000 -PreserveOutput -InputText (($commits -join "`n")+"`n")
        if($diff.code -ne 0 -or $diff.error){return $false}
        if($diff.output){
            $records=$diff.output.Split([char]0)
            if($records[-1] -or ($records.Count-1)%2){return $false}
            for($i=0;$i -lt $records.Count-1;$i+=2){
                $path=$records[$i+1]
                if(!$path -or $path.Contains([char]0xfffd) -or
                    $records[$i] -cnotmatch '^:[0-7]{6} ([0-7]{6}) [a-f0-9]{40,64} ([a-f0-9]{40,64}) [ADMT]$'){return $false}
                $mode=$Matches[1];$oid=$Matches[2]
                if($mode -notin @('000000','160000') -and $Entries.Contains($oid)){[void]$Entries[$oid].Paths.Add($path)}
            }
        }
    }

    # Explicit roots can also be trees or blobs, including through annotated tags.
    if(@($Roots | Where-Object { !$ObjectInfo.ContainsKey($_) }).Count){return $false}
    $tagTargets=@($Roots | Where-Object { $ObjectInfo[$_].type -eq 'tag' } | ForEach-Object { $_+'^{}' })
    $peeled=@()
    if($tagTargets.Count){
        $result=Invoke-SBGit $Root @('--no-replace-objects','cat-file','--batch-check=%(objectname)') -InputText (($tagTargets -join "`n")+"`n")
        $peeled=@($result.output -split '\r?\n')
        if($result.code -ne 0 -or $result.error -or $peeled.Count -ne $tagTargets.Count -or
            @($peeled | Where-Object {$_ -cnotmatch '^(?:[a-f0-9]{40}|[a-f0-9]{64})$'}).Count){return $false}
    }
    $nonCommitRoots=@($Roots + $peeled | Sort-Object -Unique)
    foreach($oid in $nonCommitRoots){
        if(!$ObjectInfo.ContainsKey($oid)){return $false}
        if($ObjectInfo[$oid].type -eq 'blob' -and $Entries.Contains($oid)){
            $Entries[$oid].Direct=$true
        }elseif($ObjectInfo[$oid].type -eq 'tree'){
            $tree=Invoke-SBGit $Root @('--no-replace-objects','ls-tree','-r','-z','--full-tree',$oid) 120000 -PreserveOutput
            if($tree.code -ne 0 -or $tree.error -or ($tree.output -and !$tree.output.EndsWith([char]0))){return $false}
            foreach($record in $tree.output.Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)){
                if($record -cnotmatch '^[0-7]{6} (blob|commit) ([a-f0-9]{40,64})\t([\s\S]+)$' -or
                    $Matches[3].Contains([char]0xfffd)){return $false}
                if($Matches[1] -eq 'blob' -and $Entries.Contains($Matches[2])){[void]$Entries[$Matches[2]].Paths.Add($Matches[3])}
            }
        }
    }
    !@($Entries.Values | Where-Object { !$_.Direct -and !$_.Paths.Count }).Count
}
function Test-SBPublication {
    param([string]$RepositoryPath,[string]$BrainRoot,[string]$PolicyPath,[ValidateRange(0,[int]::MaxValue)][int]$MaxHistoryBlobs=10000,[ValidateRange(0,[int]::MaxValue)][int]$MaxTextBytes=2097152,[switch]$Initial,
        [ValidatePattern('^(?:[0-9a-f]{40}|[0-9a-f]{64})$')][string[]]$PushObjectIds=@())
    $repo=Invoke-SBGit $RepositoryPath @('rev-parse','--show-toplevel');if($repo.code -ne 0){throw (New-SBError 'publication.checkout')};$root=$repo.output
    $allowances=@();$binaryReviews=@();if($PolicyPath){$policyFile=if([IO.Path]::GetFullPath($PolicyPath) -ieq [IO.Path]::GetFullPath((Get-SBTrackedPublicationPolicyPath $BrainRoot))){Assert-SBPlainPath $PolicyPath;[IO.Path]::GetFullPath($PolicyPath)}else{Assert-SBCentralDataPath $BrainRoot $PolicyPath};$policy=Read-SBJson $policyFile $null;if(!$policy -or $policy.schemaVersion -ne 1){throw (New-SBError 'publication.policy')};if($policy.ContainsKey('allowances')){$allowances=@($policy.allowances)};if($policy.ContainsKey('binaryReviews')){$binaryReviews=@($policy.binaryReviews)}}
    $findings=@();$incomplete=@();$checked=0

    $baselineFile = if ($BrainRoot) { Get-SBPublicationBaselinePath $BrainRoot $root }
    $baselineBefore = if ($Initial -and $baselineFile) {
        Assert-SBPlainPath $baselineFile
        Get-SBFileHash $baselineFile
    }
    $files=Invoke-SBGit $root @('ls-files','-z','--cached','--others','--exclude-standard') -PreserveOutput
    if($files.code -ne 0){throw (New-SBError 'publication.inventory')}
    $targetFiles = @($files.output -split "`0"|Where-Object {$_}|Sort-Object -CaseSensitive -Unique)

    # Index OIDs in one process, then batch type/size: no per-file rev-parse/cat-file -s.
    $indexMap=[hashtable]::new([StringComparer]::Ordinal)
    $indexList=Invoke-SBGit $root @('ls-files','-s','-z') 120000 -PreserveOutput
    if($indexList.code -ne 0){throw (New-SBError 'publication.index')}
    foreach($entry in $indexList.output -split "`0"){
        if(!$entry){continue}
        if($entry -cnotmatch '^(\d+) ((?:[a-f0-9]{40}|[a-f0-9]{64})) ([0-3])\t([\s\S]+)$'){throw (New-SBError 'publication.index')}
        if($Matches[3] -ne '0'){$incomplete+=@{path=$Matches[4];surface='index';reason='index-unmerged'};continue}
        if($Matches[1] -ne '160000'){$indexMap[$Matches[4]]=$Matches[2]}
    }
    $indexInfo=Get-SBGitObjectInfo $root @($indexMap.Values|Sort-Object -Unique) -NoReplaceObjects
    # Index blob contents in one process within a memory budget; beyond the budget, retain per-file reads.
    $indexText=@{};$prefetchBudget=268435456;$prefetch=[Collections.Generic.List[object]]::new()
    foreach($oid in @($indexInfo.Keys|Sort-Object)){
        $meta=$indexInfo[$oid];if($meta.type -ne 'blob' -or $meta.size -gt $MaxTextBytes -or $meta.size -gt $prefetchBudget){continue}
        $prefetchBudget-=$meta.size;$prefetch.Add(@{Oid=$oid;Skip=$false})
    }
    if($prefetch.Count){Read-SBGitBlobs $root $prefetch.ToArray() -NoReplaceObjects|ForEach-Object {if(!$_.Missing -and $null -ne $_.Bytes){$indexText[$_.Entry.Oid]=ConvertTo-SBBlobText $_.Bytes}}}

    $verifiedAncestors=@{}
    foreach($relative in $targetFiles){
        if($relative -match '(^|/)(?:\.runtime|\.scratch|\.worktrees|node_modules|__pycache__|bin|obj|test-results|backups?)(/|$)|\.(?:bak|tmp|recovery)$'){
            $findings+=@{rule='operational-artifact';severity='error';path=$relative;surface='working-or-index';reviewed=$false}
        }
        $full=Join-Path $root $relative
        try{
            Assert-SBPlainPath $full $verifiedAncestors
            if(Test-Path -LiteralPath $full -PathType Leaf){
                $file=Get-Item -LiteralPath $full
                if($file.Length -le $MaxTextBytes){
                    $bytes=[IO.File]::ReadAllBytes($full)
                    if($bytes -notcontains 0){$findings+=@(Test-SBPublicationText ([Text.Encoding]::UTF8.GetString($bytes)) $relative 'working' $allowances);$checked++}
                    elseif(!@($binaryReviews|Where-Object {$_.path -ceq $relative -and $_.sha256 -eq (Get-SBHash $bytes) -and $_.reviewed -and $_.reason}).Count){$incomplete+=@{path=$relative;surface='working';reason='binary-review-required'}}
                }
                elseif(!@($binaryReviews|Where-Object {$_.path -ceq $relative -and $_.sha256 -eq (Get-SBFileHash $full) -and $_.reviewed -and $_.reason}).Count){$incomplete+=@{path=$relative;surface='working';reason='size-limit'}}
            }
            $indexOid=if($indexMap.ContainsKey($relative)){$indexMap[$relative]}else{$null}
            $index=@{code=1;output=''}
            if($indexOid -and (!$indexInfo.ContainsKey($indexOid) -or $indexInfo[$indexOid].type -ne 'blob')){
                $incomplete+=@{path=$relative;surface='index';reason='unreadable'}
            }elseif($indexOid){
                if($indexInfo[$indexOid].size -le $MaxTextBytes){
                    $index=if($indexText.ContainsKey($indexOid)){@{code=0;output=$indexText[$indexOid]}}else{Invoke-SBGit $root @('--no-replace-objects','cat-file','blob',$indexOid) -PreserveOutput}
                    if($index.code -ne 0){$incomplete+=@{path=$relative;surface='index';reason='unreadable'}}
                }
                elseif(!@($binaryReviews|Where-Object {$_.path -ceq $relative -and $_.gitBlob -eq $indexOid -and $_.reviewed -and $_.reason}).Count){$incomplete+=@{path=$relative;surface='index';reason='size-limit'}}
            }
            if($index.code -eq 0){
                if([Text.Encoding]::UTF8.GetByteCount($index.output) -le $MaxTextBytes -and !$index.output.Contains([char]0)){$findings+=@(Test-SBPublicationText $index.output $relative 'index' $allowances);$checked++}
                else{if(!@($binaryReviews|Where-Object {$_.path -ceq $relative -and $_.gitBlob -eq $indexOid -and $_.reviewed -and $_.reason}).Count){$incomplete+=@{path=$relative;surface='index';reason='binary-or-size-limit'}}}
            }
            if($relative -match '\.md$' -and (Test-Path -LiteralPath $full -PathType Leaf)){
                $markdown=Read-SBText $full
                $markdown=[regex]::Replace($markdown,'(?ms)^```.*?^```[^\r\n]*$','')
                $markdown=[regex]::Replace($markdown,'`[^`\r\n]*`','')
                foreach($match in [regex]::Matches($markdown,'!?\[[^\]]*\]\(([^)\s]+)\)')){
                    $target=$match.Groups[1].Value
                    if($target -match '^(?:[a-z][a-z0-9+.-]*:|#)' ){continue}
                    $target=($target -split '[?#]',2)[0]
                    if($target -and !(Test-Path -LiteralPath (Join-Path (Split-Path $full) ([Uri]::UnescapeDataString($target))))){$findings+=@{rule='broken-local-link';severity='error';path=$relative;surface='working';reviewed=$false}}
                }
            }
        }catch{$incomplete+=@{path=$relative;surface='working-or-index';reason=$_.Exception.GetType().Name}}
    }

    $headRes = Invoke-SBGit $root @('rev-parse','--verify','--quiet','HEAD')
    $currentHead = if ($headRes.code -eq 0) { $headRes.output }
    $refList = Invoke-SBGit $root @('for-each-ref','--sort=refname','--format=%(objectname) %(refname)')
    $refs = @($refList.output -split '\r?\n' | Where-Object {$_})
    $selectedRefs = @($refs | Where-Object {$_ -cmatch ' refs/(heads|tags|remotes)/'})
    $pushObjects = @($PushObjectIds | Where-Object {$_ -notmatch '^0+$'} | Sort-Object -Unique)
    $excludedRefs = @($refs | Where-Object {$_ -cnotmatch ' refs/(heads|tags|remotes)/'} | ForEach-Object {
        $oid,$ref = $_ -split ' ',2
        if ($oid -notin $pushObjects) { $ref }
    })
    $roots = @(@($currentHead) + $pushObjects + @($selectedRefs | ForEach-Object { ($_ -split ' ',2)[0] }) |
        Where-Object {$_} | Sort-Object -Unique)
    $shallow = Invoke-SBGit $root @('rev-parse','--is-shallow-repository')
    $grafts = Invoke-SBGit $root @('rev-parse','--path-format=absolute','--git-path','info/grafts')
    if ($refList.code -ne 0 -or $refList.error -or $shallow.code -ne 0 -or $grafts.code -ne 0 -or $headRes.code -notin @(0,1)) {
        $incomplete+=@{surface='history';reason='history-unavailable'}
    } elseif ($shallow.output -ne 'false' -or $env:GIT_GRAFT_FILE -or (Test-Path -LiteralPath $grafts.output)) {
        $incomplete+=@{surface='history';reason='history-limited'}
    }
    $historyAvailable = !@($incomplete | Where-Object surface -eq 'history').Count
    $historyKey = Get-SBTextHash (ConvertTo-SBJson @{
        repository=$root; refs=$selectedRefs; head=$currentHead; pushObjects=$pushObjects
        policy=@{allowances=$allowances;binaryReviews=$binaryReviews}
        limits=@{history=$MaxHistoryBlobs;text=$MaxTextBytes}
        scanner=(Get-SBFileHash $PSCommandPath)
        gitReader=(Get-SBFileHash (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1'))
    })
    $baseline = if (!$Initial -and $baselineFile -and $historyAvailable) {
        $saved = Read-SBPublicationBaseline $BrainRoot $root
        if ($saved -is [Collections.IDictionary] -and $saved['schemaVersion'] -eq 2 -and $saved['historyKey'] -ceq $historyKey -and
            $saved['repository'] -ceq $root -and $saved['historyBlobs'] -is [ValueType] -and
            $saved.historyBlobs -ge 0 -and $saved.historyBlobs -le $MaxHistoryBlobs -and
            $saved['historyFindings'] -is [array] -and
            !@($saved.historyFindings | Where-Object { $_ -isnot [Collections.IDictionary] -or $_['surface'] -ne 'history' -or $_['reviewed'] -ne $true }).Count) { $saved }
    }
    $historyCount = 0
    if ($baseline) {
        $historyCount = [int]$baseline.historyBlobs
        $findings += @($baseline.historyFindings)
    } elseif ($roots.Count -and $historyAvailable) {
        $objects = Invoke-SBGit $root @('--no-replace-objects','rev-list','--objects','--no-object-names','--stdin') 120000 -InputText (($roots -join "`n")+"`n")
        if ($objects.code -ne 0 -or $objects.error) {
            $incomplete+=@{surface='history';reason='history-unavailable'}
        } else {
            $oids=@($objects.output -split '\r?\n')
            if(@($oids | Where-Object {$_ -cnotmatch '^(?:[a-f0-9]{40}|[a-f0-9]{64})$'}).Count){
                $incomplete+=@{surface='history';reason='unreadable'}
            }else{
                $objectInfo=Get-SBGitObjectInfo $root $oids -NoReplaceObjects
                $entries=[ordered]@{}
                foreach($oid in $oids){
                    $meta=$objectInfo[$oid]
                    if(!$meta){$incomplete+=@{surface='history';reason='unreadable'};continue}
                    if($meta.type -ne 'blob'){continue}
                    if($entries.Count -ge $MaxHistoryBlobs){$incomplete+=@{surface='history';reason='blob-limit'};break}
                    $entries[$oid]=@{Oid=$oid;Skip=([long]$meta.size -gt $MaxTextBytes);Paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);Direct=$false}
                }
                if($entries.Count){
                    if(!(Set-SBPublicationHistoryPaths $root $roots $objectInfo $entries)){
                        $incomplete+=@{surface='history';reason='history-paths-unavailable'}
                    }else{
                        $historyCount=$entries.Count
                        Read-SBGitBlobs $root @($entries.Values) -NoReplaceObjects | ForEach-Object {
                            $entry=$_.Entry
                            $oid=$entry.Oid
                            $reason=if($entry.Skip){'size-limit'}elseif($_.Missing -or $null -eq $_.Bytes){'unreadable'}
                            $blobText=if(!$reason){ConvertTo-SBBlobText $_.Bytes}
                            if(!$reason -and $blobText.Contains([char]0)){$reason='binary-review-required'}
                            foreach($relative in $entry.Paths | Sort-Object -CaseSensitive){
                                if(!$reason){
                                    $findings+=@(Test-SBPublicationText $blobText $relative 'history' $allowances)
                                }elseif($reason -eq 'unreadable' -or !@($binaryReviews|Where-Object {$_.path -ceq $relative -and $_.gitBlob -eq $oid -and $_.reviewed -and $_.reason}).Count){
                                    $incomplete+=@{path=$relative;surface='history';reason=$reason}
                                }
                            }
                            if($entry.Direct){
                                $label='(object '+$oid+')'
                                if($reason){$incomplete+=@{path=$label;surface='history';reason=$reason}}
                                else{$findings+=@(Test-SBPublicationText $blobText $label 'history')}
                            }
                        }
                    }
                }
            }
        }
    }
    $status=Invoke-SBGit $root @('status','--porcelain=v1','-z','--ignored=matching') 30000 -PreserveOutput
    if($status.code -ne 0){$incomplete+=@{surface='ignored';reason='status-unavailable'}}
    $dirty=$false;$renameSource=$false
    foreach($line in $status.output -split "`0"){
        if($renameSource){$renameSource=$false;continue}
        if($line.StartsWith('!! ')){
            $ignored=$line.Substring(3)
            if($ignored -match '(^|/)(?:node_modules|bin|obj|build|dist|\.gradle|\.venv|__pycache__|test-results|backups?)(/|$)|(^|/)\.env(?:\.|$)|\.(?:bak|tmp)$'){
                $findings+=@{rule='ignored-operational-residue';severity='review';path=$ignored;surface='ignored';reviewed=$false}
            }
        }elseif($line){
            $dirty=$true
            $renameSource=$line.Substring(0,2) -match '[RC]'
        }
    }
    $unresolved=@($findings|Where-Object {!$_.reviewed})
    
    if ($Initial -and $baselineFile -and $roots.Count -and !$unresolved.Count -and !$incomplete.Count) {
        $baselineObj = @{
            schemaVersion = 2
            historyKey = $historyKey
            generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
            historyBlobs = $historyCount
            historyFindings = @($findings | Where-Object surface -eq 'history')
            repository = $root
        }
        [void](Write-SBFile $baselineFile ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $baselineObj))) $baselineBefore (Join-Path $BrainRoot '.runtime/backups/publication'))
    }

    foreach($diagnostic in $incomplete){[void](Add-SBReportDiagnostic $diagnostic 'publication')}
    @{schemaVersion=1;repositoryPath=$root;ready=(!$unresolved.Count -and !$incomplete.Count);complete=(!$incomplete.Count);findings=$findings;incomplete=$incomplete;
      checkedTextSurfaces=$checked;historyBlobs=$historyCount;workingTreeDirty=$dirty;historyRewritten=$false;incremental=[bool]$baseline;baseline=$baseline;excludedRefs=$excludedRefs;pushObjectIds=$pushObjects;coverage='Rule-based text and Git inventory checks on branches, tags, remotes, HEAD and explicit push objects; binary contents and legal compliance are not certified.'}
}
function New-SBCaptureRecord {
    param([string]$BrainRoot,[string]$SourcePath,[string]$Repository,[string]$Application,[string]$Version,[string]$Commit,[string]$Scenario,[string]$CaptureTool,[string]$Reproduction,[bool]$Dirty=$false)
    $source=Assert-SBCentralDataPath $BrainRoot $SourcePath
    foreach($value in @($Repository,$Application,$Version,$Commit,$Scenario,$CaptureTool,$Reproduction)){if(!$value){throw (New-SBError 'publication.capture.metadata')}}
    $bytes=[IO.File]::ReadAllBytes($source)
    if($bytes.Length -lt 24 -or [BitConverter]::ToString($bytes[0..7]) -ne '89-50-4E-47-0D-0A-1A-0A'){throw (New-SBError 'publication.capture.png')}
    function Read-BigEndian([int]$Offset){$part=[byte[]]$bytes[$Offset..($Offset+3)];[array]::Reverse($part);[BitConverter]::ToUInt32($part,0)}
    @{schemaVersion=1;repository=$Repository;source=$source;sha256=(Get-SBFileHash $source);application=$Application;version=$Version;commit=$Commit;dirty=$Dirty;scenario=$Scenario;
      captureTool=$CaptureTool;reproduction=$Reproduction;dataKind='synthetic';width=(Read-BigEndian 16);height=(Read-BigEndian 20);realCaptureReviewed=$false;privacyReviewed=$false;reviewNote='';published=$false}
}
function Export-SBPublicCapture {
    param([string]$BrainRoot,[string]$ManifestPath,[string]$RepositoryPath,[string]$Name,[string]$BackupRoot,[switch]$Apply,$Bindings=@())
    $manifest=Read-SBJson (Assert-SBCentralDataPath $BrainRoot $ManifestPath) $null
    if(!$manifest -or $manifest.schemaVersion -ne 1 -or $manifest.dataKind -ne 'synthetic' -or !$manifest.realCaptureReviewed -or !$manifest.privacyReviewed -or !$manifest.reviewNote){throw (New-SBError 'publication.capture.review')}
    if($Name -notmatch '^[a-z0-9][a-z0-9-]{0,79}\.png$'){throw (New-SBError 'publication.asset.name')}
    $checkout=Invoke-SBGit $RepositoryPath @('rev-parse','--show-toplevel')
    if($checkout.code -ne 0 -or [IO.Path]::GetFullPath($checkout.output) -ne [IO.Path]::GetFullPath($RepositoryPath)){throw (New-SBError 'publication.asset.root')}
    $resolved=Resolve-SBBoundIdentity $RepositoryPath $Bindings
    if($resolved -cne $manifest.repository){throw (New-SBError 'publication.asset.repository')}
    [void](Assert-SBCentralDataPath $BrainRoot $manifest.source)
    if((Get-SBFileHash $manifest.source) -ne $manifest.sha256){throw (New-SBError 'publication.capture.changed')}
    $destination=Join-Path $RepositoryPath ('docs/assets/'+$Name)
    # PNG ancillary chunks may contain paths or private metadata: publish only IHDR/PLTE/IDAT/IEND and transparency/color chunks.
    $sourceBytes=[IO.File]::ReadAllBytes($manifest.source);$stream=[IO.MemoryStream]::new()
    $chunkKinds=@()
    try{
        $stream.Write($sourceBytes,0,8);$offset=8
        while($offset -lt $sourceBytes.Length){
            if($offset+12 -gt $sourceBytes.Length){throw (New-SBError 'publication.png.truncated')}
            $lengthBytes=[byte[]]$sourceBytes[$offset..($offset+3)];[array]::Reverse($lengthBytes);$length=[BitConverter]::ToUInt32($lengthBytes,0)
            if([long]$offset+12+$length -gt $sourceBytes.Length){throw (New-SBError 'publication.png.chunk')}
            $kind=[Text.Encoding]::ASCII.GetString($sourceBytes,$offset+4,4)
            $chunkKinds+=$kind
            if($kind -in @('IHDR','PLTE','IDAT','IEND','tRNS','sRGB','gAMA','cHRM')){$stream.Write($sourceBytes,$offset,[int]($length+12))}
            $offset+=[int]($length+12)
        }
        $output=$stream.ToArray()
    }finally{$stream.Dispose()}
    if($chunkKinds[0] -ne 'IHDR' -or $chunkKinds[-1] -ne 'IEND' -or 'IDAT' -notin $chunkKinds -or @($chunkKinds|Where-Object {$_ -eq 'IHDR'}).Count -ne 1){throw (New-SBError 'publication.png.structure')}
    if($Apply){[void](Assert-SBCentralDataPath $BrainRoot $BackupRoot);Write-SBFile $destination $output (Get-SBFileHash $destination) $BackupRoot|Out-Null}
    @{applied=[bool]$Apply;destination=$destination;sourceSha256=$manifest.sha256;publicSha256=(Get-SBHash $output);metadataRemoved=$true;originalRetained=$true}
}

function Get-SBPublicationHookContent {
    @'
#!/bin/sh
# SecondBrain pre-push hook (SEC07 publication guard)
# Checks working tree, index and history for secrets, host paths and unreviewed assets before push.

if [ -n "$SECONDBRAIN_SKIP_PRE_PUSH" ] && [ "$SECONDBRAIN_SKIP_PRE_PUSH" = "1" ]; then
    exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
    exit 0
fi

# Fail-closed: senza SecondBrain il push non e verificato, quindi si ferma con istruzioni.
fail_closed() {
    echo "[SecondBrain pre-push] ERRORE: $1" >&2
    echo "[SecondBrain pre-push] Push annullato: la verifica SEC07 non puo essere eseguita." >&2
    echo "[SecondBrain pre-push] Per ripristinarla: imposta SECONDBRAIN_HOME sul clone di SecondBrain (pwsh -NoProfile -File <SecondBrain>/scripts/secondbrain.ps1 -Setup ... -RegisterEnvironment) e riapri il terminale." >&2
    echo "[SecondBrain pre-push] Solo per un push una tantum e consapevole: SECONDBRAIN_SKIP_PRE_PUSH=1 git push ..." >&2
    exit 1
}

PWSH_CMD=""
if command -v pwsh >/dev/null 2>&1; then
    PWSH_CMD="pwsh"
elif command -v powershell >/dev/null 2>&1; then
    PWSH_CMD="powershell"
fi

if [ -z "$PWSH_CMD" ]; then
    fail_closed "PowerShell (pwsh) non trovato nel PATH."
fi

SB_ROOT="${SECONDBRAIN_HOME}"
if [ -z "$SB_ROOT" ] && [ -f "$REPO_ROOT/scripts/publication.ps1" ]; then
    SB_ROOT="$REPO_ROOT"
fi

if [ -z "$SB_ROOT" ]; then
    fail_closed "SECONDBRAIN_HOME non e impostata."
fi

if [ ! -f "$SB_ROOT/scripts/publication.ps1" ]; then
    fail_closed "SECONDBRAIN_HOME punta a un percorso senza scripts/publication.ps1 (clone spostato o variabile obsoleta)."
fi

"$PWSH_CMD" -NoProfile -ExecutionPolicy Bypass -File "$SB_ROOT/scripts/publication.ps1" -RepositoryPath "$REPO_ROOT" -PrePushInput
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "[SecondBrain pre-push] ERRORE: La verifica di pubblicabilita (SEC07) ha rilevato criticita bloccanti (codice $EXIT_CODE)." >&2
    echo "[SecondBrain pre-push] Push annullato per impedire la diffusione di credenziali, percorsi host o dati non verificati." >&2
    exit 1
fi

exit 0
'@
}

function Install-SBPublicationHook {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryPath,
        [string]$BrainRoot,
        [switch]$Apply,
        [switch]$Force
    )
    $repo = Invoke-SBGit $RepositoryPath @('rev-parse','--show-toplevel')
    if ($repo.code -ne 0) { throw (New-SBError 'publication.hook.checkout') }
    $root = [IO.Path]::GetFullPath($repo.output)
    
    $gitDirRes = Invoke-SBGit $root @('rev-parse','--git-path','hooks')
    $hooksDir = if ($gitDirRes.code -eq 0 -and $gitDirRes.output) {
        if ([IO.Path]::IsPathRooted($gitDirRes.output)) { $gitDirRes.output } else { Join-Path $root $gitDirRes.output }
    } else {
        Join-Path $root '.git/hooks'
    }
    
    $hookFile = Join-Path $hooksDir 'pre-push'
    $content = (Get-SBPublicationHookContent).Replace("`r`n", "`n")
    
    $alreadyExists = Test-Path -LiteralPath $hookFile -PathType Leaf
    if ($alreadyExists -and !$Force) {
        $existing = [IO.File]::ReadAllText($hookFile)
        if ($existing -notmatch 'SecondBrain pre-push hook') {
            throw (New-SBError 'publication.hook.custom' @($hookFile))
        }
    }
    
    if (!$Apply) {
        return @{
            applied = $false
            preview = $true
            repositoryPath = $root
            hookPath = $hookFile
            message = "Anteprima: specificare -Apply per installare l'hook pre-push in $hookFile"
        }
    }
    
    if (!(Test-Path -LiteralPath $hooksDir -PathType Container)) {
        [IO.Directory]::CreateDirectory($hooksDir) | Out-Null
    }
    
    [IO.File]::WriteAllText($hookFile, $content, [Text.UTF8Encoding]::new($false))
    
    return @{
        applied = $true
        preview = $false
        repositoryPath = $root
        hookPath = $hookFile
        sha256 = (Get-SBFileHash $hookFile)
    }
}

function Uninstall-SBPublicationHook {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryPath,
        [switch]$Apply
    )
    $repo = Invoke-SBGit $RepositoryPath @('rev-parse','--show-toplevel')
    if ($repo.code -ne 0) { throw (New-SBError 'publication.checkout') }
    $root = [IO.Path]::GetFullPath($repo.output)
    
    $gitDirRes = Invoke-SBGit $root @('rev-parse','--git-path','hooks')
    $hooksDir = if ($gitDirRes.code -eq 0 -and $gitDirRes.output) {
        if ([IO.Path]::IsPathRooted($gitDirRes.output)) { $gitDirRes.output } else { Join-Path $root $gitDirRes.output }
    } else {
        Join-Path $root '.git/hooks'
    }
    $hookFile = Join-Path $hooksDir 'pre-push'
    
    if (!(Test-Path -LiteralPath $hookFile -PathType Leaf)) {
        return @{
            applied = [bool]$Apply
            removed = $false
            hookPath = $hookFile
            message = 'Hook pre-push non presente.'
        }
    }
    
    if (!$Apply) {
        return @{
            applied = $false
            preview = $true
            hookPath = $hookFile
            message = "Anteprima: specificare -Apply per rimuovere l'hook pre-push $hookFile"
        }
    }
    
    # A pre-push hook not created by SecondBrain belongs to the user: never delete it.
    if ((Get-Content -LiteralPath $hookFile -Raw) -notmatch 'SecondBrain pre-push hook') {
        throw (New-SBError 'publication.hook.foreign' @($hookFile))
    }
    Remove-Item -LiteralPath $hookFile -Force
    return @{
        applied = $true
        removed = $true
        hookPath = $hookFile
    }
}

function Get-SBPublicationHookStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryPath)
    $repo = Invoke-SBGit $RepositoryPath @('rev-parse','--show-toplevel')
    if ($repo.code -ne 0) { throw (New-SBError 'publication.checkout') }
    $root = [IO.Path]::GetFullPath($repo.output)
    
    $gitDirRes = Invoke-SBGit $root @('rev-parse','--git-path','hooks')
    $hooksDir = if ($gitDirRes.code -eq 0 -and $gitDirRes.output) {
        if ([IO.Path]::IsPathRooted($gitDirRes.output)) { $gitDirRes.output } else { Join-Path $root $gitDirRes.output }
    } else {
        Join-Path $root '.git/hooks'
    }
    $hookFile = Join-Path $hooksDir 'pre-push'
    
    $installed = Test-Path -LiteralPath $hookFile -PathType Leaf
    $isSecondBrainHook = $false
    $usesPushInput = $false
    if ($installed) {
        $text = [IO.File]::ReadAllText($hookFile)
        $isSecondBrainHook = [bool]($text -match 'SecondBrain pre-push hook')
        $usesPushInput = $isSecondBrainHook -and $text.Contains('-PrePushInput')
    }
    
    @{
        repositoryPath = $root
        hookPath = $hookFile
        installed = $installed
        isSecondBrainHook = $isSecondBrainHook
        usesPushInput = $usesPushInput
    }
}

Export-ModuleMember -Function @(
    'Test-SBPublicationText',
    'Resolve-SBPublicationPolicyPath',
    'Get-SBTrackedPublicationPolicyPath',
    'Move-SBPublicationPolicy',
    'Get-SBPublicationBaselinePath',
    'Read-SBPublicationBaseline',
    'Test-SBPublication',
    'New-SBCaptureRecord',
    'Export-SBPublicCapture',
    'Install-SBPublicationHook',
    'Uninstall-SBPublicationHook',
    'Get-SBPublicationHookStatus'
)
