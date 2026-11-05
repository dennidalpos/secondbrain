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
        throw (New-SBError 'messages.language.invalid' @($Language, ($script:SBSupportedLanguages -join ', ')))
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
    if ($null -eq $Arguments -or $Arguments.Count -eq 0) { $template } else { $template -f $Arguments }
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

function Add-SBReportDiagnostic([System.Collections.IDictionary]$Record, [string]$Prefix) {
    # Only call on program-owned diagnostics: user notes and policy reasons are data.
    $reason = if ($Record.Contains('reason')) { [string]$Record.reason } else { '' }
    $Record['code'] = $null; $Record['message'] = $null
    if (!$reason) { return $Record }
    $key = $Prefix + '.reason.' + $reason
    $arguments = @()
    if ($reason -match '^http[-_](\d{3})$') { $key = $Prefix + '.reason.http'; $arguments = @([int]$Matches[1]) }
    if (!$script:SBMessages.ContainsKey($key)) { $key = 'report.reason.unverified' }
    $Record['code'] = $key
    $Record['message'] = Get-SBMessage $key $arguments
    $Record
}

Add-SBMessages @{
    'messages.language.invalid' = @{ it = "Lingua non supportata '{0}'. Supportate: {1}"; en = "Unsupported language '{0}'. Supported: {1}" }
    'report.reason.unverified' = @{ it = 'Esito non verificabile; consultare i dettagli tecnici'; en = 'Outcome could not be verified; see technical details' }
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
    'core.runtime.reason.identity-unverified' = @{ it = 'identita della postazione o del proprietario non verificabile'; en = 'workstation or owner identity is not verifiable' }
    'core.runtime.reason.unsupported-layout' = @{ it = 'fuori dal layout fixture/tmp annidato: dati conservati'; en = 'outside the nested fixture/tmp layout: data retained' }
    'core.runtime.reason.foreign-host' = @{ it = 'cartella di un altra postazione: dati conservati'; en = 'folder belongs to another workstation: data retained' }
    'core.runtime.reason.foreign-owner' = @{ it = 'manifest di un altro proprietario: dati conservati'; en = 'manifest belongs to another owner: data retained' }
    'core.runtime.reason.manifest-missing' = @{ it = 'MANIFEST.json assente: dati conservati'; en = 'MANIFEST.json missing: data retained' }
    'core.runtime.reason.manifest-invalid' = @{ it = 'manifest illeggibile, non supportato o incoerente con il percorso'; en = 'manifest unreadable, unsupported or inconsistent with its path' }
    'core.runtime.reason.manifest-not-closed' = @{ it = 'manifest non chiuso: dati conservati'; en = 'manifest is not closed: data retained' }
    'core.runtime.reason.manifest-expiry-invalid' = @{ it = 'scadenza del manifest assente o non valida'; en = 'manifest expiry missing or invalid' }
    'core.runtime.reason.manifest-not-expired' = @{ it = 'scadenza non trascorsa (il giorno di scadenza e incluso)'; en = 'expiry has not passed (the expiry day is included)' }
    'core.runtime.reason.retention' = @{ it = 'cartella tra le ultime da conservare per repository e categoria'; en = 'folder is among the latest retained per repository and category' }
    'core.runtime.reason.inspection-failed' = @{ it = 'ispezione incompleta: nessuna rimozione autorizzata dal piano'; en = 'inspection incomplete: the plan does not permit removal' }
    'core.runtime.reason.target-changed' = @{ it = 'target modificato o non piu idoneo dopo la selezione: dati conservati'; en = 'target changed or no longer eligible after selection: data retained' }
    'core.runtime.regenerable.recovery' = @{ it = 'ricreare con la suite o il comando indicato dal task nel manifest; verificare i riferimenti prima di autorizzare'; en = 'recreate with the suite or command identified by the manifest task; review references before authorizing' }
    'core.write.contended'      = @{ it = 'Scrittura contesa: il file è in uso o è stato sostituito da un altro scrittore: {0}'; en = 'Write contended: the file is in use or was replaced by another writer: {0}' }
    'core.write.denied'         = @{ it = 'Accesso negato durante la scrittura: {0}'; en = 'Access denied while writing: {0}' }
    'core.write.retry'          = @{ it = 'Ripeti in PowerShell 7.5+ fuori dalla sandbox: {0}'; en = 'Retry in PowerShell 7.5+ outside the sandbox: {0}' }
    'core.retry.parameter'      = @{ it = 'Nome parametro non valido per il comando di ripetizione'; en = 'Invalid parameter name for the retry command' }
    'core.write.finalization'   = @{ it = 'Registrazione finale non riuscita; errore originale conservato ({0}): {1}'; en = 'Final record failed; original error preserved ({0}): {1}' }
    'trace.event.lost'          = @{ it = 'Evento Trace perso: {0}'; en = 'Trace event lost: {0}' }
    'core.tracked.dirty'        = @{ it = "File tracciato con modifiche non committate: {0}. Committa o metti da parte (git stash) le modifiche al file, poi ripeti l'operazione."; en = 'Tracked file has uncommitted changes: {0}. Commit or stash (git stash) the file changes, then retry.' }
    'core.readback.staging'     = @{ it = 'Readback staging fallito'; en = 'Staging readback failed' }
    'core.race.kept'            = @{ it = 'Gara di scrittura rilevata; copia concorrente conservata: {0}'; en = 'Write race detected; concurrent copy kept: {0}' }
    'core.backup.unverified'    = @{ it = 'Backup non verificato; recupero locale: {0}'; en = 'Backup not verified; local recovery: {0}' }
    'core.readback.destination' = @{ it = 'Readback destinazione fallito: {0}'; en = 'Destination readback failed: {0}' }
    'core.staging.kept'         = @{ it = 'Staging transazionale conservato: {0}'; en = 'Transactional staging kept: {0}' }
    'core.migrate.destination'  = @{ it = 'Destinazione già esistente: {0}'; en = 'Destination already exists: {0}' }
    'core.olderthan.min'        =@{ it = 'OlderThanDays deve essere almeno 1'; en = 'OlderThanDays must be at least 1' }
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

Export-ModuleMember -Function Set-SBUiLanguage, Set-SBUiLanguageProvider, Get-SBUiLanguage, Add-SBMessages, Get-SBMessage, New-SBError, Test-SBError, Add-SBReportDiagnostic
