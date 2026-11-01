#requires -Version 7.5
[CmdletBinding()]
param([switch]$Full)
$script:Full = [bool]$Full
Write-Output ('Runtime suite: '+$PSVersionTable.PSVersion+'; pwsh figli: '+(Get-Command pwsh).Source + $(if(!$script:Full){ ' [Modalità Fast]' }else{ ' [Modalità Full]' }))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
$script:passed=0
function Assert($Condition,[string]$Message){
    if(!$Condition){throw "FAIL: $Message"}
    $script:passed++
    if($script:Full){Write-Output "PASS: $Message"}
}
function Invoke-SubSuite([string]$Name, [scriptblock]$Action) {
    if ($script:Full) {
        & $Action
        Assert ($LASTEXITCODE -eq 0) $Name
    } else {
        $output = & $Action 2>&1
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Host ("ERRORE IN SUB-SUITE " + $Name + " (exit code " + $code + "):") -ForegroundColor Red
            $output | ForEach-Object { Write-Output $_ }
            throw "FAIL: $Name fallito con codice $code"
        }
        $summary = @($output | Where-Object { $_ -match '^(?:SUCCESS|PASS:)\s*' })
        if ($summary.Count) {
            Write-Output ($summary[-1])
        } else {
            Write-Output ("SUCCESS " + $Name + ": verifiche superate (exit code 0)")
        }
        $script:passed++
    }
}
function Throws([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Assert $caught $Message}
function Put([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Git([string]$Path,[string[]]$Arguments){$r=Invoke-SBGit $Path $Arguments;if($r.code -ne 0){throw $r.error};$r.output}
$root=Join-Path (Get-SBTestRoot) ('secondbrain-v3-test-'+[guid]::NewGuid().ToString('N'))
$backup=Join-Path (Get-SBTestRoot) ('secondbrain-test-backup-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root)|Out-Null
$success=$false
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
    $brain=Join-Path $root 'brain'
    [IO.Directory]::CreateDirectory((Join-Path $brain 'scripts'))|Out-Null
    Get-ChildItem $PSScriptRoot -File | Where-Object Name -ne 'test-secondbrain.ps1' | Copy-Item -Destination (Join-Path $brain 'scripts')
    # I flussi CLI usano codice di produzione, file, Git e processi reali isolati.
    Put (Join-Path $brain 'config/shared.json') (ConvertTo-SBJson @{schemaVersion=3;allowedOwners=@('test');excludedDirectories=@('.git','node_modules')})
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
    Put $restoreConfig (ConvertTo-SBJson @{schemaVersion=3;mode='portable';workstationId='restore';runtimeRoot=$restoreRuntime;backupRoot=(Join-Path $restoreRuntime 'backups');bindings=@();ides=@()})
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/restore-managed.ps1') -MetadataPath $metadata.FullName -ConfigPath $restoreConfig | Out-Null
    Assert ($LASTEXITCODE -eq 0 -and (Get-SBFileHash $path) -eq $hash) 'CLI ripristino esatto'
    & pwsh -NoProfile -File (Join-Path $brain 'scripts/restore-managed.ps1') -MetadataPath $metadata.FullName -ConfigPath $restoreConfig *> $null
    Assert ($LASTEXITCODE -ne 0 -and (Get-SBFileHash $path) -eq $hash) 'CLI ripristino rifiuta destinazione cambiata'
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
    
    Invoke-SubSuite 'Portabile: discovery, attivazione, compattazione, pubblicazione e asset' {
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test-secondbrain-portable.ps1')
    }
    Invoke-SubSuite 'Workflow v2: catalogo, contesto Git/PARA, composizione e output' {
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test-secondbrain-workflows.ps1')
    }
    Invoke-SubSuite 'Fonti: registro, sicurezza, acquisizione, confronto e conversione' {
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test-secondbrain-sources.ps1')
    }
    Invoke-SubSuite 'Tracker: conversioni, resolver, riferimenti, migrazione e recupero' {
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test-secondbrain-trackers.ps1')
    }
    Invoke-SubSuite 'Audit2: rimozione protetta, Markdown, provenienza e recupero' {
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test-secondbrain-audit2.ps1')
    }
    Invoke-SubSuite 'Audit esterno: paginazione, copertura, errori e protezione dei contenuti' {
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test-secondbrain-external-audit.ps1')
    }

    foreach($script in Get-ChildItem $PSScriptRoot -File|Where-Object Extension -in @('.ps1','.psm1')){
        $tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)|Out-Null
        Assert ($errors.Count -eq 0) ('parser '+$script.Name)
    }
    if (!$script:Full) {
        Write-Output "SUCCESS PARSER: tutti gli script analizzati senza errori di sintassi"
    }
    $success=$true
    "SUCCESS: $script:passed verifiche; nessun accesso a dati applicativi o remote di rete."
} finally {
    if($success){
        foreach($target in @($root,$backup)){
            $resolved=[IO.Path]::GetFullPath($target)
            $allowed=if($target -eq $root){[IO.Path]::GetFullPath((Get-SBTestRoot))}else{[IO.Path]::GetFullPath((Get-SBTestRoot))}

            if(Test-Path -LiteralPath $resolved){Write-Output ('Fixture conservata: '+$resolved)}
        }
    }else{"Fixture conservata: $root"}
}
