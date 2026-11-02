# Funzioni di sola prova: usate soltanto dalle suite test-secondbrain*.ps1 (non fanno parte dei moduli di produzione).
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
# Le suite audit impostano $script:auditLabel e $script:auditChecks prima di usarla.
function Assert-Audit($Condition,[string]$Message){if(!$Condition){throw 'FAIL '+$script:auditLabel+': '+$Message};$script:auditChecks++;'PASS '+$script:auditLabel+': '+$Message}
function Get-SBTestRoot {
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $root=if($env:SECONDBRAIN_TEST_ROOT){$env:SECONDBRAIN_TEST_ROOT}else{Join-Path $brain '.runtime/tests'}
    $root=Assert-SBCentralDataPath $brain $root
    [IO.Directory]::CreateDirectory($root)|Out-Null
    $root
}