#requires -Version 7.5
<#
.SYNOPSIS
Prova di coordinamento (FileShare.None, scritture concorrenti, ExecutionPolicy, permessi) su una share SMB di loopback.

.DESCRIPTION
Esegue la checklist di docs/riferimento/shared-brain.md su una share raggiunta da questo stesso PC e dallo stesso utente:
UNC con localhost, 127.0.0.1, nome macchina e FQDN. Non crea share né utenti: per impostazione predefinita usa la
share amministrativa dell'unità del clone (\\<alias>\D$), che passa dallo stack SMB (client e server). Con -ShareRoot
si indica una share diversa (per esempio creata a mano con New-SmbShare).

Limiti dichiarati: un solo PC e un solo utente; nessun NAS/Samba. L'esito massimo e quindi partial.
La fixture resta sotto .runtime/tests (cartella smb-<data>) fino a una pulizia richiesta; il rapporto e report.json.

.EXAMPLE
pwsh -NoProfile -File scripts/test-secondbrain-smb.ps1
pwsh -NoProfile -File scripts/test-secondbrain-smb.ps1 -ShareRoot \\localhost\sbtest -ShareLocalPath C:\sbtest
#>
[CmdletBinding()]
param(
    [string]$ShareRoot,
    [string]$ShareLocalPath,
    [string[]]$Aliases,
    [int]$Writers = 4,
    [int]$HoldMs = 400
)
$ErrorActionPreference = 'Stop'
$brain = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$failures = [Collections.Generic.List[string]]::new()
$results = [Collections.Generic.List[object]]::new()
function Add-Result([string]$Name, [bool]$Ok, [string]$Detail = '', [switch]$Informational) {
    $results.Add([pscustomobject]@{ name = $Name; ok = $Ok; informational = [bool]$Informational; detail = $Detail })
    $mark = if ($Ok) { 'OK ' } elseif ($Informational) { 'INFO' } else { 'FAIL' }
    Write-Host ("[{0}] {1}{2}" -f $mark, $Name, $(if ($Detail) { ' - ' + $Detail } else { '' }))
    if (!$Ok -and !$Informational) { $failures.Add($Name) }
}

