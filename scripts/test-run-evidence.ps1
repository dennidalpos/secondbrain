# Test-only run provenance. Reports contain hashes and an allowlist of environment values, never a full environment dump.
function Get-SBTestInputSnapshot([string]$BrainRoot,[switch]$NoGit) {
    if($NoGit){
        $files=[ordered]@{}
        $paths=@(foreach($directory in @('scripts','docs','direttive','.github')){Get-ChildItem -LiteralPath (Join-Path $BrainRoot $directory) -File -Recurse})
        $paths+=@(Get-ChildItem -LiteralPath (Join-Path $BrainRoot 'config') -File)
        $paths+=@(foreach($name in @('VERSION','README.md','AGENTS.md','.gitignore','CHANGELOG.md','CREDITS.md')){Get-Item -LiteralPath (Join-Path $BrainRoot $name)})
        foreach($file in $paths|Sort-Object FullName){
            Assert-SBPlainPath $file.FullName
            $files[[IO.Path]::GetRelativePath($BrainRoot,$file.FullName).Replace('\','/')]=Get-SBFileHash $file.FullName
        }
        return @{coverage='Quick only: explicit public source directories, config root files, VERSION/README/AGENTS/.gitignore/CHANGELOG/CREDITS; no Git inventory or ignored/private data.';files=$files;sha256=(Get-SBTextHash (ConvertTo-SBJson $files))}
    }
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
function Get-SBTestEvidenceEnvironment([switch]$NoGit) {
    $values=[ordered]@{}
    foreach($name in @('SECONDBRAIN_LANG','SECONDBRAIN_TEST_TIMING','SECONDBRAIN_TEST_KEEP','SECONDBRAIN_TEST_ROOT','GIT_TEMPLATE_DIR')){
        $values[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
    }
    # Config pairs may contain credentials: fingerprint them without copying their values into reports.
    $gitConfig=[ordered]@{}
    Get-ChildItem Env:GIT_CONFIG* | Sort-Object Name | ForEach-Object {$gitConfig[$_.Name]=$_.Value}
    if($NoGit){return @{powershell=$PSVersionTable.PSVersion.ToString();os=[Environment]::OSVersion.VersionString;values=$values;git='not inspected (pure Quick)';limits='Quick does not inspect Git or external state. No automatic reuse.'}}
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
# Only the default fixture container is managed: new runs get <yyyyMMdd>-minimal with MANIFEST.json (open while a run is active, closed afterwards).
# Containers created before this layout and custom SECONDBRAIN_TEST_ROOT values are never given a manifest.
function Open-SBTestFixtureManifest([string]$Base,[string]$HostId,[string]$Repository) {
    $path=Join-Path $Base 'MANIFEST.json'
    $today=Get-Date
    $record=if([IO.File]::Exists($path)){Read-SBJson $path $null}else{$null}
    if($record -isnot [Collections.IDictionary] -or $record.schemaVersion -ne 1){
        $record=[ordered]@{schemaVersion=1;category='fixture';name=(Split-Path $Base -Leaf);created=$today.ToString('yyyy-MM-dd');hostId=$HostId;repository=$Repository
            owner=@{user=$env:USERNAME;computer=$env:COMPUTERNAME;client='test-runner'};sessionId=$null;task='SecondBrain test runner fixtures'}
    }
    $record.status='open';$record.expires=$today.AddDays(7).ToString('yyyy-MM-dd');$record.Remove('closed')
    Write-SBTestEvidenceJson $path $record
    $path
}
# Closes the container only when no other run in it is still active; runs on failure paths too.
function Close-SBTestFixtureManifest($Run) {
    if(!$Run.ContainsKey('manifest') -or !$Run.manifest -or ![IO.File]::Exists($Run.manifest)){return}
    $active=@(foreach($candidate in Get-ChildItem -LiteralPath $Run.baseRoot -Directory -Filter 'run-*'){
        if($candidate.Name -ceq $Run.runId){continue}
        $other=Read-SBJson (Join-Path $candidate.FullName 'run.json') $null
        if($other -and $other.status -in @('running','finalizing')){$candidate.Name}
    })
    if($active.Count){return}
    $record=Read-SBJson $Run.manifest $null
    if($record -isnot [Collections.IDictionary]){return}
    $record.status='closed';$record.closed=(Get-Date).ToString('yyyy-MM-dd')
    Write-SBTestEvidenceJson $Run.manifest $record
}
function New-SBTestRun([string]$BrainRoot,[string]$Level,$Parameters,[Diagnostics.Stopwatch]$Watch=[Diagnostics.Stopwatch]::StartNew()) {
    $managed=$null
    $requested=if($env:SECONDBRAIN_TEST_ROOT){$env:SECONDBRAIN_TEST_ROOT}else{
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
        $segment='tests-'+(Get-SBTextHash $BrainRoot).Substring(0,8).ToLowerInvariant()
        $hostId=Get-SBHostId
        $managed=@{hostId=$hostId;repository=$segment}
        Join-Path (Get-SBLocalRoot $BrainRoot $hostId) ('repos/'+$segment+'/fixture/'+(Get-Date -Format yyyyMMdd)+'-minimal')
    }
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
    $manifest=$null
    if($managed -and !$parent){$manifest=Open-SBTestFixtureManifest $base $managed.hostId $managed.repository}
    $state=@{manifest=$manifest;schemaVersion=1;brainRoot=$BrainRoot;runId=$runId;baseRoot=$base;directory=$directory;report=(Join-Path $directory 'run.json');log=(Join-Path $directory 'runner.log')
      parent=$parent;children=@();level=$Level;command=@{script='scripts/test-secondbrain.ps1';parameters=@{};workingDirectory=(Get-Location).Path}
      startedAt=[DateTimeOffset]::UtcNow.Subtract($Watch.Elapsed).ToString('o');status='running';error=$null;watch=$Watch}
    foreach($key in $Parameters.Keys){$value=$Parameters[$key];$state.command.parameters[$key]=if($value -is [Management.Automation.SwitchParameter]){[bool]$value}else{$value}}
    # Write the identity first so setup failures still have a durable report.
    Save-SBTestRunRecord $state -CreateNew
    $state
}
function Complete-SBTestRun($Run,[bool]$Success,[int]$Checks,$Suites,[bool]$KeepRequested) {
    $after=$null
    try{$after=Get-SBTestInputSnapshot $Run.brainRoot -NoGit:($Run.ContainsKey('noGit') -and $Run.noGit)}catch{$Run.inputEvidenceError=$_.Exception.Message}
    $stable=$Run.ContainsKey('inputsBefore') -and $null -ne $after -and $Run.inputsBefore.sha256 -ceq $after.sha256
    $Run.inputsAfter=$after;$Run.inputsStable=$stable
    $Run.status='finalizing'
    $Run.eligibleForClosure=$false
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
    $summary=[ordered]@{schemaVersion=1;level=$Run.level;observedAt=$null;durationSeconds=$null;status=$Run.status;checks=$Checks
      fixtures=$Run.fixtures;suites=@($Suites);details=@($(if(Test-Path (Join-Path $Run.directory 'esito-concurrency.json')){$Run.runId+'/esito-concurrency.json'}))
      report=$Run.report;runId=$Run.runId;inputsStable=$stable;eligibleForClosure=$false}
    # Serialize only the short latest-summary update. Different runs keep their own complete evidence regardless of contention.
    $lockPath=Join-Path $Run.baseRoot 'esito.lock';$lock=$null
    $summaryPath=Join-Path $Run.baseRoot 'esito.json'
    $overBudget=$false
    function Test-ProfileBudget {
        $Run.ContainsKey('budgetSeconds') -and $Run.budgetSeconds -gt 0 -and $Run.watch.Elapsed.TotalSeconds -gt $Run.budgetSeconds
    }
    function Publish-Outcome {
        $Run.finishedAt=[DateTimeOffset]::UtcNow.ToString('o')
        $Run.durationSeconds=[Math]::Round($Run.watch.Elapsed.TotalSeconds,3)
        # The time budget is a warning (#498): exceeding it is recorded in run.json and reported, never a failure.
        $Run.budgetExceeded=[bool]$overBudget
        $Run.status=if(!$Success -or !$Checks){'failed'}elseif(!$stable){'invalidated'}else{'passed'}
        $Run.eligibleForClosure=$Run.status -eq 'passed'
        $Run.warnings=@($(if($overBudget){'Profile exceeded its time budget of '+$Run.budgetSeconds+' seconds.'}))
        $summary.observedAt=$Run.finishedAt
        foreach($key in @('durationSeconds','status','eligibleForClosure')){$summary[$key]=$Run[$key]}
        Save-SBTestRunRecord $Run
        Write-SBTestEvidenceJson $summaryPath $summary
    }
    try{
        for($attempt=0;$attempt -lt 50 -and !$lock;$attempt++){
            try{$lock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
            catch [IO.IOException]{Start-Sleep -Milliseconds 20}
        }
        if(!$lock){throw 'Latest-summary lock unavailable; permanent run report retained.'}
        Write-SBTestEvidenceJson $summaryPath $summary
        # The first durable writes, input snapshot, lock wait and environment restoration all precede this stamp.
        $overBudget=Test-ProfileBudget
        Publish-Outcome
        if(!$overBudget -and (Test-ProfileBudget)){
            $overBudget=$true
            Publish-Outcome
        }
    }catch{
        $Run.status='failed';$Run.eligibleForClosure=$false;$Run.error=$_.Exception.Message
        Save-SBTestRunRecord $Run
        throw
    }finally{
        if($lock){$lock.Dispose()}
        Close-SBTestFixtureManifest $Run
    }
    $Run.watch.Stop()
    if($Success -and !$Checks){throw 'No test suite ran. See run.json.'}
    if($Success -and !$stable){throw 'Test inputs changed or were not captured; evidence is insufficient for closure. See run.json.'}
    if($overBudget){Write-Warning ('Profile exceeded its time budget of '+$Run.budgetSeconds+' seconds ('+[Math]::Round($Run.watch.Elapsed.TotalSeconds,1)+' s); the run is not failed, see run.json.')}
}
