# Funzioni di sola prova: usate soltanto dalle suite test-secondbrain*.ps1 (non fanno parte dei moduli di produzione).
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
function Get-SBTestRoot {
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $root=if($env:SECONDBRAIN_TEST_ROOT){$env:SECONDBRAIN_TEST_ROOT}else{Join-Path $brain '.runtime/tests'}
    $root=Assert-SBCentralDataPath $brain $root
    [IO.Directory]::CreateDirectory($root)|Out-Null
    $root
}