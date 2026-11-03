# Scenari di policy: repository vietati, identita cervello, configurazione e Git; invocato da test-secondbrain.ps1 con fixture isolate.
if(!(Get-Command Assert -ErrorAction SilentlyContinue)){throw 'Eseguire scripts/test-secondbrain.ps1'}
$policyRoot=Join-Path $root 'policy projects with spaces'
$owned=Join-Path $policyRoot 'owned'
$infraBrain=Join-Path $root 'infrastructure brain';[IO.Directory]::CreateDirectory($infraBrain)|Out-Null
Git $infraBrain @('init','-q')|Out-Null;Git $infraBrain @('remote','add','origin','https://github.com/example-user/secondbrain.git')|Out-Null
Assert ((Get-SBBrainIdentity $infraBrain) -ceq 'github.com/example-user/secondbrain') 'identita cervello: origin del proprio repository'
$nestedBrain=Join-Path $infraBrain 'nested';[IO.Directory]::CreateDirectory($nestedBrain)|Out-Null
Assert ((Get-SBBrainIdentity $nestedBrain) -ceq '') 'identita cervello: nessuna ereditarieta dall origin di un repository padre'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
$forbidden=@(@{path=$owned;identity='github.com/Test/Blocked'})
Assert (Test-SBForbiddenRepository $forbidden ($owned+'\') '') 'repo vietati: slash finale equivalente'
Assert (Test-SBForbiddenRepository $forbidden ($owned.Replace('\','/').ToUpperInvariant()) '') 'repo vietati: maiuscole e separatori equivalenti'
Assert (Test-SBForbiddenRepository $forbidden (Join-Path $policyRoot 'other') 'github.com/test/blocked') 'repo vietati: identita senza distinzione di maiuscole'
Assert (!(Test-SBForbiddenRepository $forbidden (Join-Path $policyRoot 'other') 'github.com/test/free')) 'repo vietati: repository non elencato ammesso'
$missingMessage=''
try{Read-SBConfiguration (Join-Path $root 'missing-config.json')|Out-Null}catch{$missingMessage=Test-SBError $_ 'access.config.missing'}
Assert ($missingMessage -eq $true) 'ConfigPath inesistente: errore dedicato'
$accentRepo=Join-Path $root 'accent repo';[IO.Directory]::CreateDirectory($accentRepo)|Out-Null
Git $accentRepo @('init','-q')|Out-Null;Put (Join-Path $accentRepo 'perché.txt') 'x';Git $accentRepo @('add','-A')|Out-Null
Assert ((Git $accentRepo @('ls-files')) -ceq 'perché.txt') 'Invoke-SBGit: percorsi accentati in UTF-8 senza escape'
