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
# Schema 2 (docs/riferimento/asset-contracts.md section 4): identity, revisioning, composable cards, output contract and delegation bounds.
$script:SBSubagentFields2=@('schemaVersion','id','name','revision','status','description','role','context','permissions','cards','output','bounds','replacedBy')
$script:SBSubagentOptional2=@('cards','replacedBy')
$script:SBSubagentPermissionFields=@('tools','write')
$script:SBSubagentStatuses=@('draft','active','deprecated','retired')
$script:SBSubagentOutputKinds=@('text','report','object')
$script:SBSubagentModeRank=@{read=0;verify=1;write=2}

function Get-SBSubagentTools { @{read=$script:SBSubagentReadTools;write=$script:SBSubagentWriteTools;special=$script:SBSubagentSpecialTools} }

function Get-SBSubagentDirectory([string]$Dossier) { Join-Path $Dossier 'subagents' }

function Test-SBSubagentInteger($Value,[long]$Min,[long]$Max) { ($Value -is [int] -or $Value -is [long]) -and $Value -ge $Min -and $Value -le $Max }

# Highest card mode a delegate may compose: without write permission only read cards (verify cards write reports).
function Get-SBSubagentMaxMode($Definition) { if($Definition.permissions.write){'write'}else{'read'} }

function Test-SBSubagentDefinition($Definition) {
    $fail={param($why) throw (New-SBError 'subagent.invalid' @($why))}
    if($Definition -isnot [Collections.IDictionary]){& $fail 'definition'}
    if(!$Definition.Contains('schemaVersion') -or !(Test-SBSubagentInteger $Definition.schemaVersion 1 2)){& $fail 'schemaVersion'}
    $schema=[int]$Definition.schemaVersion
    $fields=if($schema -eq 1){$script:SBSubagentFields}else{$script:SBSubagentFields2}
    $required=if($schema -eq 1){$script:SBSubagentFields}else{@($script:SBSubagentFields2|Where-Object {$_ -cnotin $script:SBSubagentOptional2})}
    foreach($key in $Definition.Keys){if($key -cnotin $fields){& $fail ('field '+$key)}}
    foreach($key in $required){if(!$Definition.Contains($key)){& $fail ('missing '+$key)}}
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
    if($schema -eq 2){
        if($Definition.id -isnot [string] -or $Definition.id -cnotmatch '^agt-[0-9a-f]{8}$'){& $fail 'id'}
        if(!(Test-SBSubagentInteger $Definition.revision 1 ([int]::MaxValue))){& $fail 'revision'}
        if($Definition.status -isnot [string] -or $Definition.status -cnotin $script:SBSubagentStatuses){& $fail 'status'}
        if($Definition.Contains('replacedBy')){
            if($Definition.replacedBy -isnot [string] -or $Definition.replacedBy -cnotmatch '^agt-[0-9a-f]{8}$' -or $Definition.replacedBy -ceq $Definition.id){& $fail 'replacedBy'}
            if($Definition.status -cnotin @('deprecated','retired')){& $fail 'replacedBy without deprecated or retired status'}
        }
        if($Definition.Contains('cards')){
            if($Definition.cards -isnot [Collections.IEnumerable] -or $Definition.cards -is [string] -or $Definition.cards -is [Collections.IDictionary]){& $fail 'cards'}
            $refs=@{}
            foreach($ref in @($Definition.cards)){
                if($ref -isnot [string] -or ($ref -cnotmatch '^pmt-[0-9a-f]{8}$' -and $ref -cnotmatch '^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)*$')){& $fail 'cards entry'}
                if($refs.ContainsKey($ref)){& $fail 'cards duplicate'}
                $refs[$ref]=$true
            }
        }
        $out=$Definition.output
        if($out -isnot [Collections.IDictionary]){& $fail 'output'}
        foreach($key in $out.Keys){if($key -cnotin @('kind','schema')){& $fail ('output.'+$key)}}
        if($out.kind -isnot [string] -or $out.kind -cnotin $script:SBSubagentOutputKinds){& $fail 'output.kind'}
        if($out.Contains('schema') -and ($out.schema -isnot [string] -or $out.schema -cnotmatch '^config/[A-Za-z0-9._/-]+\.json$' -or $out.schema.Contains('..'))){& $fail 'output.schema'}
        if($out.kind -ceq 'object' -and !$out.Contains('schema')){& $fail 'output.schema required for object'}
        $bounds=$Definition.bounds
        if($bounds -isnot [Collections.IDictionary]){& $fail 'bounds'}
        foreach($key in $bounds.Keys){if($key -cnotin @('depth','budget')){& $fail ('bounds.'+$key)}}
        if(!$bounds.Contains('depth') -or !(Test-SBSubagentInteger $bounds.depth 1 1)){& $fail 'bounds.depth'}
        $budget=if($bounds.Contains('budget')){$bounds.budget}else{$null}
        if($budget -isnot [Collections.IDictionary] -or !$budget.Count){& $fail 'bounds.budget'}
        foreach($key in $budget.Keys){if($key -cnotin @('turns','minutes')){& $fail ('bounds.budget.'+$key)}}
        if($budget.Contains('turns') -and !(Test-SBSubagentInteger $budget.turns 1 1000)){& $fail 'bounds.budget.turns'}
        if($budget.Contains('minutes') -and !(Test-SBSubagentInteger $budget.minutes 1 1440)){& $fail 'bounds.budget.minutes'}
    }
    $true
}

