#requires -Version 7.5
# Subagent definitions (F8): one versioned JSON format stored as a dossier asset under <dossier>/subagents/<name>.json,
# permissions that can never exceed the parent agent, and per-client export through the adapters of #321.
# Definitions carry no authorization: any write stays behind the parent's reviewed MCP write path (F5).
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.MemoryCycle.psm1')
Add-SBMessages @{
    'subagent.invalid' = @{it='Definizione subagente non valida ({0})';en='Invalid subagent definition ({0})'}
    'subagent.permission' = @{it='Il subagente richiede permessi oltre quelli del padre ({0})';en='The subagent requests permissions beyond its parent ({0})'}
    'subagent.fallback' = @{it='Client senza formato nativo verificato: esporta la definizione normalizzata; l installazione non concede permessi.';en='Client without a verified native format: export the normalized definition; installation grants no permission.'}
}
$script:SBSubagentReadTools=@('get_startup_context','get_ready_tasks','get_task','search_knowledge','list_prompts','get_prompt_home','get_prompt')
$script:SBSubagentWriteTools=@('preview_dossier_write','submit_dossier_write')
$script:SBSubagentSpecialTools=@('check_publication')
$script:SBSubagentFields=@('schemaVersion','name','description','role','context','permissions')
$script:SBSubagentPermissionFields=@('tools','write')

function Get-SBSubagentTools { @{read=$script:SBSubagentReadTools;write=$script:SBSubagentWriteTools;special=$script:SBSubagentSpecialTools} }

function Get-SBSubagentDirectory([string]$Dossier) { Join-Path $Dossier 'subagents' }

