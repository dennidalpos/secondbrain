#requires -Version 7.5
# Fixtures for dossier grouping by customer (#485): search and backup filters, migration with preview, ID preservation. Synthetic data only.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$script:custChecks=0
function Assert-Cust($Condition,[string]$Message){if(!$Condition){throw ('FAIL CUSTOMER: '+$Message)};$script:custChecks++}
$root=Join-Path (Get-SBTestRoot) ('customer-'+[guid]::NewGuid().ToString('N').Substring(0,12))
$brain=Join-Path $root 'brain'
function Put([string]$rel,[string]$text){$p=Join-Path $brain $rel;[IO.Directory]::CreateDirectory((Split-Path $p))|Out-Null;[IO.File]::WriteAllText($p,$text)}
foreach($sub in @('scripts','config')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('../'+$sub)) -Destination (Join-Path $brain $sub) -Recurse -Force}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../VERSION') -Destination (Join-Path $brain 'VERSION')
Put 'config/shared.json' (ConvertTo-SBJson @{schemaVersion=1;allowedOwners=@('test');excludedDirectories=@('.git')})
function New-Dossier([string]$Path,[string]$Name,$Customer,[string]$Status='active'){
    $record=@{schemaVersion=1;identity="github.com/test/$Name";tracker=@{location='dossier';path='tracker.json';schemaVersion=1}}
    if($null -ne $Customer){$record.customer=$Customer}
    Put "$Path/repository.json" (ConvertTo-SBJson $record)
    Put "$Path/para.json" (ConvertTo-SBJson @{schemaVersion=1;id="dossier-$Name";kind='project';title=$Name;status=$Status})
    Put "$Path/brief.md" "# $Name"
    Put "$Path/context.md" "# Contesto`nshared-term $Name context`n"
    Put "$Path/memory.md" "# Memoria`n"
    Put "$Path/tracker.json" (ConvertTo-SBJson @{schemaVersion=1;repository="github.com/test/$Name";tasks=@(@{id="T-$Name-1";title='uno'},@{id="T-$Name-2";title='due'});history=@()})
}
New-Dossier '01-projects/a' 'a' 'Acme'
New-Dossier '01-projects/b' 'b' ' acme '
New-Dossier '01-projects/c' 'c' 'Beta'
New-Dossier '01-projects/d' 'd' $null
New-Dossier '04-archives/projects/dossier-e' 'e' 'Acme' 'completed'
$runtime=Get-SBLocalRoot $brain 'fixture';$cfg=Join-Path $runtime 'workstation.json'
Put ([IO.Path]::GetRelativePath($brain,$cfg)) (ConvertTo-SBJson @{schemaVersion=1;mode='portable';workstationId='fixture';runtimeRoot=$runtime;backupRoot=(Join-Path $runtime 'backups');ides=@();bindings=@()})
$para=Join-Path $brain 'scripts/para.ps1'
function Invoke-Para([string[]]$Arguments){$out=& pwsh -NoProfile -File $para -ConfigPath $cfg @Arguments 2>&1|Out-String;@{code=$LASTEXITCODE;out=$out}}
$r=Invoke-Para @('-BuildIndex')
Assert-Cust ($r.code -eq 0) ('fixture index built: '+$r.out)

# Entities expose the customer; matching ignores case and surrounding spaces.
$entities=@(Get-SBParaEntities $brain @('test'))
Assert-Cust (@($entities|Where-Object customer -eq 'Acme').Count -eq 3 -and @($entities|Where-Object {$_.customer -eq ''}).Count -eq 1) 'entities carry the trimmed customer'
Assert-Cust ((Test-SBCustomerMatch ' ACME ' 'acme') -and !(Test-SBCustomerMatch 'Acme' 'Beta') -and (Test-SBCustomerMatch '' '')-and (Test-SBCustomerMatch 'Beta' '')) 'customer match is trimmed, case-insensitive; empty filter selects all'

