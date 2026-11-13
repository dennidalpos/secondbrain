#requires -Version 7.5
# #479: the README scenario from a clean clone - clone, Setup with -Roots, Startup, search of a source - on a synthetic Git repository.
# The clone is made from the committed state of this checkout (in CI: the checked-out commit) with the not-ignored working files of the checkout laid over it.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
. (Join-Path $PSScriptRoot 'test-helpers.ps1')
$checks=0
function Assert-Clean($Value,[string]$Message){if(!$Value){throw ('FAIL CLEANCLONE: '+$Message)};$script:checks++;'PASS CLEANCLONE: '+$Message}
function Invoke-Pwsh([string]$Script,[string[]]$CliArguments,[string]$StdIn){
    $lines=if($PSBoundParameters.ContainsKey('StdIn')){@($StdIn|& pwsh -NoProfile -File $Script @CliArguments 2>&1)}else{@(& pwsh -NoProfile -File $Script @CliArguments 2>&1)}
    $code=$LASTEXITCODE
    $text=(@($lines|Where-Object {$_ -isnot [Management.Automation.ErrorRecord]}) -join "`n")
    $data=$null;try{$data=$text|ConvertFrom-Json -AsHashtable}catch{Write-Verbose $_.Exception.Message}
    @{code=$code;text=$text;data=$data;all=($lines -join "`n")}
}
$source=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixture=Join-Path (Get-SBTestRoot) ('cleanclone-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$clone=Join-Path $fixture 'brain';$project=Join-Path $fixture 'project'
$identity='github.com/test/cleanclone'
# A clone must not inherit the test run context of the checkout that launches the suite.
$saved=@{}
foreach($name in @('SECONDBRAIN_TEST_ROOT','SECONDBRAIN_TEST_RUN_CONTEXT','SECONDBRAIN_TEST_KEEP','SECONDBRAIN_HOME','SECONDBRAIN_STATE_ROOT')){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process');[Environment]::SetEnvironmentVariable($name,$null,'Process')}
try{
    [void][IO.Directory]::CreateDirectory($fixture)
    & git -c core.longpaths=true clone -q --no-hardlinks $source $clone 2>&1|Out-Null
    Assert-Clean ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath (Join-Path $clone 'scripts/secondbrain.ps1'))) 'a clean clone contains the scripts'
    # Overlay the checkout's tracked and not-ignored files (what the next commit contains), so uncommitted work is exercised exactly as a clone of it would be.
    $overlay=@(& git -c core.quotepath=false -C $source ls-files -z --cached --others --exclude-standard|ForEach-Object {$_}) -join ''
    foreach($relative in ($overlay -split "`0"|Where-Object {$_})){
        $from=Join-Path $source $relative
        if(!(Test-Path -LiteralPath $from -PathType Leaf)){continue}
        $to=Join-Path $clone $relative
        [void][IO.Directory]::CreateDirectory((Split-Path $to))
        Copy-Item -LiteralPath $from -Destination $to -Force
    }
    Assert-Clean (!(Test-Path -LiteralPath (Join-Path $clone '.runtime')) -and !(Test-Path -LiteralPath (Join-Path $clone '01-projects/SecondBrain'))) 'a clean clone has no runtime and no private dossier'

    [void][IO.Directory]::CreateDirectory($project)
    & git -c core.longpaths=true -C $project init -q
    & git -C $project remote add origin ('https://'+$identity+'.git')
    [IO.File]::WriteAllText((Join-Path $project 'README.md'),"# Synthetic project`n",[Text.UTF8Encoding]::new($false))
    Assert-Clean ($LASTEXITCODE -eq 0) 'synthetic Git repository created'

    $setup=Join-Path $clone 'scripts/secondbrain.ps1'
    $preview=Invoke-Pwsh $setup @('-Setup','-PreviewOnly','-Roots',$project,'-Select',$project)
    Assert-Clean ($preview.code -eq 0 -and $preview.data -and !(Test-Path -LiteralPath (Join-Path $clone '.runtime/hosts'))) 'Setup preview discovers the project and writes nothing'
    $apply=Invoke-Pwsh $setup @('-Setup','-Roots',$project,'-Select',$project,'-Yes','-Apply','-NoRegisterEnvironment')
    Assert-Clean ($apply.code -eq 0 -and (Test-Path -LiteralPath (Join-Path $clone '.runtime/hosts'))) 'Setup with -Roots activates the selected repository'
    # #484: the default Setup leaves the client repository untouched; instruction files appear only after an explicit choice.
    $leftover=@(Get-ChildItem -LiteralPath $project -Force|Where-Object Name -notin @('.git','README.md')|ForEach-Object Name)
    Assert-Clean ($leftover.Count -eq 0) ('Setup by default writes nothing into the repository: '+($leftover -join ', '))
    $zeroStartup=Invoke-Pwsh (Join-Path $clone 'scripts/knowledge.ps1') @('-Startup','-Profile','Slim','-CheckoutPath',$project)
    Assert-Clean ($zeroStartup.code -eq 0 -and $zeroStartup.data -and $zeroStartup.data.repository -ceq $identity -and !(Test-Path -LiteralPath (Join-Path $project 'AGENTS.md'))) 'Startup resolves the repository from Git without any file in the checkout'
    $optIn=Invoke-Pwsh $setup @('-Setup','-Roots',$project,'-Select',$project,'-RepositoryFiles','AGENTS.md','-Yes','-Apply','-NoRegisterEnvironment')
    Assert-Clean ($optIn.code -eq 0 -and (Test-Path -LiteralPath (Join-Path $project 'AGENTS.md')) -and !(Test-Path -LiteralPath (Join-Path $project 'CLAUDE.md'))) 'Setup with -RepositoryFiles AGENTS.md writes the approved repository instructions only'

    $knowledge=Join-Path $clone 'scripts/knowledge.ps1'
    $startup=Invoke-Pwsh $knowledge @('-Startup','-Profile','Slim','-CheckoutPath',$project)
    Assert-Clean ($startup.code -eq 0 -and $startup.data -and $startup.data.repository -ceq $identity -and $startup.data.profile -ceq 'Slim' -and $startup.data.withinBudget -eq $true) 'Startup returns the repository identity, the Slim profile and a load within budget'
    $dossier=Join-Path $clone ((Get-ChildItem -LiteralPath (Join-Path $clone '01-projects') -Directory|Select-Object -First 1).FullName.Substring($clone.Length+1))
    Assert-Clean ((Test-Path -LiteralPath (Join-Path $dossier 'tracker.json')) -and (Test-Path -LiteralPath (Join-Path $dossier 'repository.json'))) 'Setup created the dossier with tracker and repository metadata'

    # A source note in the new dossier is found by a category search (the library itself is seeded by #478).
    $note=Join-Path $dossier 'topics/normative/synthetic-clean-clone-source.md'
    [void][IO.Directory]::CreateDirectory((Split-Path $note))
    [IO.File]::WriteAllText($note,"# Synthetic source`n`nCleancloneNeedle: a synthetic authoritative source for the clean clone test.`n",[Text.UTF8Encoding]::new($false))
    $search=Invoke-Pwsh $knowledge @('-Search','CleancloneNeedle','-CheckoutPath',$project)
    Assert-Clean ($search.code -eq 0 -and $search.text.Contains('CleancloneNeedle')) 'search finds a source note of the dossier'
    $categorySearch=Invoke-Pwsh $knowledge @('-Search','CleancloneNeedle','-Category','normative','-CheckoutPath',$project)
    Assert-Clean ($categorySearch.code -eq 0 -and $categorySearch.text.Contains('CleancloneNeedle')) 'search restricted to the normative category finds the source note'

    # #478: the library travels in Git (metadata, transcripts, evidence of public-reusable sources); originals are downloaded by resources.ps1 -Sync.
    $library=Join-Path $clone '03-resources/authoritative-sources'
    $catalog=Get-Content -Raw -LiteralPath (Join-Path $library 'catalog.json')|ConvertFrom-Json -AsHashtable
    Assert-Clean (@($catalog.sources).Count -ge 30 -and (Test-Path -LiteralPath (Join-Path $library 'domains.json')) -and @(Get-ChildItem -LiteralPath (Join-Path $library 'profiles') -File).Count -ge 3) 'a clean clone has the source catalog, the domains and the profiles'
    Assert-Clean (@(Get-ChildItem -LiteralPath (Join-Path $library 'entries') -Directory|Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'metadata.json')}).Count -eq @($catalog.sources).Count) 'every catalog source has its metadata in the clone'
    Assert-Clean (@(Get-ChildItem -LiteralPath (Join-Path $clone '03-resources') -Recurse -Directory -Filter originals).Count -eq 0) 'originals are not in the clone'
    $resourcesCheck=Invoke-Pwsh (Join-Path $clone 'scripts/resources.ps1') @('-Check')
    Assert-Clean ($resourcesCheck.code -eq 0 -and @($resourcesCheck.data.issues).Count -eq 0) 'resources.ps1 -Check is clean on the clone without originals'
    $sourcesCheck=Invoke-Pwsh (Join-Path $clone 'scripts/sources.ps1') @('-Check')
    Assert-Clean ($sourcesCheck.code -in @(0,1) -and $sourcesCheck.text -match 'original-missing') 'sources.ps1 -Check reports the missing originals as restorable, not as an error'
    # Distribution gates (#478): a text version of a reference-only source and any original are refused in the index.
    $distribution=Join-Path $clone 'scripts/check-distribution.ps1'
    $restricted=Join-Path $library 'entries/iso-27001/versions/synthetic/transcript.md'
    [void][IO.Directory]::CreateDirectory((Split-Path $restricted));[IO.File]::WriteAllText($restricted,"synthetic`n")
    & git -C $clone add -f -- $restricted 2>&1|Out-Null
    $licenceGate=Invoke-Pwsh $distribution @('-RepositoryPath',$clone)
    Assert-Clean ($licenceGate.code -eq 1 -and $licenceGate.all -match 'VIOLAZIONE LICENZA') 'check-distribution refuses a stored text of a reference-only source'
    & git -C $clone reset -q -- $restricted;Remove-Item -LiteralPath (Split-Path $restricted) -Recurse -Force
    $original=Join-Path $library 'entries/eu-gdpr/versions/synthetic/originals/x.pdf'
    [void][IO.Directory]::CreateDirectory((Split-Path $original));[IO.File]::WriteAllText($original,"%PDF-synthetic`n")
    & git -C $clone add -f -- $original 2>&1|Out-Null
    $originalGate=Invoke-Pwsh $distribution @('-RepositoryPath',$clone)
    Assert-Clean ($originalGate.code -eq 1 -and $originalGate.all -match 'VIOLAZIONE CRITICA') 'check-distribution refuses a tracked original'
    & git -C $clone reset -q -- $original;Remove-Item -LiteralPath (Split-Path (Split-Path $original)) -Recurse -Force
    $prompt=Invoke-Pwsh (Join-Path $clone 'scripts/prompts.ps1') @('-Show','-Prompt','REP01','-Language','en')
    Assert-Clean ($prompt.code -eq 0 -and $prompt.text.Length -gt 0) 'the next-task prompt opens'
    $check=Invoke-Pwsh $setup @('-Check','-Repository',$identity)
    Assert-Clean ($check.code -in @(0,1) -and $check.data) 'Check on the clean clone returns a report'
    'SUCCESS CLEANCLONE: '+$checks+' checks; retained fixture '+$fixture
}finally{
    foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}
}
