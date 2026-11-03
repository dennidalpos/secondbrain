#requires -Version 7.5
# Livelli: -Quick (controlli puri, pochi secondi), predefinito Fast (sub-suite in parallelo, output sintetico), -Full (sequenziale, output completo).
# -Only <chiave> esegue una sola sub-suite; -KeepFixtures (o SECONDBRAIN_TEST_KEEP=1) conserva le fixture anche dopo un esito verde;
# SECONDBRAIN_TEST_TIMING=1 esegue in sequenza e stampa le sezioni piu lente.
[CmdletBinding()]
param([switch]$Full,[switch]$Quick,[ValidateSet('portable','workflows','trackers','audit2','trace','sources','external-audit','quick')][string[]]$Only,[switch]$KeepFixtures,[switch]$Sequential)
$script:Full = [bool]$Full
$script:Quick = [bool]$Quick
$script:Timing = ($env:SECONDBRAIN_TEST_TIMING -eq '1')
$script:Level = if($Only){ 'Only' }elseif($script:Quick){ 'Quick' }elseif($script:Full){ 'Full' }else{ 'Fast' }
Write-Output ('Runtime suite: '+$PSVersionTable.PSVersion+'; pwsh figli: '+(Get-Command pwsh).Source + ' [Modalità '+$script:Level+']')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:passed=0
function Assert($Condition,[string]$Message){
    if(!$Condition){throw "FAIL: $Message"}
    $script:passed++
    if($script:Full){Write-Output "PASS: $Message"}
}
$script:laps = [Collections.Generic.List[object]]::new()
# Sub-suite: chiave, titolo, file. Le prime cinque hanno fixture proprie e partono insieme in Fast (le piu lente per prime).
$script:SubSuites = @(
    @{ Key='portable';       File='test-secondbrain-portable.ps1';       Name='Portabile: discovery, attivazione, compattazione, pubblicazione e asset' }
    @{ Key='trackers';       File='test-secondbrain-trackers.ps1';       Name='Tracker: conversioni, resolver, riferimenti, migrazione e recupero' }
    @{ Key='workflows';      File='test-secondbrain-workflows.ps1';      Name='Workflow: catalogo, contesto Git/PARA, composizione e output' }
    @{ Key='audit2';         File='test-secondbrain-audit2.ps1';         Name='Audit2: rimozione protetta, Markdown, provenienza e recupero' }
    @{ Key='trace';          File='test-secondbrain-trace.ps1';          Name='Traccia di fine turno: evento, hook Stop e avviso di compattazione' }
    @{ Key='sources';        File='test-secondbrain-sources.ps1';        Name='Fonti: registro, sicurezza, acquisizione, confronto e conversione' }
    @{ Key='external-audit'; File='test-secondbrain-external-audit.ps1'; Name='Audit esterno: paginazione, copertura, errori e protezione dei contenuti' }
    @{ Key='quick';          File='test-secondbrain-quick.ps1';          Name='Quick: controlli puri su identita, JSON, versione, catalogo e messaggi' }
)
function Get-SubSuiteKeys {
    if ($Only) { return @($Only) }
    if ($script:Quick) { return @('quick','sources','external-audit') }
    @('portable','trackers','workflows','audit2','trace','sources','external-audit')
}
function Format-Seconds([double]$Seconds) { ('{0:N1} s' -f $Seconds) }
function Write-SubSuiteResult($Suite, $Output, [int]$Code, [double]$Seconds) {
    if ($Code -ne 0) {
        Write-Host ("ERRORE IN SUB-SUITE " + $Suite.Name + " (exit code " + $Code + "):") -ForegroundColor Red
        $Output | ForEach-Object { Write-Output ([string]$_) }
        throw "FAIL: $($Suite.Name) fallito con codice $Code"
    }
    $summary = @($Output | ForEach-Object { [string]$_ } | Where-Object { $_ -match '^(?:SUCCESS|PASS:)\s*' })
    $line = if ($summary.Count) { $summary[-1] } else { "SUCCESS $($Suite.Name): verifiche superate (exit code 0)" }
    Write-Output ($line + ' [' + $Suite.Key + ', ' + (Format-Seconds $Seconds) + ']')
    $script:passed++
}
function Invoke-SubSuiteTimed($Suite) {
    # Esecuzione in sequenza con marca di tempo per riga: il tempo di una riga PASS e l'intervallo dalla precedente.
    $watch = [Diagnostics.Stopwatch]::StartNew(); $previous = 0.0
    $output = @(& pwsh -NoProfile -File (Join-Path $PSScriptRoot $Suite.File) 2>&1 | ForEach-Object {
        $now = $watch.Elapsed.TotalSeconds
        $script:laps.Add([pscustomobject]@{ Suite = $Suite.Key; Seconds = $now - $previous; Line = [string]$_ })
        $previous = $now
        $_
    })
    Write-SubSuiteResult $Suite $output $LASTEXITCODE $watch.Elapsed.TotalSeconds
}
function Invoke-SubSuitePool($Suites) {
    # Processi pwsh figli concorrenti (ThreadJob), output raccolto e stampato nell'ordine dichiarato.
    $limit = [Math]::Max(1, [Math]::Min(4, [Environment]::ProcessorCount))
    $jobs = @(foreach ($suite in $Suites) {
        Start-ThreadJob -ThrottleLimit $limit -ArgumentList (Join-Path $PSScriptRoot $suite.File) -ScriptBlock {
            param($File)
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $out = @(& pwsh -NoProfile -File $File 2>&1 | ForEach-Object { [string]$_ })
            [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out; Seconds = $watch.Elapsed.TotalSeconds }
        }
    })
    $failed = @()
    for ($i = 0; $i -lt $Suites.Count; $i++) {
        $result = $jobs[$i] | Receive-Job -Wait -AutoRemoveJob
        try { Write-SubSuiteResult $Suites[$i] $result.Output $result.Code $result.Seconds } catch { $failed += $_.Exception.Message }
    }
    if ($failed.Count) { throw ($failed -join '; ') }
}
function Invoke-SubSuites([string[]]$Keys) {
    $suites = @($Keys | ForEach-Object { $key = $_; $script:SubSuites | Where-Object { $_.Key -eq $key } })
    if ($script:Full) {
        foreach ($suite in $suites) {
            & pwsh -NoProfile -File (Join-Path $PSScriptRoot $suite.File)
            Assert ($LASTEXITCODE -eq 0) $suite.Name
        }
    } elseif ($script:Timing -or $Sequential -or $suites.Count -lt 2) {
        foreach ($suite in $suites) { Invoke-SubSuiteTimed $suite }
    } else {
        Invoke-SubSuitePool $suites
    }
}
function Write-SlowestSections {
    if (!$script:Timing -or !$script:laps.Count) { return }
    Write-Output 'Sezioni piu lente (tempo fino alla riga indicata):'
    $script:laps | Where-Object { $_.Line -match '^PASS' } | Sort-Object Seconds -Descending | Select-Object -First 15 | ForEach-Object {
        Write-Output ('  {0,7}  {1,-14} {2}' -f (Format-Seconds $_.Seconds), $_.Suite, $_.Line)
    }
}
function Remove-TestRun([string]$RunDirectory, [string]$BaseRoot) {
    # Rimuove soltanto la directory di questa esecuzione: figlia diretta della radice dei test con nome run-<8 esadecimali>.
    $resolved = [IO.Path]::GetFullPath($RunDirectory).TrimEnd('\','/')
    $base = [IO.Path]::GetFullPath($BaseRoot).TrimEnd('\','/')
    if ((Split-Path $resolved -Parent) -ine $base -or (Split-Path $resolved -Leaf) -cnotmatch '^run-[0-9a-f]{8}$') { return $false }
    if (!(Test-Path -LiteralPath $resolved)) { return $true }
    try { Remove-Item -LiteralPath ('\\?\' + $resolved) -Recurse -Force -ErrorAction Stop; return $true }
    catch { Write-Warning ('Fixture non rimosse: ' + $_.Exception.Message); return $false }
}
function Throws([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Assert $caught $Message}
function Put([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Git([string]$Path,[string[]]$Arguments){$r=Invoke-SBGit $Path $Arguments;if($r.code -ne 0){throw $r.error};$r.output}
# Ogni esecuzione lavora in una propria directory run-<id> sotto la radice dei test: sub-suite comprese (le eredita da SECONDBRAIN_TEST_ROOT).
# A esito verde la directory si rimuove (autorizzazione dell'utente, limitata a cio che crea questa esecuzione); a esito rosso si conserva.
$keepFixtures = $KeepFixtures -or $env:SECONDBRAIN_TEST_KEEP -eq '1'
$testBase = Get-SBTestRoot
$savedTestRoot = $env:SECONDBRAIN_TEST_ROOT
$runDirectory = Join-Path $testBase ('run-'+[guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($runDirectory)|Out-Null
$env:SECONDBRAIN_TEST_ROOT = $runDirectory
$root=Join-Path (Get-SBTestRoot) ('secondbrain-test-'+[guid]::NewGuid().ToString('N'))
$backup=Join-Path (Get-SBTestRoot) ('secondbrain-test-backup-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root)|Out-Null
$success=$false
$runWatch = [Diagnostics.Stopwatch]::StartNew()
try {
    & {
        $backup = Join-Path $root 'directive-backups'
        [IO.Directory]::CreateDirectory($backup) | Out-Null
        $prev = $script:passed
        . (Join-Path $PSScriptRoot 'test-secondbrain-directives.ps1')
        $diff = $script:passed - $prev
        if (!$script:Full) {
            Write-Output "SUCCESS DIRECTIVES: $diff verifiche"
        }
    }
    if ($script:Level -in 'Fast','Full') {
    $brain=Join-Path $root 'brain'
    [IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
    Get-ChildItem $PSScriptRoot -File | Where-Object Name -ne 'test-secondbrain.ps1' | Copy-Item -Destination (Join-Path $brain 'scripts')
    # I flussi CLI usano codice di produzione, file, Git e processi reali isolati.
    Put (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git','node_modules')})
    Assert ((ConvertTo-SBJson @{b=2;a=@{z=3;y=@()}}) -ceq (ConvertTo-SBJson @{a=@{y=@();z=3};b=2})) 'JSON deterministico'
    $path=Join-Path $root 'file con spazi.md';Put $path "originale`n"
    $hash=Get-SBFileHash $path
    Throws {Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes('lost')) 'wrong' $backup} 'scrittura concorrente rifiutata'
    Assert ((Get-SBFileHash $path) -eq $hash) 'file intatto dopo rifiuto'
    Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes('nuovo')) $hash $backup|Out-Null
    $metadata=Get-ChildItem $backup -Filter '*.json'|Select-Object -First 1
    $record=Read-SBJson $metadata.FullName @{}
    Assert ((Get-SBFileHash $record.backup) -eq $hash) 'backup verificato anche fra volumi'
    $restoreRuntime=Get-SBLocalRoot $brain 'restore'
    $restoreConfig=Join-Path $restoreRuntime 'workstation.json'
    Put $restoreConfig (ConvertTo-SBJson @{schemaVersion=1;mode='portable';workstationId='restore';runtimeRoot=$restoreRuntime;backupRoot=(Join-Path $restoreRuntime 'backups');bindings=@();ides=@()})
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/restore-managed.ps1') -MetadataPath $metadata.FullName -ConfigPath $restoreConfig | Out-Null
    Assert ($LASTEXITCODE -eq 0 -and (Get-SBFileHash $path) -eq $hash) 'CLI ripristino esatto'
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/restore-managed.ps1') -MetadataPath $metadata.FullName -ConfigPath $restoreConfig *> $null
    Assert ($LASTEXITCODE -ne 0 -and (Get-SBFileHash $path) -eq $hash) 'CLI ripristino rifiuta destinazione cambiata'
    # Git salva i file tracciati: pulito = nessun .bin (commit e blob registrati), sporco = rifiuto, non tracciato = .bin invariato.
    $gitRepo=Join-Path $root 'git repo';[IO.Directory]::CreateDirectory($gitRepo)|Out-Null
    Git $gitRepo @('init','-q')|Out-Null
    Git $gitRepo @('config','user.email','test@example.invalid')|Out-Null
    Git $gitRepo @('config','user.name','Test')|Out-Null
    $tracked=Join-Path $gitRepo 'tracked.md';Put $tracked "uno`n"
    $untracked=Join-Path $gitRepo 'untracked.md';Put $untracked "uno`n"
    Git $gitRepo @('add','tracked.md')|Out-Null
    Git $gitRepo @('commit','-q','-m','base')|Out-Null
    $gitBackup=Join-Path $root 'git-backups'
    $trackedHash=Get-SBFileHash $tracked
    Assert ((Write-SBFile $tracked ([Text.Encoding]::UTF8.GetBytes("due`n")) $trackedHash $gitBackup) -eq $true) 'file tracciato pulito riscritto'
    Assert (@(Get-ChildItem $gitBackup -Filter '*.bin' -ErrorAction SilentlyContinue).Count -eq 0) 'file tracciato pulito: nessun .bin'
    $gitRecord=Read-SBJson (Get-ChildItem $gitBackup -Filter '*.git.json'|Select-Object -First 1).FullName @{}
    Assert ($gitRecord.gitCommit -eq (Git $gitRepo @('rev-parse','HEAD')|Select-Object -First 1) -and $gitRecord.gitBlob -and $gitRecord.previousHash -eq $trackedHash) 'record Git con commit e blob'
    Assert (@(Get-ChildItem $gitRepo -Force -Filter '.secondbrain-*').Count -eq 0) 'nessun residuo accanto al file tracciato'
    $dirtyHash=Get-SBFileHash $tracked
    Throws {Write-SBFile $tracked ([Text.Encoding]::UTF8.GetBytes("tre`n")) $dirtyHash $gitBackup} 'file tracciato sporco rifiutato'
    Assert ((Get-SBFileHash $tracked) -eq $dirtyHash) 'file tracciato sporco intatto dopo rifiuto'
    $dirtyMessage='';try{Write-SBFile $tracked ([Text.Encoding]::UTF8.GetBytes("tre`n")) $dirtyHash $gitBackup|Out-Null}catch{$dirtyMessage=$_.Exception.Message}
    Assert ($dirtyMessage -like '*modifiche non committate*git stash*') 'rifiuto con istruzioni chiare'
    Assert ((Write-SBFile $tracked ([Text.Encoding]::UTF8.GetBytes("tre`n")) $dirtyHash $gitBackup -BackupDirty) -eq $true -and @(Get-ChildItem $gitBackup -Filter '*.bin').Count -eq 1) 'rigenerato sporco con -BackupDirty conserva il .bin'
    Write-SBFile $untracked ([Text.Encoding]::UTF8.GetBytes("due`n")) (Get-SBFileHash $untracked) $gitBackup|Out-Null
    Assert (@(Get-ChildItem $gitBackup -Filter '*.bin').Count -eq 2) 'file non tracciato: .bin invariato'
    $managedOutput=@(Set-SBManagedContent $tracked 'regola' 'gitdirty' @{} $false $gitBackup 3>&1)
    Assert ($managedOutput -contains 'conflict' -and @($managedOutput|Where-Object {$_ -is [Management.Automation.WarningRecord]}).Count -ge 1) 'blocco gestito su file tracciato sporco: conflitto con avviso'
    $pruneRoot=Join-Path $root 'prune-brain';$pruneBackups=Join-Path $pruneRoot '.runtime/hosts/h1/backups';[IO.Directory]::CreateDirectory($pruneBackups)|Out-Null
    $pruneFile=Join-Path $gitRepo 'prune.md';Put $pruneFile "uno`n";Git $gitRepo @('add','prune.md')|Out-Null;Git $gitRepo @('commit','-q','-m','prune')|Out-Null
    $oldBin=Join-Path $pruneBackups 'old.bin';[IO.File]::WriteAllText($oldBin,"uno`n");[IO.File]::WriteAllText($oldBin+'.json',(ConvertTo-SBJson @{path=$pruneFile;previousHash=(Get-SBFileHash $oldBin);deployedHash='y';backup=$oldBin}))
    $lostBin=Join-Path $pruneBackups 'lost.bin';[IO.File]::WriteAllText($lostBin,"mai committato`n");[IO.File]::WriteAllText($lostBin+'.json',(ConvertTo-SBJson @{path=$pruneFile;previousHash=(Get-SBFileHash $lostBin);deployedHash='y';backup=$lostBin}))
    $proposal=Get-SBRuntimeCleanupProposal $pruneRoot @() 90 5
    $binCandidates=@($proposal.candidates|Where-Object {$_.path -like '*backups/*.bin'})
    Assert ($binCandidates.Count -eq 1 -and $binCandidates[0].files -eq 1 -and $proposal.applied -eq $false -and (Test-Path $oldBin) -and (Test-Path $lostBin)) 'proposta di potatura dei soli .bin con blob in Git, senza eseguirla (il .bin senza blob e escluso)'
    foreach($runtimeCase in @('work-20261102-prova','evidence-20261102-prova','report-20261102-prova','t77')){$caseDir=Join-Path $pruneRoot (Join-Path '.runtime' $runtimeCase);[IO.Directory]::CreateDirectory($caseDir)|Out-Null;[IO.File]::WriteAllText((Join-Path $caseDir 'x.txt'),'x')}
    [IO.Directory]::CreateDirectory((Join-Path $pruneRoot '.runtime/trace/h1'))|Out-Null;[IO.File]::WriteAllText((Join-Path $pruneRoot '.runtime/trace/h1/2026-11-02.jsonl'),'{}')
    $runtimeBefore=@(Get-ChildItem (Join-Path $pruneRoot '.runtime') -Recurse -File|ForEach-Object FullName|Sort-Object)
    $runtimeIndex=Get-SBRuntimeIndex $pruneRoot @() 90
    $categoryOf=@{};foreach($entry in $runtimeIndex.entries){$categoryOf[$entry.name]=$entry.category}
    Assert ($categoryOf['work-20261102-prova'] -eq 'working' -and $categoryOf['evidence-20261102-prova'] -eq 'evidence' -and $categoryOf['report-20261102-prova'] -eq 'evidence' -and $categoryOf['trace'] -eq 'evidence' -and $categoryOf['t77'] -eq 'working') 'indice .runtime: i prefissi della convenzione e trace sono classificati'
    $indexRows=@($runtimeIndex.markdown -split "`n"|Where-Object {$_ -match '^\| `'})
    $categoryRank=@{protected=0;evidence=1;backup=2;working=3;regenerable=4};$ranks=@($indexRows|ForEach-Object {$categoryRank[(($_ -split '\|')[2]).Trim()]})
    Assert ($indexRows.Count -eq @($runtimeIndex.entries).Count -and (@($ranks|Sort-Object) -join ',') -eq ($ranks -join ',') -and $runtimeIndex.markdown -match 'nome conforme') 'indice .runtime: righe ordinate per categoria e nomi conformi segnalati'
    Assert ((@(Get-ChildItem (Join-Path $pruneRoot '.runtime') -Recurse -File|ForEach-Object FullName|Sort-Object) -join '|') -eq ($runtimeBefore -join '|')) 'indice .runtime: sola lettura, nessun file creato o rimosso'
    $state=@{}
    Assert ((Set-SBManagedContent $path 'regola' 'test' $state $true $backup) -eq 'pending') 'Check rileva blocco mancante'
    Assert ((Get-SBFileHash $path) -eq $hash -and $state.Count -eq 0) 'Check senza scritture o adozione'
    $whitespacePath=Join-Path $root 'whitespace.md';Put $whitespacePath "`n`nistruzioni  `n`n"
    Set-SBManagedContent $whitespacePath 'regola' 'test' @{} $false $backup|Out-Null
    Assert ((Read-SBText $whitespacePath).StartsWith("`n`nistruzioni  `n`n")) 'whitespace del testo utente preservato'
    Assert ((Set-SBManagedContent $path 'regola' 'test' $state $false $backup) -eq 'updated') 'aggiunta blocco'
    $managedHash=Get-SBFileHash $path
    Assert ((Set-SBManagedContent $path 'regola' 'test' $state $false $backup) -eq 'aligned') 'seconda applicazione idempotente'
    Assert ((Get-SBFileHash $path) -eq $managedHash) 'contenuto stabile'
    Put $path ((Read-SBText $path)+"testo personale`n")
    Set-SBManagedContent $path 'regola nuova' 'test' $state $false $backup|Out-Null
    Assert ((Read-SBText $path).Contains('testo personale')) 'testo esterno al blocco preservato'
    Put $path ((Read-SBText $path).Replace('regola nuova','modifica utente'))
    Assert ((Set-SBManagedContent $path 'regola terza' 'test' $state $false $backup) -eq 'conflict') 'drift nel blocco conservato'
    Assert ((Read-SBText $path).Contains('modifica utente')) 'conflitto non sovrascritto'
    Throws {Get-SBManagedContent '<!-- secondbrain:test:begin -->broken' 'test'} 'blocco incompleto rifiutato'
    $whole=Join-Path $root 'whole.md';Put $whole 'utente'
    Assert ((Set-SBManagedContent $whole 'generated' 'file' @{} $false $backup -WholeFile) -eq 'conflict') 'file non gestito non adottato'
    $brain=Join-Path $root 'brain'
    $commonFixture = "# common`n`nRevisione 3.0 — 2026-10-19."
    Put (Join-Path $brain 'direttive/AGENTS.global_ide.md') $commonFixture
    Put (Join-Path $brain 'direttive/workstation.template.md') 'workstation'
    $approval=@{authorization='test';files=@{'direttive/AGENTS.global_ide.md'=Get-SBFileHash (Join-Path $brain 'direttive/AGENTS.global_ide.md');'direttive/workstation.template.md'=Get-SBFileHash (Join-Path $brain 'direttive/workstation.template.md')}}
    Put (Join-Path $brain 'direttive/approved.json') (ConvertTo-SBJson $approval)
    Assert (Test-SBApproval $brain) 'revisione approvata valida'
    Put (Join-Path $brain 'direttive/AGENTS.global_ide.md') 'unapproved'
    Assert (!(Test-SBApproval $brain)) 'modifica non approvata blocca distribuzione'
    $profile=Join-Path $root 'profile';[IO.Directory]::CreateDirectory($profile)|Out-Null
    $oldCodexHome=$env:CODEX_HOME
    try {
        $env:CODEX_HOME=Join-Path $profile '.codex'
        $prev = $script:passed
        . (Join-Path $PSScriptRoot 'test-secondbrain-integration.ps1')
        $diff = $script:passed - $prev
        if (!$script:Full) {
            Write-Output "SUCCESS INTEGRATION: $diff verifiche"
        }
    }
    finally {$env:CODEX_HOME=$oldCodexHome}
    }

    Invoke-SubSuites (Get-SubSuiteKeys)

    if ($script:Level -ne 'Only') {
        foreach($script in Get-ChildItem $PSScriptRoot -File|Where-Object Extension -in @('.ps1','.psm1')){
            $tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)|Out-Null
            Assert ($errors.Count -eq 0) ('parser '+$script.Name)
        }
        if (!$script:Full) {
            Write-Output "SUCCESS PARSER: tutti gli script analizzati senza errori di sintassi"
        }
    }
    Write-SlowestSections
    $success=$true
    "SUCCESS: $script:passed verifiche in $(Format-Seconds $runWatch.Elapsed.TotalSeconds) [$($script:Level)]; nessun accesso a dati applicativi o remote di rete."
} finally {
    $env:SECONDBRAIN_TEST_ROOT = $savedTestRoot
    if ($success -and !$keepFixtures) {
        if (Remove-TestRun $runDirectory $testBase) { Write-Output 'Fixture di questa esecuzione rimosse (esito verde; -KeepFixtures le conserva).' }
        else { Write-Output ('Fixture conservata: '+$runDirectory) }
    } else { Write-Output ('Fixture conservata: '+$runDirectory) }
}
