#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
$script:SBCycleModulePath=$PSCommandPath
$script:SBCycleModuleHash=Get-SBFileHash $PSCommandPath
Add-SBMessages @{
    'cycle.adapter.fallback' = @{it='Esporta il solo turno corrente nel contratto normalizzato; l installazione non autorizza la persistenza.';en='Export only the current turn into the normalized envelope; installation does not authorize persistence.'}
    'cycle.invalid' = @{it='Ciclo memorie: input non valido ({0})';en='Memory cycle: invalid input ({0})'}
    'cycle.conflict' = @{it='Ciclo memorie: fonte cambiata o proposta ambigua ({0})';en='Memory cycle: changed source or ambiguous proposal ({0})'}
    'cycle.workspace' = @{it='Ciclo memorie: cartella evidence non appartenente a questa postazione e repository';en='Memory cycle: evidence workspace does not belong to this host and repository'}
}

function Test-SBCyclePrivate($Value) {
    $text=ConvertTo-SBJson $Value
    $text -match '(?is)<\s*/?\s*private\b|<\s*/?\s*do[-_]not[-_]memorize\b|"(?:private|doNotMemorize)"\s*:\s*true' -or
        ($Value -is [Collections.IDictionary] -and (($Value.ContainsKey('private') -and $Value.private -eq $true) -or
        ($Value.ContainsKey('doNotMemorize') -and $Value.doNotMemorize -eq $true)))
}

function Resolve-SBCycleDossier([string]$BrainRoot,[string]$Repository) {
    if(!(Test-SBRepositoryIdentity $Repository)){throw (New-SBError 'cycle.invalid' @('repository'))}
    $areas=@(Get-SBParaEntities $BrainRoot @()|Where-Object {$_.kind -eq 'area' -and !$_.archived -and $_.status -eq 'active' -and $_.repository -ceq $Repository})
    if($areas.Count -ne 1){throw (New-SBError 'cycle.invalid' @('active dossier'))}
    $dir=Resolve-SBParaPath $BrainRoot $areas[0].path
    if((Read-SBJson (Join-Path $dir 'repository.json') $null).identity -cne $Repository){throw (New-SBError 'cycle.invalid' @('dossier identity'))}
    $dir
}

function Test-SBCyclePersistence($InputObject) {
    # Neither an installed hook nor a previous turn is a per-turn authorization.
    $InputObject -is [Collections.IDictionary] -and $InputObject.ContainsKey('persistence') -and
        $InputObject.persistence -ceq 'allowed' -and $InputObject.ContainsKey('policyEvidence') -and
        $InputObject.policyEvidence -is [string] -and ![string]::IsNullOrWhiteSpace($InputObject.policyEvidence) -and
        !(Test-SBCyclePrivate $InputObject.policyEvidence)
}