# Search filter.
function Find([string]$Customer,[string]$Repository='',[string]$Dossier=''){Find-SBKnowledge -BrainRoot $brain -Search 'shared-term' -Customer $Customer -Repository $Repository -Dossier $Dossier -Budget 0 -Limit 0}
$names={param($res) @($res.extracts|ForEach-Object {$_.repository -replace '^.*/',''}|Sort-Object -Unique) -join ','}
Assert-Cust ((& $names (Find '')) -ceq 'a,b,c,d') 'no filter: every active dossier (archived excluded)'
Assert-Cust ((& $names (Find 'acme')) -ceq 'a,b') 'customer filter selects the customer''s active dossiers only'
Assert-Cust ((Find 'Gamma').count -eq 0) 'unknown customer finds nothing'
Assert-Cust ((& $names (Find 'Acme' 'github.com/test/a')) -ceq 'a' -and (Find 'Acme' 'github.com/test/c').count -eq 0) 'customer combines with repository (intersection)'
Assert-Cust ((Find 'Beta' '' '01-projects/c').count -eq 1 -and (Find 'Beta' '' '01-projects/a').count -eq 0) 'customer combines with dossier'

# Migration: preview does not write; apply writes only repository.json and preserves identifiers.
$files=@('a','b','c','d')|ForEach-Object {Get-ChildItem -LiteralPath (Join-Path $brain "01-projects/$_") -File -Recurse}
$hashes=@{};foreach($f in $files){$hashes[$f.FullName]=Get-SBFileHash $f.FullName}
$r=Invoke-Para @('-SetCustomer','-Customer','Gamma','-Only','dossier-c,github.com/test/d')
$preview=$r.out
Assert-Cust ($r.code -eq 0 -and $preview -match '"apply":\s*false' -and $preview -match 'dossier-c' -and $preview -match 'customerAfter') ('preview lists the plan: '+$preview)
Assert-Cust (@($files|Where-Object {(Get-SBFileHash $_.FullName) -ne $hashes[$_.FullName]}).Count -eq 0) 'preview writes nothing'
$r=Invoke-Para @('-SetCustomer','-Customer','Gamma','-Only','dossier-c,github.com/test/d','-Apply')
Assert-Cust ($r.code -eq 0) ('apply succeeds: '+$r.out)
foreach($name in @('c','d')){
    $dir=Join-Path $brain "01-projects/$name"
    Assert-Cust ((Read-SBJson (Join-Path $dir 'repository.json') $null).customer -ceq 'Gamma') "customer written for $name"
    foreach($keep in @('para.json','tracker.json','brief.md','context.md','memory.md')){
        Assert-Cust ((Get-SBFileHash (Join-Path $dir $keep)) -ceq $hashes[(Join-Path $dir $keep)]) "$name/$keep unchanged (ids and tasks preserved)"
    }
}
Assert-Cust ((Read-SBJson (Join-Path $brain '01-projects/a/repository.json') $null).customer -ceq 'Acme' -and (Get-SBFileHash (Join-Path $brain '01-projects/a/repository.json')) -ceq $hashes[(Join-Path $brain '01-projects/a/repository.json')]) 'unselected dossier untouched'
$after=@(Get-SBParaEntities $brain @('test'))
Assert-Cust ((($entities|ForEach-Object id|Sort-Object) -join ',') -ceq (($after|ForEach-Object id|Sort-Object) -join ',') -and (($entities|ForEach-Object repository|Sort-Object) -join ',') -ceq (($after|ForEach-Object repository|Sort-Object) -join ',')) 'PARA ids and repository identities unchanged'
Assert-Cust ((& $names (Find 'gamma')) -ceq 'c,d') 'search sees the migrated customer'
$r=Invoke-Para @('-Check')
Assert-Cust ($r.code -eq 0) ('PARA check passes after migration: '+$r.out)
$r=Invoke-Para @('-SetCustomer','-Customer','Gamma','-Only','dossier-c','-Apply')
Assert-Cust ($r.code -eq 0) 'apply is idempotent'
$r=Invoke-Para @('-SetCustomer','-Clear','-Only','dossier-d','-Apply')
Assert-Cust ($r.code -eq 0 -and !(Read-SBJson (Join-Path $brain '01-projects/d/repository.json') @{}).ContainsKey('customer')) 'clear removes the field'
Assert-Cust ((Invoke-Para @('-SetCustomer','-Only','dossier-c')).code -ne 0) 'customer or -Clear is required'
Assert-Cust ((Invoke-Para @('-SetCustomer','-Customer','x','-Only','dossier-zzz')).code -ne 0) 'unmatched -Only is refused'
Assert-Cust ((Invoke-Para @('-SetCustomer','-Customer',('x'*121),'-Only','dossier-c')).code -ne 0) 'overlong customer is refused'