# Radice della share e percorso locale equivalente.
if (!$ShareRoot) {
    $drive = [IO.Path]::GetPathRoot($brain).Substring(0, 1)
    $ShareRoot = '\\localhost\' + $drive + '$'
    $ShareLocalPath = $drive + ':\'
}
if (!$ShareLocalPath) { throw 'Con -ShareRoot indicare anche -ShareLocalPath (percorso locale della share)' }
$shareHost = if ($ShareRoot -match '^\\\\([^\\]+)\\') { $Matches[1] } else { throw 'ShareRoot deve essere un percorso UNC' }
$shareName = ($ShareRoot -replace '^\\\\[^\\]+\\', '').TrimEnd('\')
if (!$Aliases) {
    $fqdn = try { [Net.Dns]::GetHostEntry([Net.Dns]::GetHostName()).HostName } catch { $null }
    $Aliases = @('localhost', '127.0.0.1', [Environment]::MachineName) + @($(if ($fqdn -and $fqdn -ine [Environment]::MachineName) { $fqdn }))
    $Aliases = @($Aliases | Select-Object -Unique)
}
$stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss')
$localFixture = Join-Path $brain ('.runtime\tests\smb-' + $stamp)
New-Item -ItemType Directory -Force -Path $localFixture | Out-Null
$relative = [IO.Path]::GetRelativePath($ShareLocalPath, $localFixture)
if ($relative.StartsWith('..')) { throw 'La fixture deve stare sotto il percorso locale della share' }
function Get-UncPath([string]$Alias, [string]$Leaf = '') {
    $base = '\\' + $Alias + '\' + $shareName + '\' + $relative
    if ($Leaf) { Join-Path $base $Leaf } else { $base }
}
Write-Host "Share: $ShareRoot  Fixture: $localFixture  Alias: $($Aliases -join ', ')"

# Script figli, scritti nella fixture locale.
$tools = Join-Path $localFixture 'tools'; New-Item -ItemType Directory -Force -Path $tools | Out-Null
Set-Content -LiteralPath (Join-Path $tools 'holder.ps1') -Encoding utf8 -Value @'
param($Path,$Ready,$Stop)
$h=[IO.File]::Open($Path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
[IO.File]::WriteAllText($Ready,'ready')
$end=[DateTime]::UtcNow.AddSeconds(90)
while(![IO.File]::Exists($Stop) -and [DateTime]::UtcNow -lt $end){Start-Sleep -Milliseconds 100}
$h.Dispose()
'@
Set-Content -LiteralPath (Join-Path $tools 'contender.ps1') -Encoding utf8 -Value @'
param($Path,$Out)
try{$h=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$h.Dispose();[IO.File]::WriteAllText($Out,'OPENED')}
catch{$hr=$_.Exception.GetBaseException().HResult -band 0xffff;[IO.File]::WriteAllText($Out,"HR=$hr")}
'@
Set-Content -LiteralPath (Join-Path $tools 'writer.ps1') -Encoding utf8 -Value @'
param($Scripts,$Lock,$Log,$Id,$Hold)
Import-Module (Join-Path $Scripts 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $Scripts 'SecondBrain.Access.psm1') -Force
$t0=[DateTime]::UtcNow
$h=Open-SBLockFile $Lock ([IO.FileMode]::OpenOrCreate) ([IO.FileAccess]::ReadWrite) ([IO.FileShare]::None) 90000
$enter=[DateTime]::UtcNow.Ticks
Start-Sleep -Milliseconds $Hold
$leave=[DateTime]::UtcNow.Ticks
$h.Dispose()
$line="$Id;$enter;$leave;$([int]([DateTime]::UtcNow-$t0).TotalMilliseconds)`n"
for($i=0;$i -lt 50;$i++){try{[IO.File]::AppendAllText($Log,$line);break}catch{Start-Sleep -Milliseconds 50}}
'@
Set-Content -LiteralPath (Join-Path $tools 'fifo-writer.ps1') -Encoding utf8 -Value @'
param($Scripts,$Root,$Log,$Id,$Stop)
Import-Module (Join-Path $Scripts 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $Scripts 'SecondBrain.Access.psm1') -Force
$h=Open-SBWriterLock @{coordinationRoot=$Root;workstationId='smb-fifo'} (Join-Path $Root 'writer.lock') 90000
$enter=[DateTime]::UtcNow.Ticks
$end=[DateTime]::UtcNow.AddSeconds(90)
while($Stop -and ![IO.File]::Exists($Stop) -and [DateTime]::UtcNow -lt $end){Start-Sleep -Milliseconds 100}
$leave=[DateTime]::UtcNow.Ticks
$h.Dispose()
$line="$Id;$enter;$leave`n"
for($i=0;$i -lt 50;$i++){try{[IO.File]::AppendAllText($Log,$line);break}catch{Start-Sleep -Milliseconds 50}}
'@
Set-Content -LiteralPath (Join-Path $tools 'probe.ps1') -Encoding utf8 -Value "'probe-ok'"

function Start-Child([string]$Script, [string[]]$Arguments, [string[]]$Pre = @()) {
    Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList (@('-NoProfile') + $Pre + @('-File', (Join-Path $tools $Script)) + $Arguments) -PassThru -WindowStyle Hidden
}
function Wait-File([string]$Path, [int]$Seconds = 30) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while (![IO.File]::Exists($Path) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    [IO.File]::Exists($Path)
}

# 1. Raggiungibilita, scrittura e lettura con hash per ogni alias.
foreach ($alias in $Aliases) {
    try {
        $dir = Get-UncPath $alias
        $file = Join-Path $dir ("rw-$($alias -replace '[^A-Za-z0-9]','_').bin")
        $bytes = [byte[]]::new(1048576); [Random]::new(7).NextBytes($bytes)
        [IO.File]::WriteAllBytes($file, $bytes)
        $same = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -eq [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($bytes)).Replace('-', '')
        Add-Result "scrittura e lettura 1 MiB via $alias" $same
    } catch { Add-Result "scrittura e lettura 1 MiB via $alias" $false $_.Exception.Message }
}

# 2. FileShare.None: un titolare su un alias, sfidanti su tutti gli alias e sul percorso locale.
$holderAlias = $Aliases[0]
$lockLeaf = 'exclusive.lock'
$lockHolderPath = Get-UncPath $holderAlias $lockLeaf
$ready = Join-Path $localFixture 'holder.ready'; $stop = Join-Path $localFixture 'holder.stop'
$holder = Start-Child 'holder.ps1' @($lockHolderPath, $ready, $stop)
try {
    if (!(Wait-File $ready)) { throw 'Il titolare non ha preso il lock' }
    $targets = @($Aliases | ForEach-Object { @{ label = "UNC $_"; path = (Get-UncPath $_ $lockLeaf) } }) + @(@{ label = 'percorso locale'; path = (Join-Path $localFixture $lockLeaf) })
    $i = 0
    foreach ($target in $targets) {
        $out = Join-Path $localFixture ("contender-$((++$i)).txt")
        $child = Start-Child 'contender.ps1' @($target.path, $out)
        $child.WaitForExit(60000) | Out-Null
        $answer = if ([IO.File]::Exists($out)) { [IO.File]::ReadAllText($out) } else { 'nessun esito' }
        Add-Result "lock FileShare.None tenuto via $holderAlias respinge $($target.label)" ($answer -in @('HR=32', 'HR=33')) $answer
    }
} finally {
    [IO.File]::WriteAllText($stop, 'stop')
    if ($holder -and !$holder.WaitForExit(15000)) { $holder.Kill() }
}
$out = Join-Path $localFixture 'contender-after.txt'
(Start-Child 'contender.ps1' @((Get-UncPath $Aliases[-1] $lockLeaf), $out)).WaitForExit(60000) | Out-Null
Add-Result 'lock rilasciato alla chiusura del titolare' ([IO.File]::ReadAllText($out) -eq 'OPENED') ([IO.File]::ReadAllText($out))

# 2b. Titolare terminato con Kill: il sistema rilascia il lock (nessun marker da ripulire).
Remove-Item -LiteralPath $ready, $stop -Force -ErrorAction SilentlyContinue
$holder = Start-Child 'holder.ps1' @($lockHolderPath, $ready, $stop)
if (Wait-File $ready) {
    $holder.Kill(); $holder.WaitForExit(15000) | Out-Null
    $out = Join-Path $localFixture 'contender-killed.txt'
    $opened = $false
    for ($try = 0; $try -lt 20 -and !$opened; $try++) {
        Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
        (Start-Child 'contender.ps1' @((Get-UncPath $Aliases[-1] $lockLeaf), $out)).WaitForExit(60000) | Out-Null
        $opened = [IO.File]::Exists($out) -and [IO.File]::ReadAllText($out) -eq 'OPENED'
        if (!$opened) { Start-Sleep -Milliseconds 500 }
    }
    Add-Result 'lock rilasciato dopo la terminazione forzata del titolare' $opened $(if ($opened) { '' } else { 'ancora occupato dopo 10 s' })
} else { Add-Result 'lock rilasciato dopo la terminazione forzata del titolare' $false 'titolare non avviato' }

# 3. Scritture concorrenti con Open-SBLockFile del modulo, un alias diverso per ogni processo.
$log = Join-Path $localFixture 'writers.log'
$writerLock = Get-UncPath $Aliases[0] 'writer.lock'
New-Item -ItemType Directory -Force -Path (Split-Path (Get-UncPath $Aliases[0] 'x')) | Out-Null
$procs = for ($n = 0; $n -lt $Writers; $n++) {
    $alias = $Aliases[$n % $Aliases.Count]
    Start-Child 'writer.ps1' @((Join-Path $brain 'scripts'), (Get-UncPath $alias 'writer.lock'), $log, "w$n@$alias", "$HoldMs")
}
foreach ($p in $procs) { $p.WaitForExit(180000) | Out-Null }
$lines = if ([IO.File]::Exists($log)) { @([IO.File]::ReadAllLines($log) | Where-Object { $_ }) } else { @() }
$intervals = @($lines | ForEach-Object { $f = $_ -split ';'; [pscustomobject]@{ id = $f[0]; enter = [long]$f[1]; leave = [long]$f[2]; waitedMs = [int]$f[3] } } | Sort-Object enter)
$overlap = $false
for ($k = 1; $k -lt $intervals.Count; $k++) { if ($intervals[$k].enter -lt $intervals[$k - 1].leave) { $overlap = $true } }
Add-Result "scritture concorrenti ($Writers processi, alias diversi): tutte completate" ($intervals.Count -eq $Writers) "$($intervals.Count)/$Writers"
Add-Result 'scritture concorrenti: mutua esclusione (nessuna sovrapposizione)' (!$overlap -and $intervals.Count -gt 1) (($intervals | ForEach-Object { "$($_.id) attesa $($_.waitedMs) ms" }) -join '; ')

# 3b. Coda FIFO (Open-SBWriterLock): il primo writer tiene il lock, gli altri si accodano uno alla volta (ordine di arrivo noto) e devono entrare nello stesso ordine.
$fifoRoot = Get-UncPath $Aliases[0] 'fifo-coord'
New-Item -ItemType Directory -Force -Path $fifoRoot | Out-Null
$fifoLog = Join-Path $localFixture 'fifo.log'; $fifoStop = Join-Path $localFixture 'fifo.stop'
$fifoProcs = [Collections.Generic.List[object]]::new()
$fifoReady = $true
for ($n = 0; $n -lt $Writers -and $fifoReady; $n++) {
    $alias = $Aliases[$n % $Aliases.Count]
    $fifoProcs.Add((Start-Child 'fifo-writer.ps1' @((Join-Path $brain 'scripts'), (Get-UncPath $alias 'fifo-coord'), $fifoLog, "w$n", $fifoStop)))
    # Il successivo parte solo quando il precedente e visibile: w0 ha il lock (writer.lock creato), gli altri hanno un ticket in coda.
    $fifoReady = if ($n -eq 0) { Wait-File (Join-Path $fifoRoot 'writer.lock') 60 } else {
        $queued = 0
        for ($t = 0; $t -lt 240 -and $queued -lt $n; $t++) { $queued = @(Get-ChildItem -LiteralPath (Join-Path $fifoRoot 'queue') -Filter '*.lease' -File -ErrorAction SilentlyContinue).Count; if ($queued -lt $n) { Start-Sleep -Milliseconds 250 } }
        $queued -ge $n
    }
}
[IO.File]::WriteAllText($fifoStop, 'stop')
foreach ($p in $fifoProcs) { if (!$p.WaitForExit(180000)) { $p.Kill() } }
$fifoLines = if ([IO.File]::Exists($fifoLog)) { @([IO.File]::ReadAllLines($fifoLog) | Where-Object { $_ }) } else { @() }
$fifoOrder = @($fifoLines | ForEach-Object { $f = $_ -split ';'; [pscustomobject]@{ id = $f[0]; enter = [long]$f[1]; leave = [long]$f[2] } } | Sort-Object enter)
$expectedOrder = (0..($Writers - 1) | ForEach-Object { "w$_" }) -join ','
$fifoOverlap = $false
for ($k = 1; $k -lt $fifoOrder.Count; $k++) { if ($fifoOrder[$k].enter -lt $fifoOrder[$k - 1].leave) { $fifoOverlap = $true } }
$actualOrder = ($fifoOrder | ForEach-Object id) -join ','
Add-Result "coda FIFO su share ($Writers writer, alias diversi): ingresso in ordine di arrivo" ($fifoReady -and $actualOrder -eq $expectedOrder -and !$fifoOverlap) "atteso $expectedOrder, osservato $actualOrder"

# 4. ExecutionPolicy: esito osservato per alias (informativo, dipende da zona e criterio).
Copy-Item -LiteralPath (Join-Path $tools 'probe.ps1') -Destination (Get-UncPath $Aliases[0] 'probe.ps1') -Force
$pwsh = (Get-Process -Id $PID).Path
foreach ($alias in $Aliases) {
    foreach ($policy in @('Default', 'RemoteSigned', 'Bypass')) {
        $argList = @('-NoProfile') + $(if ($policy -ne 'Default') { @('-ExecutionPolicy', $policy) }) + @('-File', (Get-UncPath $alias 'probe.ps1'))
        $text = (& $pwsh @argList 2>&1 | Out-String).Trim()
        Add-Result "ExecutionPolicy $policy, script su UNC $alias" ($LASTEXITCODE -eq 0 -and $text -eq 'probe-ok') $(if ($text.Length -gt 120) { $text.Substring(0, 120) } else { $text }) -Informational
    }
}
Add-Result 'ExecutionPolicy effettiva (Get-ExecutionPolicy -List)' $true ((Get-ExecutionPolicy -List | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" }) -join ', ') -Informational

# 5. Permessi: una cartella con negazione esplicita deve restare negata attraverso SMB (informativo).
$denyDir = Join-Path $localFixture 'deny-probe'
New-Item -ItemType Directory -Force -Path $denyDir | Out-Null
[IO.File]::WriteAllText((Join-Path $denyDir 'secret.txt'), 'x')
$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls $denyDir /deny "${me}:(OI)(CI)(R)" | Out-Null
try {
    $viaUnc = try { [IO.File]::ReadAllText((Join-Path (Get-UncPath $Aliases[0]) 'deny-probe\secret.txt')) | Out-Null; 'lettura consentita' } catch [UnauthorizedAccessException] { 'negata' } catch { 'errore: ' + $_.Exception.GetType().Name }
    Add-Result 'permessi: la negazione ACL vale via UNC' ($viaUnc -eq 'negata') $viaUnc -Informational
} finally {
    & icacls $denyDir /remove:d $me | Out-Null
}
$owner = try { (Get-Acl -LiteralPath (Get-UncPath $Aliases[0])).Owner } catch { 'non leggibile' }
Add-Result 'permessi: proprietario della fixture via UNC' $true $owner -Informational

$hard = @($results | Where-Object { !$_.informational })
$report = [ordered]@{
    schemaVersion = 1; date = [DateTimeOffset]::Now.ToString('o'); machine = [Environment]::MachineName; user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    shareRoot = $ShareRoot; aliases = $Aliases; fixture = $localFixture
    outcome = $(if ($failures.Count) { 'failed' } else { 'partial' })
    limits = 'Un solo PC e un solo utente (loopback); nessun secondo host, nessun utente diverso, nessun NAS/Samba: esito massimo partial'
    passed = @($hard | Where-Object ok).Count; total = $hard.Count; failures = @($failures); results = $results
}
$reportPath = Join-Path $localFixture 'report.json'
[IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
Write-Host ("Controlli vincolanti: {0}/{1}. Esito: {2}. Rapporto: {3}" -f $report.passed, $report.total, $report.outcome, $reportPath)
exit $(if ($failures.Count) { 1 } else { 0 })