function Assert-SBCycleIdentifier([string]$Value) {
    if($Value -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$'){throw (New-SBError 'cycle.invalid' @('identifier'))}
}
function Test-SBCycleCredentialPath([string]$Path) {
    $Path -match '(?i)[\\/](?:\.ssh|\.aws|\.azure|credentials|secrets|auth|authentication|gcloud)[\\/]|[\\/](?:auth\.json|\.?credentials[^\\/]*|oauth_creds\.json|google_accounts\.json|\.claude\.json)$'
}

function Get-SBCycleAdapter([ValidateSet('claude-code','codex','antigravity','vscode','android-studio','claude','cursor','windsurf','continue','jetbrains')][string]$Client,
    [string]$BrainRoot,[string]$Repository,[string]$ObservationPath) {
    $event=switch($Client){'claude-code'{'Stop'} 'codex'{'Stop'} 'antigravity'{'Stop'} 'cursor'{'stop'} 'windsurf'{'post_cascade_response'} 'vscode'{'runtime-dependent'} default{'unverified'}}
    $result=@{client=$Client;event=$event;liveVerified=$false;coverage='partial';mode='normalized-envelope';
      requires=@('per-turn-persistence','current-turn-boundary','visible-events','client-version');
      fallback=(Get-SBMessage 'cycle.adapter.fallback')}
    if($ObservationPath){
        [void](Resolve-SBCycleDossier $BrainRoot $Repository)
        $observationScope=[IO.Path]::GetFullPath((Join-Path $BrainRoot ('.runtime/hosts/'+(Get-SBHostId)+'/repos/'+(Get-SBRuntimeRepoSegment $Repository)+'/evidence'))).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if(![IO.Path]::GetFullPath($ObservationPath).StartsWith($observationScope,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'cycle.invalid' @('observation scope'))}
        Assert-SBPlainPath $ObservationPath
        $observation=Read-SBJson $ObservationPath $null
        if(!$observation -or !$observation.ContainsKey('workspace')){throw (New-SBError 'cycle.invalid' @('observation'))}
        $scope=(Assert-SBCycleWorkspace $BrainRoot $Repository $observation.workspace)+[IO.Path]::DirectorySeparatorChar
        if(![IO.Path]::GetFullPath($ObservationPath).StartsWith($scope,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'cycle.invalid' @('observation scope'))}
        foreach($field in @('schemaVersion','repository','client','clientVersion','evidenceKind','evidencePath','evidenceSha256','moduleSha256','coverage','observedAt')){
            if(!$observation.ContainsKey($field)){throw (New-SBError 'cycle.invalid' @('observation '+$field))}
        }
        $evidence=[IO.Path]::GetFullPath($observation.evidencePath)
        if(!$evidence.StartsWith($scope,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'cycle.invalid' @('observation evidence scope'))}
        Assert-SBPlainPath $evidence
        $date=[DateTimeOffset]::MinValue
        if($observation.schemaVersion -ne 1 -or $observation.repository -cne $Repository -or $observation.client -cne $Client -or
           !$observation.clientVersion -or ![DateTimeOffset]::TryParse([string]$observation.observedAt,[ref]$date) -or $date -gt [DateTimeOffset]::UtcNow -or
           $observation.coverage -cnotin @('partial','complete') -or $observation.moduleSha256 -cne $script:SBCycleModuleHash -or
           $script:SBCycleModuleHash -cne (Get-SBFileHash $script:SBCycleModulePath) -or
           $observation.evidenceSha256 -cne (Get-SBFileHash $evidence)){throw (New-SBError 'cycle.invalid' @('observation revision'))}
        $result.liveVerified=$observation.evidenceKind -ceq 'live-client';$result.coverage=$observation.coverage;$result.clientVersion=$observation.clientVersion;$result.observedAt=$observation.observedAt
    }
    $result
}

function ConvertFrom-SBCycleNativeTurn([string]$Client,$NativeEvent,$Permit) {
    # A caller-owned, single-turn permit supplies permission and exact source scope.
    if(!(Test-SBCyclePersistence $Permit) -or (Test-SBCyclePrivate $Permit)){return @{state='suppressed';writes=0}}
    foreach($field in @('repository','client','clientVersion','sessionId','turnId','transcriptPath','lastUserSha256')){
        if(!$Permit.ContainsKey($field)){throw (New-SBError 'cycle.invalid' @('permit '+$field))}
    }
    if($Client -cnotin @('codex','claude-code','antigravity') -or $Permit.client -cne $Client){throw (New-SBError 'cycle.invalid' @('native client'))}
    $session=if($NativeEvent.ContainsKey('session_id')){[string]$NativeEvent.session_id}elseif($NativeEvent.ContainsKey('conversationId')){[string]$NativeEvent.conversationId}else{''}
    $path=if($NativeEvent.ContainsKey('transcript_path')){[string]$NativeEvent.transcript_path}elseif($NativeEvent.ContainsKey('transcriptPath')){[string]$NativeEvent.transcriptPath}else{''}
    if(!$session -or $session -cne $Permit.sessionId -or !$path -or !(Test-SBSamePath $path $Permit.transcriptPath) -or
       (Test-SBCycleCredentialPath $path)){
        return @{state='suppressed';reason='native-scope-unverified';writes=0}
    }
    Assert-SBPlainPath $path
    if(![IO.File]::Exists($path) -or ([IO.FileInfo]::new($path)).Length -gt 128MB){return @{state='suppressed';reason='native-source-unavailable';writes=0}}
    $events=@();$lineNumber=0;$lastUser=$null;$lastUserId='';$lastAssistant='';$lastAssistantText=$null;$unsupported=0
    # The native client can still hold its transcript open for writing at Stop.
    $stream=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $reader=$null
    try {
        $reader=[IO.StreamReader]::new($stream)
        while($null -ne ($line=$reader.ReadLine())){
            $lineNumber++
            if($line.Length -gt 8MB){throw (New-SBError 'cycle.invalid' @('native line size'))}
            try{$entry=$line|ConvertFrom-Json -AsHashtable -ErrorAction Stop}catch{$unsupported++;continue}
            if($entry -isnot [Collections.IDictionary]){$unsupported++;continue}
            $message=$entry
            if($entry.ContainsKey('type') -and $entry.type -eq 'response_item' -and $entry.ContainsKey('payload')){$message=$entry.payload}
            elseif($entry.ContainsKey('message') -and $entry.message -is [Collections.IDictionary]){$message=$entry.message}
            $kind='';$content=$null;$human=$false
            if($message.ContainsKey('channel') -and $message.channel -notin @('final','commentary')){$unsupported++;continue}
            if($message.ContainsKey('role') -and $message.ContainsKey('content')){
                if($message.role -in @('user','assistant')){
                    if($message.content -isnot [string] -and $message.content -isnot [array]){$unsupported++;continue}
                    $blocks=$message.content
                    if($blocks -is [array]){
                        $visible=@($blocks|Where-Object {$_ -is [Collections.IDictionary] -and $_.ContainsKey('type') -and $_.type -in @('text','input_text','output_text','image','input_image','document','tool_use','tool_result')})
                        $unsupported+=$blocks.Count-$visible.Count;$blocks=$visible
                    }
                    $toolResult=@($blocks|Where-Object {$_ -is [Collections.IDictionary] -and $_.ContainsKey('type') -and $_.type -eq 'tool_result'}).Count -gt 0
                    $kind=if($toolResult){'tool-result'}else{[string]$message.role};$content=$blocks;$human=($kind -eq 'user')
                }
            }elseif($message.ContainsKey('type') -and $message.type -in @('function_call','function_call_output')){
                $kind=if($message.type -eq 'function_call'){'tool-request'}else{'tool-result'}
                $content=@{};foreach($field in @('name','arguments','output','call_id')){if($message.ContainsKey($field)){$content[$field]=$message[$field]}}
            }elseif($message.ContainsKey('userMessage') -and $message.userMessage -is [string]){$kind='user';$human=$true;$content=$message.userMessage}
            elseif($message.ContainsKey('assistantMessage') -and $message.assistantMessage -is [string]){$kind='assistant';$content=$message.assistantMessage}
            if(!$kind){$unsupported++;continue}
            if($human){
                $events=@();$lastUser=$content;$lastAssistant='';$lastAssistantText=$null
                $lastUserId=if($entry.ContainsKey('uuid')){[string]$entry.uuid}elseif($entry.ContainsKey('id')){[string]$entry.id}else{''}
            }
            if($null -eq $lastUser){continue}
            $events+=@{id=('native-'+$lineNumber);kind=$kind;content=$content}
            if($kind -eq 'assistant'){
                $lastAssistant=ConvertTo-SBJson $content
                $lastAssistantText=$null
                if($Client -eq 'codex' -and $message.ContainsKey('channel') -and $message.channel -ceq 'final' -and
                   $content -is [array] -and $content.Count -gt 0 -and
                   !@($content|Where-Object {$_.type -cne 'output_text' -or $_['text'] -isnot [string]}).Count){
                    $lastAssistantText=($content.text -join '')
                }
            }
        }
    } finally {
        if($reader){$reader.Dispose()}else{$stream.Dispose()}
    }
    $turn=if($NativeEvent.ContainsKey('turn_id')){[string]$NativeEvent.turn_id}elseif($Client -eq 'claude-code'){$lastUserId}elseif($NativeEvent.ContainsKey('executionNum')){[string]$NativeEvent.executionNum}else{''}
    if(!$turn -or $turn -cne $Permit.turnId -or $null -eq $lastUser -or (Get-SBTextHash (ConvertTo-SBJson $lastUser)) -cne $Permit.lastUserSha256){
        return @{state='suppressed';reason='current-turn-permit-mismatch';writes=0}
    }
    if($NativeEvent.ContainsKey('last_assistant_message') -and $NativeEvent.last_assistant_message){
        $stopReply=$NativeEvent.last_assistant_message
        if($lastAssistant -cne (ConvertTo-SBJson $stopReply) -and
           !($stopReply -is [string] -and $lastAssistantText -ceq $stopReply)){
            $events+=@{id='native-final';kind='assistant';content=$stopReply}
        }
    }
    $envelope=@{schemaVersion=1;repository=$Permit.repository;client=$Client;clientVersion=$Permit.clientVersion;sessionId=$session;turnId=$turn;
        persistence='allowed';policyEvidence=$Permit.policyEvidence;events=$events;coverage='partial';termination='unknown';attachments=@()}
    if($Permit.ContainsKey('attachments')){$envelope.attachments=$Permit.attachments}
    if($NativeEvent.ContainsKey('terminationReason')){$envelope.termination=switch($NativeEvent.terminationReason){'model_stop'{'completed'} 'error'{'error'} default{'interrupted'}}}
    @{state='prepared';envelope=$envelope;unsupportedRecords=$unsupported;coverage='partial'}
}

function ConvertTo-SBCycleTurn($Envelope) {
    if(!(Test-SBCyclePersistence $Envelope)){return @{state='suppressed';reason='persistence-disabled-or-unknown';writes=0}}
    foreach($key in @('schemaVersion','repository','client','clientVersion','sessionId','turnId','events')){
        if(!$Envelope.ContainsKey($key)){throw (New-SBError 'cycle.invalid' @($key))}
    }
    if($Envelope.schemaVersion -ne 1 -or $Envelope.events -isnot [array] -or $Envelope.events.Count -gt 10000){throw (New-SBError 'cycle.invalid' @('schema/events'))}
    Assert-SBCycleIdentifier $Envelope.sessionId; Assert-SBCycleIdentifier $Envelope.turnId
    if($Envelope.clientVersion -isnot [string] -or $Envelope.clientVersion.Length -gt 100 -or (Test-SBCyclePrivate $Envelope.clientVersion)){throw (New-SBError 'cycle.invalid' @('clientVersion'))}
    $adapter=Get-SBCycleAdapter $Envelope.client
    $events=@();$omitted=0;$privateSpan=$false;$privateRequest=$false;$seen=@{};$position=0
    foreach($event in $Envelope.events){
        $position++
        if($event -isnot [Collections.IDictionary]){throw (New-SBError 'cycle.invalid' @('event'))}
        $serialized=ConvertTo-SBJson $event
        $marked=Test-SBCyclePrivate $event
        if($event.ContainsKey('kind') -and $event.kind -ceq 'user'){
            if($marked -or $privateSpan){$privateRequest=$true}else{$privateRequest=$false}
        }
        $private=$privateSpan -or $privateRequest -or $marked
        if($serialized -match '(?is)<\s*(?:private|do[-_]not[-_]memorize)\b' -and $serialized -notmatch '(?is)<\s*/\s*(?:private|do[-_]not[-_]memorize)\s*>'){$privateSpan=$true}
        if($serialized -match '(?is)<\s*/\s*(?:private|do[-_]not[-_]memorize)\s*>'){$privateSpan=$false}
        if($private){$omitted++;continue}
        foreach($key in @('id','kind','content')){if(!$event.ContainsKey($key)){throw (New-SBError 'cycle.invalid' @('event '+$key))}}
        Assert-SBCycleIdentifier $event.id
        if($event.kind -cnotin @('user','assistant','tool-request','tool-result','error','interruption')){throw (New-SBError 'cycle.invalid' @('event kind'))}
        # Only exposed content is retained; unknown fields and hidden reasoning are not imported.
        $row=[ordered]@{id=[string]$event.id;position=$position;kind=[string]$event.kind;content=$event.content}
        foreach($key in @('timestamp','tool','exitCode','requestId')){if($event.ContainsKey($key)){$row[$key]=$event[$key]}}
        $hash=Get-SBTextHash (ConvertTo-SBJson $row)
        if($seen.ContainsKey($event.id)){throw (New-SBError 'cycle.invalid' @('duplicate event id'))}
        $seen[$event.id]=$hash;$events+=,$row
    }
    $turn=[ordered]@{schemaVersion=1;repository=[string]$Envelope.repository;client=[string]$Envelope.client;
      clientVersion=$Envelope.clientVersion;sessionId=[string]$Envelope.sessionId;turnId=[string]$Envelope.turnId;
      policyEvidence=$Envelope.policyEvidence;coverage='partial';omittedPrivateEvents=$omitted;events=$events;attachments=@()}
    if($Envelope.ContainsKey('coverage') -and $Envelope.coverage -ceq 'complete'){$turn.coverage='declared-complete-unverified'}
    if($Envelope.ContainsKey('termination') -and $Envelope.termination -cin @('completed','interrupted','error')){$turn.termination=$Envelope.termination}else{$turn.termination='unknown'}
    @{state='prepared';turn=$turn;adapter=$adapter}
}

function Assert-SBCycleWorkspace([string]$BrainRoot,[string]$Repository,[string]$Workspace) {
    $prefix=Join-Path $BrainRoot ('.runtime/hosts/'+(Get-SBHostId)+'/repos/'+(Get-SBRuntimeRepoSegment $Repository)+'/evidence')
    $full=[IO.Path]::GetFullPath($Workspace)
    if(!$full.StartsWith([IO.Path]::GetFullPath($prefix).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
        throw (New-SBError 'cycle.workspace')
    }
    Assert-SBPlainPath $full
    $m=Read-SBJson (Join-Path $full 'MANIFEST.json') $null
    if(!$m -or $m.category -cne 'evidence' -or $m.repository -cne (Get-SBRuntimeRepoSegment $Repository) -or !$m.ContainsKey('owner') -or
       $m.owner.computer -cne [Environment]::MachineName -or $m.owner.user -cne $env:USERNAME){throw (New-SBError 'cycle.workspace')}
    $full
}

function Get-SBCycleAttachment($Attachment,[string[]]$AllowedAttachmentPaths,[hashtable]$EventIds) {
    if($Attachment -isnot [Collections.IDictionary] -or (Test-SBCyclePrivate $Attachment) -or !$Attachment.ContainsKey('eventId') -or !$EventIds.ContainsKey([string]$Attachment.eventId)){
        return @{state='omitted';persist=$false}
    }
    if(!$Attachment.ContainsKey('path') -or ![IO.Path]::IsPathFullyQualified([string]$Attachment.path)){return @{state='unavailable';eventId=$Attachment.eventId;persist=$true}}
    $path=[IO.Path]::GetFullPath([string]$Attachment.path)
    $allowed=@($AllowedAttachmentPaths|Where-Object {[IO.Path]::IsPathFullyQualified($_) -and (Test-SBSamePath $_ $path)}).Count -gt 0
    # The caller supplies exact allowed files separately; paths in transcript data grant no access.
    if(!$allowed -or (Test-SBCycleCredentialPath $path)){
        return @{state='not-authorized';eventId=$Attachment.eventId;persist=$true}
    }
    Assert-SBPlainPath $path
    if(![IO.File]::Exists($path)){return @{state='unavailable';eventId=$Attachment.eventId;persist=$true}}
    if(([IO.FileInfo]::new($path)).Length -gt 64MB){return @{state='too-large';eventId=$Attachment.eventId;persist=$true}}
    $bytes=[IO.File]::ReadAllBytes($path);$hash=Get-SBHash $bytes
    $extension=[IO.Path]::GetExtension($path).ToLowerInvariant()
    $result=@{state='original-only';persist=$true;eventId=$Attachment.eventId;sha256=$hash;bytes=$bytes;extension=$extension;size=$bytes.Length;method='none';coverage='original-bytes'}
    if($extension -in @('.md','.txt','.json','.csv','.tsv','.log')){
        try{
            $text=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)
            if(Test-SBCyclePrivate $text){return @{state='omitted';persist=$false}}
            $result.text=$text;$result.method='utf8-strict';$result.state='extracted';$result.coverage='text-only'
        }catch [Text.DecoderFallbackException]{}
    }
    $result
}

function Test-SBCycleStoredTurn($Record,[string]$ExpectedHash,[string]$BrainRoot,[string]$EvidenceRoot) {
    if(!$Record -or !$Record.ContainsKey('turn') -or !$Record.ContainsKey('sha256') -or $Record.sha256 -cne $ExpectedHash -or
       (Get-SBTextHash (ConvertTo-SBJson $Record.turn)) -cne $ExpectedHash -or !$Record.ContainsKey('assetLocations') -or $Record.assetLocations -isnot [Collections.IDictionary]){return $false}
    $scope=[IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    foreach($key in $Record.assetLocations.Keys){
        if($key -cnotmatch '^[A-Fa-f0-9]{64}$'){return $false}
        $path=[IO.Path]::GetFullPath((Join-Path $BrainRoot $Record.assetLocations[$key]))
        if(!$path.StartsWith($scope,[StringComparison]::OrdinalIgnoreCase)){return $false}
        Assert-SBPlainPath $path
        if((Get-SBFileHash $path) -cne $key){return $false}
    }
    $true
}

function Save-SBCycleTurn {
    [CmdletBinding()]
    param([string]$BrainRoot,$Envelope,[string]$Workspace,[string]$BackupRoot,[string[]]$AllowedAttachmentPaths=@(),[switch]$Apply)
    $prepared=ConvertTo-SBCycleTurn $Envelope
    if($prepared.state -eq 'suppressed'){return $prepared}
    [void](Resolve-SBCycleDossier $BrainRoot $Envelope.repository)
    $eventIds=@{};foreach($e in $prepared.turn.events){$eventIds[$e.id]=$true}
    $assets=@();$ops=@()
    if($Envelope.ContainsKey('attachments')){
        if($Envelope.attachments -isnot [array]){throw (New-SBError 'cycle.invalid' @('attachments'))}
        foreach($attachment in $Envelope.attachments){
            $asset=Get-SBCycleAttachment $attachment $AllowedAttachmentPaths $eventIds
            if(!$asset.persist){continue}
            $row=@{state=$asset.state;eventId=$asset.eventId}
            if($asset.ContainsKey('bytes')){
                $row.sha256=$asset.sha256;$row.size=$asset.size;$row.extension=$asset.extension;$row.method=$asset.method;$row.coverage=$asset.coverage
                $row.original='assets/'+$asset.sha256.ToLowerInvariant()+'.bin'
                if($asset.ContainsKey('text')){$row.extraction='assets/'+$asset.sha256.ToLowerInvariant()+'.txt'}
                $assets+=,$asset
            }
            $prepared.turn.attachments+=,$row
        }
    }
    $key=(Get-SBTextHash ($Envelope.repository+"`n"+$Envelope.client+"`n"+$Envelope.sessionId+"`n"+$Envelope.turnId)).ToLowerInvariant()
    $hash=Get-SBTextHash (ConvertTo-SBJson $prepared.turn)
    $root=Assert-SBCycleWorkspace $BrainRoot $Envelope.repository $Workspace
    $evidenceRoot=Split-Path $root
    # A retry in a later initialized workspace still identifies the same logical turn.
    foreach($folder in @(Get-ChildItem -LiteralPath $evidenceRoot -Directory)){
        Assert-SBPlainPath $folder.FullName
        $priorPath=Join-Path $folder.FullName ('turns/'+$key+'.json')
        Assert-SBPlainPath $priorPath
        if([IO.File]::Exists($priorPath)){
            $prior=Read-SBJson $priorPath $null
            if(!(Test-SBCycleStoredTurn $prior $hash $BrainRoot $evidenceRoot)){return @{state='conflict';turnId=$Envelope.turnId;path=$priorPath;writes=0}}
            return @{state='duplicate';path=$priorPath;sha256=$hash;writes=0}
        }
    }
    $target=Join-Path $root ('turns/'+$key+'.json')
    if([IO.File]::Exists($target)){
        Assert-SBPlainPath $target
        $prior=Read-SBJson $target $null
        if(!(Test-SBCycleStoredTurn $prior $hash $BrainRoot $evidenceRoot)){return @{state='conflict';turnId=$Envelope.turnId;path=$target;writes=0}}
        return @{state='duplicate';path=$target;sha256=$hash;writes=0}
    }
    $assetLocations=@{}
    foreach($asset in $assets){
        $original=Join-Path $root ('assets/'+$asset.sha256.ToLowerInvariant()+'.bin')
        foreach($folder in @(Get-ChildItem -LiteralPath $evidenceRoot -Directory|Sort-Object Name)){
            Assert-SBPlainPath $folder.FullName
            $existingOriginal=Join-Path $folder.FullName ('assets/'+$asset.sha256.ToLowerInvariant()+'.bin')
            Assert-SBPlainPath $existingOriginal
            if((Get-SBFileHash $existingOriginal) -ceq $asset.sha256){$original=$existingOriginal;break}
        }
        $assetLocations[$asset.sha256]=[IO.Path]::GetRelativePath($BrainRoot,$original).Replace('\','/')
        $existing=Get-SBFileHash $original
        if($existing -eq 'absent'){$ops+=@{path=$original;expected='absent';bytes=$asset.bytes}}
        elseif($existing -cne $asset.sha256){throw (New-SBError 'cycle.conflict' @('original hash'))}
        if($asset.ContainsKey('text')){
            $extract=Join-Path $root ('assets/'+$asset.sha256.ToLowerInvariant()+'.txt')
            if((Get-SBFileHash $extract) -eq 'absent'){$ops+=@{path=$extract;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes($asset.text)}}
        }
    }
    # Multiple events may refer to the same original; one operation per destination.
    $ops=@($ops|Group-Object path|ForEach-Object {$_.Group[0]})
    $record=@{schemaVersion=1;sha256=$hash;capturedAt=[DateTimeOffset]::UtcNow.ToString('o');turn=$prepared.turn;assetLocations=$assetLocations}
    $ops+=@{path=$target;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $record))}
    $turnIndex=Join-Path $root 'turns-index.json';Assert-SBPlainPath $turnIndex
    $metadata=Read-SBJson $turnIndex @{schemaVersion=1;repository=$Envelope.repository;turns=@()}
    if($metadata.schemaVersion -ne 1 -or $metadata.repository -cne $Envelope.repository -or $metadata.turns -isnot [array]){throw (New-SBError 'cycle.invalid' @('turn index'))}
    $metadata.turns+=@{id=$key;sha256=$hash;capturedAt=$record.capturedAt;client=$Envelope.client;sessionId=$Envelope.sessionId;turnId=$Envelope.turnId;events=$prepared.turn.events.Count;coverage=$prepared.turn.coverage;path=('turns/'+$key+'.json')}
    $ops+=@{path=$turnIndex;expected=(Get-SBFileHash $turnIndex);bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $metadata))}
    if($Apply){[void](Invoke-SBParaTransaction $ops $BackupRoot $BrainRoot)}
    @{state=$(if($Apply){'captured'}else{'preview'});path=$target;sha256=$hash;events=$prepared.turn.events.Count;omittedPrivateEvents=$prepared.turn.omittedPrivateEvents;coverage=$prepared.turn.coverage;operations=$ops.Count;writes=$(if($Apply){$ops.Count}else{0})}
}

