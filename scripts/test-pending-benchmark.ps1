#requires -Version 7.5
<#
.SYNOPSIS
Opt-in local pending-write latency benchmark. All fixtures and raw samples are retained.
.EXAMPLE
pwsh -NoProfile -File scripts/test-pending-benchmark.ps1 -OutputRoot <central-runtime-directory>
#>
[CmdletBinding()]
param(
    [string]$OutputRoot,
    [ValidateSet(1,2,4,8)][int[]]$Producers = @(1,2,4,8),
    [ValidateRange(1,10)][int]$Repetitions = 3,
    [ValidateRange(1,1000)][int]$Samples = 100,
    [ValidateRange(0,100)][int]$Warmup = 5,
    [string]$WorkerConfig,
    [ValidateRange(1,8)][int]$WorkerId = 1,
    [switch]$Importer
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Pending.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
function Write-BenchmarkJson([string]$Path, $Value) {
    [IO.Directory]::CreateDirectory((Split-Path $Path)) | Out-Null
    [IO.File]::WriteAllText($Path, (ConvertTo-SBJson $Value), [Text.UTF8Encoding]::new($false))
}
function Start-BenchmarkProcess([string[]]$Arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($arg in @('-NoProfile','-File',$PSCommandPath) + $Arguments) { $start.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::Start($start)
    $process | Add-Member -NotePropertyName OutputTask -NotePropertyValue $process.StandardOutput.ReadToEndAsync()
    $process | Add-Member -NotePropertyName ErrorTask -NotePropertyValue $process.StandardError.ReadToEndAsync()
    $process
}
function Close-BenchmarkProcess($Process, [string]$Path) {
    if (!$Process.HasExited) { $Process.Kill($true); $Process.WaitForExit() }
    [IO.File]::WriteAllText($Path, ($Process.OutputTask.GetAwaiter().GetResult()+$Process.ErrorTask.GetAwaiter().GetResult()))
    $Process.Dispose()
}
function Get-BenchmarkDistribution($Values) {
    $sorted = @($Values | Sort-Object)
    if (!$sorted.Count) { return $null }
    $result = @{count=$sorted.Count; max=[double]$sorted[-1]}
    foreach ($p in @(50,95,99)) { $result['p'+$p] = [double]$sorted[[Math]::Max(0,[int][Math]::Ceiling($sorted.Count*$p/100.0)-1)] }
    $result
}
if ($WorkerConfig) {
    $productRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $WorkerConfig = Assert-SBCentralDataPath $productRoot $WorkerConfig
    $benchmarkProfile = Read-SBJson $WorkerConfig $null
    $cfg = $benchmarkProfile.config
    $expectedRoot = Split-Path $WorkerConfig
    $expectedBrain = Join-Path $expectedRoot 'brain'
    if ($benchmarkProfile.identity -cne 'github.com/test/pending-benchmark' -or !(Test-SBSamePath $benchmarkProfile.root $expectedRoot) -or !(Test-SBSamePath $cfg.brainRoot $expectedBrain) -or !(Test-SBSamePath $cfg.coordinationRoot (Join-Path $expectedBrain '.runtime/access')) -or !(Test-SBSamePath $cfg.backupRoot (Join-Path $expectedBrain '.runtime/hosts/benchmark/backups'))) {
        throw 'Invalid isolated benchmark profile.'
    }
    if ($Importer) {
        # A new process (fresh module state) repeatedly imports with non-blocking acquisition.
        $deadline = [DateTimeOffset]::UtcNow.AddMinutes(30)
        do {
            $result = Invoke-SBPendingWrites -BrainRoot $cfg.brainRoot -Config $cfg -Limit 100
            if ($result.errors.Count -or $result.conflicts.Count) { throw ('Importer error: '+(ConvertTo-SBJson $result)) }
            if ($result.pending -eq 0) { break }
            if ([DateTimeOffset]::UtcNow -gt $deadline) { throw 'Importer deadline exceeded; fixture retained.' }
            if ($result.state -eq 'busy') { Start-Sleep -Milliseconds 20 }
        } while ($true)
        Write-BenchmarkJson (Join-Path $benchmarkProfile.root ('importer-'+$WorkerId+'.json')) @{status='passed'}
        return
    }
    $rows = [Collections.Generic.List[object]]::new()
    [IO.File]::WriteAllText((Join-Path $benchmarkProfile.root ('ready-'+$WorkerId)), 'ready')
    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(2)
    while (!(Test-Path -LiteralPath (Join-Path $benchmarkProfile.root 'start'))) {
        if ([DateTimeOffset]::UtcNow -gt $deadline) { throw 'Producer start deadline exceeded.' }
        Start-Sleep -Milliseconds 20
    }
    $process = [Diagnostics.Process]::GetCurrentProcess()
    try {
    for ($i = 0; $i -lt ($benchmarkProfile.samples + $benchmarkProfile.warmup); $i++) {
        $marker = 'p{0:D2}-n{1:D4}' -f $WorkerId,$i
        $content = $marker + ' ' + ('x' * (1023-$marker.Length-1)) + "`n"
        $diagnostics = @{}
        $process.Refresh(); $cpuBefore = $process.TotalProcessorTime.TotalMilliseconds
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $submission = New-SBPendingWrite -BrainRoot $cfg.brainRoot -Repository $benchmarkProfile.identity -Operation file.append -Arguments @{relativePath='history/benchmark/report.md';content=$content} -Config $cfg -Diagnostics $diagnostics
        $result = Complete-SBPendingSubmission $submission $cfg -Diagnostics $diagnostics
        $wallMs = $watch.Elapsed.TotalMilliseconds
        $process.Refresh(); $cpuMs = $process.TotalProcessorTime.TotalMilliseconds-$cpuBefore
        if ($result.applied -or $result.state -ne 'deferred' -or $result.pendingWrites.state -ne 'busy') { throw 'Busy writer must defer the durable request.' }
        $rows.Add(@{worker=$WorkerId;index=$i;warmup=($i -lt $benchmarkProfile.warmup);marker=$marker;requestId=$submission.id;wallMs=$wallMs;cpuMs=$cpuMs;payloadBytes=1024;diagnostics=$diagnostics})
    }
    } finally { Write-BenchmarkJson (Join-Path $benchmarkProfile.root ('samples-'+$WorkerId+'.json')) @($rows) }
    return
}
if (!$OutputRoot) { throw 'OutputRoot is required and must be inside SecondBrain/.runtime.' }
if (@($Producers | Sort-Object -Unique).Count -ne $Producers.Count) { throw 'Producer profiles must be distinct.' }
$brainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$OutputRoot = Assert-SBCentralDataPath $brainRoot $OutputRoot
if (Test-Path -LiteralPath $OutputRoot) { throw 'OutputRoot already exists; choose a new directory. Previous evidence is preserved.' }
[IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
$sourceHashes = @{}
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'SecondBrain.*.psm1' -File) { $sourceHashes[$file.Name] = Get-SBFileHash $file.FullName }
$sourceHashes['test-pending-benchmark.ps1'] = Get-SBFileHash $PSCommandPath
$sourceHashes['config/tracker.schema.json'] = Get-SBFileHash (Join-Path $PSScriptRoot '../config/tracker.schema.json')
$report = @{schemaVersion=1;status='running';startedAt=[DateTimeOffset]::UtcNow.ToString('o');runtime=$PSVersionTable.PSVersion.ToString();os=[Environment]::OSVersion.VersionString;logicalProcessors=[Environment]::ProcessorCount;sourceHashes=$sourceHashes;parameters=@{producers=$Producers;repetitions=$Repetitions;samplesPerProducer=$Samples;warmupPerProducer=$Warmup;payloadBytes=1024;configuredLockTimeoutMs=60000};profiles=@();interpretation='Local process CPU and wall time are measured separately; their difference does not identify disk latency. No physical SMB qualification.'}
Write-BenchmarkJson (Join-Path $OutputRoot 'report.json') $report
try {
foreach ($producerCount in $Producers) {
    foreach ($repeat in 1..$Repetitions) {
        $report.activeProfile=@{producers=$producerCount;repeat=$repeat;phase='production'}
        Write-BenchmarkJson (Join-Path $OutputRoot 'report.json') $report
        'BENCHMARK start producers='+$producerCount+' repeat='+$repeat
        $benchmarkProfileRoot = Join-Path $OutputRoot ('producers-'+$producerCount+'-repeat-'+$repeat)
        $brain = Join-Path $benchmarkProfileRoot 'brain'
        $dossier = Join-Path $brain '02-areas/products/Benchmark'
        $identity = 'github.com/test/pending-benchmark'
        Write-BenchmarkJson (Join-Path $dossier 'para.json') @{schemaVersion=1;id='benchmark-area';kind='area';title='Benchmark';status='active'}
        Write-BenchmarkJson (Join-Path $dossier 'repository.json') @{schemaVersion=1;identity=$identity;tracker=@{location='dossier';path='tracker.json';schemaVersion=1}}
        [IO.File]::WriteAllText((Join-Path $dossier 'brief.md'), '# Synthetic benchmark fixture')
        foreach($name in @('context.md','memory.md')){[IO.File]::WriteAllText((Join-Path $dossier $name), '# Synthetic benchmark fixture')}
        [IO.File]::WriteAllText((Join-Path $dossier 'index.md'), '# Synthetic benchmark dossier')
        Write-BenchmarkJson (Join-Path $dossier 'tracker.json') @{schemaVersion=1;repository=$identity;updatedAt=[DateTimeOffset]::UtcNow.ToString('o');tasks=@();history=@();extensions=@{lastSeq=0}}
        Write-BenchmarkJson (Join-Path $brain 'config/shared.json') @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')}
        [IO.File]::WriteAllBytes((Join-Path $brain 'config/tracker.schema.json'),[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../config/tracker.schema.json')))
        $cfg = @{schemaVersion=1;mode='portable';brainRoot=$brain;workstationId=(Get-SBHostId);runtimeRoot=(Join-Path $brain '.runtime/hosts/benchmark');backupRoot=(Join-Path $brain '.runtime/hosts/benchmark/backups');repositoryRoot=$brain;coordinationRoot=(Join-Path $brain '.runtime/access');bindings=@();ides=@();lockWaitMs=60000}
        $benchmarkProfile = @{root=$benchmarkProfileRoot;identity=$identity;config=$cfg;samples=$Samples;warmup=$Warmup}
        $benchmarkProfilePath = Join-Path $benchmarkProfileRoot 'profile.json'
        Write-BenchmarkJson $benchmarkProfilePath $benchmarkProfile
        $holder = $null; $workers = @()
        try {
            $holder = Enter-SBOperation $cfg -WaitMs 0
            foreach ($workerId in 1..$producerCount) { $workers += Start-BenchmarkProcess @('-WorkerConfig',$benchmarkProfilePath,'-WorkerId',[string]$workerId) }
            $deadline = [DateTimeOffset]::UtcNow.AddMinutes(2)
            while (@(Get-ChildItem -LiteralPath $benchmarkProfileRoot -Filter 'ready-*').Count -ne $producerCount) {
                if (@($workers | Where-Object HasExited).Count -or [DateTimeOffset]::UtcNow -gt $deadline) { throw 'Producer initialization failed; fixture retained.' }
                Start-Sleep -Milliseconds 50
            }
            [IO.File]::WriteAllText((Join-Path $benchmarkProfileRoot 'start'), 'start')
            foreach ($worker in $workers) { $worker.WaitForExit(); if ($worker.ExitCode -ne 0) { throw 'Producer failed; fixture retained.' } }
        } finally {
            Exit-SBOperation $holder
            for($i=0;$i -lt $workers.Count;$i++){Close-BenchmarkProcess $workers[$i] (Join-Path $benchmarkProfileRoot ('producer-'+($i+1)+'.log'))}
        }
        # Producers have exited: no in-memory submission survives. Two fresh importers race on the durable files.
        $report.activeProfile.phase='integration'
        Write-BenchmarkJson (Join-Path $OutputRoot 'report.json') $report
        $importers = @()
        try {
            foreach ($workerId in 1..2) { $importers += Start-BenchmarkProcess @('-WorkerConfig',$benchmarkProfilePath,'-WorkerId',[string]$workerId,'-Importer') }
            foreach ($worker in $importers) { $worker.WaitForExit(); if ($worker.ExitCode -ne 0) { throw 'Importer failed; fixture retained.' } }
        } finally { for($i=0;$i -lt $importers.Count;$i++){Close-BenchmarkProcess $importers[$i] (Join-Path $benchmarkProfileRoot ('importer-'+($i+1)+'.log'))} }
        $allRows = @(Get-ChildItem -LiteralPath $benchmarkProfileRoot -Filter 'samples-*.json' | ForEach-Object { Read-SBJson $_.FullName @() })
        $expected = $producerCount*($Samples+$Warmup)
        $lines = @([IO.File]::ReadAllLines((Join-Path $dossier 'history/benchmark/report.md')))
        $markers = @($lines | ForEach-Object { ($_ -split ' ',2)[0] })
        foreach($line in $lines){
            $marker=($line -split ' ',2)[0]
            if($marker.Length -gt 1022 -or $line -cne ($marker+' '+('x'*(1023-$marker.Length-1)))){throw 'Append payload was not preserved.'}
        }
        $entries = @(Get-SBPendingWrites $brain)
        if ($allRows.Count -ne $expected -or $lines.Count -ne $expected -or (Get-Item -LiteralPath (Join-Path $dossier 'history/benchmark/report.md')).Length -ne $expected*1024 -or @($markers | Sort-Object -Unique).Count -ne $expected -or @($allRows | Where-Object marker -NotIn $markers).Count -or $entries.Count -ne $expected -or @($entries | Where-Object state -ne 'applied').Count) { throw 'Exactly-once verification failed; fixture retained.' }
        $hash = Get-SBFileHash (Join-Path $dossier 'history/benchmark/report.md')
        $again = Invoke-SBPendingWrites -BrainRoot $brain -Config $cfg
        if ($again.applied.Count -or $hash -ne (Get-SBFileHash (Join-Path $dossier 'history/benchmark/report.md'))) { throw 'Replay changed the appended report.' }
        $measured = @($allRows | Where-Object {!$_.warmup})
        $latency = Get-BenchmarkDistribution $measured.wallMs
        $stats = @{producers=$producerCount;repeat=$repeat;requests=$expected;measured=$measured.Count;latencyMs=$latency;cpuMs=(Get-BenchmarkDistribution $measured.cpuMs);stages=@{};passes=($latency.p95 -le 2000 -and $latency.p99 -le 5000);exactlyOnce=$true;reportHash=$hash;fixture=([IO.Path]::GetRelativePath($OutputRoot,$benchmarkProfileRoot))}
        foreach ($stage in @('prepareMs','writeFlushMs','readbackMs','scanMs','lockAttemptMs','responseMs')) { $stats.stages[$stage] = Get-BenchmarkDistribution @($measured | ForEach-Object { $_.diagnostics[$stage] }) }
        $report.profiles += $stats
        Write-BenchmarkJson (Join-Path $OutputRoot 'report.json') $report
        'BENCHMARK producers='+$producerCount+' repeat='+$repeat+' p95='+[Math]::Round($latency.p95,1)+'ms p99='+[Math]::Round($latency.p99,1)+'ms pass='+$stats.passes+' exactlyOnce=true'
    }
}
$passing = @($Producers | Where-Object { $n=$_; @($report.profiles | Where-Object {$_.producers -eq $n -and !$_.passes}).Count -eq 0 })
$report.maximumVerifiedProducers = if($passing.Count){($passing | Measure-Object -Maximum).Maximum}else{0}
$report.status = if($report.maximumVerifiedProducers -gt 0){'passed'}else{'partial'}
$report.activeProfile.phase='complete'
$report.completedAt = [DateTimeOffset]::UtcNow.ToString('o')
Write-BenchmarkJson (Join-Path $OutputRoot 'report.json') $report
'BENCHMARK '+$report.status+'; maximum verified producers='+$report.maximumVerifiedProducers+'; evidence='+$OutputRoot
} catch {
    $report.status='failed';$report.error=$_.Exception.Message;$report.completedAt=[DateTimeOffset]::UtcNow.ToString('o')
    Write-BenchmarkJson (Join-Path $OutputRoot 'report.json') $report
    throw
}