function Test-SBSubagentDefinition($Definition) {
    $fail={param($why) throw (New-SBError 'subagent.invalid' @($why))}
    if($Definition -isnot [Collections.IDictionary]){& $fail 'definition'}
    foreach($key in $Definition.Keys){if($key -cnotin $script:SBSubagentFields){& $fail ('field '+$key)}}
    foreach($key in $script:SBSubagentFields){if(!$Definition.Contains($key)){& $fail ('missing '+$key)}}
    if($Definition.schemaVersion -ne 1){& $fail 'schemaVersion'}
    if($Definition.name -isnot [string] -or $Definition.name -cnotmatch '^[a-z0-9][a-z0-9-]{0,63}$'){& $fail 'name'}
    foreach($key in 'description','role','context'){
        if($Definition[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($Definition[$key]) -or $Definition[$key].Length -gt 8192){& $fail $key}
    }
    $perm=$Definition.permissions
    if($perm -isnot [Collections.IDictionary]){& $fail 'permissions'}
    foreach($key in $perm.Keys){if($key -cnotin $script:SBSubagentPermissionFields){& $fail ('permissions.'+$key)}}
    foreach($key in $script:SBSubagentPermissionFields){if(!$perm.Contains($key)){& $fail ('permissions missing '+$key)}}
    if($perm.write -isnot [bool]){& $fail 'permissions.write'}
    if($perm.tools -isnot [Collections.IEnumerable] -or $perm.tools -is [string]){& $fail 'permissions.tools'}
    $known=$script:SBSubagentReadTools+$script:SBSubagentWriteTools+$script:SBSubagentSpecialTools
    $seen=@{}
    foreach($tool in @($perm.tools)){
        if($tool -isnot [string] -or $tool -cnotin $known){& $fail 'permissions.tools entry'}
        if($seen.ContainsKey($tool)){& $fail 'permissions.tools duplicate'}
        $seen[$tool]=$true
        if($tool -cin $script:SBSubagentWriteTools -and !$perm.write){& $fail 'write tool without write=true'}
    }
    $true
}

function Read-SBSubagentDefinitions([string]$Dossier) {
    $directory=Get-SBSubagentDirectory $Dossier
    $items=@()
    if(!(Test-Path -LiteralPath $directory -PathType Container)){return $items}
    Assert-SBPlainPath $directory
    foreach($file in Get-ChildItem -LiteralPath $directory -File -Force|Sort-Object Name){
        if($file.Extension -cne '.json'){throw (New-SBError 'subagent.invalid' @('file '+$file.Name))}
        Assert-SBPlainPath $file.FullName
        try{$definition=(Read-SBText $file.FullName)|ConvertFrom-Json -AsHashtable -ErrorAction Stop}catch{throw (New-SBError 'subagent.invalid' @('json '+$file.Name))}
        [void](Test-SBSubagentDefinition $definition)
        if($file.BaseName -cne $definition.name){throw (New-SBError 'subagent.invalid' @('name differs from file '+$file.Name))}
        $items+=,@{definition=$definition;path=$file.FullName;sha256=(Get-SBFileHash $file.FullName)}
    }
    $items
}

# Effective permissions are the intersection with the parent; requesting anything the parent lacks is an error, never silently trimmed.
function Resolve-SBSubagentPermissions($Definition,$Parent) {
    [void](Test-SBSubagentDefinition $Definition)
    if($Parent -isnot [Collections.IDictionary] -or !$Parent.Contains('tools') -or !$Parent.Contains('write') -or $Parent.write -isnot [bool]){throw (New-SBError 'subagent.invalid' @('parent'))}
    $parentTools=@($Parent.tools)
    foreach($tool in @($Definition.permissions.tools)){
        if($tool -cnotin $parentTools){throw (New-SBError 'subagent.permission' @($tool))}
    }
    if($Definition.permissions.write -and !$Parent.write){throw (New-SBError 'subagent.permission' @('write'))}
    $writeAllowed=$Definition.permissions.write -and $Parent.write
    @{name=$Definition.name;tools=@($Definition.permissions.tools|Sort-Object);write=$writeAllowed;
      writeAuthorization='parent-reviewed-mcp-write';inherited=$true}
}

function ConvertTo-SBSubagentExport($Definition,$Permissions,[string]$Client) {
    $adapter=Get-SBCycleAdapter $Client
    $tools=@($Permissions.tools)
    $normalized=[ordered]@{schemaVersion=1;name=$Definition.name;description=$Definition.description;role=$Definition.role;context=$Definition.context;
        permissions=[ordered]@{tools=$tools;write=[bool]$Permissions.write;writeAuthorization=$Permissions.writeAuthorization}}
    if($Client -ceq 'claude-code'){
        $mcpTools=@($tools|ForEach-Object {'mcp__secondbrain__'+$_}) -join ', '
        $oneLine=($Definition.description -replace '\s+',' ').Trim()
        $body="---`nname: "+$Definition.name+"`ndescription: "+(ConvertTo-Json $oneLine -Compress)+"`ntools: "+$mcpTools+"`n---`n`n"+$Definition.role.Trim()+"`n`n"+$Definition.context.Trim()+"`n"
        return @{client=$Client;format='claude-code-markdown';relativePath=('.claude/agents/'+$Definition.name+'.md');content=$body.Replace("`r`n","`n");liveVerified=$adapter.liveVerified;note=$null}
    }
    @{client=$Client;format='normalized-json';relativePath=('subagents/'+$Definition.name+'.'+$Client+'.json');content=(ConvertTo-SBJson $normalized);liveVerified=$false;note=(Get-SBMessage 'subagent.fallback')}
}

# Export to a package folder (never into a checkout): preview by default, apply writes verified files.
function Export-SBSubagents([string]$Dossier,[string]$Client,$Parent,[string]$OutputRoot,[string]$BackupRoot,[switch]$Apply) {
    $entries=Read-SBSubagentDefinitions $Dossier
    $files=@()
    foreach($entry in $entries){
        $permissions=Resolve-SBSubagentPermissions $entry.definition $Parent
        $export=ConvertTo-SBSubagentExport $entry.definition $permissions $Client
        $files+=,@{name=$entry.definition.name;relativePath=$export.relativePath;format=$export.format;sourceSha256=$entry.sha256;contentSha256=(Get-SBTextHash $export.content);content=$export.content;liveVerified=$export.liveVerified;note=$export.note}
    }
    $root=[IO.Path]::GetFullPath($OutputRoot)
    $changed=@()
    foreach($file in $files){
        $target=[IO.Path]::GetFullPath((Join-Path $root $file.relativePath))
        if(!$target.StartsWith($root.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw (New-SBError 'subagent.invalid' @('output scope'))}
        Assert-SBPlainPath $target
        $current=Get-SBFileHash $target
        if($current -ne (Get-SBHash ([Text.UTF8Encoding]::new($false).GetBytes($file.content)))){$changed+=,@{file=$file;target=$target;current=$current}}
    }
    if($Apply){
        foreach($item in $changed){
            [void][IO.Directory]::CreateDirectory((Split-Path $item.target))
            [void](Write-SBFile $item.target ([Text.UTF8Encoding]::new($false).GetBytes($item.file.content)) $item.current $BackupRoot)
        }
    }
    @{state=$(if(!$changed.Count){'unchanged'}elseif($Apply){'applied'}else{'preview'});client=$Client;count=$files.Count;changed=@($changed|ForEach-Object {$_.file.relativePath});
      files=@($files|ForEach-Object {@{name=$_.name;relativePath=$_.relativePath;format=$_.format;sourceSha256=$_.sourceSha256;contentSha256=$_.contentSha256;liveVerified=$_.liveVerified}})}
}

# Register record of a subagent job: always references the parent session (validated by the register against the log).
function New-SBSubagentActivityRecord([string]$Repository,[string]$User,[string]$Computer,[string]$TaskId,[string]$ParentSession,[string]$Agent,[string]$Session,[string]$When,[string]$Outcome,[string]$Detail,[string]$Where='subagent') {
    $key=$Repository+"`n"+$ParentSession+"`n"+$Agent+"`n"+$Session+"`n"+$When+"`n"+$Outcome
    @{schemaVersion=1;eventId=(Get-SBTextHash $key).Substring(0,32).ToLowerInvariant();user=$User;repository=$Repository;taskId=$TaskId;session=$Session;when=$When;where=$Where;computer=$Computer;outcome=$Outcome;detail=$Detail;parent=$ParentSession;agent=$Agent}
}
Export-ModuleMember -Function @('Get-SBSubagentTools','Get-SBSubagentDirectory','Test-SBSubagentDefinition','Read-SBSubagentDefinitions','Resolve-SBSubagentPermissions','ConvertTo-SBSubagentExport','Export-SBSubagents','New-SBSubagentActivityRecord')