function Get-SBCycleKnowledgeIndex([string]$BrainRoot,[string]$Repository) {
    $dir=Resolve-SBCycleDossier $BrainRoot $Repository
    $cached=@{};$indexPath=Join-Path $dir 'knowledge-index.json';Assert-SBPlainPath $indexPath
    try{
        $manifest=Read-SBJson $indexPath $null
        if($manifest -and $manifest.repository -ceq $Repository){
            foreach($shard in @($manifest.shards)){
                if($shard.path -cnotmatch '^knowledge-index/[a-f0-9]{64}\.json$'){continue}
                $shardPath=Join-Path $dir $shard.path;Assert-SBPlainPath $shardPath
                if((Get-SBFileHash $shardPath) -cne $shard.sha256){continue}
                $data=Read-SBJson $shardPath $null
                if($data.repository -ceq $Repository){foreach($entry in @($data.entries)){$cached[$entry.path]=$entry}}
            }
        }
    }catch{$cached=@{}}
    $files=@(foreach($name in @('context.md','memory.md','tracker.json')){if([IO.File]::Exists((Join-Path $dir $name))){Get-Item -LiteralPath (Join-Path $dir $name)}})
    foreach($name in @('topics','knowledge','history')){
        $folder=Join-Path $dir $name
        if([IO.Directory]::Exists($folder)){
            Assert-SBPlainPath $folder
            $files+=@(Get-ChildItem -LiteralPath $folder -Recurse -File -Filter '*.md'|Where-Object {$_.FullName -notmatch '[\\/](?:compaction|memcycle-sources)[\\/]'})
        }
    }
    $entries=@()
    foreach($file in $files){
        Assert-SBPlainPath $file.FullName
        $relative=[IO.Path]::GetRelativePath($dir,$file.FullName).Replace('\','/')
        $bytes=[IO.File]::ReadAllBytes($file.FullName);$sourceHash=Get-SBHash $bytes
        if($cached.ContainsKey($relative) -and $cached[$relative].sha256 -ceq $sourceHash){$entries+=,$cached[$relative];continue}
        $text=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)
        if(Test-SBCyclePrivate $text){continue}
        $parts=$relative -split '/';$topic='essential'
        if($parts.Count -gt 1){
            $label=[IO.Path]::GetFileNameWithoutExtension($parts[1])
            if($parts[0] -eq 'history'){$label=$label -replace '^\d{4}-?\d{2}-?\d{2}[-_]?','';if(!$label){$label=$parts[1]}}
            $topic=$parts[0]+'/'+$label
        }
        $entries+=@{id=(Get-SBTextHash ($Repository+':'+$relative)).ToLowerInvariant();path=$relative;sha256=$sourceHash;characters=$text.Length;bytes=$bytes.Length;
            tier=$(if($relative.StartsWith('history/')){'history'}elseif($relative.StartsWith('topics/') -or $relative.StartsWith('knowledge/')){'topic'}else{'essential'});
            topic=$topic;state='source';headings=@([regex]::Matches($text,'(?m)^#{1,3} (.+)$')|ForEach-Object {$_.Groups[1].Value.Trim()});
            links=@([regex]::Matches($text,'\[[^\]]*\]\(([^)]+)\)')|ForEach-Object {$_.Groups[1].Value}|Sort-Object -Unique);
            decisions=@([regex]::Matches($text,'<!-- sb:decision id=([^ ]+) state=([^ ]+)(?: [^>]+)? -->')|ForEach-Object {@{id=$_.Groups[1].Value;state=$_.Groups[2].Value;supersedes=[regex]::Match($_.Value,' supersedes=([^ ]+)').Groups[1].Value;supersededBy=[regex]::Match($_.Value,' supersededBy=([^ ]+)').Groups[1].Value}})}
    }
    @{schemaVersion=1;repository=$Repository;entries=@($entries|Sort-Object path);revision=(Get-SBTextHash (ConvertTo-SBJson @($entries|Sort-Object path)))}
}

