#requires -Version 7.5
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Sources.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'resources.root.missing' = @{ it = 'Cartella 03-resources assente'; en = '03-resources folder missing' }
    'resources.sync.archived' = @{ it = 'Registro fonti archiviato: sincronizzazione non eseguita'; en = 'Source registry archived: sync not performed' }
}
$script:ResourceControlName='CONTROL.json'
$script:ResourceIndexName='INDEX.md'
function Get-SBResourceFolders([string]$BrainRoot) {
    $root=Join-Path $BrainRoot '03-resources'
    if(!(Test-Path -LiteralPath $root)){throw (New-SBError 'resources.root.missing')}
    Assert-SBPlainPath $root
    @(Get-ChildItem -LiteralPath $root -Directory|Where-Object {!$_.Name.StartsWith('.',[StringComparison]::Ordinal)}|Sort-Object Name|ForEach-Object {Assert-SBPlainPath $_.FullName;$_.FullName})
}
function Get-SBResourceControl([string]$Folder) {
    $base=[IO.Path]::GetFullPath($Folder).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $files=@()
    foreach($file in Get-ChildItem -LiteralPath $Folder -File -Recurse -Force){
        Assert-SBPlainPath $file.FullName
        $relative=$file.FullName.Substring($base.Length).Replace('\','/')
        if($relative -in @($script:ResourceControlName,$script:ResourceIndexName) -or $relative -match '(^|/)\.(secondbrain-.*|gitkeep)$|\.(tmp|lock)$'){continue}
        # #478: originals (restored by Sync, hash in the manifest) and QA screenshots are not in Git, so they are not part of the control.
        if($relative -match '(^|/)versions/[^/]+/originals/' -or $relative -match '(^|/)census/qa/'){continue}
        $files+=@{path=$relative;sha256=(Get-SBFileHash $file.FullName);bytes=[int64]$file.Length}
    }
    $files=@($files|Sort-Object {$_.path})
    @{schemaVersion=1;resource=(Split-Path $Folder -Leaf);fileCount=$files.Count;files=$files}
}
function Get-SBResourceIndex([string]$Folder,$Control) {
    $meta=Read-SBJson (Join-Path $Folder 'para.json') $null
    $title=if($meta -and $meta.ContainsKey('title') -and $meta.title){[string]$meta.title}else{Split-Path $Folder -Leaf}
    $groups=[ordered]@{}
    foreach($file in $Control.files){
        $parts=$file.path -split '/'
        $key=if($parts.Count -gt 1){$parts[0]}else{'.'}
        if(!$groups.Contains($key)){$groups[$key]=@{files=0;bytes=[int64]0}}
        $groups[$key].files++;$groups[$key].bytes+=$file.bytes
    }
    $lines=@("# $title",'','Indice generato da `scripts/resources.ps1`; non modificare a mano. Controllo integrita: `CONTROL.json`.','','| Percorso | File | Byte |','|---|---|---|')
    foreach($key in $groups.Keys){$lines+='| '+$(if($key -eq '.'){'(radice)'}else{$key+'/'})+' | '+$groups[$key].files+' | '+$groups[$key].bytes+' |'}
    ($lines -join "`n")+"`n"
}
function Test-SBResourceLayout([string]$Folder) {
    $issues=@()
    $name=Split-Path $Folder -Leaf
    foreach($required in @('para.json','brief.md')){if(!(Test-Path -LiteralPath (Join-Path $Folder $required))){$issues+=@{kind='layout-missing';resource=$name;path=$required}}}
    $meta=Read-SBJson (Join-Path $Folder 'para.json') $null
    if($meta -and ($meta.kind -ne 'resource' -or $meta.id -cne ('resource-'+$name))){$issues+=@{kind='layout-identity';resource=$name}}
    $issues
}
function Get-SBResourceChecks([string]$BrainRoot) {
    $issues=[Collections.Generic.List[object]]::new()
    foreach($folder in Get-SBResourceFolders $BrainRoot){
        $name=Split-Path $folder -Leaf
        foreach($issue in Test-SBResourceLayout $folder){$issues.Add($issue)}
        $control=Get-SBResourceControl $folder
        $stored=Read-SBJson (Join-Path $folder $script:ResourceControlName) $null
        if(!$stored){$issues.Add(@{kind='control-missing';resource=$name})}
        else{
            $known=@{};foreach($f in $stored.files){$known[$f.path]=$f.sha256}
            $current=@{};foreach($f in $control.files){$current[$f.path]=$true}
            $changed=@($control.files|Where-Object {$known.ContainsKey($_.path) -and $known[$_.path] -cne $_.sha256})
            $added=@($control.files|Where-Object {!$known.ContainsKey($_.path)})
            $removed=@($stored.files|Where-Object {!$current.ContainsKey($_.path)})
            if($changed.Count -or $added.Count -or $removed.Count){$issues.Add(@{kind='control-drift';resource=$name;changed=$changed.Count;added=$added.Count;removed=$removed.Count})}
        }
        $indexPath=Join-Path $folder $script:ResourceIndexName
        if((Get-SBFileHash $indexPath) -cne (Get-SBTextHash (Get-SBResourceIndex $folder $control))){$issues.Add(@{kind='index-drift';resource=$name})}
    }
    @($issues.ToArray())
}
function Update-SBResourceViews($Config) {
    $written=@()
    foreach($folder in Get-SBResourceFolders $Config.brainRoot){
        $control=Get-SBResourceControl $folder
        $views=@(@{name=$script:ResourceControlName;text=(ConvertTo-SBJson $control)},@{name=$script:ResourceIndexName;text=(Get-SBResourceIndex $folder $control)})
        foreach($view in $views){
            $path=Join-Path $folder $view.name
            if(Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($view.text)) (Get-SBFileHash $path) $Config.backupRoot){$written+=((Split-Path $folder -Leaf)+'/'+$view.name)}
        }
    }
    $written
}
function Test-SBResourceStale($Config,[int]$MaxAgeDays=14) {
    $latest=Read-SBJson (Join-Path $Config.runtimeRoot 'sources/latest.json') $null
    if(!$latest){return $true}
    [DateTimeOffset]::Parse($latest.checkedAt) -lt (Get-SBNow).AddDays(-$MaxAgeDays)
}
function Invoke-SBResourceSync($Config,$Registry,[string]$PythonPath,[ValidateRange(0,10)][int]$MaxDepth=3,[ValidateRange(1,500)][int]$MaxSources=50,[scriptblock]$Transport) {
    if($Registry.archived){throw (New-SBError 'resources.sync.archived')}
    # 0. Originals are not in Git (#478): restore the missing ones, hash-verified, before anything else.
    $restore=Restore-SBSourceOriginals $Config $Registry $Transport
    # 1. Probe every endpoint and keep the report.
    $report=Invoke-SBSourceProbe $Registry $Transport
    $reportPath=Save-SBSourceReport $Config $report
    # 2. Closure over related sources and detected references, from every public-reusable source.
    $seeds=@($Registry.sources|Where-Object {$_.rights.status -eq 'public-reusable'}|ForEach-Object {$_.id})
    $closure=Get-SBSourceClosure $Registry $seeds $MaxDepth $MaxSources
    # 3. Collect candidates only where the probe saw a change; accepted and older versions stay untouched.
    $collected=@()
    foreach($result in @($report.sources|Where-Object {$_.status -in @('changed','unbaselined')})){
        $source=@($Registry.sources|Where-Object id -ceq $result.sourceId)[0]
        if($source.rights.status -ne 'public-reusable' -or $result.sourceId -notin $closure.sources){continue}
        $collected+=Invoke-SBSourceCollect $Config $Registry $result.sourceId $PythonPath $Transport
        $Registry=Read-SBSourceRegistry $Config.brainRoot
    }
    # 4. Queue for review: unresolved references and limits. Nothing unverified is downloaded.
    $queuePath=Join-Path $Registry.root 'normative-queue.json'
    $queue=@{schemaVersion=1;items=@($closure.queue)}
    Write-SBFile $queuePath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $queue))) (Get-SBFileHash $queuePath) $Config.backupRoot|Out-Null
    # 5. Regenerate the source indexes and every control file.
    $catalog=Get-SBSourceCatalog $Registry
    foreach($view in @(@{name='catalog.json';text=$catalog.json},@{name='README.md';text=$catalog.markdown})){
        $path=Join-Path $Registry.root $view.name
        Write-SBFile $path ([Text.Encoding]::UTF8.GetBytes($view.text)) (Get-SBFileHash $path) $Config.backupRoot|Out-Null
    }
    $views=@(Update-SBResourceViews $Config)
    @{schemaVersion=1;restored=@($restore.restored).Count;restoreFailed=@($restore.failed);reportPath=$reportPath;complete=$report.complete;closure=@($closure.sources).Count;queued=@($closure.queue).Count;collected=$collected;viewsWritten=$views.Count}
}
Export-ModuleMember -Function @(
    'Get-SBResourceFolders',
    'Get-SBResourceControl',
    'Get-SBResourceIndex',
    'Test-SBResourceLayout',
    'Get-SBResourceChecks',
    'Update-SBResourceViews',
    'Test-SBResourceStale',
    'Invoke-SBResourceSync'
)
