#requires -Version 7.5
Set-StrictMode -Version Latest

# Message catalog: every user-visible message has a stable key and one text per language.
# Placeholders use .NET composite format ({0}, {1}); the text of a missing language falls back to en, then it, then the key.
$script:SBSupportedLanguages = @('en', 'it')
$script:SBLanguageOverride = $null
$script:SBLanguageProvider = $null
$script:SBMessages = @{}

function Set-SBUiLanguage([string]$Language) {
    # Explicit override (for example from -Language); an empty value removes it.
    if ($Language -and $Language -notin $script:SBSupportedLanguages) {
        throw ("Unsupported language '{0}'. Supported: {1}" -f $Language, ($script:SBSupportedLanguages -join ', '))
    }
    $script:SBLanguageOverride = if ($Language) { $Language } else { $null }
}
function Set-SBUiLanguageProvider([scriptblock]$Provider) {
    # Registered by the module that can read the workstation configuration (kept out of here to avoid a module cycle).
    $script:SBLanguageProvider = $Provider
}
function ConvertTo-SBLanguageCode($Value) {
    if ($null -eq $Value) { return $null }
    $code = ([string]$Value).Trim().ToLowerInvariant()
    if ($code.Length -lt 2) { return $null }
    $code = $code.Substring(0, 2)
    if ($code -in $script:SBSupportedLanguages) { $code } else { $null }
}
function Get-SBUiLanguage {
    # Order: explicit override, SECONDBRAIN_LANG, workstation configuration, system UI culture, en.
    $explicit = ConvertTo-SBLanguageCode $script:SBLanguageOverride
    if ($explicit) { return $explicit }
    $fromEnvironment = ConvertTo-SBLanguageCode $env:SECONDBRAIN_LANG
    if ($fromEnvironment) { return $fromEnvironment }
    if ($script:SBLanguageProvider) {
        $fromConfiguration = $null
        try { $fromConfiguration = ConvertTo-SBLanguageCode (& $script:SBLanguageProvider) } catch { }
        if ($fromConfiguration) { return $fromConfiguration }
    }
    $fromCulture = ConvertTo-SBLanguageCode ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName)
    if ($fromCulture) { $fromCulture } else { 'en' }
}
function Add-SBMessages([hashtable]$Messages) {
    foreach ($key in $Messages.Keys) { $script:SBMessages[$key] = $Messages[$key] }
}
function Get-SBMessage([string]$Key, [object[]]$Arguments = @(), [string]$Language) {
    $entry = $script:SBMessages[$Key]
    if ($null -eq $entry) { return $Key }
    $code = if ($Language) { ConvertTo-SBLanguageCode $Language } else { Get-SBUiLanguage }
    $template = $null
    foreach ($candidate in @($code, 'en', 'it')) {
        if ($candidate -and $entry.ContainsKey($candidate)) { $template = [string]$entry[$candidate]; break }
    }
    if ($null -eq $template) { return $Key }
    if ($Arguments.Count -eq 0) { $template } else { $template -f $Arguments }
}
function New-SBError([string]$Key, [object[]]$Arguments = @(), [type]$Type, [int]$HResult = 0, [Exception]$Inner) {
    # The exception carries the stable key in Data['code'] so callers and tests match the code, not the text.
    $text = Get-SBMessage $Key $Arguments
    $exception = if ($Type -eq [IO.IOException]) {
        if ($Inner) { [IO.IOException]::new($text, $Inner) } elseif ($HResult) { [IO.IOException]::new($text, $HResult) } else { [IO.IOException]::new($text) }
    } else { [InvalidOperationException]::new($text) }
    $exception.Data['code'] = $Key
    $exception
}
function Test-SBError($ErrorRecord, [string]$Key) {
    $exception = if ($ErrorRecord -is [Management.Automation.ErrorRecord]) { $ErrorRecord.Exception } else { $ErrorRecord }
    while ($null -ne $exception) {
        if ($exception.Data.Contains('code') -and $exception.Data['code'] -ceq $Key) { return $true }
        $exception = $exception.InnerException
    }
    $false
}