function Save-SBCycleKnowledgeIndex([string]$BrainRoot,[string]$Repository,[string]$BackupRoot,[switch]$Apply) {
    $dir=Resolve-SBCycleDossier $BrainRoot $Repository;$index=Get-SBCycleKnowledgeIndex $BrainRoot $Repository
    $ops=@();$paths=@()
    foreach($topic in @($index.entries|Group-Object topic)){
        $relative='knowledge-index/'+(Get-SBTextHash $topic.Name).ToLowerInvariant()+'.json';$path=Join-Path $dir $relative
        $value=@{schemaVersion=1;repository=$Repository;topic=$topic.Name;entries=@($topic.Group)}
        $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $value));$before=Get-SBFileHash $path
        if($before -cne (Get-SBHash $bytes)){$ops+=@{path=$path;expected=$before;bytes=$bytes}}
        $paths+=@{topic=$topic.Name;path=$relative;sha256=(Get-SBHash $bytes);count=$topic.Count}
    }
    $manifest=@{schemaVersion=1;repository=$Repository;revision=$index.revision;shards=$paths}
    $manifestPath=Join-Path $dir 'knowledge-index.json';$bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $manifest));$before=Get-SBFileHash $manifestPath
    if($before -cne (Get-SBHash $bytes)){$ops+=@{path=$manifestPath;expected=$before;bytes=$bytes}}
    if($Apply -and $ops.Count){[void](Invoke-SBParaTransaction $ops $BackupRoot $BrainRoot)}
    @{repository=$Repository;revision=$index.revision;entries=$index.entries.Count;operations=$ops.Count;applied=[bool]($Apply -and $ops.Count)}
}

