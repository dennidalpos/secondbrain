# Message contract regressions, included by the tracker suite with its fixture root.
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.ExternalAudit.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sources.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Mcp.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.McpPackage.psm1')
$contractRoot = Join-Path $root "message-contract's root"
$trackerPath = Join-Path $contractRoot 'dossier/tracker.json'
$archivePath = Join-Path $contractRoot 'dossier/history/tracker-archive.json'
$backups = Join-Path $contractRoot '.runtime/backups'
$identity = 'github.com/test/messages'
$note = 'Nota privata originale: perché; not a program message.'
$history = @(
    @{description='Esiti storici espliciti usati per risolvere le dipendenze';reference='history/source.md';sha256=('A'*64)},
    @{description=$note;reference='history/note.md';sha256=('B'*64)},
    @{description='Numerazione retroattiva: 3 task (archivio e attivi) in ordine cronologico; originali conservati per hash.';reference='history/seq.json';sha256=('C'*64)}
)
$data = @{schemaVersion=1;repository=$identity;updatedAt='2026-11-03T00:00:00Z';tasks=@();history=$history;extensions=@{}}
Put-Tracker $trackerPath (ConvertTo-SBJson $data)
Put-Tracker $archivePath (ConvertTo-SBJson @{schemaVersion=1;repository=$identity;tasks=@();description=$note})
$null = Get-SBFileHash $trackerPath; $null = Get-SBFileHash $archivePath
$before = Snapshot-Tracker $contractRoot
$preview = Invoke-SBTrackerHistoryMigration -BrainRoot $contractRoot -Identity $identity -Path $trackerPath
Assert-Tracker ($preview.changed -and !$preview.applied -and $preview.files.Count -eq 2 -and (Snapshot-Tracker $contractRoot) -ceq $before) 'history migration preview preserves bytes, timestamps and directories'
$applied = Invoke-SBTrackerHistoryMigration -BrainRoot $contractRoot -Identity $identity -Path $trackerPath -BackupRoot $backups -Apply
$migrated = Read-SBJson $trackerPath $null
$archiveView = @(Get-SBTrackerHistoryMessages (Read-SBJson $archivePath $null))
Assert-Tracker ($archiveView.Count -eq 1 -and !$archiveView[0].ContainsKey('tasks') -and $archiveView[0].description -ceq $note) 'archive history view returns metadata without duplicating archived tasks'
Assert-Tracker ($applied.applied -and $migrated.history[0].code -eq 'tracker.history.dependencies' -and $migrated.history[1].code -eq 'tracker.history.note' -and $migrated.history[2].messageArgs[0] -eq 3) 'history migration recognizes only deterministic events'
Assert-Tracker ((ConvertTo-SBJson $data.tasks) -ceq (ConvertTo-SBJson $migrated.tasks) -and $migrated.history[1].description -ceq $note -and $migrated.history[1].sha256 -ceq ('B'*64)) 'history migration preserves tasks, private descriptions and provenance'
foreach ($original in $applied.originals) {
    Assert-Tracker ((Get-SBFileHash (Join-Path (Split-Path $trackerPath) $original.path)) -ceq $original.sha256) 'history migration preserves exact originals by hash'
}
$before = Snapshot-Tracker $contractRoot
$again = Invoke-SBTrackerHistoryMigration -BrainRoot $contractRoot -Identity $identity -Path $trackerPath -BackupRoot $backups -Apply
Assert-Tracker (!$again.changed -and !$again.applied -and (Snapshot-Tracker $contractRoot) -ceq $before) 'history migration is idempotent without timestamp or backup changes'
$invalid = ConvertTo-SBJson $migrated | ConvertFrom-Json -AsHashtable -DateKind String
$invalid.history[0].Remove('messageArgs')
Reject-Tracker {Test-SBTrackerData $invalid $identity @($identity) (Join-Path $PSScriptRoot '../config/tracker.schema.json')} 'history schema rejects incomplete message metadata'
Put-Tracker $trackerPath (ConvertTo-SBJson $invalid)
Reject-Tracker {Invoke-SBTrackerHistoryMigration -BrainRoot $contractRoot -Identity $identity -Path $trackerPath} 'history migration validates metadata even on an already migrated tracker'
Put-Tracker $trackerPath (ConvertTo-SBJson $migrated)
Reject-Tracker {Invoke-SBTrackerHistoryMigration -BrainRoot $contractRoot -Identity $identity -Path $trackerPath -WorkingRepository 'github.com/test/other' -Apply} 'history migration rejects a foreign working repository'
$texts = @{}; $savedLanguage = $env:SECONDBRAIN_LANG
try {
    foreach ($language in 'it','en') {
        $env:SECONDBRAIN_LANG = $language
        $view = @(Get-SBTrackerHistoryMessages $migrated)
        $audit = (Get-SBAuditResource 'https://api.github.com/repos/test/repo/issues?per_page=100' 'issues' $true @{halted=$false;reason=$null} {param($url) @{statusCode=404;headers=@{};body=$null;bodySha256=$null;errorKind=$null}}).resource
        $pagination = (Get-SBAuditResource 'https://api.github.com/repos/test/repo/issues?per_page=100' 'issues' $true @{halted=$false;reason=$null} {param($url) @{statusCode=200;headers=@{link='<https://evil.example/items>; rel="next"'};body=@();bodySha256=$null;errorKind=$null}}).resource
        $conversion = Add-SBReportDiagnostic @{reason='converter-unavailable'} 'sources'
        $publication = Add-SBReportDiagnostic @{reason='binary-review-required'} 'publication'
        Assert-Tracker ($audit.code -ceq 'audit.reason.http' -and !$audit.complete -and $audit.reason -eq 'http_404' -and $pagination.code -ceq 'audit.reason.unsafe_pagination_link') ('stable HTTP and pagination codes: '+$language)
        Assert-Tracker ($conversion.code -ceq 'sources.reason.converter-unavailable' -and $publication.code -ceq 'publication.reason.binary-review-required') ('stable conversion and publication codes: '+$language)
        Assert-Tracker ($view[1].description -ceq $note -and $view[1].message.Contains($note) -and !(Read-SBText $trackerPath).Contains('"message":')) ('localized history is a derived view: '+$language)
        $tools = @((Invoke-SBMcpMessage -BrainRoot $contractRoot -Message '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | ConvertFrom-Json -AsHashtable).result.tools)
        $texts[$language] = @{history=$view[0].message;http=$audit.message;pagination=$pagination.message;conversion=$conversion.message;publication=$publication.message;tools=$tools}
    }
    foreach ($field in 'history','http','pagination','conversion','publication') {
        Assert-Tracker ($texts.it[$field] -cne $texts.en[$field]) ('localized text with stable identity: '+$field)
    }
    Assert-Tracker (($texts.it.tools.name -join ',') -ceq ($texts.en.tools.name -join ',') -and $texts.en.tools.Count -eq 12) 'MCP localization preserves tool identities'
    for($i=0;$i -lt $texts.it.tools.Count;$i++){
        $it=$texts.it.tools[$i];$en=$texts.en.tools[$i]
        Assert-Tracker ($it.description -cne $en.description) ('MCP tool description localized: '+$it.name)
        foreach($parameter in $it.inputSchema.properties.Keys){
            Assert-Tracker ($it.inputSchema.properties[$parameter].description -cne $en.inputSchema.properties[$parameter].description) ('MCP parameter description localized: '+$it.name+'.'+$parameter)
        }
    }
} finally { $env:SECONDBRAIN_LANG = $savedLanguage }

# Interrupt after the first update; recovery must restore both input files exactly.
$recoveryRoot = Join-Path $contractRoot 'recovery'
$recoveryTracker = Join-Path $recoveryRoot 'dossier/tracker.json'
Put-Tracker $recoveryTracker (ConvertTo-SBJson $data)
$recoveryHash = Get-SBFileHash $recoveryTracker
$recoveryBackups = Join-Path $recoveryRoot '.runtime/backups'
$guard = { if((Get-SBFileHash $recoveryTracker) -cne $recoveryHash){throw 'fixture interruption after tracker update'} }.GetNewClosure()
try {
    Set-SBWriteGuard $guard
    Reject-Tracker {Invoke-SBTrackerHistoryMigration -BrainRoot $recoveryRoot -Identity $identity -Path $recoveryTracker -BackupRoot $recoveryBackups -Apply} 'history migration interruption retains a recovery journal'
} finally { Set-SBWriteGuard $null }
$marker = Read-SBJson (Join-Path $recoveryRoot '.runtime/access/para-transaction.json') $null
Assert-Tracker ($marker -and (Get-SBFileHash $recoveryTracker) -cne $recoveryHash) 'history migration records the applied change before interruption'
$deployed = Read-SBText $recoveryTracker
Put-Tracker $recoveryTracker 'concurrent edit'
Reject-Tracker {Restore-SBParaTransaction $marker.manifest $recoveryRoot $recoveryBackups} 'history recovery refuses a concurrent edit'
Assert-Tracker ((Read-SBText $recoveryTracker) -ceq 'concurrent edit') 'history recovery preserves concurrent work'
Put-Tracker $recoveryTracker $deployed
Restore-SBParaTransaction $marker.manifest $recoveryRoot $recoveryBackups | Out-Null
Assert-Tracker ((Get-SBFileHash $recoveryTracker) -ceq $recoveryHash -and !(Test-Path (Join-Path $recoveryRoot '.runtime/access/para-transaction.json'))) 'history recovery restores exact original bytes'

$package = New-SBMcpPackage -BrainRoot $contractRoot -OutDir (Join-Path $contractRoot '.runtime/package')
$installer = Join-Path $package.PackageDir 'install-all-ides.ps1'
$tokens=$null;$parseErrors=$null
[void][Management.Automation.Language.Parser]::ParseFile($installer,[ref]$tokens,[ref]$parseErrors)
Assert-Tracker (!$parseErrors.Count -and (Read-SBText $installer) -notmatch 'throw\s+["'']|Write-Host\s+["'']') 'generated MCP installer parses and has no literal error or status messages'
$probe = Join-Path $contractRoot '.runtime/package-probe.ps1'
Put-Tracker $probe 'param($Installer,$Language) $env:SECONDBRAIN_HOME=$null; try { & $Installer -Language $Language; exit 1 } catch { $failure=$_.Exception;while(!$failure.Data.Contains("code") -and $failure.InnerException){$failure=$failure.InnerException};@{code=$failure.Data["code"];message=$failure.Message}|ConvertTo-Json -Compress }'
$packageResults=@{}
foreach($language in 'it','en'){
    $packageResults[$language] = (& pwsh -NoProfile -File $probe -Installer $installer -Language $language) | ConvertFrom-Json
    Assert-Tracker ($LASTEXITCODE -eq 0 -and $packageResults[$language].code -ceq 'mcp.package.root') ('standalone MCP bootstrap code without a brain: '+$language)
}
Assert-Tracker ($packageResults.it.message -cne $packageResults.en.message) 'standalone MCP bootstrap localizes without a brain'