Add-SBMessages @{
    'core.version.missing'      = @{ it = 'File VERSION mancante'; en = 'VERSION file missing' }
    'core.reparse.unwritable'   = @{ it = 'Reparse point non scrivibile: {0}'; en = 'Reparse point is not writable: {0}' }
    'core.concurrent.modified'  = @{ it = 'Modifica concorrente: {0}'; en = 'Concurrent modification: {0}' }
    'core.runtime.reason.reparse-point' = @{ it = 'reparse point: non seguito'; en = 'reparse point: not followed' }
    'core.runtime.reason.runtime-access' = @{ it = 'sessioni e lock di accesso'; en = 'access sessions and locks' }
    'core.runtime.reason.runtime-hosts' = @{ it = 'configurazione e backup delle postazioni'; en = 'workstation configuration and backups' }
    'core.runtime.reason.runtime-cleanup' = @{ it = 'registro delle pulizie (prova di recuperabilita)'; en = 'cleanup log (recoverability proof)' }
    'core.runtime.reason.runtime-state' = @{ it = 'stato operativo'; en = 'operational state' }
    'core.runtime.reason.runtime-para-marker' = @{ it = 'marker di transazione pendente'; en = 'pending transaction marker' }
    'core.runtime.reason.config-path' = @{ it = 'percorso della configurazione o del registro postazioni'; en = 'configuration or workstation registry path' }
    'core.runtime.reason.protected-path' = @{ it = 'contiene percorsi della configurazione o degli accessi'; en = 'contains configuration or access paths' }
    'core.runtime.reason.recently-written' = @{ it = 'scritta negli ultimi {0} minuti: potrebbe essere in uso'; en = 'written in the last {0} minutes: it may be in use' }
    'core.write.contended'      = @{ it = 'Scrittura contesa: il file è in uso o è stato sostituito da un altro scrittore: {0}'; en = 'Write contended: the file is in use or was replaced by another writer: {0}' }
    'core.tracked.dirty'        = @{ it = "File tracciato con modifiche non committate: {0}. Committa o metti da parte (git stash) le modifiche al file, poi ripeti l'operazione."; en = 'Tracked file has uncommitted changes: {0}. Commit or stash (git stash) the file changes, then retry.' }
    'core.readback.staging'     = @{ it = 'Readback staging fallito'; en = 'Staging readback failed' }
    'core.race.kept'            = @{ it = 'Gara di scrittura rilevata; copia concorrente conservata: {0}'; en = 'Write race detected; concurrent copy kept: {0}' }
    'core.backup.unverified'    = @{ it = 'Backup non verificato; recupero locale: {0}'; en = 'Backup not verified; local recovery: {0}' }
    'core.readback.destination' = @{ it = 'Readback destinazione fallito: {0}'; en = 'Destination readback failed: {0}' }
    'core.staging.kept'         = @{ it = 'Staging transazionale conservato: {0}'; en = 'Transactional staging kept: {0}' }
    'core.olderthan.min'        = @{ it = 'OlderThanDays deve essere almeno 1'; en = 'OlderThanDays must be at least 1' }
    'core.runtime.outside'      = @{ it = 'Percorso fuori da .runtime'; en = 'Path outside .runtime' }
    'core.runtime.reparse'      = @{ it = 'Reparse point non rimovibile con questo passo'; en = 'Reparse point cannot be removed by this step' }
    'core.checkout.ambiguous'   = @{ it = 'Associazione checkout ambigua'; en = 'Ambiguous checkout binding' }
    'core.origin.changed'       = @{ it = 'Origin cambiato: riconciliazione esplicita richiesta'; en = 'Origin changed: explicit reconciliation required' }
    'core.workstation.invalid'  = @{ it = 'WorkstationId non valido'; en = 'Invalid WorkstationId' }
    'core.output.outside'       = @{ it = 'Output operativo fuori da SecondBrain/.runtime: {0}'; en = 'Operational output outside SecondBrain/.runtime: {0}' }
    'core.block.duplicate'      = @{ it = 'Blocco duplicato: {0}'; en = 'Duplicate block: {0}' }
    'core.block.incomplete'     = @{ it = 'Blocco incompleto: {0}'; en = 'Incomplete block: {0}' }
    'core.remove.outside'       = @{ it = 'Rimozione fuori perimetro: {0}'; en = 'Removal outside scope: {0}' }
    'core.remove.changed'       = @{ it = 'File cambiato prima della rimozione: {0}'; en = 'File changed before removal: {0}' }
    'core.remove.concurrent'    = @{ it = 'Modifica concorrente prima della rimozione'; en = 'Concurrent modification before removal' }
    'core.git.batchcheck'       = @{ it = 'Git cat-file --batch-check non riuscito: {0}'; en = 'Git cat-file --batch-check failed: {0}' }
    'core.git.stream'           = @{ it = 'Git cat-file --batch: flusso interrotto'; en = 'Git cat-file --batch: stream interrupted' }
    'core.git.header'           = @{ it = 'Git cat-file --batch: intestazione inattesa: {0}'; en = 'Git cat-file --batch: unexpected header: {0}' }
    'core.git.timeout'          = @{ it = 'Git timeout: {0}'; en = 'Git timeout: {0}' }
    'core.remove.backup'        = @{ it = 'Backup rimozione non verificato'; en = 'Removal backup not verified' }
}

Export-ModuleMember -Function Set-SBUiLanguage, Set-SBUiLanguageProvider, Get-SBUiLanguage, Add-SBMessages, Get-SBMessage, New-SBError, Test-SBError
