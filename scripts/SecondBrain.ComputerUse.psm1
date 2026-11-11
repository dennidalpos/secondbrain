#requires -Version 7.5
# Computer use without a person present: which agents can pre-approve it, the opt-in Codex setting and the runner preflight (#455).
# Pure functions plus one guarded write (Set-SBCodexComputerUseApps). Nothing here enables computer use by itself.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'computeruse.app.invalid' = @{it='Identificatore di app non valido: {0}. Usare l''ID dell''app senza spazi, apici o caratteri di controllo (separare più ID con virgola o punto e virgola)';en='Invalid app identifier: {0}. Use the app ID without spaces, quotes or control characters (separate several IDs with a comma or semicolon)'}
    'computeruse.apply.hash.missing' = @{it='Applicazione rifiutata: manca -PreviewSha256. Eseguire prima l''anteprima senza -Apply e riusare il valore previewSha256';en='Apply refused: -PreviewSha256 is missing. Run the preview without -Apply first and reuse its previewSha256 value'}
    'computeruse.appid.required' = @{it='Manca -AppId: indicare almeno un ID app dopo -CodexApps';en='-AppId is missing: give at least one app ID after -CodexApps'}
    'computeruse.usage' = @{it='Nessuna modalità indicata. Usare -Table (tabella delle capacità per IDE) oppure -CodexApps -AppId <id>[,<id>] (anteprima della pre-approvazione Codex; aggiungere -Apply -PreviewSha256 <hash> per scriverla)';en='No mode given. Use -Table (capability table per IDE) or -CodexApps -AppId <id>[,<id>] (preview of the Codex pre-approval; add -Apply -PreviewSha256 <hash> to write it)'}
    'computeruse.toml.ambiguous' = @{it='Configurazione Codex ambigua per always_allowed_app_ids: modificarla a mano';en='Ambiguous Codex configuration for always_allowed_app_ids: edit it by hand'}
    'computeruse.apply.preview' = @{it='Applicazione rifiutata: -PreviewSha256 non corrisponde all''anteprima corrente. Rieseguire l''anteprima e usare il nuovo previewSha256';en='Apply refused: -PreviewSha256 does not match the current preview. Rerun the preview and use the new previewSha256'}
    'computeruse.platform' = @{it='La pre-approvazione di Codex per computer use e documentata solo per Windows';en='Codex computer-use pre-approval is documented for Windows only'}
}
$script:SBCodexTable='computer_use.windows'
$script:SBCodexKey='always_allowed_app_ids'
# unattended: opt-in-config (a documented setting pre-approves apps), interactive-only (approval needs a person), mcp-tools-only (no native computer use, MCP tools only), not-documented.
$script:SBComputerUseCapabilities=@(
    @{ide='Claude Code';unattended='interactive-only';mechanism='';platforms=@('windows','macos','linux');note='`claude -p` cannot approve apps: tasks that need computer use stay for attended sessions.'},
    @{ide='Codex';unattended='opt-in-config';mechanism=('[{0}] {1}' -f $script:SBCodexTable,$script:SBCodexKey);platforms=@('windows');note='Documented in the Codex configuration reference; not verified with `codex exec` on this workstation.'},
    @{ide='Cursor';unattended='mcp-tools-only';mechanism='';platforms=@();note='No native computer use documented; only MCP tools.'},
    @{ide='Antigravity';unattended='mcp-tools-only';mechanism='';platforms=@();note='No native computer use documented; only MCP tools.'},
    @{ide='VS Code (Copilot)';unattended='mcp-tools-only';mechanism='';platforms=@();note='No native computer use documented; only MCP tools.'},
    @{ide='Windsurf';unattended='not-documented';mechanism='';platforms=@();note='Nothing documented about computer use.'}
)
# Vocabulary of capabilities a task may require (extensions.requires): this module owns the list.
$script:SBTaskRequiresValues=@('computer-use')
function Get-SBComputerUseRequiresValues { ,@($script:SBTaskRequiresValues) }
function Get-SBComputerUseRequirement { 'computer-use' }
function Get-SBComputerUseCapabilities { ,@($script:SBComputerUseCapabilities|ForEach-Object {$_.Clone()}) }
function Get-SBComputerUseAgentName([string]$AgentPath) {
    # Agent identity from the executable name only; any other agent is unknown and gets no pre-approval.
    if(!$AgentPath){return $null}
    $leaf=[IO.Path]::GetFileNameWithoutExtension($AgentPath).ToLowerInvariant()
    switch($leaf){'claude'{'Claude Code'}'codex'{'Codex'}default{$null}}
}
function ConvertTo-SBCodexAppIds([string[]]$AppIds) {
    # ';' also separates values (pwsh -File passes lists as one string). Literal TOML strings are used, so quotes and control characters are refused.
    $ids=@($AppIds|ForEach-Object {$_ -split ';'}|ForEach-Object {$_.Trim()}|Where-Object {$_}|Select-Object -Unique)
    foreach($id in $ids){if($id.Length -gt 260 -or $id -match "['`"\s\x00-\x1f]"){throw (New-SBError 'computeruse.app.invalid' @($id))}}
    ,$ids
}
function Read-SBCodexAllowedApps([string]$Text) {
    # Exactly one single-line array in [computer_use.windows], and no other mention of the key; anything else is ambiguous and never rewritten.
    $keyLines=@([regex]::Matches($Text,'(?m)^[ \t]*[^#\r\n]*'+$script:SBCodexKey+'[^\r\n]*'))
    if(!$keyLines.Count){return @{status='absent';ids=@()}}
    $header='(?m)^\['+[regex]::Escape($script:SBCodexTable)+'\][ \t]*(?:#[^\r\n]*)?\r?$'
    $tables=[regex]::Matches($Text,$header)
    if($tables.Count -ne 1 -or $keyLines.Count -ne 1){return @{status='ambiguous';ids=@()}}
    $start=$tables[0].Index+$tables[0].Length
    $next=[regex]::Match($Text.Substring($start),'(?m)^\[')
    $end=if($next.Success){$start+$next.Index}else{$Text.Length}
    $line=[regex]::Match($Text.Substring($start,$end-$start),'(?m)^[ \t]*'+$script:SBCodexKey+'[ \t]*=[ \t]*\[(?<items>[^\]\r\n]*)\][ \t]*(?:#[^\r\n]*)?\r?$')
    if(!$line.Success){return @{status='ambiguous';ids=@()}}
    $ids=@()
    $rest=$line.Groups['items'].Value.Trim()
    while($rest){
        $item=[regex]::Match($rest,"^(?:'(?<v>[^']*)'|`"(?<v>[^`"\\]*)`")[ \t]*(?:,[ \t]*|$)")
        if(!$item.Success){return @{status='ambiguous';ids=@()}}
        $ids+=$item.Groups['v'].Value
        $rest=$rest.Substring($item.Length).Trim()
    }
    @{status='ok';ids=@($ids)}
}
function Get-SBCodexComputerUsePlan([string]$Text,[string[]]$AppIds) {
    # Adds the given app IDs to computer_use.windows.always_allowed_app_ids (never removes); preserves every other byte of the file.
    $add=ConvertTo-SBCodexAppIds $AppIds
    $current=Read-SBCodexAllowedApps $Text
    if($current.status -eq 'ambiguous'){throw (New-SBError 'computeruse.toml.ambiguous')}
    $merged=@($current.ids)+@($add|Where-Object {$_ -cnotin $current.ids})
    $added=@($merged|Where-Object {$_ -cnotin $current.ids})
    $array='['+(($merged|ForEach-Object {"'"+$_+"'"}) -join ', ')+']'
    $newLine=$script:SBCodexKey+' = '+$array
    $newText=$Text
    if($added.Count){
        $header='(?m)^\['+[regex]::Escape($script:SBCodexTable)+'\][ \t]*(?:#[^\r\n]*)?\r?$'
        $tables=[regex]::Matches($Text,$header)
        if($tables.Count -gt 1){throw (New-SBError 'computeruse.toml.ambiguous')}
        if($tables.Count -eq 0){
            $newText=$Text.TrimEnd("`r","`n")+$(if($Text.Trim()){"`n`n"}else{''})+'['+$script:SBCodexTable+"]`n"+$newLine+"`n"
        }elseif($current.status -eq 'absent'){
            $start=$tables[0].Index+$tables[0].Length
            $next=[regex]::Match($Text.Substring($start),'(?m)^\[')
            $end=if($next.Success){$start+$next.Index}else{$Text.Length}
            $body=$Text.Substring($start,$end-$start)
            $newText=$Text.Substring(0,$start)+$body.TrimEnd("`r","`n")+"`n"+$newLine+"`n"+$(if($next.Success){"`n"}else{''})+$Text.Substring($end)
        }else{
            $pattern='(?m)^([ \t]*)'+$script:SBCodexKey+'[ \t]*=[ \t]*\[[^\]\r\n]*\]'
            $newText=[regex]::new($pattern).Replace($Text,[Text.RegularExpressions.MatchEvaluator]{param($m) $m.Groups[1].Value+$newLine},1)
        }
    }
    @{status=$(if($added.Count){'changed'}else{'unchanged'});existing=@($current.ids);added=@($added);ids=@($merged);text=$newText;sha256=(Get-SBTextHash $newText);currentSha256=(Get-SBTextHash $Text)}
}
function Get-SBCodexConfigPath { Join-Path (Split-Path -Parent (Get-SBIDEContext 'Codex').instructions) 'config.toml' }
function Set-SBCodexComputerUseApps([string]$BrainRoot,[string[]]$AppIds,[string]$ConfigPath,[switch]$Apply,[string]$PreviewSha256) {
    # Preview by default. -Apply needs the preview hash and writes through Write-SBFile with a verified backup.
    if(!$IsWindows){throw (New-SBError 'computeruse.platform')}
    if(!$ConfigPath){$ConfigPath=Get-SBCodexConfigPath}
    $exists=Test-Path -LiteralPath $ConfigPath -PathType Leaf
    $text=if($exists){[IO.File]::ReadAllText($ConfigPath)}else{''}
    $plan=Get-SBCodexComputerUsePlan $text $AppIds
    $result=@{applied=$false;status=$plan.status;path=$ConfigPath;existing=$plan.existing;added=$plan.added;previewSha256=$plan.sha256;configExists=$exists}
    if($plan.status -eq 'changed' -and !$Apply){
        $result.applyCommand='pwsh -NoProfile -File scripts/computer-use.ps1 -CodexApps -AppId '+((@($plan.added)|ForEach-Object {"'"+$_+"'"}) -join ',')+' -Apply -PreviewSha256 '+$plan.sha256
    }
    if($Apply -and $plan.status -eq 'changed'){
        if(!$PreviewSha256){throw (New-SBError 'computeruse.apply.hash.missing')}
        if($PreviewSha256 -cne $plan.sha256){throw (New-SBError 'computeruse.apply.preview')}
        $expected=if($exists){Get-SBFileHash $ConfigPath}else{'absent'}
        [void](Write-SBFile $ConfigPath ([Text.UTF8Encoding]::new($false).GetBytes($plan.text)) $expected (Join-Path $BrainRoot '.runtime/backups/computer-use'))
        $result.applied=$true
    }
    $result
}
function Test-SBAgentUnattendedComputerUse([string]$AgentPath,[string]$CodexConfigPath) {
    # Runner preflight: true only when the table says the agent can pre-approve AND the setting is actually present (Codex on Windows with at least one app).
    $name=Get-SBComputerUseAgentName $AgentPath
    if(!$name){return $false}
    $row=@($script:SBComputerUseCapabilities|Where-Object {$_.ide -eq $name})[0]
    if($row.unattended -ne 'opt-in-config' -or !$IsWindows){return $false}
    if(!$CodexConfigPath){try{$CodexConfigPath=Get-SBCodexConfigPath}catch{return $false}}
    if(!(Test-Path -LiteralPath $CodexConfigPath -PathType Leaf)){return $false}
    $apps=Read-SBCodexAllowedApps ([IO.File]::ReadAllText($CodexConfigPath))
    ($apps.status -eq 'ok' -and @($apps.ids).Count -gt 0)
}
Export-ModuleMember -Function @('Get-SBComputerUseRequiresValues','Get-SBComputerUseRequirement','Get-SBComputerUseCapabilities','Get-SBComputerUseAgentName','ConvertTo-SBCodexAppIds','Read-SBCodexAllowedApps','Get-SBCodexComputerUsePlan','Get-SBCodexConfigPath','Set-SBCodexComputerUseApps','Test-SBAgentUnattendedComputerUse')