# Card references resolve against the public catalog (direttive/prompts/catalog.json): by pmt- ID, or by role on exactly one active card.
# Draft and retired cards are not composable; a card above the definition's effective mode is an error.
function Resolve-SBSubagentCards($Definition,$Catalog) {
    $fail={param($why) throw (New-SBError 'subagent.invalid' @($why))}
    if([int]$Definition.schemaVersion -ne 2 -or !$Definition.Contains('cards')){return ,@()}
    $refs=@($Definition.cards)
    if(!$refs.Count){return ,@()}
    if($Catalog -isnot [Collections.IDictionary] -or !$Catalog.Contains('prompts')){& $fail 'cards without catalog'}
    $maxMode=Get-SBSubagentMaxMode $Definition
    $resolved=@()
    foreach($ref in $refs){
        $byId=$ref.StartsWith('pmt-')
        $found=@($Catalog.prompts|Where-Object {$_ -is [Collections.IDictionary] -and $(if($byId){$_.id -ceq $ref}else{$_.Contains('role') -and $_.role -ceq $ref -and (!$_.Contains('status') -or $_.status -ceq 'active')})})
        if($found.Count -ne 1){& $fail ('card unresolved '+$ref)}
        $card=$found[0]
        $status=if($card.Contains('status')){[string]$card.status}else{'active'}
        if($status -cnotin @('active','deprecated')){& $fail ('card not composable '+$ref)}
        if($card.mode -isnot [string] -or !$script:SBSubagentModeRank.ContainsKey($card.mode)){& $fail ('card mode '+$ref)}
        if($script:SBSubagentModeRank[$card.mode] -gt $script:SBSubagentModeRank[$maxMode]){& $fail ('card '+$ref+' mode '+$card.mode+' above '+$maxMode)}
        $resolved+=,([ordered]@{ref=$ref;id=$card.id;code=$card.code;mode=$card.mode;status=$status})
    }
    ,$resolved
}

function Read-SBSubagentCatalog([string]$BrainRoot) {
    $path=Join-Path $BrainRoot 'direttive/prompts/catalog.json'
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
    (Read-SBText $path)|ConvertFrom-Json -AsHashtable -ErrorAction Stop
}

function Read-SBSubagentDefinitions([string]$Dossier,$Catalog) {
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
        if($definition.Contains('id') -and @($items|Where-Object {$_.definition.Contains('id') -and $_.definition.id -ceq $definition.id}).Count){throw (New-SBError 'subagent.invalid' @('duplicate id '+$definition.id))}
        $cards=Resolve-SBSubagentCards $definition $Catalog
        $items+=,@{definition=$definition;cards=$cards;path=$file.FullName;sha256=(Get-SBFileHash $file.FullName)}
    }
    $items
}

# Lifecycle, output and delegation bounds as Resolve reports them; schema 1 has the fixed depth 1 and no declared budget.
function Get-SBSubagentSummary($Definition) {
    if([int]$Definition.schemaVersion -eq 2){
        $budget=[ordered]@{};foreach($key in @($Definition.bounds.budget.Keys|Sort-Object)){$budget[$key]=$Definition.bounds.budget[$key]}
        return [ordered]@{schemaVersion=2;id=$Definition.id;revision=$Definition.revision;status=$Definition.status;replacedBy=$(if($Definition.Contains('replacedBy')){$Definition.replacedBy}else{$null});
            output=[ordered]@{kind=$Definition.output.kind;schema=$(if($Definition.output.Contains('schema')){$Definition.output.schema}else{$null})};
            bounds=[ordered]@{depth=1;budget=$budget};maxCardMode=(Get-SBSubagentMaxMode $Definition)}
    }
    [ordered]@{schemaVersion=1;id=$null;revision=$null;status='active';replacedBy=$null;output=$null;bounds=[ordered]@{depth=1;budget=$null};maxCardMode=(Get-SBSubagentMaxMode $Definition)}
}

