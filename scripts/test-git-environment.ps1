# Test-only process configuration. No persistent Git configuration is changed.
function Assert-SBTestGitEnvironment {
    if (!$IsWindows) { return }
    $value = & git config --type=bool --get core.longpaths 2>$null
    if ($LASTEXITCODE -ne 0 -or $value -cne 'true') {
        throw 'Git fixture prerequisite: core.longpaths must be true. Use test-secondbrain.ps1 or Enter-SBTestGitEnvironment for a standalone suite; see docs/riferimento/runtime-maintenance.md.'
    }
    $fileValue = & git config --global --includes --type=bool --get core.longpaths 2>$null
    if ($LASTEXITCODE -ne 0 -or $fileValue -cne 'true') {
        throw 'Git fixture prerequisite: the process global config must enable longpaths before command overrides. Use Enter-SBTestGitEnvironment; see docs/riferimento/runtime-maintenance.md.'
    }
}
function Enter-SBTestGitEnvironment {
    $snapshot = @{}
    if (!$IsWindows) { return $snapshot }
    $countText = [Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT', 'Process')
    $count = 0
    if ($countText -and (![int]::TryParse($countText, [ref]$count) -or $count -lt 0 -or $count -eq [int]::MaxValue)) {
        throw 'Invalid GIT_CONFIG_COUNT; the test environment was not changed.'
    }
    for ($i = 0; $i -lt $count; $i++) {
        foreach ($prefix in @('KEY','VALUE')) {
            if ($null -eq [Environment]::GetEnvironmentVariable("GIT_CONFIG_${prefix}_$i", 'Process')) {
                throw 'Incomplete inherited Git configuration; the test environment was not changed.'
            }
        }
    }
    foreach ($name in @('GIT_CONFIG_COUNT', "GIT_CONFIG_KEY_$count", "GIT_CONFIG_VALUE_$count", 'GIT_TEMPLATE_DIR', 'GIT_CONFIG_GLOBAL')) {
        $snapshot[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        # The Windows path layer can consult file configuration before command
        # overrides. Include the inherited global files, then enable longpaths in
        # a retained, process-only wrapper. Never rewrite the inherited files.
        $globalPaths = @(& git var GIT_CONFIG_GLOBAL 2>$null)
        if ($LASTEXITCODE -notin @(0,1)) { throw 'git var GIT_CONFIG_GLOBAL is required for the test environment.' }
        $includes = ''
        foreach ($path in $globalPaths) {
            if (![IO.Path]::IsPathFullyQualified($path) -or $path.IndexOfAny([char[]]"`r`n") -ge 0) {
                throw 'Inherited global Git config paths must be absolute and single-line.'
            }
            $quoted = $path.Replace('\','\\').Replace('"','\"')
            $includes += "[include]`npath = `"$quoted`"`n"
        }
        Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
        $brainRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
        $hostIdentity = [Environment]::MachineName+'|'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $hostId = 'ws-'+(Get-SBTextHash $hostIdentity).Substring(0,16).ToLowerInvariant()
        $repositoryKey = 'tests-'+(Get-SBTextHash $brainRoot).Substring(0,8).ToLowerInvariant()
        # One daily tmp container per workstation (hosts/<id>/repos/tests-<hash>/tmp/<yyyyMMdd>-git-env) with MANIFEST.json;
        # each process writes its wrapper in its own subfolder. The container is closed with a seven-day expiry: the wrappers
        # are needed only while the owning test process runs, and Regenerable still skips recently written folders.
        $today = Get-Date
        $name = $today.ToString('yyyyMMdd')+'-git-env'
        $container = Assert-SBCentralDataPath $brainRoot (Join-Path (Get-SBLocalRoot $brainRoot $hostId) ('repos/'+$repositoryKey+'/tmp/'+$name))
        $directory = Join-Path $container ([guid]::NewGuid().ToString('N').Substring(0,12))
        $wrapper = Join-Path $directory 'global.config'
        if ($wrapper.Length -ge 260) { throw 'The test Git bootstrap must be readable below MAX_PATH; fixture roots are not shortened.' }
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $manifestPath = Join-Path $container 'MANIFEST.json'
        if (![IO.File]::Exists($manifestPath)) {
            $record = [ordered]@{schemaVersion=1;category='tmp';name=$name;created=$today.ToString('yyyy-MM-dd');hostId=$hostId;repository=$repositoryKey
                owner=@{user=$env:USERNAME;computer=$env:COMPUTERNAME;client='test-git-environment'};sessionId=$null;task='Process-only Git configuration for SecondBrain test suites'
                status='closed';closed=$today.ToString('yyyy-MM-dd');expires=$today.AddDays(7).ToString('yyyy-MM-dd')}
            $manifestBytes = [Text.UTF8Encoding]::new($false).GetBytes(($record | ConvertTo-Json -Depth 4))
            # Parallel suites may race to create it: the first writer wins, the others keep its content.
            try {
                $manifestStream = [IO.FileStream]::new($manifestPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try { $manifestStream.Write($manifestBytes); $manifestStream.Flush($true) } finally { $manifestStream.Dispose() }
            } catch [IO.IOException] { if (![IO.File]::Exists($manifestPath)) { throw } }
        }
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($includes+"[core]`nlongpaths = true`n")
        $stream = [IO.FileStream]::new($wrapper,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
        $env:GIT_CONFIG_GLOBAL = $wrapper
        [Environment]::SetEnvironmentVariable("GIT_CONFIG_KEY_$count", 'core.longpaths', 'Process')
        [Environment]::SetEnvironmentVariable("GIT_CONFIG_VALUE_$count", 'true', 'Process')
        [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', [string]($count + 1), 'Process')
        Assert-SBTestGitEnvironment
        return $snapshot
    } catch {
        Exit-SBTestGitEnvironment $snapshot
        throw
    }
}
function Exit-SBTestGitEnvironment($Snapshot) {
    foreach ($name in $Snapshot.Keys) {
        if ($null -eq $Snapshot[$name]) { Remove-Item -LiteralPath ('Env:\' + $name) -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($name, $Snapshot[$name], 'Process') }
    }
}