function Get-SBCycleContext([string]$BrainRoot,[string]$Repository,[string[]]$TaskIds=@(),[string]$PreviousRevision,[int]$Budget=30000) {
    $dir=Resolve-SBCycleDossier $BrainRoot $Repository
    $index=Get-SBCycleKnowledgeIndex $BrainRoot $Repository
    $revision=Get-SBTextHash ($index.revision+':'+(ConvertTo-SBJson @($TaskIds))+':'+$Budget)
    $warnings=@();$indexPath=Join-Path $dir 'knowledge-index.json';Assert-SBPlainPath $indexPath;$persisted=Read-SBJson $indexPath $null
    if(!$persisted){$warnings+='index-missing'}elseif($persisted.repository -cne $Repository -or $persisted.revision -cne $index.revision){$warnings+='index-stale'}
    $evidence=Join-Path $BrainRoot ('.runtime/hosts/'+(Get-SBHostId)+'/repos/'+(Get-SBRuntimeRepoSegment $Repository)+'/evidence')
    $pending=0
    if([IO.Directory]::Exists($evidence)){
        Assert-SBPlainPath $evidence
        foreach($folder in Get-ChildItem -LiteralPath $evidence -Directory){
            $proposals=Join-Path $folder.FullName 'proposals';Assert-SBPlainPath $proposals
            if([IO.Directory]::Exists($proposals)){$pending+=@(Get-ChildItem -LiteralPath $proposals -File -Filter '*.json').Count}
        }
    }
    if($pending){$warnings+='proposals-pending'}
    if($PreviousRevision -and $PreviousRevision -ceq $revision){return @{repository=$Repository;revision=$revision;sourceRevision=$index.revision;changed=$false;parts=@{};characters=0;warnings=$warnings;pendingProposals=$pending}}
    $startup=Get-SBStartupContext -BrainRoot $BrainRoot -Dossier $dir -Profile Slim -Budget $Budget -TaskIds $TaskIds
    @{repository=$Repository;revision=$revision;sourceRevision=$index.revision;changed=$true;startup=$startup;advice=(Get-SBCompactionAdvice $startup $BrainRoot $dir);warnings=$warnings;pendingProposals=$pending;indexPersisted=([IO.File]::Exists((Join-Path $dir 'knowledge-index.json')))}
}

