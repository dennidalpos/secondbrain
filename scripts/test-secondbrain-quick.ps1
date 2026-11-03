#requires -Version 7.5
# Livello Quick: controlli puri (nessun Git, nessun processo figlio, nessuna fixture). Duplicano per scelta alcuni controlli di Portable e Workflow.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Portable.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Para.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Prompts.psm1') -Force
$script:quickChecks=0
function Assert-Quick($Condition,[string]$Message){if(!$Condition){throw 'FAIL QUICK: '+$Message};$script:quickChecks++;'PASS QUICK: '+$Message}
$productRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$savedLang=$env:SECONDBRAIN_LANG
try {
    $env:SECONDBRAIN_LANG='it';Set-SBUiLanguage ''
    # Identita dei repository
    Assert-Quick ((ConvertTo-SBRepositoryIdentity 'git@gitlab.example:group/nested/repo.git') -eq 'gitlab.example/group/nested/repo') 'GitLab annidato senza vincolo owner'
    Assert-Quick ((ConvertTo-SBRepositoryIdentity 'https://user:private@github.com/OWNER/REPO.git') -eq 'github.com/owner/repo') 'identita normalizzata senza credenziali'
    Assert-Quick ((ConvertTo-SBRepositoryIdentity 'git@ssh.dev.azure.com:v3/org/project/repo') -eq 'dev.azure.com/org/project/_git/repo') 'alias SSH Azure DevOps'
    Assert-Quick ((ConvertTo-SBRepositoryIdentity 'file:///not-a-remote') -eq $null) 'remoto file non promosso a identita globale'
    Assert-Quick (Test-SBRepositoryIdentity ('local:'+('a'*32))) 'identita locale persistente'
    # JSON deterministico
    Assert-Quick ((ConvertTo-SBJson @{b=2;a=@{z=3;y=@()}}) -ceq (ConvertTo-SBJson @{a=@{y=@();z=3};b=2})) 'JSON deterministico'
    # VERSION e direttive
    $productVersion=(Read-SBText (Join-Path $productRoot 'VERSION')).Trim()
    $revisionLine=[regex]::Match((Read-SBText (Join-Path $productRoot 'direttive/AGENTS.global_ide.md')),'(?m)^Revisione (\d+\.\d+) ').Groups[1].Value
    Assert-Quick ($productVersion -match '^\d+\.\d+\.\d+$' -and $productVersion.StartsWith($revisionLine+'.')) 'VERSION coerente con la revisione delle direttive'
    # Catalogo prompt reale
    Assert-Quick (@(Get-SBWorkflowDrift $productRoot).Count -eq 0) 'catalogo reale allineato'
    # Catalogo messaggi: lingue e chiavi stabili
    $env:SECONDBRAIN_LANG='en'
    Assert-Quick ((Get-SBUiLanguage) -ceq 'en' -and (Get-SBMessage 'core.block.duplicate' @('x')) -ceq 'Duplicate block: x') 'lingua en da SECONDBRAIN_LANG'
    $env:SECONDBRAIN_LANG='it'
    Assert-Quick ((Get-SBUiLanguage) -ceq 'it' -and (Get-SBMessage 'core.block.duplicate' @('x')) -ceq 'Blocco duplicato: x') 'lingua it da SECONDBRAIN_LANG'
    Assert-Quick ((Get-SBMessage 'chiave.inesistente') -ceq 'chiave.inesistente') 'chiave sconosciuta restituisce la chiave'
    $messageGaps=@()
    foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'SecondBrain.*.psm1'|Where-Object Name -ne 'SecondBrain.Messages.psm1'){Import-Module $file.FullName -Force}
    foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'SecondBrain.*.psm1'){
        foreach($m in [regex]::Matches((Read-SBText $file.FullName),"New-SBError '([a-z0-9.]+)'|Get-SBMessage '([a-z0-9.]+)'")){
            $key=if($m.Groups[1].Success){$m.Groups[1].Value}else{$m.Groups[2].Value}
            if((Get-SBMessage $key @() 'en') -ceq $key -or (Get-SBMessage $key @() 'it') -ceq $key){$messageGaps+=$key}
        }
    }
    Assert-Quick (!$messageGaps.Count) ('ogni chiave usata ha testo it e en'+$(if($messageGaps.Count){': '+(($messageGaps|Select-Object -Unique) -join ', ')}))
    $literalThrows=@();$scriptGaps=@()
    foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Include '*.ps1','*.psm1' -File|Where-Object {$_.Name -notlike 'test-*' -and $_.Name -ne 'check-distribution.ps1'}){
        $source=Read-SBText $file.FullName
        foreach($m in [regex]::Matches($source,"throw\s+['""]([^'""]*)['""]")){
            if($m.Groups[1].Value -notmatch '^(redirect-limit|http-\$code|download-too-large|access-challenge|Impossibile trovare scripts/mcp-server\.ps1 .*)$'){$literalThrows+=($file.Name+': '+$m.Groups[1].Value)}
        }
        if($file.Extension -eq '.ps1'){
            foreach($m in [regex]::Matches($source,"New-SBError '([a-z0-9.]+)'")){
                $escaped=[regex]::Escape($m.Groups[1].Value)
                if($source -notmatch ("'"+$escaped+"'\s*=\s*@\{\s*it\s*=.*en\s*=")){$scriptGaps+=($file.Name+': '+$m.Groups[1].Value)}
            }
        }
    }
    Assert-Quick (!$literalThrows.Count) ('nessun throw con testo letterale nei moduli e negli script'+$(if($literalThrows.Count){': '+(($literalThrows|Select-Object -First 5) -join '; ')}))
    Assert-Quick (!$scriptGaps.Count) ('ogni chiave usata dagli script ha testo it e en nello script'+$(if($scriptGaps.Count){': '+(($scriptGaps|Select-Object -Unique -First 5) -join '; ')}))
    $env:SECONDBRAIN_LANG='it';$itPara=Get-SBMessage 'para.status.invalid'
    $env:SECONDBRAIN_LANG='en';$enPara=Get-SBMessage 'para.status.invalid'
    Assert-Quick ($itPara -ceq 'Stato PARA non valido' -and $enPara -ceq 'Invalid PARA status') 'catalogo messaggi: Para in it e en'
    'SUCCESS QUICK: '+$script:quickChecks+' verifiche pure (nessun Git, nessun processo figlio).'
} finally { $env:SECONDBRAIN_LANG=$savedLang; Set-SBUiLanguage '' }
