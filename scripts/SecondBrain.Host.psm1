#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')

function Get-SBHostId {
    $identity=[Environment]::MachineName+'|'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    'ws-'+(Get-SBTextHash $identity).Substring(0,16).ToLowerInvariant()
}
function Get-SBHostConfigPath([string]$BrainRoot) {
    Join-Path (Get-SBLocalRoot $BrainRoot (Get-SBHostId)) 'workstation.json'
}
function Get-SBCheckoutAsset([string]$Path,$Bindings=@()) {
    $root=Invoke-SBGit $Path @('rev-parse','--show-toplevel')
    if($root.code -ne 0){throw 'Checkout Git non leggibile'}
    $full=[IO.Path]::GetFullPath($root.output)
    $common=Invoke-SBGit $full @('rev-parse','--path-format=absolute','--git-common-dir')
    $gitDir=Invoke-SBGit $full @('rev-parse','--absolute-git-dir')
    $super=Invoke-SBGit $full @('rev-parse','--show-superproject-working-tree')
    if($common.code -ne 0 -or $gitDir.code -ne 0){throw 'Metadati Git non leggibili'}
    $origin=Invoke-SBGit $full @('config','--get','remote.origin.url')
    if($origin.code -notin @(0,1)){throw 'Origin non leggibile'}
    $remoteIdentity=if($origin.code -eq 0){ConvertTo-SBRepositoryIdentity $origin.output}else{$null}
    $binding=@($Bindings|Where-Object {$null -ne $_ -and [IO.Path]::GetFullPath($_.path) -eq $full})
    $identity=if($binding.Count -eq 1 -and $binding[0].remoteIdentity -ceq $remoteIdentity){$binding[0].identity}else{$remoteIdentity}
    $kind=if($super.output){'submodule'}elseif($common.output -ne $gitDir.output){'worktree'}else{'repository'}
    $agents=Join-Path $full 'AGENTS.md'
    @{id=(Get-SBTextHash $full.ToLowerInvariant()).Substring(0,24).ToLowerInvariant();path=$full;name=[IO.Path]::GetFileName($full);identity=$identity;remoteIdentity=$remoteIdentity;
      kind=$kind;commonGitDir=$common.output;agentsHash=(Get-SBFileHash $agents);fingerprint=(Get-SBTextHash ($full+'|'+$remoteIdentity+'|'+$common.output));status='discovered';requiresIdentity=(!$identity)}
}
function Get-SBIDERoot([string]$Variable,[string]$Default) {
    $value=[Environment]::GetEnvironmentVariable($Variable,'User');$source='user-env'
    if(!$value){$value=[Environment]::GetEnvironmentVariable($Variable,'Process');$source='process-env'}
    if(!$value){$value=$Default;$source='default'}
    @{path=$value;source=$source}
}
function Get-SBIDEContext([string]$Name) {
    # Contesto osservabile senza leggere archivi di autenticazione: radice di configurazione, origine dell override e cartelle di configurazione presenti.
    # Non rileva un cambio di account nella stessa radice: quello resta dichiarato (accountAlias) e provato dalla ricevuta di osservazione.
    # Le configurazioni migrate usano nomi descrittivi (es. "Claude Code (file CLAUDE.md)"): si riconducono al nome canonico.
    $Name=switch -Regex ($Name){
        '^Claude Code' {'Claude Code'}
        '^Codex' {'Codex'}
        '^Antigravity' {'Antigravity'}
        '^Cursor' {'Cursor'}
        '^Windsurf' {'Windsurf'}
        '^JetBrains' {'JetBrains AI'}
        '^Android Studio' {'Android Studio'}
        '^(VS Code \+ )?Continue' {'Continue'}
        '^Claude \(app|^Claude account' {'Claude account instructions'}
        default {$Name}
    }
    $profileRoot=$env:USERPROFILE;$appData=$env:APPDATA
    $claude=Get-SBIDERoot 'CLAUDE_CONFIG_DIR' (Join-Path $profileRoot '.claude')
    $codex=Get-SBIDERoot 'CODEX_HOME' (Join-Path $profileRoot '.codex')
    $instructions='';$root=@{path='';source=''};$candidates=@()
    switch($Name){
        'Claude Code' {$root=$claude;$instructions=Join-Path $claude.path 'CLAUDE.md'}
        'Codex' {$root=$codex;$instructions=Join-Path $codex.path 'AGENTS.md'}
        'Antigravity' {$root=@{path=(Join-Path $profileRoot '.gemini');source='default'};$instructions=Join-Path $profileRoot '.gemini/GEMINI.md'}
        'Cursor' {$candidates=@(@{label='~/.cursor';path=(Join-Path $profileRoot '.cursor')},@{label='%APPDATA%/Cursor';path=(Join-Path $appData 'Cursor')})}
        'Windsurf' {$candidates=@(@{label='~/.windsurf';path=(Join-Path $profileRoot '.windsurf')},@{label='~/.codeium';path=(Join-Path $profileRoot '.codeium')},@{label='%APPDATA%/Windsurf';path=(Join-Path $appData 'Windsurf')})}
        'JetBrains AI' {$candidates=@(@{label='%APPDATA%/JetBrains';path=(Join-Path $appData 'JetBrains')})}
        'Continue' {$candidates=@(@{label='~/.continue';path=(Join-Path $profileRoot '.continue')})}
        'Android Studio' {$candidates=@(@{label='%APPDATA%/Google';path=(Join-Path $appData 'Google')})}
        'Claude account instructions' {$candidates=@(@{label='%APPDATA%/Claude';path=(Join-Path $appData 'Claude')})}
        default {return $null}
    }
    $present=@($candidates|Where-Object {$_.path -and (Test-Path -LiteralPath $_.path)}|ForEach-Object {$_.label}|Sort-Object)
    $fingerprint=Get-SBTextHash (@($Name,$instructions.ToLowerInvariant(),$root.source,([string]$root.path).ToLowerInvariant(),($present -join ',')) -join '|')
    @{name=$Name;instructions=$instructions;rootSource=$root.source;configDirectories=$present;fingerprint=$fingerprint}
}
function Get-SBIDEAssets {
    $codexRoot=Split-Path -Parent (Get-SBIDEContext 'Codex').instructions
    $definitions=@(
        @{name='Claude Code';adapter='claude-code';instructions=(Get-SBIDEContext 'Claude Code').instructions;commands=@('claude')},
        @{name='Codex';adapter='codex';instructions=(Get-SBIDEContext 'Codex').instructions;commands=@('codex')},
        @{name='Antigravity';adapter='antigravity';instructions=(Get-SBIDEContext 'Antigravity').instructions;commands=@('antigravity')},
        @{name='VS Code';adapter='vscode';instructions='';commands=@('code','code-insiders')},
        @{name='Cursor';adapter='manual';instructions='';commands=@('cursor')},
        @{name='Windsurf';adapter='manual';instructions='';commands=@('windsurf')},
        @{name='Android Studio';adapter='manual';instructions='';commands=@('studio64','studio')}
    )
    $installed=@()
    foreach($registryPath in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')){
        $installed+=@(Get-ItemProperty $registryPath -ErrorAction SilentlyContinue|Where-Object {$_.PSObject.Properties.Name -contains 'DisplayName'}|ForEach-Object {[string]$_.DisplayName})
    }
    if(Get-Command Get-AppxPackage -ErrorAction SilentlyContinue){$installed+=@(Get-AppxPackage -ErrorAction SilentlyContinue|ForEach-Object {$_.Name})}
    foreach($definition in $definitions){
        $executables=@(foreach($command in $definition.commands){Get-Command $command -ErrorAction SilentlyContinue|Select-Object -ExpandProperty Source})
        $evidence=@($installed|Where-Object {$_ -match [regex]::Escape($definition.name)})
        $mcpConfigPath = $null
        $mcpConfigured = $false
        if ($definition.name -eq 'Codex') {
            $codexToml = Join-Path $codexRoot 'config.toml'
            $mcpConfigPath = $codexToml
            if (Test-Path -LiteralPath $codexToml -PathType Leaf) {
                $content = Get-Content -LiteralPath $codexToml -Raw -ErrorAction SilentlyContinue
                if ($content -match 'mcp_servers\.secondbrain|secondbrain') {
                    $mcpConfigured = $true
                }
            }
        }
        if ($definition.name -eq 'Android Studio') {
            $googleConfig = Join-Path $env:APPDATA 'Google'
            if (Test-Path -LiteralPath $googleConfig) {
                $asDirs = @(Get-ChildItem -LiteralPath $googleConfig -Filter '*AndroidStudio*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
                if ($asDirs.Count) {
                    $evidence += ("Config: " + ($asDirs -join ", "))
                }
            }
        }
        $context=Get-SBIDEContext $definition.name
        # Cursor e Windsurf: solo presenza delle cartelle di configurazione (nessuna lettura di credenziali o sessioni).
        if($definition.name -in @('Cursor','Windsurf')){$evidence+=@($context.configDirectories|ForEach-Object {'Directory: '+$_})}
        if($executables.Count -or $evidence.Count -or ($definition.instructions -and (Test-Path -LiteralPath $definition.instructions))){
            @{id=$definition.adapter+'-'+(Get-SBTextHash $definition.name).Substring(0,8);name=$definition.name;adapter=$definition.adapter;mode=$(if($definition.instructions){'file'}else{'manual'});
              instructions=$definition.instructions;sha256=$(if($definition.instructions){Get-SBFileHash $definition.instructions}else{'absent'});executables=$executables;installationEvidence=$evidence;
              mcpConfigPath=$mcpConfigPath;mcpConfigured=$mcpConfigured;profile='current-user';accountAlias='';accountStatus='unverified';loadingStatus='unverified';
              environmentFingerprint=$(if($context){$context.fingerprint}else{''});selected=$false}
        }
    }
    foreach($name in @('Claude account instructions','Continue','JetBrains AI')){
        $evidence=@()
        if ($name -eq 'JetBrains AI') {
            $jetBrains=Get-SBIDEContext 'JetBrains AI'
            if ($jetBrains.configDirectories.Count) {
                $products=@(Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'JetBrains') -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
                $evidence += ('Directory: %APPDATA%/JetBrains'+$(if($products.Count){' ('+($products -join ', ')+')'}else{''}))
            }
        }
        if ($name -eq 'Continue') {
            $continueDir = Join-Path $env:USERPROFILE '.continue'
            if (Test-Path -LiteralPath $continueDir) { $evidence += 'Directory: ~/.continue' }
            $vscodeExt = Join-Path $env:USERPROFILE '.vscode/extensions'
            if (Test-Path -LiteralPath $vscodeExt) {
                $found = @(Get-ChildItem -LiteralPath $vscodeExt -Filter '*continue*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
                if ($found.Count) { $evidence += ('VS Code extension: ' + ($found -join ', ')) }
            }
        }
        elseif ($name -eq 'Claude account instructions') {
            $claudeDesktop = Join-Path $env:LOCALAPPDATA 'Programs\Claude\Claude.exe'
            if (Test-Path -LiteralPath $claudeDesktop) { $evidence += "Claude Desktop: $claudeDesktop" }
            $claudeData = Join-Path $env:APPDATA 'Claude'
            if (Test-Path -LiteralPath $claudeData) { $evidence += "Config: $claudeData" }
        }
        @{id='manual-'+(Get-SBTextHash $name).Substring(0,8);name=$name;adapter='manual';mode='manual';instructions='';sha256='absent';executables=@();installationEvidence=$evidence;profile='current-user';accountAlias='';accountStatus='unverified';loadingStatus='unverified';environmentFingerprint=(Get-SBIDEContext $name).fingerprint;selected=$false}
    }
}
function ConvertTo-SBHostComparablePath([string]$Path) {
    # Come ConvertTo-SBComparablePath di Core (unica forma di confronto), ma tollerante: percorso vuoto o non valido non interrompe la ricognizione.
    if(!$Path){return ''}
    try{ConvertTo-SBComparablePath $Path}catch{$Path.TrimEnd('\','/').ToLowerInvariant()}
}
function Get-SBSharedPolicy([string]$BrainRoot) {
    $policy=@{allowedOwners=@();excludedDirectories=@();forbiddenRepositories=@()}
    $sharedPath=Join-Path $BrainRoot 'config/shared.json'
    if(Test-Path -LiteralPath $sharedPath){
        $shared=Read-SBJson $sharedPath @{}
        foreach($key in @($policy.Keys)){if($shared.ContainsKey($key)){$policy[$key]=@($shared[$key])}}
    }
    $policy
}
function Get-SBForbiddenRepositories([string]$BrainRoot,$HostConfig) {
    $list=@();if($HostConfig -and $HostConfig.ContainsKey('forbiddenRepositories')){$list=@($HostConfig.forbiddenRepositories)}
    @($list+@((Get-SBSharedPolicy $BrainRoot).forbiddenRepositories))
}
function Test-SBForbiddenRepository($List,[string]$Path,[string]$Identity='') {
    $comparable=ConvertTo-SBHostComparablePath $Path
    foreach($f in @($List)){
        if($f.ContainsKey('path') -and $f.path -and $comparable -and $comparable -ieq (ConvertTo-SBHostComparablePath $f.path)){return $true}
        if($f.ContainsKey('identity') -and $f.identity -and $Identity -and $f.identity -ieq $Identity){return $true}
    }
    $false
}
function Test-SBSystemAccessPath([string]$Path) {
    # Cartelle di sistema o di altri profili: un accesso negato li e atteso e non rende incompleta la ricognizione.
    $full=ConvertTo-SBHostComparablePath $Path
    if(!$full){return $false}
    foreach($base in @($env:SystemRoot,$env:ProgramFiles,${env:ProgramFiles(x86)},$env:ProgramData)){
        if($base){$prefix=ConvertTo-SBHostComparablePath $base;if($full -ieq $prefix -or $full.StartsWith($prefix+'\',[StringComparison]::OrdinalIgnoreCase)){return $true}}
    }
    if($full -match '^[A-Za-z]:\\(?:\$Recycle\.Bin|System Volume Information|Recovery|Config\.Msi|Documents and Settings)(?:\\|$)'){return $true}
    if($full -match '^[A-Za-z]:\\Users\\(?<profile>[^\\]+)(?:\\|$)'){return $Matches.profile -ine $env:USERNAME}
    $false
}
function Invoke-SBHostDiscovery {
    param([string]$BrainRoot,[string[]]$Roots=@(),$Bindings=@(),[string]$ResumePath,[string]$ReportPath,[int]$MaxDirectories=0)
    $brain=[IO.Path]::GetFullPath($BrainRoot);$queue=[Collections.Generic.Queue[string]]::new();$visited=@{};$repositories=@();$issues=@();$warnings=@();$excluded=@();$portableIDEs=@()
    if(!$Roots.Count){$Roots=@([IO.DriveInfo]::GetDrives()|Where-Object {$_.IsReady -and $_.DriveType -eq 'Fixed'}|ForEach-Object {$_.RootDirectory.FullName})}
    if($ResumePath){
        [void](Assert-SBCentralDataPath $brain $ResumePath);$resume=Read-SBJson $ResumePath $null
        if(!$resume -or $resume.schemaVersion -ne 1 -or !(Test-SBSamePath $resume.brainRoot $brain) -or $resume.hostId -ne (Get-SBHostId)){throw 'Checkpoint discovery di altra postazione o clone'}
        $Roots=@($resume.roots);foreach($path in $resume.pending){$queue.Enqueue($path)};foreach($path in $resume.visited){$visited[$path]=$true}
        $repositories=@($resume.repositories);$issues=@($resume.issues);$excluded=@($resume.excluded)
        if($resume.ContainsKey('warnings')){$warnings=@($resume.warnings)}
    }else{foreach($root in $Roots){$full=[IO.Path]::GetFullPath($root);if(!(Test-Path -LiteralPath $full -PathType Container)){throw 'Radice discovery assente: '+$full};$queue.Enqueue($full)}}
    $count=0;$paused=$false;$hardExcludedNames=@('Windows','Program Files','Program Files (x86)','AppData','node_modules','.venv');$excludedNames=@($hardExcludedNames+@('bin','obj'))
    $configPath=Get-SBHostConfigPath $brain
    $hostCfg=if(Test-Path -LiteralPath $configPath){Read-SBJson $configPath @{}}else{@{}}
    $sharedPolicy=Get-SBSharedPolicy $brain
    $forbiddenList=@(Get-SBForbiddenRepositories $brain $hostCfg)
    $excludedNames=@($excludedNames+$sharedPolicy.excludedDirectories|Sort-Object -Unique)
    # Un nome "da build" (bin, build, dist, vendor, ...) non nasconde un checkout: si salta solo se la cartella non contiene .git.
    $isSkippedName={param([string]$Name,[string]$FullPath) $Name -in $excludedNames -and ($Name -in $hardExcludedNames -or !(Test-Path -LiteralPath (Join-Path $FullPath '.git')))}
    $allowedOwners=@();if($hostCfg.ContainsKey('allowedOwners')){$allowedOwners=@($hostCfg.allowedOwners)}
    $allowedOwners=@($allowedOwners+$sharedPolicy.allowedOwners|Sort-Object -Unique)
    while($queue.Count){
        if($MaxDirectories -gt 0 -and $count -ge $MaxDirectories){$paused=$true;break}
        $path=$queue.Dequeue();if($visited.ContainsKey($path)){continue};$visited[$path]=$true;$count++
        try{
            $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
            if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){$excluded+=@{path=$path;reason='reparse-point'};continue}
            if($path -eq (Join-Path $brain '.runtime')){$excluded+=@{path=$path;reason='SecondBrain operational data'};continue}
            if(& $isSkippedName $item.Name $path){$excluded+=@{path=$path;reason='known-system-or-build-tree'};continue}
            if(Test-SBForbiddenRepository $forbiddenList $path){$excluded+=@{path=$path;reason='forbidden-by-user-policy'};continue}
            $entries=@(Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop)
            if(@($entries|Where-Object Name -eq '.git').Count){
                $asset=Get-SBCheckoutAsset $path $Bindings
                if(Test-SBForbiddenRepository $forbiddenList $path ([string]$asset.identity)){
                    $excluded+=@{path=$path;reason='forbidden-by-user-policy';identity=$asset.identity}
                    continue
                }
                if($allowedOwners.Count -gt 0 -and $asset.remoteIdentity){
                    $ownerMatch=$false
                    foreach($owner in $allowedOwners){
                        if($asset.remoteIdentity -match ("^(?:github\.com|gitlab\.com|bitbucket\.org)/"+[regex]::Escape($owner)+"/")){ $ownerMatch=$true; break }
                    }
                    if(!$ownerMatch){
                        $asset.kind='external'
                        $asset.status='external-ignored'
                        $excluded+=@{path=$path;reason='external-project-detected';identity=$asset.identity}
                        continue
                    }
                }
                $repositories+=$asset
            }
            elseif((Test-Path -LiteralPath (Join-Path $path 'HEAD') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $path 'objects') -PathType Container) -and (Test-Path -LiteralPath (Join-Path $path 'config') -PathType Leaf)){
                $bare=Invoke-SBGit $path @('rev-parse','--is-bare-repository')
                if($bare.code -eq 0 -and $bare.output -eq 'true'){$repositories+=@{id=(Get-SBTextHash $path).Substring(0,24);path=$path;name=[IO.Path]::GetFileName($path);kind='bare';status='reference-only';identity=$null};continue}
            }
            foreach($entry in $entries){
                if($entry.PSIsContainer){
                    if($entry.Name -eq '.git'){continue}
                    if(& $isSkippedName $entry.Name $entry.FullName){$excluded+=@{path=$entry.FullName;reason='known-system-or-build-tree'};continue}
                    $queue.Enqueue($entry.FullName)
                }
                elseif($entry.Name -match '^(?:Code(?: - Insiders)?|Cursor|Windsurf|studio64|Antigravity|Claude|Codex)\.exe$'){
                    $portableIDEs+=@{id='executable-'+(Get-SBTextHash $entry.FullName).Substring(0,16);name=$entry.BaseName;adapter='manual';mode='manual';instructions='';sha256='absent';executables=@($entry.FullName);profile='unverified';accountAlias='';accountStatus='unverified';loadingStatus='unverified';selected=$false}
                }
            }
        }catch{
            # Solo cartelle di sistema o di altri profili non leggibili sono un avviso; nelle cartelle dell'utente la ricognizione resta incompleta.
            if($_.Exception -is [UnauthorizedAccessException] -or $_.Exception.InnerException -is [UnauthorizedAccessException]){
                if(Test-SBSystemAccessPath $path){$warnings+=@{path=$path;kind='access-denied'}}
                else{$issues+=@{path=$path;kind='access-denied';reason='UnauthorizedAccessException'}}
            }
            else{$issues+=@{path=$path;kind='unreadable';reason=$_.Exception.GetType().Name}}
        }
    }
    $extensions=@([IO.DriveInfo]::GetDrives()|Where-Object {$_.DriveType -in @('Network','Removable')}|ForEach-Object {@{kind=$_.DriveType.ToString();path=$_.Name;included=$false}})
    foreach($kind in @('WSL','VM','container')){$extensions+=@{kind=$kind;included=$false;status='requires-explicit-selection'}}
    $report=@{schemaVersion=1;hostId=(Get-SBHostId);brainRoot=$brain;observedAt=[DateTimeOffset]::UtcNow.ToString('o');roots=$Roots;visited=@($visited.Keys|Sort-Object);pending=@($queue.ToArray());
        complete=(!$paused -and !$issues.Count);paused=$paused;repositories=@($repositories|Sort-Object path -Unique);ides=@((Get-SBIDEAssets)+$portableIDEs);issues=$issues;warnings=$warnings;excluded=$excluded;extensions=$extensions}
    if($ReportPath){$output=Assert-SBCentralDataPath $brain $ReportPath;[IO.Directory]::CreateDirectory((Split-Path $output))|Out-Null;Write-SBFile $output ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $report))) (Get-SBFileHash $output) (Join-Path (Get-SBLocalRoot $brain (Get-SBHostId)) 'backups')|Out-Null}
    $report
}
function Get-SBWorkEnvironment {
    param([string]$BrainRoot,[string]$HostId,[string]$Repository,[string]$Project='root',[string]$Runtime='default')
    foreach($segment in @($Project,$Runtime)){if($segment -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$'){throw 'Progetto/runtime non valido'}}
    $relative='repositories/'+(Get-SBTextHash $Repository).Substring(0,24).ToLowerInvariant()+'/'+$Project+'/'+$Runtime
    $location='brain-runtime';$advice=@()
    $override=$env:SECONDBRAIN_WORK_LOCAL_ROOT
    if($override){
        # Cervello su share: TEMP, cache e build dell'host possono stare su un disco locale (eccezione dichiarata, non il comportamento predefinito).
        if(![IO.Path]::IsPathFullyQualified($override) -or $override.StartsWith('\\')){throw 'SECONDBRAIN_WORK_LOCAL_ROOT deve essere un percorso locale assoluto'}
        $hostRoot=Join-Path ([IO.Path]::GetFullPath($override)) (Split-Path (Get-SBLocalRoot $BrainRoot $HostId) -Leaf)
        $root=[IO.Path]::GetFullPath((Join-Path $hostRoot $relative));$location='local-override'
    }else{
        $root=Assert-SBCentralDataPath $BrainRoot (Join-Path (Get-SBLocalRoot $BrainRoot $HostId) $relative)
        if($BrainRoot.StartsWith('\\')){$advice+='Cervello su share: cache e build risiedono sulla rete. Impostare SECONDBRAIN_WORK_LOCAL_ROOT su un disco locale per prestazioni e per non mescolare TEMP tra host.'}
    }
    $map=@{SECONDBRAIN_WORK_ROOT=$root;TEMP=(Join-Path $root 'temp');TMP=(Join-Path $root 'temp');TMPDIR=(Join-Path $root 'temp');XDG_CACHE_HOME=(Join-Path $root 'cache');npm_config_cache=(Join-Path $root 'cache/npm');NUGET_PACKAGES=(Join-Path $root 'cache/nuget');DOTNET_CLI_HOME=(Join-Path $root 'cache/dotnet');GRADLE_USER_HOME=(Join-Path $root 'cache/gradle');CARGO_TARGET_DIR=(Join-Path $root 'build/cargo');PIP_CACHE_DIR=(Join-Path $root 'cache/pip');PYTHONPYCACHEPREFIX=(Join-Path $root 'cache/python')}
    @{root=$root;location=$location;advice=$advice;environment=$map;buildRoot=(Join-Path $root 'build');status='configuration-only';exceptions=@('Tool-specific intermediate/output configuration must be verified in the product repository; environment alone does not redirect every build output.')}
}
Export-ModuleMember -Function @(
    'Get-SBHostId',
    'Get-SBHostConfigPath',
    'Get-SBCheckoutAsset',
    'Get-SBIDEContext',
    'Get-SBIDEAssets',
    'Get-SBSharedPolicy',
    'Get-SBForbiddenRepositories',
    'Test-SBForbiddenRepository',
    'Test-SBSystemAccessPath',
    'Invoke-SBHostDiscovery',
    'Get-SBWorkEnvironment'
)
