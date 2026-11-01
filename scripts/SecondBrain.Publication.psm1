#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')

$script:SBPublicationRuleCache=$null
function Get-SBPublicationRules {
    # Regole e regex costruite una sola volta per processo (IgnoreCase come l operatore -match).
    if($script:SBPublicationRuleCache){return $script:SBPublicationRuleCache}
    $script:SBPublicationRuleCache=@(
        @{id='credential';severity='error';pattern='(?i)(?:gh[pousr]_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|(?:api[_-]?key|password|token)\s*[:=]\s*["''][^"''\r\n]{12,}["''])'},
        @{id='host-path';severity='error';pattern='(?i)(?:[A-Z]:[\\/](?:Users|GITHUB)[\\/]|/(?:Users|home)/[^/\s\(\)\[\]]+(?=/|$))'},
        @{id='personal-email';severity='review';pattern='\b[A-Za-z0-9._%+-]+@(?!example\.(?:com|org|net)\b|[^\s@]*\.invalid\b|users\.noreply\.github\.com\b)[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'}
    )|ForEach-Object {$_.regex=[regex]::new($_.pattern,[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant, Compiled');$_}
    $script:SBPublicationRuleCache
}
function ConvertTo-SBBlobText([byte[]]$Bytes) {
    # Stessa decodifica dello stream di processo: UTF-8 con rilevamento del BOM (UTF-16/32 inclusi).
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
function Test-SBPublication {
    param([string]$RepositoryPath,[string]$BrainRoot,[string]$PolicyPath,[int]$MaxHistoryBlobs=10000,[int]$MaxTextBytes=2097152,[switch]$Initial)
    $repo=Invoke-SBGit $RepositoryPath @('rev-parse','--show-toplevel');if($repo.code -ne 0){throw 'Checkout Git richiesto'};$root=$repo.output
    $allowances=@();$binaryReviews=@();if($PolicyPath){$policy=Read-SBJson (Assert-SBCentralDataPath $BrainRoot $PolicyPath) $null;if(!$policy -or $policy.schemaVersion -ne 1){throw 'Policy pubblicazione non valida'};if($policy.ContainsKey('allowances')){$allowances=@($policy.allowances)};if($policy.ContainsKey('binaryReviews')){$binaryReviews=@($policy.binaryReviews)}}
    $findings=@();$incomplete=@();$checked=0
    
    $baselineFile = if ($BrainRoot) { Join-Path $BrainRoot '.runtime/publication/baseline.json' } else { $null }
    $baseline = if (!$Initial -and $baselineFile -and (Test-Path -LiteralPath $baselineFile -PathType Leaf)) {
        Read-SBJson $baselineFile $null
    } else { $null }

    $targetFiles = @()
    if ($baseline -and $baseline.headCommit) {
        # Modalità incrementale: scansiona solo file modificati, staged o non tracciati
        $diffFiles = Invoke-SBGit $root @('diff', '--name-only', $baseline.headCommit)
        $untracked = Invoke-SBGit $root @('ls-files', '--others', '--exclude-standard')
        $cached = Invoke-SBGit $root @('diff', '--cached', '--name-only')
        $rawList = @()
        if ($diffFiles.code -eq 0 -and $diffFiles.output) { $rawList += @($diffFiles.output -split "`n") }
        if ($untracked.code -eq 0 -and $untracked.output) { $rawList += @($untracked.output -split "`n") }
        if ($cached.code -eq 0 -and $cached.output) { $rawList += @($cached.output -split "`n") }
        $targetFiles = @($rawList | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
    } else {
        $files=Invoke-SBGit $root @('ls-files','-z','--cached','--others','--exclude-standard') -PreserveOutput
        if($files.code -ne 0){throw 'Inventario Git non leggibile'}
        $targetFiles = @($files.output -split "`0"|Where-Object {$_}|Sort-Object -Unique)
    }

    # Oid dell indice in un solo processo, poi tipo/dimensione in batch: niente rev-parse/cat-file -s per file.
    $indexMap=@{}
    $indexList=Invoke-SBGit $root @('ls-files','-s','-z') 120000 -PreserveOutput
    if($indexList.code -ne 0){throw 'Indice Git non leggibile'}
    foreach($entry in $indexList.output -split "`0"){if($entry -match '^\d+ ([a-f0-9]{40,64}) 0\t(.+)$'){$indexMap[$Matches[2]]=$Matches[1]}}
    $indexInfo=Get-SBGitObjectInfo $root @($targetFiles|Where-Object {$indexMap.ContainsKey($_)}|ForEach-Object {$indexMap[$_]}|Sort-Object -Unique)
    # Contenuto dei blob d indice in un solo processo, entro un budget di memoria; oltre il budget resta la lettura per file.
    $indexText=@{};$prefetchBudget=268435456;$prefetch=[Collections.Generic.List[object]]::new()
    foreach($oid in @($indexInfo.Keys|Sort-Object)){
        $meta=$indexInfo[$oid];if($meta.type -ne 'blob' -or $meta.size -gt $MaxTextBytes -or $meta.size -gt $prefetchBudget){continue}
        $prefetchBudget-=$meta.size;$prefetch.Add(@{Oid=$oid;Skip=$false})
    }
    if($prefetch.Count){Read-SBGitBlobs $root $prefetch.ToArray()|ForEach-Object {if(!$_.Missing -and $null -ne $_.Bytes){$indexText[$_.Entry.Oid]=ConvertTo-SBBlobText $_.Bytes}}}

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
            if($indexOid -and $indexInfo.ContainsKey($indexOid)){
                if($indexInfo[$indexOid].size -le $MaxTextBytes){$index=if($indexText.ContainsKey($indexOid)){@{code=0;output=$indexText[$indexOid]}}else{Invoke-SBGit $root @('cat-file','blob',$indexOid) -PreserveOutput}}
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

    $headRes = Invoke-SBGit $root @('rev-parse', 'HEAD')
    $currentHead = if ($headRes.code -eq 0) { $headRes.output.Trim() } else { $null }

    $objects = if ($baseline -and $baseline.headCommit -and $currentHead) {
        if ($currentHead -eq $baseline.headCommit) {
            @{ code = 0; output = '' }
        } else {
            Invoke-SBGit $root @('rev-list', '--objects', "$($baseline.headCommit)..$currentHead")
        }
    } else {
        Invoke-SBGit $root @('rev-list', '--objects', '--all')
    }

    $historyCount = if ($baseline -and $baseline.historyBlobs) { [int]$baseline.historyBlobs } else { 0 }
    if($objects.code -eq 0){
        # Tipo/dimensione di tutti gli oggetti con un processo, contenuto dei blob con un altro (streaming nell ordine di rev-list).
        $entries=[Collections.Generic.List[object]]::new()
        foreach($line in $objects.output -split "`n"){
            if($line -notmatch '^([a-f0-9]{40,64}) (.+)$'){continue}
            $entries.Add(@{Oid=$Matches[1];Path=$Matches[2]})
        }
        $objectInfo=Get-SBGitObjectInfo $root @($entries|ForEach-Object {$_.Oid})
        $queue=[Collections.Generic.List[object]]::new();$blobLimit=$false
        foreach($entry in $entries){
            if($historyCount -ge $MaxHistoryBlobs){$blobLimit=$true;break}
            $meta=$objectInfo[$entry.Oid];if(!$meta -or $meta.type -ne 'blob'){continue};$historyCount++
            $entry.Skip=([long]$meta.size -gt $MaxTextBytes)
            $queue.Add($entry)
        }
        if($queue.Count){
            Read-SBGitBlobs $root $queue.ToArray() | ForEach-Object {
                $relative=$_.Entry.Path;$oid=$_.Entry.Oid
                if($_.Entry.Skip){$incomplete+=@{path=$relative;surface='history';reason='size-limit'};return}
                if($_.Missing -or $null -eq $_.Bytes){$incomplete+=@{path=$relative;surface='history';reason='unreadable'};return}
                $blobText=ConvertTo-SBBlobText $_.Bytes
                if(!$blobText.Contains([char]0)){$findings+=@(Test-SBPublicationText $blobText $relative 'history' $allowances)}
                elseif(!@($binaryReviews|Where-Object {$_.path -ceq $relative -and $_.gitBlob -eq $oid -and $_.reviewed -and $_.reason}).Count){$incomplete+=@{path=$relative;surface='history';reason='binary-review-required'}}
            }
        }
        if($blobLimit){$incomplete+=@{surface='history';reason='blob-limit'}}
    }else{$incomplete+=@{surface='history';reason='history-unavailable'}}
    $status=Invoke-SBGit $root @('status','--porcelain=v1','--ignored') 30000
    foreach($line in $status.output -split "`n"){
        if($line -match '^!! (.+)$'){
            $ignored=$Matches[1].Trim('"')
            if($ignored -match '(^|/)(?:node_modules|bin|obj|build|dist|\.gradle|\.venv|__pycache__|test-results|backups?)(/|$)|(^|/)\.env(?:\.|$)|\.(?:bak|tmp)$'){
                $findings+=@{rule='ignored-operational-residue';severity='review';path=$ignored;surface='ignored';reviewed=$false}
            }
        }
    }
    $unresolved=@($findings|Where-Object {!$_.reviewed})
    
    if ($Initial -and $BrainRoot -and $currentHead) {
        [IO.Directory]::CreateDirectory((Join-Path $BrainRoot '.runtime/publication')) | Out-Null
        $baselineObj = @{
            schemaVersion = 1
            headCommit = $currentHead
            generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
            historyBlobs = $historyCount
            authorized = $true
            repository = $root
        }
        [IO.File]::WriteAllText($baselineFile, (ConvertTo-SBJson $baselineObj), [Text.UTF8Encoding]::new($false))
    }

    @{schemaVersion=1;repositoryPath=$root;ready=(!$unresolved.Count -and !$incomplete.Count);complete=(!$incomplete.Count);findings=$findings;incomplete=$incomplete;
      checkedTextSurfaces=$checked;historyBlobs=$historyCount;workingTreeDirty=[bool]$status.output;historyRewritten=$false;incremental=[bool]$baseline;baseline=$baseline;coverage='Rule-based text and Git inventory checks; binary contents and legal compliance are not certified.'}
}
function New-SBCaptureRecord {
    param([string]$BrainRoot,[string]$SourcePath,[string]$Repository,[string]$Application,[string]$Version,[string]$Commit,[string]$Scenario,[string]$CaptureTool,[string]$Reproduction,[bool]$Dirty=$false)
    $source=Assert-SBCentralDataPath $BrainRoot $SourcePath
    foreach($value in @($Repository,$Application,$Version,$Commit,$Scenario,$CaptureTool,$Reproduction)){if(!$value){throw 'Metadati di acquisizione incompleti'}}
    $bytes=[IO.File]::ReadAllBytes($source)
    if($bytes.Length -lt 24 -or [BitConverter]::ToString($bytes[0..7]) -ne '89-50-4E-47-0D-0A-1A-0A'){throw 'Acquisizione PNG richiesta'}
    function Read-BigEndian([int]$Offset){$part=[byte[]]$bytes[$Offset..($Offset+3)];[array]::Reverse($part);[BitConverter]::ToUInt32($part,0)}
    @{schemaVersion=1;repository=$Repository;source=$source;sha256=(Get-SBFileHash $source);application=$Application;version=$Version;commit=$Commit;dirty=$Dirty;scenario=$Scenario;
      captureTool=$CaptureTool;reproduction=$Reproduction;dataKind='synthetic';width=(Read-BigEndian 16);height=(Read-BigEndian 20);realCaptureReviewed=$false;privacyReviewed=$false;reviewNote='';published=$false}
}
function Export-SBPublicCapture {
    param([string]$BrainRoot,[string]$ManifestPath,[string]$RepositoryPath,[string]$Name,[string]$BackupRoot,[switch]$Apply,$Bindings=@())
    $manifest=Read-SBJson (Assert-SBCentralDataPath $BrainRoot $ManifestPath) $null
    if(!$manifest -or $manifest.schemaVersion -ne 1 -or $manifest.dataKind -ne 'synthetic' -or !$manifest.realCaptureReviewed -or !$manifest.privacyReviewed -or !$manifest.reviewNote){throw 'Acquisizione reale e privacy richiedono revisione esplicita'}
    if($Name -notmatch '^[a-z0-9][a-z0-9-]{0,79}\.png$'){throw 'Nome asset PNG non valido'}
    $checkout=Invoke-SBGit $RepositoryPath @('rev-parse','--show-toplevel')
    if($checkout.code -ne 0 -or [IO.Path]::GetFullPath($checkout.output) -ne [IO.Path]::GetFullPath($RepositoryPath)){throw 'Radice checkout Git richiesta per esportare asset'}
    $resolved=Resolve-SBBoundIdentity $RepositoryPath $Bindings
    if($resolved -cne $manifest.repository){throw 'Repository dellʼasset divergente'}
    [void](Assert-SBCentralDataPath $BrainRoot $manifest.source)
    if((Get-SBFileHash $manifest.source) -ne $manifest.sha256){throw 'Cattura modificata dopo la revisione'}
    $destination=Join-Path $RepositoryPath ('docs/assets/'+$Name)
    # PNG ancillary chunks may contain paths or private metadata: publish only IHDR/PLTE/IDAT/IEND and transparency/color chunks.
    $sourceBytes=[IO.File]::ReadAllBytes($manifest.source);$stream=[IO.MemoryStream]::new()
    $chunkKinds=@()
    try{
        $stream.Write($sourceBytes,0,8);$offset=8
        while($offset -lt $sourceBytes.Length){
            if($offset+12 -gt $sourceBytes.Length){throw 'PNG troncato'}
            $lengthBytes=[byte[]]$sourceBytes[$offset..($offset+3)];[array]::Reverse($lengthBytes);$length=[BitConverter]::ToUInt32($lengthBytes,0)
            if([long]$offset+12+$length -gt $sourceBytes.Length){throw 'Chunk PNG non valido'}
            $kind=[Text.Encoding]::ASCII.GetString($sourceBytes,$offset+4,4)
            $chunkKinds+=$kind
            if($kind -in @('IHDR','PLTE','IDAT','IEND','tRNS','sRGB','gAMA','cHRM')){$stream.Write($sourceBytes,$offset,[int]($length+12))}
            $offset+=[int]($length+12)
        }
        $output=$stream.ToArray()
    }finally{$stream.Dispose()}
    if($chunkKinds[0] -ne 'IHDR' -or $chunkKinds[-1] -ne 'IEND' -or 'IDAT' -notin $chunkKinds -or @($chunkKinds|Where-Object {$_ -eq 'IHDR'}).Count -ne 1){throw 'Struttura PNG non valida'}
    if($Apply){[void](Assert-SBCentralDataPath $BrainRoot $BackupRoot);Write-SBFile $destination $output (Get-SBFileHash $destination) $BackupRoot|Out-Null}
    @{applied=[bool]$Apply;destination=$destination;sourceSha256=$manifest.sha256;publicSha256=(Get-SBHash $output);metadataRemoved=$true;originalRetained=$true}
}

function Get-SBPublicationHookContent {
    @'
#!/bin/sh
# SecondBrain pre-push hook (REP05 publication guard)
# Checks working tree, index and history for secrets, host paths and unreviewed assets before push.

if [ -n "$SECONDBRAIN_SKIP_PRE_PUSH" ] && [ "$SECONDBRAIN_SKIP_PRE_PUSH" = "1" ]; then
    exit 0
fi

PWSH_CMD=""
if command -v pwsh >/dev/null 2>&1; then
    PWSH_CMD="pwsh"
elif command -v powershell >/dev/null 2>&1; then
    PWSH_CMD="powershell"
fi

if [ -z "$PWSH_CMD" ]; then
    echo "[SecondBrain pre-push] AVVISO: PowerShell non trovato nel PATH. Push consentito senza verifica REP05." >&2
    exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
    exit 0
fi

SB_ROOT="${SECONDBRAIN_HOME}"
if [ -z "$SB_ROOT" ] && [ -f "$REPO_ROOT/scripts/publication.ps1" ]; then
    SB_ROOT="$REPO_ROOT"
fi

if [ -z "$SB_ROOT" ] || [ ! -f "$SB_ROOT/scripts/publication.ps1" ]; then
    echo "[SecondBrain pre-push] AVVISO: SECONDBRAIN_HOME non configurato e scripts/publication.ps1 non trovato. Push consentito." >&2
    exit 0
fi

"$PWSH_CMD" -NoProfile -ExecutionPolicy Bypass -File "$SB_ROOT/scripts/publication.ps1" -RepositoryPath "$REPO_ROOT"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "[SecondBrain pre-push] ERRORE: La verifica di pubblicabilita (REP05) ha rilevato criticita bloccanti (codice $EXIT_CODE)." >&2
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
    if ($repo.code -ne 0) { throw 'Checkout Git richiesto per installare lʼhook pre-push' }
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
            throw "Hook pre-push personalizzato preesistente trovato in $hookFile. Usare -Force per sovrascrivere."
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
    
    [IO.File]::WriteAllText($hookFile, $content, [Text.Encoding]::UTF8)
    
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
    if ($repo.code -ne 0) { throw 'Checkout Git richiesto' }
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
    
    # Un pre-push non creato da SecondBrain e dell'utente: non si cancella.
    if ((Get-Content -LiteralPath $hookFile -Raw) -notmatch 'SecondBrain pre-push hook') {
        throw "Hook pre-push non creato da SecondBrain, rimozione rifiutata: $hookFile"
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
    if ($repo.code -ne 0) { throw 'Checkout Git richiesto' }
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
    if ($installed) {
        $text = [IO.File]::ReadAllText($hookFile)
        $isSecondBrainHook = [bool]($text -match 'SecondBrain pre-push hook')
    }
    
    @{
        repositoryPath = $root
        hookPath = $hookFile
        installed = $installed
        isSecondBrainHook = $isSecondBrainHook
    }
}

Export-ModuleMember -Function *-SB*