# Reports of the Validate and Resolve operations over entries from Read-SBSubagentDefinitions.
function Get-SBSubagentValidateReport($Entries) {
    @{state='valid';definitions=@($Entries|ForEach-Object {@{name=$_.definition.name;schemaVersion=$_.definition.schemaVersion;id=$(if($_.definition.Contains('id')){$_.definition.id}else{$null});sha256=$_.sha256;cards=@($_.cards)}})}
}

function Get-SBSubagentResolveReport($Entries,$Parent) {
    @{parent=$Parent;agents=@($Entries|ForEach-Object {
        $agent=Resolve-SBSubagentPermissions $_.definition $Parent
        $summary=Get-SBSubagentSummary $_.definition
        foreach($key in $summary.Keys){$agent[$key]=$summary[$key]}
        $agent.cards=@($_.cards)
        $agent})}
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
    if([int]$Definition.schemaVersion -eq 2){
        $summary=Get-SBSubagentSummary $Definition
        $normalized=[ordered]@{schemaVersion=2;id=$Definition.id;name=$Definition.name;revision=$Definition.revision;status=$Definition.status;description=$Definition.description;role=$Definition.role;context=$Definition.context;
            permissions=$normalized.permissions;cards=@(if($Definition.Contains('cards')){$Definition.cards});output=$summary.output;bounds=$summary.bounds}
    }
    if($Client -ceq 'claude-code'){
        $mcpTools=@($tools|ForEach-Object {'mcp__secondbrain__'+$_}) -join ', '
        $oneLine=($Definition.description -replace '\s+',' ').Trim()
        $body="---`nname: "+$Definition.name+"`ndescription: "+(ConvertTo-Json $oneLine -Compress)+"`ntools: "+$mcpTools+"`n---`n`n"+$Definition.role.Trim()+"`n`n"+$Definition.context.Trim()+"`n"
        return @{client=$Client;format='claude-code-markdown';relativePath=('.claude/agents/'+$Definition.name+'.md');content=$body.Replace("`r`n","`n");liveVerified=$adapter.liveVerified;note=$null}
    }
    @{client=$Client;format='normalized-json';relativePath=('subagents/'+$Definition.name+'.'+$Client+'.json');content=(ConvertTo-SBJson $normalized);liveVerified=$false;note=(Get-SBMessage 'subagent.fallback')}
}

# Export to a package folder (never into a checkout): preview by default, apply writes verified files.
# Draft and retired definitions are not runnable (asset-contracts section 1.3) and stay out of the export.
function Export-SBSubagents([string]$Dossier,[string]$Client,$Parent,[string]$OutputRoot,[string]$BackupRoot,[switch]$Apply,$Catalog) {
    $all=@(Read-SBSubagentDefinitions $Dossier $Catalog)
    $runnable={param($e) !$e.definition.Contains('status') -or $e.definition.status -cin @('active','deprecated')}
    $entries=@($all|Where-Object {& $runnable $_})
    $skipped=@($all|Where-Object {!(& $runnable $_)}|ForEach-Object {@{name=$_.definition.name;status=$_.definition.status}})
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
    @{state=$(if(!$changed.Count){'unchanged'}elseif($Apply){'applied'}else{'preview'});client=$Client;count=$files.Count;changed=@($changed|ForEach-Object {$_.file.relativePath});skipped=$skipped;
      files=@($files|ForEach-Object {@{name=$_.name;relativePath=$_.relativePath;format=$_.format;sourceSha256=$_.sourceSha256;contentSha256=$_.contentSha256;liveVerified=$_.liveVerified}})}
}

# Register record of a subagent job: always references the parent session (validated by the register against the log).
function New-SBSubagentActivityRecord([string]$Repository,[string]$User,[string]$Computer,[string]$TaskId,[string]$ParentSession,[string]$Agent,[string]$Session,[string]$When,[string]$Outcome,[string]$Detail,[string]$Where='subagent') {
    $key=$Repository+"`n"+$ParentSession+"`n"+$Agent+"`n"+$Session+"`n"+$When+"`n"+$Outcome
    @{schemaVersion=1;eventId=(Get-SBTextHash $key).Substring(0,32).ToLowerInvariant();user=$User;repository=$Repository;taskId=$TaskId;session=$Session;when=$When;where=$Where;computer=$Computer;outcome=$Outcome;detail=$Detail;parent=$ParentSession;agent=$Agent}
}
Export-ModuleMember -Function @('Get-SBSubagentTools','Get-SBSubagentDirectory','Test-SBSubagentDefinition','Resolve-SBSubagentCards','Read-SBSubagentCatalog','Get-SBSubagentSummary','Get-SBSubagentValidateReport','Get-SBSubagentResolveReport','Read-SBSubagentDefinitions','Resolve-SBSubagentPermissions','ConvertTo-SBSubagentExport','Export-SBSubagents','New-SBSubagentActivityRecord')