# Backup filter: only the customer's dossiers (active and archived); no global indexes or workstation data.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$backup=Join-Path $brain 'scripts/backup.ps1';$zipPath=Join-Path $root 'acme.zip'
$out=& pwsh -NoProfile -File $backup -Customer 'ACME' -OutputPath $zipPath 2>&1|Out-String
Assert-Cust ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $zipPath)) ('customer backup created: '+$out)
$archive=[IO.Compression.ZipFile]::OpenRead($zipPath)
try{$names2=@($archive.Entries|ForEach-Object {$_.FullName});$manifest=([IO.StreamReader]::new($archive.GetEntry('manifest.json').Open())).ReadToEnd()|ConvertFrom-Json -AsHashtable}finally{$archive.Dispose()}
$has={param($prefix) @($names2|Where-Object {$_.StartsWith($prefix,[StringComparison]::Ordinal)}).Count -gt 0}
Assert-Cust ((& $has '01-projects/a/') -and (& $has '01-projects/b/') -and (& $has '04-archives/projects/dossier-e/')) 'backup includes active and archived dossiers of the customer'
Assert-Cust (!(& $has '01-projects/c/') -and !(& $has '01-projects/d/') -and !(& $has '.runtime/') -and 'PARA.md' -notin $names2 -and 'para-index.json' -notin $names2) 'backup leaves out other customers, indexes and workstation data'
Assert-Cust ($manifest.customer -ceq 'ACME' -and $manifest.fileCount -eq (@($names2|Where-Object {$_ -ne 'manifest.json'}).Count)) 'manifest records the customer and counts only included files'
$verify=& pwsh -NoProfile -File $backup -Verify -BackupPath $zipPath 2>&1|Out-String
Assert-Cust ($LASTEXITCODE -eq 0 -and $verify -match 'VERIFY SUCCESS') 'customer backup passes -Verify'
$null=& pwsh -NoProfile -File $backup -Customer 'Nobody' -OutputPath (Join-Path $root 'none.zip') 2>&1|Out-String
Assert-Cust ($LASTEXITCODE -ne 0 -and !(Test-Path -LiteralPath (Join-Path $root 'none.zip'))) 'backup of an unknown customer is refused and writes nothing'
$null=& pwsh -NoProfile -File $backup -OutputPath (Join-Path $root 'full.zip') 2>&1|Out-String
Assert-Cust ($LASTEXITCODE -eq 0) 'backup without filter still works'
$archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $root 'full.zip'))
try{$fullNames=@($archive.Entries|ForEach-Object {$_.FullName});$fullManifest=([IO.StreamReader]::new($archive.GetEntry('manifest.json').Open())).ReadToEnd()|ConvertFrom-Json -AsHashtable}finally{$archive.Dispose()}
Assert-Cust ((@($fullNames|Where-Object {$_ -like '01-projects/c/*'}).Count -gt 0) -and 'PARA.md' -in $fullNames -and !$fullManifest.ContainsKey('customer')) 'unfiltered backup keeps every dossier and no customer key'
'SUCCESS CUSTOMER: '+$script:custChecks+' checks; retained fixture '+$root
