#requires -Version 7.5
# Agent CLI adapters on synthetic help texts, configuration files and fake CLIs: probe, sources, validation, headless arguments and agents.ps1.
# Configuration paths and the model table point at a fixture; the real profile is never read for the asserted values.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.AgentAdapters.psm1') -Force
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:agentChecks=0
function Assert-Agent($Condition,[string]$Message){if(!$Condition){throw ('FAIL AGENTS: '+$Message)};$script:agentChecks++}
function Assert-AgentError([scriptblock]$Body,[string]$Pattern,[string]$Message){$text=$null;try{& $Body|Out-Null}catch{$text=$_.Exception.Message};Assert-Agent ($text -and $text -match $Pattern) ($Message+': '+$text)}
function Write-AgentFixture([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
$fixture=Join-Path (Get-SBTestRoot) ('agents-'+[guid]::NewGuid().ToString('N'))
$brain=Join-Path $fixture 'brain'
Write-AgentFixture (Join-Path $brain 'config/agent-models.json') (Read-SBText (Join-Path $PSScriptRoot '../config/agent-models.json'))
$claudeHelp=@'
Usage: claude [options] [command] [prompt]
Options:
  --allowedTools, --allowed-tools <tools...>
      Comma or space-separated list of tool names to allow
  --disallowedTools, --disallowed-tools <tools...>
      Comma or space-separated list of tool names to deny
  --effort <level>                      Effort level for the current session
                                        (low, medium, high, xhigh, max)
  --model <model>                       Model for the current session. Provide
                                        an alias for the latest model (e.g.
                                        'fable', 'opus', or 'sonnet') or a
                                        model's full name.
  --output-format <format>              Output format (only works with --print)
  --permission-mode <mode>              Permission mode to use for the session
  -p, --print                           Print response and exit
'@
$codexHelp=@'
Run Codex non-interactively
Usage: codex exec [OPTIONS] [PROMPT]
Options:
  -c, --config <key=value>  Override a configuration value
  -m, --model <MODEL>       Model the agent should use
  -s, --sandbox <SANDBOX_MODE>  Select the sandbox policy
      --json                Print events to stdout as JSONL
'@
$geminiHelp=@'
Usage: gemini [options]
  -m, --model            Model
  -p, --prompt           Prompt. Appended to input on stdin (if any).
  -o, --output-format    The format of the CLI output.
      --approval-mode    Set the approval mode: default, auto_edit, yolo
'@
$none=@{settings=(Join-Path $fixture 'none/settings.json');config=(Join-Path $fixture 'none/config.toml');models=(Join-Path $fixture 'none/models_cache.json')}
$fakeExe=@{path='fake';prefix=@()}

# Help parsing: flags, Claude efforts and model aliases from the option descriptions.
$parsed=ConvertFrom-SBAgentHelp 'claude' $claudeHelp
Assert-Agent ('--model' -in $parsed.flags -and '--effort' -in $parsed.flags -and '-p' -in $parsed.flags) 'help flags include long options and short aliases'
Assert-Agent (($parsed.efforts -join ',') -ceq 'low,medium,high,xhigh,max') ('Claude effort choices come from --effort: '+($parsed.efforts -join ','))
Assert-Agent (($parsed.models -join ',') -ceq 'fable,opus,sonnet') ('Claude model aliases come from --model: '+($parsed.models -join ','))
Assert-Agent ((Get-SBAgentVersion "2.1.319 (Claude Code)`n") -ceq '2.1.319' -and (Get-SBAgentVersion 'codex-cli 0.167.0') -ceq '0.167.0' -and $null -eq (Get-SBAgentVersion '')) 'version is the first dotted number'

# Claude: probe, then configuration; the fallback table only validates and is never listed. settings.json gives the configured model and effort.
$claudeSettings=Join-Path $fixture 'claude/settings.json'
Write-AgentFixture $claudeSettings '{"model":"claude-opus-5-5","effortLevel":"high"}'
$claude=Get-SBAgentCapabilities -Provider claude -BrainRoot $brain -Executable $fakeExe -HelpText $claudeHelp -VersionText '2.1.319' -ConfigPaths @{settings=$claudeSettings}
Assert-Agent ($claude.installed -and $claude.status -eq 'ready' -and $claude.helpRead -and $claude.version -ceq '2.1.319' -and $claude.supports.model -and $claude.supports.effort -and !$claude.supports.streamJson) 'Claude capabilities from the probe'
Assert-Agent (@($claude.models|Where-Object {$_.id -eq 'opus' -and $_.source -eq 'probe'}).Count -eq 1 -and @($claude.models|Where-Object {$_.source -eq 'fallback'}).Count -eq 0 -and 'haiku' -in @($claude.fallbackModels)) 'Claude lists probe and config models only; fallback ids stay for validation'
Assert-Agent ($true -eq (Test-SBAgentSelection $claude 'haiku' '')) 'a model of the fallback table is still accepted when typed'
# Streaming: a help that names stream-json makes the runner read the agent steps live (stream-json plus --verbose).
$streaming=Get-SBAgentCapabilities -Provider claude -BrainRoot $brain -Executable $fakeExe -HelpText ($claudeHelp+"`n  --verbose  Verbose`n  (choices: `"text`", `"json`", `"stream-json`")") -VersionText '2.1.319' -ConfigPaths $none
Assert-Agent ($streaming.supports.streamJson -and ((New-SBAgentInvocation -Provider claude -Capabilities $streaming).arguments -join ' ').StartsWith('-p --output-format stream-json --verbose --permission-mode')) 'Claude streams with stream-json when the installed help offers it'
Assert-Agent (@($claude.models|Where-Object {$_.id -eq 'claude-opus-5-5'})[0].source -eq 'config' -and $claude.configured.model -ceq 'claude-opus-5-5' -and $claude.configured.effort -ceq 'high') 'configured model and effort come from settings.json'
Assert-Agent (@($claude.efforts|Where-Object {$_.source -ne 'probe'}).Count -eq 0 -and @($claude.efforts).Count -eq 5) 'Claude efforts all come from the probe'
$inv=New-SBAgentInvocation -Provider claude -Capabilities $claude -Model 'opus' -Effort 'max'
$a=$inv.arguments -join ' '
Assert-Agent ($a.StartsWith('-p --output-format json --permission-mode acceptEdits --allowedTools') -and $a -match '--disallowedTools Bash\(git commit:\*\) Bash\(git push:\*\)' -and $a.EndsWith('--model opus --effort max') -and !@($inv.omitted).Count) ('Claude headless arguments with the fixed permission profile: '+$a)
Assert-Agent ($true -eq (Test-SBAgentSelection $claude 'opus' 'max')) 'Claude selection with a known model and effort passes'
Assert-AgentError {Test-SBAgentSelection $claude 'opus' 'ultra'} 'ultra' 'Claude rejects an effort level it does not list'
Assert-AgentError {Test-SBAgentSelection $claude 'my-model' ''} 'AllowCustomModel' 'an unknown model names the -AllowCustomModel next step'
Assert-Agent ($true -eq (Test-SBAgentSelection $claude 'my-model' '' -AllowCustomModel)) '-AllowCustomModel accepts a model the probe does not list'
# A CLI without --effort in its help: the flag is omitted and the effort refused before running.
$old=Get-SBAgentCapabilities -Provider claude -BrainRoot $brain -Executable $fakeExe -HelpText ($claudeHelp -replace '(?ms)^\s*--effort.*?\(low, medium, high, xhigh, max\)\r?\n','') -VersionText '1.0.0' -ConfigPaths $none
Assert-Agent (!$old.supports.effort -and '--effort' -notin $old.flags) 'an older help without --effort does not support effort'
Assert-AgentError {Test-SBAgentSelection $old '' 'high'} 'Effort' 'effort is refused when the CLI exposes none'
Assert-Agent (@((New-SBAgentInvocation -Provider claude -Capabilities $old -Effort 'high').omitted) -contains '--effort') 'a flag missing from --help is omitted and reported'

# Codex: models and per-model levels from models_cache.json (hidden ones skipped), configured model from config.toml.
$codexHome=Join-Path $fixture 'codex'
Write-AgentFixture (Join-Path $codexHome 'config.toml') "model = `"gpt-a`"`nmodel_reasoning_effort = `"high`"`n`n[profiles.x]`nmodel = `"other`"`n"
Write-AgentFixture (Join-Path $codexHome 'models_cache.json') (ConvertTo-SBJson @{models=@(
    @{slug='gpt-a';display_name='GPT A';visibility='list';default_reasoning_level='low';supported_reasoning_levels=@(@{effort='low'},@{effort='high'},@{effort='ultra'})},
    @{slug='gpt-b';display_name='GPT B';visibility='list';supported_reasoning_levels=@(@{effort='low'},@{effort='medium'})},
    @{slug='gpt-hidden';visibility='hide';supported_reasoning_levels=@()})})
$codexPaths=@{config=(Join-Path $codexHome 'config.toml');models=(Join-Path $codexHome 'models_cache.json')}
$codex=Get-SBAgentCapabilities -Provider codex -BrainRoot $brain -Executable $fakeExe -HelpText $codexHelp -VersionText 'codex-cli 0.167.0' -ConfigPaths $codexPaths
Assert-Agent ((@($codex.models|ForEach-Object id) -join ',') -ceq 'gpt-a,gpt-b' -and @($codex.models|Where-Object {$_.source -ne 'config'}).Count -eq 0) ('Codex models from the cache, hidden skipped: '+(@($codex.models|ForEach-Object id) -join ','))
Assert-Agent ($codex.configured.model -ceq 'gpt-a' -and $codex.configured.effort -ceq 'high') 'Codex configured values come from top-level config.toml keys only'
Assert-Agent ($codex.supports.model -and $codex.supports.effort) 'Codex accepts model (-m) and effort (-c)'
Assert-Agent ($true -eq (Test-SBAgentSelection $codex 'gpt-a' 'ultra')) 'Codex effort is validated against the chosen model levels'
Assert-AgentError {Test-SBAgentSelection $codex 'gpt-b' 'high'} 'low, medium' 'Codex rejects a level the chosen model does not support'
$inv=New-SBAgentInvocation -Provider codex -Capabilities $codex -Model 'gpt-b' -Effort 'medium'
Assert-Agent (($inv.arguments -join ' ') -ceq 'exec --json --sandbox workspace-write --model gpt-b --config model_reasoning_effort="medium" -' -and (@($inv.omitted) -join ',') -ceq '--skip-git-repo-check') ('Codex headless arguments read the prompt from stdin: '+($inv.arguments -join ' '))

# Gemini: no effort flag, model from settings.json (object or string form), fallback models.
$geminiSettings=Join-Path $fixture 'gemini/settings.json'
Write-AgentFixture $geminiSettings '{"model":{"name":"gemini-x"}}'
$gemini=Get-SBAgentCapabilities -Provider gemini -BrainRoot $brain -Executable $fakeExe -HelpText $geminiHelp -VersionText '0.9.0' -ConfigPaths @{settings=$geminiSettings}
Assert-Agent ($gemini.supports.model -and !$gemini.supports.effort -and !@($gemini.efforts).Count) 'Gemini has a model flag and no effort'
Assert-Agent ($gemini.configured.model -ceq 'gemini-x' -and @($gemini.models)[0].id -ceq 'gemini-x' -and @($gemini.models|Where-Object {$_.source -eq 'fallback'}).Count -eq 0) 'Gemini lists its configured model and no fallback model'
Assert-Agent (((New-SBAgentInvocation -Provider gemini -Capabilities $gemini -Model 'gemini-x').arguments -join ' ') -ceq '--output-format json --approval-mode auto_edit --model gemini-x') 'Gemini headless arguments'
Assert-AgentError {Test-SBAgentSelection $gemini '' 'high'} 'Gemini' 'Gemini refuses an effort level'

# Not installed: no probe, nothing supported, no model or effort offered.
$absent=Get-SBAgentCapabilities -Provider gemini -BrainRoot $brain -NoProbe -ConfigPaths $none
Assert-Agent (!$absent.installed -and $absent.status -eq 'not-found' -and !$absent.helpRead -and !$absent.supports.model -and @($absent.models).Count -eq 0 -and @($absent.efforts).Count -eq 0) 'an absent CLI offers no model and no effort'
# Found but silent (no --version, no --help): reported as not responding.
$silent=Get-SBAgentCapabilities -Provider gemini -BrainRoot $brain -Executable $fakeExe -HelpText '' -VersionText '' -ConfigPaths $none
Assert-Agent ($silent.installed -and $silent.status -eq 'not-responding') 'a CLI that answers neither --version nor --help is not responding'
# Search folders outside PATH: per-OS lists (synthetic profile), the extra-folder variable and a CLI found only there.
$winDirs=@(Get-SBAgentSearchDirectories -Platform windows -ProfileRoot 'C:\Profiles\u' -IncludeMissing)
Assert-Agent (@($winDirs|Where-Object {$_ -match 'WinGet\\Links$'}).Count -eq 1 -and @($winDirs|Where-Object {$_ -match 'scoop\\shims$'}).Count -eq 1 -and @($winDirs|Where-Object {$_ -match 'npm$'}).Count -ge 1) ('Windows search folders include WinGet, npm and scoop: '+($winDirs -join ';'))
$unixDirs=@(Get-SBAgentSearchDirectories -Platform unix -ProfileRoot '/srv/u' -IncludeMissing)
Assert-Agent ('/opt/homebrew/bin' -in $unixDirs -and '/snap/bin' -in $unixDirs -and @($unixDirs|Where-Object {$_ -like '*/.volta/bin'}).Count -eq 1 -and @($unixDirs|Where-Object {$_ -like '*/.bun/bin'}).Count -eq 1) ('macOS/Linux search folders include Homebrew, snap, volta and bun: '+($unixDirs -join ';'))
$hidden=Join-Path $fixture 'hidden-bin'
Write-AgentFixture (Join-Path $hidden 'sbfakeagent.ps1') "'1.2.3'"
$savedSearch=$env:SECONDBRAIN_AGENT_SEARCH_PATH
try{
    $env:SECONDBRAIN_AGENT_SEARCH_PATH=$hidden
    $outside=Resolve-SBAgentExecutable 'sbfakeagent'
    Assert-Agent ($outside -and $outside.origin -eq 'search' -and $outside.script -like '*sbfakeagent.ps1') ('a CLI outside PATH is found in the search folders: '+($outside|ConvertTo-Json -Compress))
}finally{$env:SECONDBRAIN_AGENT_SEARCH_PATH=$savedSearch}
Assert-Agent ($null -eq (Resolve-SBAgentExecutable 'sbfakeagent-missing')) 'a CLI found nowhere resolves to nothing'
Assert-AgentError {Get-SBAgentProvider 'other'} 'claude, codex, gemini' 'an unknown provider lists the allowed values'
Assert-Agent ((Get-SBAgentProviderForPath 'C:\x\codex.cmd') -ceq 'codex' -and $null -eq (Get-SBAgentProviderForPath 'fake-agent.ps1')) 'provider from the executable name'

# Workstation override: entries appended to the fallback table.
$override=Join-Path $brain ('.runtime/hosts/'+(Get-SBHostId)+'/agent-models.local.json')
Write-AgentFixture $override '{"schemaVersion":1,"providers":{"gemini":{"models":[{"id":"gemini-local","label":"Local"}],"efforts":[]}}}'
Assert-Agent (@((Read-SBAgentModelTable $brain).gemini.models|Where-Object {$_.id -eq 'gemini-local'}).Count -eq 1) 'the local override adds models'
Write-AgentFixture $override '{"schemaVersion":2}'
Assert-AgentError {Read-SBAgentModelTable $brain} 'schemaVersion' 'an invalid model table is refused with the fix'
Remove-Item -LiteralPath $override -Force

# Real process probe with a fake CLI script (.ps1 wrapped in pwsh -File): version and help come from the process.
$fakeCli=Join-Path $fixture 'bin/claude.ps1'
Write-AgentFixture $fakeCli ("if(`$args -contains '--version'){'9.8.7 (Fake)';exit 0}`n@'`n"+$claudeHelp+"`n'@`n")
$exe=Resolve-SBAgentExecutable $fakeCli
Assert-Agent ($exe -and @($exe.prefix).Count -eq 3 -and $exe.prefix[2] -ceq $fakeCli) 'a .ps1 agent is wrapped in pwsh -File'
$probed=Get-SBAgentCapabilities -Provider claude -BrainRoot $brain -AgentPath $fakeCli -ConfigPaths $none
Assert-Agent ($probed.installed -and $probed.version -ceq '9.8.7' -and $probed.helpRead -and $probed.supports.effort -and $probed.path -ceq $fakeCli) ('the probe runs the CLI for --version and --help: '+($probed|ConvertTo-Json -Compress -Depth 4))

# agents.ps1: -Probe prints JSON for the requested providers; no mode exits 2.
$out=(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'agents.ps1') -Probe -Provider gemini 2>&1|Out-String)
$code=$LASTEXITCODE
$data=$out.Substring($out.IndexOf('{'))|ConvertFrom-Json -AsHashtable
Assert-Agent ($code -eq 0 -and @($data.agents).Count -eq 1 -and $data.agents[0].provider -eq 'gemini' -and $data.agents[0].ContainsKey('supports')) ('agents.ps1 -Probe prints the capabilities: '+$out)
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'agents.ps1') *> $null
Assert-Agent ($LASTEXITCODE -eq 2) 'agents.ps1 without a mode exits 2'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'agents.ps1') -Directives *> $null
Assert-Agent ($LASTEXITCODE -eq 2) 'agents.ps1 -Directives without -RepositoryPath exits 2'
# Limits: only the final error envelope counts, with each provider's own texts; transient rate limits are throttled, not quota.
$apos=[string][char]0x2019
Assert-Agent ((Get-SBAgentLimitState -Provider claude -Output ('{"type":"result","is_error":true,"result":"You'+$apos+'ve hit your limit · resets 5pm"}') -ExitCode 1).state -ceq 'quota') 'Claude limit with the typographic apostrophe is quota'
Assert-Agent ((Get-SBAgentLimitState -Provider claude -Output '{"type":"rate_limit_event","rate_limit_info":{"status":"rejected","resetsAt":1900000000,"rateLimitType":"five_hour"}}' -ExitCode 1).state -ceq 'quota') 'a rejected rate_limit_event is quota'
Assert-Agent ((Get-SBAgentLimitState -Provider claude -Output '' -ErrorOutput 'API Error: 429 rate_limit_error' -ExitCode 1).state -ceq 'throttled') 'a Claude 429 is throttled'
Assert-Agent ($null -eq (Get-SBAgentLimitState -Provider claude -Output '{"type":"assistant","message":{"content":[{"type":"text","text":"usage limit reached, quota, rate limit"}]}}' -ExitCode 2)) 'quota words in the agent text are not a limit'
Assert-Agent ($null -eq (Get-SBAgentLimitState -Provider claude -Output 'x' -ErrorOutput 'usage limit reached' -ExitCode $null)) 'the stderr of a killed agent is not read'
Assert-Agent ($null -eq (Get-SBAgentLimitState -Provider claude -Output '{"type":"result","is_error":false,"result":"usage limit reached"}' -ExitCode 0)) 'a successful result that mentions a limit is not a limit'
Assert-Agent ((Get-SBAgentLimitState -Provider codex -Output '{"type":"error","message":"You''ve hit your usage limit. Try again at 3:00 PM."}' -ExitCode 1).state -ceq 'quota') 'Codex usage limit error is quota'
Assert-Agent ($null -eq (Get-SBAgentLimitState -Provider codex -Output '{"type":"item.completed","item":{"type":"agent_message","text":"usage_limit_reached"}}' -ExitCode 1)) 'a Codex agent message is not a limit'
Assert-Agent ((Get-SBAgentLimitState -Provider gemini -Output '{"error":{"code":429,"message":"Quota exceeded for quota metric requests per day","status":"RESOURCE_EXHAUSTED"}}' -ExitCode 1).state -ceq 'quota') 'Gemini daily quota is quota'
Assert-Agent ((Get-SBAgentLimitState -Provider gemini -Output '{"error":{"code":429,"message":"Quota exceeded for quota metric requests per minute","status":"RESOURCE_EXHAUSTED"}}' -ExitCode 1).state -ceq 'throttled') 'Gemini per-minute quota is throttled'
# Quota read: Codex session files (rate_limits windows), else the runner observation; unknown when nothing is known.
$codexHome=Join-Path $fixture 'codex-home'
$now=[DateTimeOffset]::UtcNow
$line=@{timestamp=$now.ToString('o');type='event_msg';payload=@{type='token_count';rate_limits=@{primary=@{used_percent=100.0;window_minutes=300;resets_at=$now.AddHours(1).ToUnixTimeSeconds()};secondary=@{used_percent=40.0;window_minutes=10080;resets_at=$now.AddDays(2).ToUnixTimeSeconds()}}}}|ConvertTo-Json -Compress -Depth 6
Write-AgentFixture (Join-Path $codexHome ('sessions/'+$now.ToString('yyyy/MM/dd')+'/rollout-test.jsonl')) ("{`"type`":`"session_meta`"}`n"+$line+"`n")
$cq=Get-SBAgentQuota -Provider codex -CodexHome $codexHome
Assert-Agent ($cq.state -ceq 'exhausted' -and $cq.source -ceq 'codex-session' -and $cq.resetAt -and @($cq.windows).Count -eq 2) ('Codex full primary window is exhausted until its reset: '+($cq|ConvertTo-Json -Compress -Depth 5))
Assert-Agent ((Get-SBAgentQuota -Provider codex -CodexHome (Join-Path $fixture 'no-codex')).state -ceq 'unknown') 'no Codex session is unknown'
Assert-Agent ((Get-SBAgentQuota -Provider claude).state -ceq 'unknown') 'Claude without an observation is unknown'
Assert-Agent ((Get-SBAgentQuota -Provider claude -Observation @{state='exhausted';resetAt=$now.AddHours(1).ToString('o');observedAt=$now.ToString('o')}).state -ceq 'exhausted') 'an observed exhaustion with a future reset is exhausted'
Assert-Agent ((Get-SBAgentQuota -Provider claude -Observation @{state='exhausted';resetAt=$now.AddHours(-1).ToString('o');observedAt=$now.AddHours(-3).ToString('o')}).state -ceq 'unknown') 'an exhaustion past its reset is unknown'
Assert-Agent ((Get-SBAgentQuota -Provider claude -Observation @{state='exhausted';resetAt=$null;observedAt=$now.ToString('o')}).state -ceq 'unknown') 'an exhaustion without a reset time does not block'
'SUCCESS AGENTS: '+$script:agentChecks+' checks; retained fixture '+$fixture
