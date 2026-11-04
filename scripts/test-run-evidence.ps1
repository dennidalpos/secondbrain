# Test-only run provenance. Reports contain hashes and an allowlist of environment values, never a full environment dump.
function Get-SBTestInputSnapshot([string]$BrainRoot) {
    $info=[Diagnostics.ProcessStartInfo]::new((Get-Command git).Source)
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    foreach($argument in @('-C',$BrainRoot,'ls-files','-z','--cached','--others','--exclude-standard')){$info.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::Start($info)
    try {
        $output=$process.StandardOutput.ReadToEndAsync();$errorOutput=$process.StandardError.ReadToEndAsync();$process.WaitForExit()
        if($process.ExitCode -ne 0){throw ('Cannot enumerate test inputs: '+$errorOutput.Result)}
        $files=[ordered]@{}
        foreach($relative in @($output.Result.Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)|Sort-Object -Unique)){
            $path=Join-Path $BrainRoot $relative
            Assert-SBPlainPath $path
            $files[$relative]=if([IO.File]::Exists($path)){Get-SBFileHash $path}else{'absent'}
        }
        @{coverage='All Git-indexed and nonignored untracked files, working-tree bytes; ignored runtime/dossiers and external inputs excluded. Conservative superset, not a trace of consumed files.';files=$files;sha256=(Get-SBTextHash (ConvertTo-SBJson $files))}
    } finally {$process.Dispose()}
}
function Get-SBTestEvidenceEnvironment {
    $values=[ordered]@{}
    foreach($name in @('SECONDBRAIN_LANG','SECONDBRAIN_TEST_TIMING','SECONDBRAIN_TEST_KEEP','SECONDBRAIN_TEST_ROOT','GIT_TEMPLATE_DIR')){
        $values[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
    }
    # Config pairs may contain credentials: fingerprint them without copying their values into reports.
    $gitConfig=[ordered]@{}
    Get-ChildItem Env:GIT_CONFIG* | Sort-Object Name | ForEach-Object {$gitConfig[$_.Name]=$_.Value}
    $globalPaths=@(& git var GIT_CONFIG_GLOBAL 2>$null)
    if($LASTEXITCODE -notin @(0,1)){throw 'Cannot inspect Git environment for test evidence.'}
    $globalHashes=@(foreach($path in $globalPaths){if([IO.File]::Exists($path)){Get-SBFileHash $path}else{'absent'}})
    @{powershell=$PSVersionTable.PSVersion.ToString();pwsh=(Get-Command pwsh).Source;git=(& git --version);os=[Environment]::OSVersion.VersionString
      architecture=[Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString();culture=[Globalization.CultureInfo]::CurrentCulture.Name
      values=$values;gitConfigSha256=(Get-SBTextHash (ConvertTo-SBJson $gitConfig));globalConfigHashes=$globalHashes
      limits='Environment allowlist and direct global-config hashes only; included Git config files, tools, OS state and external data are not exhaustively fingerprinted. No automatic reuse.'}
}
function Write-SBTestEvidenceJson([string]$Path,$Value,[switch]$CreateNew) {
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-SBJson $Value))
    $mode=if($CreateNew){[IO.FileMode]::CreateNew}else{[IO.FileMode]::Create}
    $stream=[IO.FileStream]::new($Path,$mode,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes);$stream.Flush($true)}finally{$stream.Dispose()}
}
function Save-SBTestRunRecord($Run,[switch]$CreateNew) {
    $copy=@{};foreach($key in $Run.Keys){if($key -ne 'watch'){$copy[$key]=$Run[$key]}}
    Write-SBTestEvidenceJson $Run.report $copy -CreateNew:$CreateNew
}
function New-SBTestRun([string]$BrainRoot,[string]$Level,$Parameters) {
    $requested=if($env:SECONDBRAIN_TEST_ROOT){$env:SECONDBRAIN_TEST_ROOT}else{Join-Path $BrainRoot '.runtime/tests'}
    $base=Assert-SBCentralDataPath $BrainRoot $requested
    $parent=$null
    if($env:SECONDBRAIN_TEST_RUN_CONTEXT){
        $contextPath=Assert-SBCentralDataPath $BrainRoot $env:SECONDBRAIN_TEST_RUN_CONTEXT
        if(!(Test-SBSamePath $contextPath (Join-Path $base 'run.json'))){throw 'Runner parent context does not match the requested fixture root.'}
        $context=Read-SBJson $contextPath $null
        if(!$context -or $context.schemaVersion -ne 1 -or $context.runId -cnotmatch '^run-[0-9a-f]{8}$' -or
            !(Test-SBSamePath $base (Join-Path $context.baseRoot $context.runId))){throw 'Invalid runner parent context.'}
        $parent=@{runId=$context.runId;report=$contextPath;directory=$base}
        $base=Assert-SBCentralDataPath $BrainRoot $context.baseRoot
    }
    $runId='run-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    $directory=Assert-SBCentralDataPath $BrainRoot (Join-Path $base $runId)
    if(Test-Path -LiteralPath $directory){throw 'Test run identifier collision; existing evidence preserved.'}
    [IO.Directory]::CreateDirectory($directory)|Out-Null
    $state=@{schemaVersion=1;brainRoot=$BrainRoot;runId=$runId;baseRoot=$base;directory=$directory;report=(Join-Path $directory 'run.json');log=(Join-Path $directory 'runner.log')
      parent=$parent;children=@();level=$Level;command=@{script='scripts/test-secondbrain.ps1';parameters=@{};workingDirectory=(Get-Location).Path}
      startedAt=[DateTimeOffset]::UtcNow.ToString('o');status='running';error=$null;watch=[Diagnostics.Stopwatch]::StartNew()}
    foreach($key in $Parameters.Keys){$value=$Parameters[$key];$state.command.parameters[$key]=if($value -is [Management.Automation.SwitchParameter]){[bool]$value}else{$value}}
    # Write the identity first so setup failures still have a durable report.
    Save-SBTestRunRecord $state -CreateNew
    $state
}
function Complete-SBTestRun($Run,[bool]$Success,[int]$Checks,$Suites,[bool]$KeepRequested) {
    $Run.watch.Stop()
    $after=$null
    try{$after=Get-SBTestInputSnapshot $Run.brainRoot}catch{$Run.inputEvidenceError=$_.Exception.Message}
    $stable=$Run.ContainsKey('inputsBefore') -and $null -ne $after -and $Run.inputsBefore.sha256 -ceq $after.sha256
    $Run.inputsAfter=$after;$Run.inputsStable=$stable
    $Run.status=if(!$Success){'failed'}elseif(!$stable){'invalidated'}else{'passed'}
    $Run.eligibleForClosure=($Success -and $stable)
    $Run.finishedAt=[DateTimeOffset]::UtcNow.ToString('o');$Run.durationSeconds=[Math]::Round($Run.watch.Elapsed.TotalSeconds,3)
    $Run.checks=$Checks;$Run.suites=@($Suites)
    $Run.fixtures=@{run=$Run.runId;removed=$false;kept=$true;keepRequested=$KeepRequested}
    $Run.children=@(foreach($candidate in Get-ChildItem -LiteralPath $Run.baseRoot -Directory -Filter 'run-*'){
        $path=Join-Path $candidate.FullName 'run.json'
        $child=Read-SBJson $path $null
        if($child -and $child.parent -and (Test-SBSamePath $child.parent.report $Run.report)){
            @{runId=$child.runId;report=$path;status=$child.status}
        }
    })
    Save-SBTestRunRecord $Run
    # Backward-compatible latest summary. Permanent reports above are never shared across runs.
    $summary=[ordered]@{schemaVersion=1;level=$Run.level;observedAt=$Run.finishedAt;durationSeconds=$Run.durationSeconds;status=$Run.status;checks=$Checks
      fixtures=$Run.fixtures;suites=@($Suites);details=@($(if(Test-Path (Join-Path $Run.directory 'esito-concurrency.json')){$Run.runId+'/esito-concurrency.json'}))
      report=$Run.report;runId=$Run.runId;inputsStable=$stable;eligibleForClosure=$Run.eligibleForClosure}
    # Serialize only the short latest-summary update. Different runs keep their own complete evidence regardless of contention.
    $lockPath=Join-Path $Run.baseRoot 'esito.lock';$lock=$null
    try{
        for($attempt=0;$attempt -lt 50 -and !$lock;$attempt++){
            try{$lock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
            catch [IO.IOException]{Start-Sleep -Milliseconds 20}
        }
        if(!$lock){throw 'Latest-summary lock unavailable; permanent run report retained.'}
        Write-SBTestEvidenceJson (Join-Path $Run.baseRoot 'esito.json') $summary
    }finally{if($lock){$lock.Dispose()}}
    if($Success -and !$stable){throw 'Test inputs changed or were not captured; evidence is insufficient for closure. See run.json.'}
}