function Invoke-SBCyclePromotion {
    [CmdletBinding()]
    param([string]$BrainRoot,$Candidate,[string]$Workspace,[string]$BackupRoot,[switch]$Apply)
    if(!(Test-SBCyclePersistence $Candidate)){return @{state='suppressed';writes=0}}
    if(Test-SBCyclePrivate $Candidate){return @{state='suppressed';reason='private';writes=0}}
    foreach($key in @('schemaVersion','repository','capturePath','captureSha256','sources','changes')){if(!$Candidate.ContainsKey($key)){throw (New-SBError 'cycle.invalid' @($key))}}
    if($Candidate.schemaVersion -ne 1 -or $Candidate.changes -isnot [array]){throw (New-SBError 'cycle.invalid' @('candidate'))}
    $dir=Resolve-SBCycleDossier $BrainRoot $Candidate.repository
    $root=Assert-SBCycleWorkspace $BrainRoot $Candidate.repository $Workspace
    $capture=[IO.Path]::GetFullPath($Candidate.capturePath)
    if(!$capture.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'cycle.invalid' @('capture scope'))}
    Assert-SBPlainPath $capture
    if((Get-SBFileHash $capture) -cne $Candidate.captureSha256){throw (New-SBError 'cycle.invalid' @('capture hash'))}
    $record=Read-SBJson $capture $null
    if(!$record -or $record.turn.repository -cne $Candidate.repository -or (Get-SBTextHash (ConvertTo-SBJson $record.turn)) -cne $record.sha256){throw (New-SBError 'cycle.invalid' @('capture identity'))}
    $key=(Get-SBTextHash (ConvertTo-SBJson $Candidate)).ToLowerInvariant();$receipt=Join-Path $root ('promotions/'+$key+'.json')
    if([IO.File]::Exists($receipt)){
        $priorReceipt=Read-SBJson $receipt $null
        if(!$priorReceipt -or $priorReceipt.repository -cne $Candidate.repository -or $priorReceipt.candidateSha256 -cne $key){throw (New-SBError 'cycle.invalid' @('promotion receipt'))}
        if($Apply){[void](Save-SBCycleKnowledgeIndex $BrainRoot $Candidate.repository $BackupRoot -Apply)}
        return @{state='duplicate';receipt=$receipt;writes=0}
    }
    $eventIds=@($record.turn.events|ForEach-Object id);$reasons=@();$planned=@{};$taskChanges=@()
    $sourceLink=[IO.Path]::GetRelativePath($dir,$capture).Replace('\','/')
    foreach($change in $Candidate.changes){
        if($change -isnot [Collections.IDictionary] -or !$change.ContainsKey('kind')){throw (New-SBError 'cycle.invalid' @('change'))}
        if(!$change.ContainsKey('verified') -or $change.verified -ne $true -or ($change.ContainsKey('ambiguous') -and $change.ambiguous)){$reasons+='unverified-or-ambiguous';continue}
        if(!$change.ContainsKey('eventIds') -or !@($change.eventIds).Count -or @($change.eventIds|Where-Object {$_ -notin $eventIds}).Count){$reasons+='missing-event-evidence';continue}
        switch($change.kind){
            'context' {
                if(!$change.ContainsKey('text')){throw (New-SBError 'cycle.invalid' @('context text'))}
                if(@(Get-SBMissingContextSection $change.text).Count){$reasons+='essential-section'}
                $planned['context.md']=([string]$change.text).TrimEnd()+"`n`nFonte: [registro del turno]("+$sourceLink+'); eventi '+($change.eventIds -join ', ')+"`n"
            }
            'decision' {
                foreach($field in @('id','text','reason')){if(!$change.ContainsKey($field) -or !$change[$field]){throw (New-SBError 'cycle.invalid' @('decision '+$field))}}
                Assert-SBCycleIdentifier $change.id
                $memory=if($planned.ContainsKey('memory.md')){$planned['memory.md']}else{Read-SBText (Join-Path $dir 'memory.md')}
                if($memory -match ('<!-- sb:decision id='+[regex]::Escape($change.id)+' ')){$reasons+='decision-id-exists';continue}
                $supersedes=''
                if($change.ContainsKey('supersedes') -and $change.supersedes){
                    Assert-SBCycleIdentifier $change.supersedes
                    $pattern='(<!-- sb:decision id='+[regex]::Escape($change.supersedes)+' state=)active((?: [^>]+)? -->)'
                    if($memory -notmatch $pattern){$reasons+='superseded-decision-missing';continue}
                    $memory=[regex]::Replace($memory,$pattern,('${1}superseded supersededBy='+$change.id+'${2}'));$supersedes=' supersedes='+$change.supersedes
                }
                $memory+="`n## Decisione "+$change.id+"`n<!-- sb:decision id="+$change.id+' state=active'+$supersedes+" -->`n- Decisione: "+$change.text+' — Motivo: '+$change.reason+"`nFonte: [registro del turno]("+$sourceLink+'); eventi '+($change.eventIds -join ', ')+"`n"
                $planned['memory.md']=$memory
            }
            'topic' {
                if(!$change.ContainsKey('path') -or $change.path -cnotmatch '^topics/[A-Za-z0-9][A-Za-z0-9_-]{0,80}\.md$' -or !$change.ContainsKey('text')){throw (New-SBError 'cycle.invalid' @('topic'))}
                $planned[$change.path]=([string]$change.text).TrimEnd()+"`n`nFonte: [registro del turno]("+[IO.Path]::GetRelativePath((Join-Path $dir 'topics'),$capture).Replace('\','/')+'); eventi '+($change.eventIds -join ', ')+"`n"
            }
            'task' {$taskChanges+=,$change}
            default {throw (New-SBError 'cycle.invalid' @('change kind'))}
        }
    }
    foreach($relative in @($planned.Keys)+$(if($taskChanges.Count){@('tracker.json')}else{@()})){
        $path=Join-Path $dir $relative
        if(!$Candidate.sources.ContainsKey($relative) -or $Candidate.sources[$relative] -cne (Get-SBFileHash $path)){$reasons+='source-changed:'+ $relative}
    }
    if($reasons.Count){
        $proposal=Join-Path $root ('proposals/'+$key+'.json')
        # Unresolved event evidence may refer to private omissions: do not persist that candidate.
        if($Apply -and 'missing-event-evidence' -notin $reasons -and (Get-SBFileHash $proposal) -eq 'absent'){
            [void](Write-SBFile $proposal ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson @{candidate=$Candidate;reasons=$reasons}))) 'absent' $BackupRoot)
        }
        return @{state='proposal';reasons=$reasons;path=$proposal;applied=$false}
    }
    $ops=@()
    foreach($relative in $planned.Keys){
        $path=Join-Path $dir $relative;$before=[string]$Candidate.sources[$relative]
        if((Get-SBFileHash $path) -cne $before){throw (New-SBError 'cycle.conflict' @('source changed during planning'))}
        if($before -ne 'absent'){
            $archive=Join-Path $dir ('history/memcycle-sources/'+$before.ToLowerInvariant()+'/'+$relative)
            $archived=Get-SBFileHash $archive
            if($archived -eq 'absent'){
                $originalBytes=[IO.File]::ReadAllBytes($path)
                if((Get-SBHash $originalBytes) -cne $before){throw (New-SBError 'cycle.conflict' @('source snapshot'))}
                $ops+=@{path=$archive;expected='absent';bytes=$originalBytes}
            }elseif($archived -cne $before){throw (New-SBError 'cycle.conflict' @('source archive'))}
        }
        $ops+=@{path=$path;expected=$before;bytes=[Text.Encoding]::UTF8.GetBytes($planned[$relative])}
    }
    if($planned.ContainsKey('memory.md')){
        $view=Join-Path $dir 'memory.agent.md';$ops+=@{path=$view;expected=(Get-SBFileHash $view);bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBAgentMemoryView $planned['memory.md']))}
    }
    $ops+=@{path=$receipt;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson @{schemaVersion=1;repository=$Candidate.repository;candidateSha256=$key;captureSha256=$Candidate.captureSha256;candidate=$Candidate;appliedAt=[DateTimeOffset]::UtcNow.ToString('o')}))}
    if($taskChanges.Count){
        # Reuse tracker validation and terminal-task archiving in the SAME transaction as memories.
        & (Get-Module SecondBrain.Tracker) {
            param($brain,$repository,$changes,$extra,$backups,$apply,$expected)
            $target=Resolve-SBTrackerWriteTarget $brain $repository
            if($target.hash -cne $expected){throw (New-SBError 'cycle.conflict' @('tracker revision'))}
            $archive=Read-SBTrackerArchive $target.path $target.identity
            foreach($change in $changes){
                $task=Get-SBTrackerTaskForUpdate $target $archive $change.id
                if($change.status -cnotin @('todo','in_progress','blocked','done','cancelled')){throw (New-SBError 'cycle.invalid' @('task status'))}
                if($change.status -eq 'done'){
                    if(!$change.ContainsKey('verifiedAcceptance') -or (ConvertTo-SBJson @($change.verifiedAcceptance)) -cne (ConvertTo-SBJson @($task.acceptance))){throw (New-SBError 'cycle.invalid' @('task acceptance evidence'))}
                    $target.data.extensions.lastClosure=@{taskId=$task.id;closedAt=[DateTimeOffset]::UtcNow.ToString('o')}
                }
                $task.status=$change.status
                $task.evidence+=@{reference=$change.evidenceReference;outcome='passed'}
            }
            [void](Save-SBTrackerData $target $target.data $backups -WhatIf:(!$apply) -Archive $archive -ExtraOperations $extra)
        } $BrainRoot $Candidate.repository $taskChanges $ops $BackupRoot ([bool]$Apply) $Candidate.sources['tracker.json']
    }elseif($Apply){[void](Invoke-SBParaTransaction $ops $BackupRoot $BrainRoot)}
    if($Apply){[void](Save-SBCycleKnowledgeIndex $BrainRoot $Candidate.repository $BackupRoot -Apply)}
    @{state=$(if($Apply){'applied'}else{'preview'});receipt=$receipt;operations=$ops.Count;applied=[bool]$Apply}
}

Export-ModuleMember -Function @('Test-SBCyclePersistence','Resolve-SBCycleDossier','Assert-SBCycleWorkspace','Get-SBCycleAdapter','ConvertFrom-SBCycleNativeTurn','ConvertTo-SBCycleTurn','Save-SBCycleTurn','Get-SBCycleKnowledgeIndex','Save-SBCycleKnowledgeIndex','Get-SBCycleContext','Invoke-SBCyclePromotion')
