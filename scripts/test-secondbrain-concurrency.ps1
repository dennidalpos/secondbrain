#requires -Version 7.5
# Concurrent writes (Write-SBFile, tracker -NewTask, trace, access queue, PARA transactions, backups) and edge cases
# (paths beyond 260 characters, Unicode, case differences, locked files). Fixtures under Get-SBTestRoot; no writes to the real .runtime.
# Fixtures are always retained; results (duration, size, fixture status) remain in this run's esito-concurrency.json.
$ErrorActionPreference='Stop'
foreach($module in @('Core','Access','Host','Para','Tracker','Trace')){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$module+'.psm1')) -Force}
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:checks=0
$script:cases=[Collections.Generic.List[object]]::new()
function Assert-Conc($Condition,[string]$Message,[string]$Detail=''){if(!$Condition){throw ('FAIL CONCURRENCY: '+$Message+$(if($Detail){' ['+$Detail+']'}else{''}))};$script:checks++;'PASS CONCURRENCY: '+$Message}
function Get-FixtureSize([string]$Path){
    $bytes=0L;$files=0
    if(Test-Path -LiteralPath $Path -PathType Container){foreach($file in ([IO.DirectoryInfo]::new($Path)).EnumerateFiles('*',[IO.SearchOption]::AllDirectories)){$bytes+=$file.Length;$files++}}
    @{files=$files;bytes=$bytes}
}
function Invoke-Case([string]$Name,[string]$Folder,[scriptblock]$Body){
    $watch=[Diagnostics.Stopwatch]::StartNew();$before=$script:checks;$status='passed';$problem=$null
    try{& $Body}catch{$status='failed';$problem=$_.Exception.Message;throw}
    finally{
        $watch.Stop();$size=Get-FixtureSize $Folder
        $script:cases.Add([ordered]@{name=$Name;status=$status;durationMs=[int]$watch.ElapsedMilliseconds;checks=($script:checks-$before);fixtureFiles=$size.files;fixtureBytes=$size.bytes;error=$problem})
    }
}
# Stable exception code (Data['code']), including inner exceptions.
function Get-ErrorCode($Exception){while($null -ne $Exception){if($Exception.Data.Contains('code')){return [string]$Exception.Data['code']};$Exception=$Exception.InnerException};$null}
# Launch $Count workers in separate threads, start them together (barrier), then return results sorted by index.
function Invoke-Race([int]$Count,[scriptblock]$Work,[object[]]$Arguments=@()){
    $gate=[Threading.ManualResetEventSlim]::new($false);$ready=[Threading.CountdownEvent]::new($Count)
    $modules=@('Core','Access','Host','Para','Tracker','Trace')|ForEach-Object {Join-Path $PSScriptRoot ('SecondBrain.'+$_+'.psm1')}
    $runner={
        param($Index,$Gate,$Ready,$Modules,$WorkText,$WorkArguments)
        $ErrorActionPreference='Stop'
        foreach($module in $Modules){Import-Module $module}
        $Ready.Signal()|Out-Null;$Gate.Wait()
        try{@{index=$Index;ok=$true;value=(& ([scriptblock]::Create($WorkText)) $Index $WorkArguments)}}
        catch{
            $exception=$_.Exception;$code=$null
            while($null -ne $exception){if($exception.Data.Contains('code')){$code=[string]$exception.Data['code'];break};$exception=$exception.InnerException}
            @{index=$Index;ok=$false;code=$code;type=$_.Exception.GetType().Name;message=$_.Exception.Message}
        }
    }
    $jobs=@(1..$Count|ForEach-Object {Start-ThreadJob -ThrottleLimit $Count -ScriptBlock $runner -ArgumentList $_,$gate,$ready,$modules,$Work.ToString(),$Arguments})
    try{
        if(!$ready.Wait(120000)){throw 'FAIL CONCURRENCY: i worker non sono pronti entro 120 s'}
        $gate.Set()
        $null=$jobs|Wait-Job -Timeout 300
        @($jobs|ForEach-Object {if($_.State -ne 'Completed'){@{index=0;ok=$false;code=$null;type='JobState';message=('job '+$_.State)}}else{Receive-Job $_}}|Sort-Object {$_.index})
    }finally{$jobs|Remove-Job -Force -ErrorAction SilentlyContinue;$gate.Dispose();$ready.Dispose()}
}
$testRoot=Get-SBTestRoot
$root=Join-Path $testRoot ('secondbrain-concurrency-'+[guid]::NewGuid().ToString('N').Substring(0,12))
$esitoDirectory=if($env:SECONDBRAIN_TEST_RUN_CONTEXT){$testRoot}else{[IO.Directory]::CreateDirectory($root).FullName}
$esitoPath=Join-Path $esitoDirectory 'esito-concurrency.json'
$suiteWatch=[Diagnostics.Stopwatch]::StartNew();$suiteStatus='failed';$removed=$false
try {
    [IO.Directory]::CreateDirectory($root)|Out-Null
    . (Join-Path $PSScriptRoot 'test-write-denied.ps1')

    Invoke-Case 'write-file' (Join-Path $root 'write') {
        $dir=Join-Path $root 'write';$backups=Join-Path $dir 'backups';[IO.Directory]::CreateDirectory($dir)|Out-Null
        # Existing file: 2 writers with the same expected hash; no mixed content and recoverable original.
        $target=Join-Path $dir 'condiviso.md';[IO.File]::WriteAllText($target,"originale`n")
        $original=Get-SBFileHash $target
        $outcomes=Invoke-Race 2 {param($i,$a) $payload=[Text.Encoding]::UTF8.GetBytes("scrittore-$i`n");Write-SBFile $a[0] $payload $a[1] $a[2]} @($target,$original,$backups)
        $wins=@($outcomes|Where-Object {$_.ok -and $_.value -eq $true});$allowed=@('core.concurrent.modified','core.write.contended','core.race.kept','core.backup.unverified','core.readback.destination')
        $final=[IO.File]::ReadAllText($target)
        Assert-Conc ($wins.Count -le 1) ('Write-SBFile su file esistente: al piu un vincitore ('+$wins.Count+' su 2)')
        Assert-Conc (@($outcomes|Where-Object {!$_.ok -and $_.code -notin $allowed}).Count -eq 0) 'Write-SBFile: i perdenti falliscono con un codice stabile noto' (@($outcomes|Where-Object {!$_.ok}|ForEach-Object {[string]$_.code+':'+$_.type+':'+$_.message}) -join ' | ')
        Assert-Conc (@(1..2|Where-Object {$final -ceq "scrittore-$_`n"}).Count -eq 1 -or $final -ceq "originale`n") 'Write-SBFile: il contenuto finale e esattamente quello di un solo scrittore (o l originale)'
        # Losing writers intentionally retain staging ("Staging transazionale conservato" warning), but each .tmp must have an interrupted .stage record describing it.
        $interrupted=@(Get-ChildItem -LiteralPath $backups -File -Filter '*.stage'|ForEach-Object {Read-SBJson $_.FullName $null}|Where-Object {$_.status -eq 'interrupted'}|ForEach-Object staging)
        $kept=@(Get-ChildItem -LiteralPath $dir -Force -Filter '.secondbrain-*.tmp'|ForEach-Object FullName)
        Assert-Conc (@($kept|Where-Object {$_ -notin $interrupted}).Count -eq 0) ('Write-SBFile: gli staging conservati ('+$kept.Count+') hanno tutti un record .stage interrotto; nessuno staging orfano')
        if($final -cne "originale`n"){
            $recoverable=@(Get-ChildItem -LiteralPath $backups -File -Filter '*.bin' -ErrorAction SilentlyContinue|Where-Object {(Get-SBFileHash $_.FullName) -eq $original}).Count+@(Get-ChildItem -LiteralPath $dir -Force -Filter '.secondbrain-*.recovery'|Where-Object {(Get-SBFileHash $_.FullName) -eq $original}).Count
            Assert-Conc ($recoverable -ge 1) 'Write-SBFile: il contenuto originale resta recuperabile (backup .bin o .recovery)'
        }
        # Absent file: only one writer can create it.
        $fresh=Join-Path $dir 'nuovo.md'
        $created=Invoke-Race 2 {param($i,$a) Write-SBFile $a[0] ([Text.Encoding]::UTF8.GetBytes("nuovo-$i`n")) 'absent' $a[1]} @($fresh,$backups)
        $creators=@($created|Where-Object {$_.ok -and $_.value -eq $true})
        Assert-Conc ($creators.Count -eq 1 -and [IO.File]::ReadAllText($fresh) -ceq ("nuovo-"+$creators[0].index+"`n")) 'Write-SBFile su file assente: esattamente un creatore e contenuto suo'
        $interruptedFresh=@(Get-ChildItem -LiteralPath $backups -File -Filter '*.stage'|ForEach-Object {Read-SBJson $_.FullName $null}|Where-Object {$_.status -eq 'interrupted'}|ForEach-Object staging)
        Assert-Conc (@(Get-ChildItem -LiteralPath $dir -Force -Filter '.secondbrain-*.tmp'|Where-Object {$_.FullName -notin $interruptedFresh}).Count -eq 0) 'Write-SBFile su file assente: nessuno staging orfano (i perdenti lasciano il record .stage interrotto)'
    }

    Invoke-Case 'git-backed-write' (Join-Path $root 'git-backed') {
        $repo=Join-Path $root 'git-backed'
        $backupRoot=Join-Path $repo 'backups'
        $target=Join-Path $repo 'tracked.txt'
        [IO.Directory]::CreateDirectory($repo)|Out-Null
        $null=& git -C $repo init -q
        Assert-Conc ($LASTEXITCODE -eq 0) 'repository Git sintetico inizializzato'
        [IO.File]::WriteAllText($target,'tracked original')
        $hidden=Join-Path $repo 'hidden.txt'
        $crlf=Join-Path $repo 'crlf.txt'
        [IO.File]::WriteAllText($hidden,'committed version')
        [IO.File]::WriteAllText((Join-Path $repo '.gitattributes'),"crlf.txt text eol=crlf`n")
        [IO.File]::WriteAllText($crlf,"line one`r`nline two`r`n")
        $null=& git -C $repo add -- tracked.txt hidden.txt crlf.txt .gitattributes
        $null=& git -C $repo -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'fixture'
        Assert-Conc ($LASTEXITCODE -eq 0) 'originale registrato in Git'
        $originalHash=Get-SBFileHash $target
        $newBytes=[Text.Encoding]::UTF8.GetBytes('updated content')
        $null=Write-SBFile $target $newBytes $originalHash $backupRoot
        $gitRecord=Get-ChildItem -LiteralPath $backupRoot -Filter '*.git.json' | ForEach-Object {Read-SBJson $_.FullName $null}
        $originalText=& git -C $repo cat-file blob $gitRecord.gitBlob
        Assert-Conc ($gitRecord.previousHash -eq $originalHash -and (Get-SBTextHash $originalText) -eq $originalHash -and !(Get-ChildItem -LiteralPath $backupRoot -Filter '*.bin')) 'originale pulito recuperabile dal blob senza copia binaria'
        $dirtyRejected=$false
        try{Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('new content')) (Get-SBFileHash $target) $backupRoot -Recoverable|Out-Null}
        catch{$dirtyRejected=(Get-ErrorCode $_.Exception) -eq 'core.tracked.dirty'}
        Assert-Conc ($dirtyRejected -and (Get-SBFileHash $target) -eq (Get-SBHash $newBytes)) 'la rigenerabilita non aggira la protezione dei file tracciati sporchi'
        $null=Write-SBFile $crlf $newBytes (Get-SBFileHash $crlf) $backupRoot
        Assert-Conc (!(Get-ChildItem -LiteralPath $backupRoot -Filter '*.bin')) 'Git riproduce anche le terminazioni CRLF della copia di lavoro'
        $null=& git -C $repo update-index --assume-unchanged -- hidden.txt
        [IO.File]::WriteAllText($hidden,'local bytes hidden from status')
        $hiddenHash=Get-SBFileHash $hidden
        $null=Write-SBFile $hidden $newBytes $hiddenHash $backupRoot
        $binaryBackup=Get-ChildItem -LiteralPath $backupRoot -Filter '*.bin'
        Assert-Conc (@($binaryBackup).Count -eq 1 -and (Get-SBFileHash $binaryBackup.FullName) -eq $hiddenHash) 'un file apparentemente pulito conserva il backup se Git non riproduce i byte locali'
    }

    Invoke-Case 'trace' (Join-Path $root 'trace') {
        $brain=Join-Path $root 'trace/brain';$checkout=Join-Path $root 'trace/work/repo-a'
        foreach($dir in @($brain,$checkout)){[IO.Directory]::CreateDirectory($dir)|Out-Null}
        $hostDir=Join-Path $brain ('.runtime/hosts/'+(Get-SBHostId));[IO.Directory]::CreateDirectory($hostDir)|Out-Null
        [IO.File]::WriteAllText((Join-Path $hostDir 'workstation.json'),(ConvertTo-SBJson @{schemaVersion=1;bindings=@(@{identity='github.com/acme/repo-a';path=$checkout})}))
        $outcomes=Invoke-Race 6 {param($i,$a) 1..15|ForEach-Object {[void](Add-SBTraceEvent $a[0] 'stop' (ConvertTo-Json -Compress @{persistence='allowed';policyEvidence='synthetic race';session_id=("sess-$i");cwd=$a[1]}))}} @($brain,$checkout)
        $files=@(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime/trace') -Recurse -File -Filter '*.jsonl')
        $rows=@($files|ForEach-Object {[IO.File]::ReadAllLines($_.FullName)})
        $parsed=@($rows|ForEach-Object {try{$_|ConvertFrom-Json -AsHashtable}catch{$null}})
        Assert-Conc (@($outcomes|Where-Object {!$_.ok}).Count -eq 0) 'traccia: nessun worker fallisce con 6 scrittori'
        Assert-Conc ($rows.Count -eq 90 -and @($parsed|Where-Object {$null -eq $_}).Count -eq 0) 'traccia: 90 eventi, 90 righe JSON valide (nessuna riga persa, troncata o mista)' ('righe='+$rows.Count+' valide='+@($parsed|Where-Object {$null -ne $_}).Count)
        Assert-Conc ((Get-SBTraceTurns $brain 'github.com/acme/repo-a') -eq 90 -and @(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime/trace') -Recurse -File -Filter '*.jsonl').Count -eq 1) 'traccia: un solo file per giorno e il file di lock non e conteggiato come traccia'
        Assert-Conc (@(1..6|Where-Object {$n=$_;@($parsed|Where-Object {$_.sessionId -eq "sess-$n"}).Count -eq 15}).Count -eq 6) 'traccia: 15 eventi per ciascun scrittore'
    }

    Invoke-Case 'access-queue' (Join-Path $root 'access') {
        $access=Join-Path $root 'access';$coordination=Join-Path $access 'coordination';$counter=Join-Path $access 'counter.txt';$marker=Join-Path $access 'inside.marker'
        [IO.Directory]::CreateDirectory($coordination)|Out-Null;[IO.File]::WriteAllText($counter,'0')
        $config=@{brainRoot=$access;coordinationRoot=$coordination;workstationId='fixture';sessionTimeoutMinutes=30;lockWaitMs=60000}
        # Writer-lock-protected critical section: non-atomic increment plus CreateNew marker; any overlap is visible.
        $outcomes=Invoke-Race 6 {
            param($i,$a)
            $lock=Enter-SBOperation $a[0] $null -LockOnly
            try{
                $stream=[IO.File]::Open($a[2],[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try{
                    $value=[int][IO.File]::ReadAllText($a[1]);Start-Sleep -Milliseconds 40;[IO.File]::WriteAllText($a[1],[string]($value+1))
                }finally{$stream.Dispose();[IO.File]::Delete($a[2])}
            }finally{Exit-SBOperation $lock}
        } @($config,$counter,$marker)
        Assert-Conc (@($outcomes|Where-Object {!$_.ok}).Count -eq 0) 'coda di accesso: tutti i worker entrano a turno' (@($outcomes|Where-Object {!$_.ok}|ForEach-Object message) -join '; ')
        Assert-Conc ([IO.File]::ReadAllText($counter) -eq '6' -and !(Test-Path -LiteralPath $marker)) 'coda di accesso: mutua esclusione, 6 incrementi senza perdite ne sovrapposizioni'
        $held=Enter-SBOperation $config $null -LockOnly
        try{
            $busy=@(Invoke-Race 1 {param($i,$a) Enter-SBOperation $a[0] $null -WaitMs 300 -LockOnly|Out-Null} @($config))
        }finally{Exit-SBOperation $held}
        Assert-Conc (!$busy[0].ok -and $busy[0].code -eq 'access.busy') 'coda di accesso: con il lock occupato l attesa scade con il codice access.busy' ([string]$busy[0].code+':'+$busy[0].type)
    }

    Invoke-Case 'para-transaction' (Join-Path $root 'para') {
        $brain=Join-Path $root 'para/brain';$backups=Join-Path $root 'para/backups';$target=Join-Path $brain '02-areas/doc.md'
        foreach($dir in @((Join-Path $brain '.runtime'),(Split-Path $target),$backups)){[IO.Directory]::CreateDirectory($dir)|Out-Null}
        [IO.File]::WriteAllText($target,"base`n");$original=Get-SBFileHash $target
        $outcomes=Invoke-Race 6 {param($i,$a) Invoke-SBParaTransaction -Operations @(@{path=$a[0];expected=$a[1];bytes=[Text.Encoding]::UTF8.GetBytes("transazione-$i`n")}) -BackupRoot $a[2] -BrainRoot $a[3]} @($target,$original,$backups,$brain)
        $wins=@($outcomes|Where-Object ok);$final=[IO.File]::ReadAllText($target)
        $marker=Join-Path $brain '.runtime/para-transaction.json'
        Assert-Conc ($wins.Count -le 1) ('transazioni PARA: al piu un vincitore sullo stesso file ('+$wins.Count+' su 6)')
        Assert-Conc (@($outcomes|Where-Object {!$_.ok -and !$_.code -and $_.type -ne 'IOException'}).Count -eq 0) 'transazioni PARA: i perdenti falliscono con codice stabile o errore di I/O dichiarato'
        Assert-Conc (@(1..6|Where-Object {$final -ceq "transazione-$_`n"}).Count -eq 1 -or $final -ceq "base`n") 'transazioni PARA: contenuto finale di una sola transazione (o originale)'
        Assert-Conc ($wins.Count -eq 0 -or (Test-Path -LiteralPath $marker) -eq $false) 'transazioni PARA: nessun marker pendente dopo la transazione vincente'

        # Deterministic sharing violation before marker acquisition: no target/marker mutation.
        $lockedBrain=Join-Path $brain 'locked-marker';$lockedMarker=Join-Path $lockedBrain '.runtime/para-transaction.json';$lockedTarget=Join-Path $lockedBrain 'target.md'
        [IO.Directory]::CreateDirectory((Split-Path $lockedMarker))|Out-Null
        [IO.File]::WriteAllText($lockedTarget,"preserve`n");$targetHash=Get-SBFileHash $lockedTarget
        [IO.File]::WriteAllText($lockedMarker,'{"fixture":"held marker"}');$markerHash=Get-SBFileHash $lockedMarker
        $holder=[IO.File]::Open($lockedMarker,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$lockedError=$null
        try{
            try{Invoke-SBParaTransaction -Operations @(@{path=$lockedTarget;expected=$targetHash;bytes=[Text.Encoding]::UTF8.GetBytes("replacement`n")}) -BackupRoot $backups -BrainRoot $lockedBrain|Out-Null}catch{$lockedError=$_.Exception}
        }finally{$holder.Dispose()}
        Assert-Conc ($null -ne $lockedError -and (Get-ErrorCode $lockedError) -eq 'core.write.contended') 'locked transaction marker: stable contention code before acquisition'
        Assert-Conc ((Get-SBFileHash $lockedTarget) -eq $targetHash -and (Get-SBFileHash $lockedMarker) -eq $markerHash) 'locked transaction marker: target and retained marker bytes unchanged'
    }

    Invoke-Case 'tracker-new-task' (Join-Path $root 'tracker') {
        $dir=Join-Path $root 'tracker';$brain=Join-Path $dir 'brain';$dossier=Join-Path $brain '02-areas/products/fixture';$backups=Join-Path $dir 'backups'
        foreach($path in @((Join-Path $brain '.runtime'),(Join-Path $dossier 'history'),$backups)){[IO.Directory]::CreateDirectory($path)|Out-Null}
        [IO.File]::WriteAllText((Join-Path $dossier 'history/fonte.md'),"fonte`n")
        $identity='github.com/acme/fixture'
        $seed=New-SBTrackerTask @{id='TASK-001';title='Seme';status='done'} $identity 'test' 'fonte.md' (Get-SBTextHash 'fonte') 'line:1'
        $seed.seq=1;$seed.title=('#001 '+[char]0x2014+' Seme')
        $trackerPath=Join-Path $dossier 'tracker.json'
        [IO.File]::WriteAllText($trackerPath,(ConvertTo-SBJson @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@($seed);history=@();extensions=@{lastSeq=1}}))
        $outcomes=Invoke-Race 5 {param($i,$a) New-SBTrackerTaskEntry -BrainRoot $a[0] -Path $a[1] -Title ("Concorrente $i") -Acceptance @('ok') -ProvenanceReference 'history/fonte.md' -BackupRoot $a[2]} @($brain,$trackerPath,$backups)
        $data=Read-SBJson $trackerPath $null;$seqs=@($data.tasks|ForEach-Object seq);$wins=@($outcomes|Where-Object ok)
        Assert-Conc (@($outcomes|Where-Object {!$_.ok -and !$_.code}).Count -eq 0) ('tracker -NewTask: i perdenti falliscono con codice stabile ('+(@($outcomes|Where-Object {!$_.ok}|ForEach-Object {[string]$_.code+':'+$_.type+':'+$_.message}) -join ' | ')+')')
        Assert-Conc ($data.tasks.Count -eq 1+$wins.Count -and @($seqs|Sort-Object -Unique).Count -eq $seqs.Count -and $data.extensions.lastSeq -eq ($seqs|Measure-Object -Maximum).Maximum) 'tracker -NewTask: file valido, numeri progressivi senza duplicati, lastSeq coerente'
        Assert-Conc ($wins.Count -ge 1 -and ((Test-Path -LiteralPath (Join-Path $brain '.runtime/para-transaction.json')) -eq $false)) 'tracker -NewTask: almeno una creazione riuscita e nessuna transazione pendente'
    }

    Invoke-Case 'backup' (Join-Path $root 'backup') {
        $brain=Join-Path $root 'backup/brain'
        foreach($sub in @('scripts','config')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('../'+$sub)) -Destination (Join-Path $brain $sub) -Recurse -Force}
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../VERSION') -Destination (Join-Path $brain 'VERSION')
        foreach($file in @('02-areas/a/uno.md','02-areas/a/due.md','.runtime/hosts/ws/workstation.json')){$p=Join-Path $brain $file;[IO.Directory]::CreateDirectory((Split-Path $p))|Out-Null;[IO.File]::WriteAllText($p,"contenuto $file`n")}
        $script=Join-Path $brain 'scripts/backup.ps1'
        $processes=@(1..3|ForEach-Object {
            $info=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source);foreach($argument in @('-NoProfile','-File',$script)){$info.ArgumentList.Add($argument)}
            $info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;$info.Environment['SECONDBRAIN_LANG']='it'
            [Diagnostics.Process]::Start($info)
        })
        $results=@($processes|ForEach-Object {$out=$_.StandardOutput.ReadToEndAsync();$err=$_.StandardError.ReadToEndAsync();$_.WaitForExit();@{exit=$_.ExitCode;out=$out.Result;err=$err.Result}})
        $zips=@(Get-ChildItem -LiteralPath (Join-Path $brain '.runtime/backups') -File -Filter 'secondbrain-backup-*.zip' -ErrorAction SilentlyContinue)
        $ok=@($results|Where-Object {$_.exit -eq 0})
        Assert-Conc (@($results|Where-Object {$_.exit -notin @(0,3)}).Count -eq 0) ('backup: ogni processo termina con 0 o con 3 (occupato); esiti '+(($results|ForEach-Object exit) -join ','))
        Assert-Conc ($ok.Count -ge 1 -and $zips.Count -eq $ok.Count) ('backup: uno zip distinto per ogni backup riuscito ('+$zips.Count+' zip, '+$ok.Count+' riusciti)')
        $verified=@($zips|Where-Object {$v=(& pwsh -NoProfile -File $script -Verify -BackupPath $_.FullName 2>&1|Out-String);$LASTEXITCODE -eq 0 -and $v -match 'VERIFY SUCCESS'})
        Assert-Conc ($verified.Count -eq $zips.Count) 'backup: tutti gli zip prodotti superano -Verify'
    }

    Invoke-Case 'edge-cases' (Join-Path $root 'edge') {
        $dir=Join-Path $root 'edge';$backups=Join-Path $dir 'backups';[IO.Directory]::CreateDirectory($dir)|Out-Null
        # Unicode filename and content.
        $unicode=Join-Path $dir ('perché-ñ-日本語-'+[char]::ConvertFromUtf32(0x1F600)+'.md');$text="àèìòù — ñ — 日本語`n"
        $created=Write-SBFile $unicode ([Text.UTF8Encoding]::new($false).GetBytes($text)) 'absent' $backups
        Assert-Conc ($created -and (Read-SBText $unicode) -ceq $text) 'Unicode: nome e contenuto UTF-8 scritti e riletti identici'
        # Case differences: same path with a different spelling, and path comparison.
        Assert-Conc (Test-SBSamePath $unicode $unicode.ToUpperInvariant() ) 'maiuscole/minuscole: lo stesso percorso e riconosciuto'
        $caseFile=Join-Path $dir 'Caso.md';[IO.File]::WriteAllText($caseFile,"uno`n");$caseHash=Get-SBFileHash $caseFile
        $upperPath=Join-Path $dir 'CASO.md'
        Assert-Conc ((Get-SBFileHash $upperPath) -eq $caseHash -and (Write-SBFile $upperPath ([Text.Encoding]::UTF8.GetBytes("due`n")) $caseHash $backups) -and [IO.File]::ReadAllText($caseFile) -ceq "due`n") 'maiuscole/minuscole: la scrittura con un altro caso aggiorna lo stesso file senza duplicarlo'
        Assert-Conc (@(Get-ChildItem -LiteralPath $dir -File -Filter 'caso.md').Count -eq 1) 'maiuscole/minuscole: nessun file duplicato'
        # File locked by another process/handle: clear error, intact content, no staging.
        $locked=Join-Path $dir 'bloccato.md';[IO.File]::WriteAllText($locked,"bloccato`n");$lockedHash=Get-SBFileHash $locked
        $holder=[IO.File]::Open($locked,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $lockError=$null
        try{try{Write-SBFile $locked ([Text.Encoding]::UTF8.GetBytes("nuovo`n")) $lockedHash $backups|Out-Null}catch{$lockError=$_.Exception}}finally{$holder.Dispose()}
        Assert-Conc ($null -ne $lockError) 'file bloccato: la scrittura fallisce con un errore, non in silenzio'
        Assert-Conc ((Get-SBFileHash $locked) -eq $lockedHash -and @(Get-ChildItem -LiteralPath $dir -Force -Filter '.secondbrain-*.tmp').Count -le 1) 'file bloccato: contenuto originale intatto'
        # Path beyond 260 characters.
        $deep=$dir;while($deep.Length -lt 300){$deep=Join-Path $deep ('sezione-lunga-numero-'+$deep.Length)}
        $longPath=Join-Path $deep 'file-lungo.md';$longError=$null;$longCreated=$false
        try{[IO.Directory]::CreateDirectory($deep)|Out-Null;$longCreated=Write-SBFile $longPath ([Text.Encoding]::UTF8.GetBytes("lungo`n")) 'absent' $backups}catch{$longError=$_.Exception}
        Assert-Conc ($longPath.Length -gt 260) ('percorso oltre 260 caratteri costruito ('+$longPath.Length+')')
        Assert-Conc (($longCreated -and [IO.File]::ReadAllText($longPath) -ceq "lungo`n") -or ($null -ne $longError -and $longError.Message)) 'percorso oltre 260: scritto e riletto, oppure rifiutato con errore esplicito (mai in silenzio)'
        $longResult=if($longCreated){'supportato'}else{'rifiutato: '+$longError.Message}
        Write-Output ('INFO CONCURRENCY: percorso '+$longPath.Length+' caratteri '+$longResult)
    }

    $suiteStatus='passed'
    'SUCCESS CONCURRENCY: '+$script:checks+' verifiche; runtime='+$PSVersionTable.PSVersion
} finally {
    $suiteWatch.Stop()
    $leftover=Get-FixtureSize $root
    $esito=[ordered]@{schemaVersion=1;suite='concurrency';status=$suiteStatus;durationMs=[int]$suiteWatch.ElapsedMilliseconds;checks=$script:checks;observedAt=[DateTimeOffset]::UtcNow.ToString('o')
        fixture=[ordered]@{path=$root;removed=$removed;kept=!$removed;files=$leftover.files;bytes=$leftover.bytes};cases=@($script:cases)}
    [IO.File]::WriteAllText($esitoPath,(ConvertTo-SBJson $esito),[Text.UTF8Encoding]::new($false))
}
