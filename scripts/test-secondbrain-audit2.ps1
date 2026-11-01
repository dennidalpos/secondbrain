#requires -Version 7.5
param([ValidateSet('All','Removal','Markdown','Provenance','Recovery')][string]$Case='All')
$ErrorActionPreference='Stop'
foreach($module in @('Core','Access','Para','Tracker','TrackerImport')){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$module+'.psm1')) -Force}
$script:checks=0
function Assert-Next($Condition,[string]$Message){if(!$Condition){throw ('FAIL AUDIT2: '+$Message)};$script:checks++;'PASS AUDIT2: '+$Message}
function Reject-Next([scriptblock]$Action,[string]$Message){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Assert-Next $rejected $Message}
function Git-Next([string]$Path,[string[]]$Arguments){$r=Invoke-SBGit $Path $Arguments;if($r.code -ne 0){throw $r.error};$r.output}
function Snapshot-Next([string]$Path){ConvertTo-SBJson @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force|ForEach-Object {@{path=$_.FullName;hash=Get-SBFileHash $_.FullName;time=$_.LastWriteTimeUtc.Ticks}}|Sort-Object path)}
# Reuse only the existing fixture constructors, without executing the older suite.
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'test-secondbrain-tracker-audit.ps1'),[ref]$tokens,[ref]$errors)
foreach($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in @('Put-Audit','New-AuditFixture')},$true)){
    . ([scriptblock]::Create($definition.Extent.Text.Replace('$PSScriptRoot',("'"+$PSScriptRoot.Replace("'","''")+"'"))))
}
$root=Join-Path (Get-SBTestRoot) ('secondbrain-audit2-'+[guid]::NewGuid().ToString('N'))
try {
    if($Case -in @('All','Removal')){
        $f=New-AuditFixture 'removal';$inputPath=Join-Path $f.checkout 'input.txt';Put-Audit $inputPath 'OLD';$hash=Get-SBFileHash $inputPath
        foreach($attempt in @('write','rename','cancel')){
            $counter=[pscustomobject]@{calls=0}
            $guard={
                $counter.calls++
                if($counter.calls -eq 2){
                    switch($attempt){
                        write{[IO.File]::WriteAllText($inputPath,'NEW-CONCURRENT')}
                        rename{[IO.File]::Move($inputPath,$inputPath+'.moved')}
                        cancel{throw 'session lost'}
                    }
                }
            }.GetNewClosure()
            Set-SBWriteGuard $guard
            try{Reject-Next {Remove-SBFile $inputPath $f.checkout $hash $f.config.backupRoot} ('rimozione: '+$attempt+' nella finestra finale rifiutato')}finally{Set-SBWriteGuard $null}
            Assert-Next ((Read-SBText $inputPath) -ceq 'OLD' -and !(Test-Path -LiteralPath ($inputPath+'.moved'))) ('rimozione: originale intatto '+$attempt)
        }
        Put-Audit $inputPath 'NEW-CONCURRENT'
        Reject-Next {Remove-SBFile $inputPath $f.checkout $hash $f.config.backupRoot} 'rimozione: versione diversa prima dell apertura conservata'
        Assert-Next ((Read-SBText $inputPath) -ceq 'NEW-CONCURRENT') 'rimozione: versione concorrente non cancellata'
        Put-Audit $inputPath 'OLD'
        $writer=[IO.FileStream]::new($inputPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        try{Reject-Next {Remove-SBFile $inputPath $f.checkout $hash $f.config.backupRoot} 'rimozione: writer gia aperto impedisce eliminazione'}finally{$writer.Dispose()}
        $metadata=Remove-SBFile $inputPath $f.checkout $hash $f.config.backupRoot
        Assert-Next (!(Test-Path -LiteralPath $inputPath) -and (Read-SBText $metadata.backup) -ceq 'OLD') 'rimozione: backup esatto dei byte rimossi'
        & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/restore-managed.ps1') -ConfigPath $f.config.configPath -MetadataPath ($metadata.backup+'.json')|Out-Null
        Assert-Next ($LASTEXITCODE -eq 0 -and (Get-SBFileHash $inputPath) -eq $hash) 'rimozione: CLI recupera il backup esatto'
        Put-Audit $inputPath 'REAPPEARED'
        & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/restore-managed.ps1') -ConfigPath $f.config.configPath -MetadataPath ($metadata.backup+'.json') *> $null
        Assert-Next ($LASTEXITCODE -ne 0 -and (Read-SBText $inputPath) -ceq 'REAPPEARED') 'rimozione: recupero conserva destinazione ricomparsa'
        Put-Audit $inputPath 'OLD'
        $probe=Join-Path $root 'kill-removal.ps1';$ready=Join-Path $root 'removal.ready'
        Put-Audit $probe 'param($Modules,$Path,$Backup,$Ready) Import-Module (Join-Path $Modules "SecondBrain.Core.psm1"); $state=[pscustomobject]@{calls=0}; Set-SBWriteGuard {$state.calls++;if($state.calls -eq 2){[IO.File]::WriteAllText($Ready,"ready");Start-Sleep -Seconds 30}}.GetNewClosure(); Remove-SBFile $Path (Split-Path $Path) (Get-SBFileHash $Path) $Backup|Out-Null'
        $start=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source);$start.UseShellExecute=$false;$start.CreateNoWindow=$true
        foreach($arg in @('-NoProfile','-File',$probe,'-Modules',$PSScriptRoot,'-Path',$inputPath,'-Backup',$f.config.backupRoot,'-Ready',$ready)){$start.ArgumentList.Add($arg)}
        $child=[Diagnostics.Process]::Start($start)
        try{
            $deadline=[DateTimeOffset]::UtcNow.AddSeconds(15)
            while(!(Test-Path -LiteralPath $ready) -and !$child.HasExited -and [DateTimeOffset]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 100}
            Assert-Next (Test-Path -LiteralPath $ready) 'rimozione: checkpoint con handle protetto raggiunto'
            $child.Kill($true);$child.WaitForExit()
        }finally{if(!$child.HasExited){$child.Kill($true);$child.WaitForExit()};$child.Dispose()}
        Assert-Next ((Get-SBFileHash $inputPath) -eq $hash) 'rimozione: processo interrotto prima della disposition conserva originale'
        $metadata=Remove-SBFile $inputPath $f.checkout $hash $f.config.backupRoot
        Assert-Next (!(Test-Path -LiteralPath $inputPath) -and (Get-SBFileHash $metadata.backup) -eq $hash) 'rimozione: ripresa dopo interruzione con backup verificato'
    }
    if($Case -in @('All','Markdown')){
        $unknown="# Tracker`n`n| ID | Stato | Attivita |`n|---|---|---|`n| APP-01 | aperto | Task |`n"
        $valid="# Tracker`n## Attivita aperte / Prossimi passi`n| ID | Priorita / stato | Dipendenze | Risultato e criterio |`n|---|---|---|---|`n| SB-OPT-01 | P1 | Nessuna | Task valido |`n"
        $inputs=@($unknown,($valid+"| APP-01 | P2 | Nessuna | Task ignorato |`n"),"# Tracker`n- [ ] fuori sezione",($valid+"## Residui verificati`n- [x] concluso non supportato"))
        $index=0
        foreach($inputText in $inputs){
            $f=New-AuditFixture ('markdown-'+$index);$f.source=Join-Path $f.dir 'tracker.md';Put-Audit $f.source $inputText;$hash=Get-SBFileHash $f.source
            Reject-Next {ConvertTo-SBTracker $f.source $f.identity} ('Markdown: formato non riconosciuto rifiutato '+$index)
            $before=Snapshot-Next (Split-Path $f.brain)
            & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/import-tracker.ps1') -ConfigPath $f.config.configPath -Repository $f.identity -SourcePath $f.source *> $null
            Assert-Next ($LASTEXITCODE -ne 0 -and (Snapshot-Next (Split-Path $f.brain)) -ceq $before) ('Markdown: anteprima rifiuta senza scrivere '+$index)
            Reject-Next {Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source -Activate} ('Markdown: attivazione rifiutata '+$index)
            Assert-Next ((Get-SBFileHash $f.source) -eq $hash -and !(Test-Path -LiteralPath (Join-Path $f.dir 'tracker.json')) -and !(Read-SBJson (Join-Path $f.dir 'repository.json') $null).ContainsKey('tracker')) ('Markdown: fonte e autorita conservate '+$index)
            $index++
        }
        $f=New-AuditFixture 'markdown-valid';$f.source=Join-Path $f.dir 'tracker.md'
        Put-Audit $f.source ($valid+"## Residui verificati`n- [ ] residuo`n## Note`nTesto da conservare.`n~~~md`n"+$unknown+"~~~`n")
        $data=ConvertTo-SBTracker $f.source $f.identity
        Assert-Next ($data.tasks.Count -eq 2 -and $data.extensions.original.markdown.Contains('APP-01')) 'Markdown: note ed esempi conservati, solo due task reali'
        $manifest=Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source -Activate
        Assert-Next ((Read-SBTrackerManifest $f.config $manifest).phase -eq 'completed' -and (Read-SBJson (Join-Path $f.dir 'tracker.json') $null).tasks.Count -eq 2) 'Markdown: migrazione supportata completa senza task persi'
        Restore-SBTrackerImport $f.config $manifest
        Assert-Next (Test-Path -LiteralPath $f.source) 'Markdown: recupero fonte supportata'
        foreach($inputText in @('# Tracker vuoto',"# Tracker`n## Attivita aperte / Prossimi passi`n| ID | Stato | Dipendenze | Criterio |`n|---|---|---|---|")){
            Put-Audit $f.source $inputText
            Assert-Next ((ConvertTo-SBTracker $f.source $f.identity).tasks.Count -eq 0) 'Markdown: tracker vuoto legittimo accettato'
        }
    }
    if($Case -in @('All','Provenance')){
        foreach($edited in @($false,$true)){
            $f=New-AuditFixture ('provenance-'+$edited);Put-Audit $f.source '{"tasks":[{"id":"X","status":"pending","note":"02-areas/products/Repo/personal"}],"notes":["02-areas/products/Repo/legacy"]}'
            $manifest=Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source -Activate
            $m=Read-SBTrackerManifest $f.config $manifest;$candidateHash=Get-SBFileHash $m.candidate;$archiveHash=Get-SBFileHash $m.source.archive
            $data=Read-SBJson $m.target $null;$originalJson=ConvertTo-SBJson $data.extensions.original
            if($edited){
                $shared=Join-Path $f.brain '02-areas/products/Shared/evidence.txt';Put-Audit $shared 'evidence'
                $data.tasks[0].evidence=@(@{reference=([IO.Path]::GetRelativePath($f.dir,$m.source.archive).Replace('\','/')+'#source');outcome='passed'},@{reference='../Shared/evidence.txt#shared';outcome='passed'})
                $data.history=@(@{reference=$data.tasks[0].provenance[0].reference;sha256=$archiveHash;description='source'})
                Put-Audit $m.target (ConvertTo-SBJson $data)
            }
            $meta=Read-SBJson (Join-Path $f.dir 'para.json') $null;$meta.status='retired';Put-Audit (Join-Path $f.dir 'para.json') (ConvertTo-SBJson $meta)
            foreach($operation in @('Archive','Restore')){
                & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/para.ps1') -ConfigPath $f.config.configPath -BackupRoot $f.config.backupRoot ('-'+$operation) -EntityId repo-area|Out-Null
                Assert-Next ($LASTEXITCODE -eq 0) ('provenienza: CLI '+$operation+'; modificato='+$edited)
                $m=Read-SBTrackerManifest $f.config $manifest;$data=Read-SBJson $m.target $null;$dir=Split-Path $m.target
                Assert-Next ((Test-Path -LiteralPath (Join-Path $f.brain $data.tasks[0].provenance[0].reference)) -and (Get-SBFileHash $m.source.archive) -eq $archiveHash) ('provenienza: originale risolvibile '+$operation)
                Assert-Next ((Get-SBFileHash $m.candidate) -eq $candidateHash -and (ConvertTo-SBJson $data.extensions.original) -ceq $originalJson -and $data.tasks[0].extensions.original.note -eq '02-areas/products/Repo/personal') ('provenienza: candidato e legacy intatti '+$operation)
                if($edited){
                    foreach($e in $data.tasks[0].evidence){Assert-Next (Test-Path -LiteralPath (Join-Path $dir (($e.reference -split '#',2)[0]))) ('provenienza: evidenza relativa risolvibile '+$operation)}
                    Assert-Next (Test-Path -LiteralPath (Join-Path $f.brain $data.history[0].reference)) ('provenienza: history risolvibile '+$operation)
                }
                Assert-Next (@(Get-SBTrackerImportIssues $f.config).Count -eq 0) ('provenienza: Check migrazione coerente '+$operation)
            }
            if($edited){Reject-Next {Restore-SBTrackerImport $f.config $manifest} 'provenienza: spostamento non adotta modifiche utente per il rollback'}
            else{Restore-SBTrackerImport $f.config $manifest;Assert-Next ((Get-SBFileHash $f.source) -eq $archiveHash) 'provenienza: rollback resta esatto dopo due spostamenti'}
        }
        $f=New-AuditFixture 'provenance-interrupted';Put-Audit $f.source '{"tasks":[{"id":"X","status":"pending"}]}'
        $manifest=Invoke-SBTrackerImport -Config $f.config -Identity $f.identity -SourcePath $f.source -Activate
        $m=Read-SBTrackerManifest $f.config $manifest;$beforeManifest=Get-SBFileHash $manifest;$beforeTracker=Get-SBFileHash $m.target
        $meta=Read-SBJson (Join-Path $f.dir 'para.json') $null;$meta.status='retired';Put-Audit (Join-Path $f.dir 'para.json') (ConvertTo-SBJson $meta)
        $area=@(Get-SBParaEntities $f.brain @('test'))[0];$mapping=@{$area.path='04-archives/areas/repo-area'}
        $changes=@{};foreach($change in @(Get-SBTrackerRelocationData $f.config $area $mapping)){$changes[$change.path]=$change}
        $destination=Join-Path $f.brain '04-archives/areas/repo-area';$ops=@()
        foreach($file in Get-ChildItem -LiteralPath $f.dir -File -Recurse -Force){
            $bytes=if($changes.ContainsKey($file.FullName)){$changes[$file.FullName].bytes}else{[IO.File]::ReadAllBytes($file.FullName)}
            $ops+=@{path=(Join-Path $destination ([IO.Path]::GetRelativePath($f.dir,$file.FullName)));expected='absent';bytes=$bytes}
            $ops+=@{path=$file.FullName;expected=Get-SBFileHash $file.FullName;bytes=$null}
        }
        $ops+=@(Get-SBParaReferenceOperations $f.config $mapping)
        $ops+=@(Get-SBTrackerRelocationOperations $f.config $mapping $changes)
        $allowed=@(Get-SBParaRuntimePaths $f.config)
        Set-SBWriteGuard {if((Get-SBFileHash $manifest) -ne $beforeManifest){throw 'checkpoint after manifest relocation'}}.GetNewClosure()
        try{Reject-Next {Invoke-SBParaTransaction $ops $f.config.backupRoot $f.brain $allowed} 'provenienza: interruzione dopo trasformazione tracker e manifest'}finally{Set-SBWriteGuard $null}
        $marker=Read-SBJson (Join-Path $f.brain '.runtime/para-transaction.json') $null
        $target=Join-Path $destination 'tracker.json';$deployed=Read-SBText $target;Put-Audit $target ($deployed+"`n")
        Reject-Next {Restore-SBParaTransaction $marker.manifest $f.brain $f.config.backupRoot @(Get-SBParaRuntimePaths $f.config)} 'provenienza: recupero interrotto non sovrascrive modifica successiva'
        Put-Audit $target $deployed
        & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/recover.ps1') -ManifestPath $marker.manifest -ConfigPath $f.config.configPath -Apply|Out-Null
        Assert-Next ($LASTEXITCODE -eq 0 -and (Get-SBFileHash $m.target) -eq $beforeTracker -and (Get-SBFileHash $manifest) -eq $beforeManifest) 'provenienza: recupero CLI ripristina byte tracker e manifest insieme'
        Assert-Next (!(Test-Path -LiteralPath (Join-Path $f.brain '.runtime/para-transaction.json')) -and @(Get-SBTrackerImportIssues $f.config).Count -eq 0) 'provenienza: recupero rilascia gate e conserva coerenza'
        $change=@(Get-SBTrackerRelocationData $f.config $area $mapping)[0]
        $concurrent=Read-SBJson $m.target $null
        $concurrent.tasks+=,(New-SBTrackerTask @{id='NEW';status='pending';title='Concorrente'} $f.identity 'tasks' 'fixture' ('A'*64) '/tasks/1')
        Put-Audit $m.target (ConvertTo-SBJson $concurrent)
        $copyPath=Join-Path $destination 'tracker.json'
        $raceOps=@(@{path=$copyPath;expected='absent';bytes=$change.bytes},@{path=$change.path;expected=$change.previousHash;bytes=$null})
        Reject-Next {Invoke-SBParaTransaction $raceOps $f.config.backupRoot $f.brain} 'provenienza: fonte cambiata dopo trasformazione rifiutata prima di scrivere'
        Assert-Next (!(Test-Path -LiteralPath $copyPath) -and (Read-SBJson $m.target $null).tasks.Count -eq 2) 'provenienza: task concorrente e fonte attiva conservati'
    }
    if($Case -in @('All','Recovery')){
        $f=New-AuditFixture 'recovery';$marker=Join-Path $f.brain '.runtime/para-transaction.json';Put-Audit $marker '{"manifest":"fixture-only"}'
        foreach($option in @('-Check','-Sync')){
            & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/secondbrain.ps1') -ConfigPath $f.config.configPath $option *> $null
            Assert-Next ($LASTEXITCODE -ne 0 -and (Read-SBText $marker) -eq '{"manifest":"fixture-only"}') ('recupero: gate resta chiuso '+$option)
        }
        # Verifica che recover.ps1 non sia bloccato dal gate (AllowPendingTransaction) e risolva una transazione senza record.
        $markerReal=Join-Path $f.brain '.runtime/para-transaction.json'
        $paraManifest=Join-Path $f.config.backupRoot 'para-fixture/manifest.json'
        Put-Audit $paraManifest (ConvertTo-SBJson @{schemaVersion=1;brainRoot=$f.brain;records=@()})
        Put-Audit $markerReal (ConvertTo-SBJson @{manifest=$paraManifest})
        & pwsh -NoProfile -File (Join-Path $f.brain 'scripts/recover.ps1') -ManifestPath $paraManifest -ConfigPath $f.config.configPath -Apply|Out-Null
        Assert-Next ($LASTEXITCODE -eq 0 -and !(Test-Path -LiteralPath $markerReal)) 'recupero: recover.ps1 -ConfigPath risolve transazione pendente e rimuove marker'
        Put-Audit $marker '{"manifest":"fixture-only"}'
    }
    'SUCCESS AUDIT2: '+$script:checks+' verifiche; runtime='+$PSVersionTable.PSVersion
} finally {
    Set-SBWriteGuard $null
    $full=[IO.Path]::GetFullPath($root);$boundary=[IO.Path]::GetFullPath((Get-SBTestRoot)).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture audit2 fuori TEMP'}
    if(Test-Path -LiteralPath $full){
        $entries=@(Get-ChildItem -LiteralPath $full -Force -Recurse)
        foreach($entry in $entries){if(!$entry.FullName.StartsWith($full+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Fixture audit2 non confinata'}}
        foreach($entry in $entries|Where-Object {!$_.PSIsContainer}){[IO.File]::SetAttributes($entry.FullName,[IO.FileAttributes]::Normal);[IO.File]::Delete($entry.FullName)}
        foreach($entry in $entries|Where-Object PSIsContainer|Sort-Object {$_.FullName.Length} -Descending){[IO.Directory]::Delete($entry.FullName)}
        [IO.Directory]::Delete($full)
    }
}
