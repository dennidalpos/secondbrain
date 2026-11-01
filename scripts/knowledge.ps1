#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName='Tasks')]
param([Parameter(ParameterSetName='Tasks')][switch]$Tasks,[Parameter(ParameterSetName='Tasks')][switch]$All,[switch]$ReadyOnly,[string]$Repository,
    [Parameter(Mandatory,ParameterSetName='Startup')][switch]$Startup,
    [Parameter(ParameterSetName='Startup')][ValidateSet('Slim','Full')][string]$Profile='Slim',
    [Parameter(ParameterSetName='Startup')][switch]$Report,
    [Parameter(Mandatory,ParameterSetName='Compact')][switch]$Compact,
    [Parameter(ParameterSetName='Compact')][Parameter(ParameterSetName='Renumber')][switch]$Apply,[Parameter(ParameterSetName='Compact')][string]$CandidatePath,
    [Parameter(Mandatory,ParameterSetName='Search')][string]$Search,[Parameter(ParameterSetName='Search')][Parameter(ParameterSetName='Startup')][Parameter(ParameterSetName='Compact')][int]$Budget=50000,
    [Parameter(Mandatory,ParameterSetName='TaskUpdate')][string]$UpdateTaskId,[Parameter(ParameterSetName='TaskUpdate')][string]$Status,[Parameter(ParameterSetName='TaskUpdate')][string]$StateReason,
    [Parameter(Mandatory,ParameterSetName='TaskNew')][string]$NewTask,[Parameter(ParameterSetName='TaskNew')][string]$TaskId,[Parameter(ParameterSetName='TaskNew')][string]$Description,
    [Parameter(ParameterSetName='TaskNew')][string]$Priority='P2',[Parameter(ParameterSetName='TaskNew')][ValidateSet('autonomous','user_required','unspecified')][string]$Execution='autonomous',
    [Parameter(ParameterSetName='TaskNew')][string[]]$DependsOn=@(),[Parameter(Mandatory,ParameterSetName='TaskNew')][string[]]$Acceptance,
    [Parameter(Mandatory,ParameterSetName='TaskNew')][string]$Provenance,[Parameter(ParameterSetName='TaskNew')][string]$ProvenancePointer,
    [Parameter(Mandatory,ParameterSetName='Renumber')][switch]$RenumberTasks,
    [Parameter(ParameterSetName='Startup')][Parameter(ParameterSetName='Compact')][Parameter(ParameterSetName='Search')][string]$Dossier,[string]$CheckoutPath,[string]$ConfigPath,[string]$SessionId,
    [Parameter(ParameterSetName='Search')][ValidateSet('Literal','Relevance')][string]$Mode='Literal',
    [Parameter(ParameterSetName='Startup')][string[]]$TaskIds=@())
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Tracker.psm1')
$brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$lock=$null
try{
    $readOnly=(!$Apply -and !$UpdateTaskId -and !$NewTask)
    $config=Read-SBConfiguration $ConfigPath -ReadOnly:$readOnly;$lock=Enter-SBOperation $config $SessionId -ReadOnly:$readOnly
    if($readOnly){Write-SBReadWarnings $lock $config}
    # Slim: tetto di 20.000 caratteri (parti essenziali, resto a richiesta). Full: startupBudget della postazione o 50.000.
    # Il tetto vale solo per il primo caricamento (Slim: 20.000). Full e ricerca non hanno tetto (0) salvo -Budget esplicito; -Compact usa startupBudget o 50.000.
    $effectiveBudget = if($PSBoundParameters.ContainsKey('Budget')){ $Budget } elseif($Startup -and $Profile -eq 'Slim'){ 20000 } elseif($Search -or $Startup){ 0 } elseif($config -and $config.ContainsKey('startupBudget') -and $config.startupBudget -gt 0){ [int]$config.startupBudget } else { 50000 }
    # Perimetro cooperativo: repository esplicito o, in sua assenza, quello del checkout in lavoro (directory corrente).
    $resolveWorking={
        if($Repository){return $Repository}
        $resolved=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$resolved){throw 'Repository in lavoro non risolvibile: eseguire dal checkout, indicare -Repository o -CheckoutPath (-All per la vista globale dei task, sola lettura)'}
        $resolved
    }
    if($Startup){
        if(!$Dossier){$Dossier=Join-Path $brain (Resolve-SBWorkingDossier $brain (& $resolveWorking))}
        elseif(![IO.Path]::IsPathRooted($Dossier)){$Dossier=Join-Path $brain $Dossier}
        $result=Get-SBStartupContext -BrainRoot $brain -Dossier $Dossier -CheckoutPath $CheckoutPath -TaskIds $TaskIds -Budget $effectiveBudget -ReadyOnly:$ReadyOnly -Profile $Profile
        if($Report){
            $directives=@{}
            try{
                Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
                foreach($ide in @(Get-SBIDEAssets|Where-Object {$_.instructions -and (Test-Path -LiteralPath $_.instructions -PathType Leaf)})){$directives[$ide.name+' (globale)']=([IO.File]::ReadAllText($ide.instructions).Length.ToString()+' caratteri')}
            }catch{$directives['IDE']='non rilevabile: '+$_.Exception.Message}
            $checkout=if($CheckoutPath){$CheckoutPath}else{(Get-Location).Path}
            $agents=Join-Path $checkout 'AGENTS.md'
            if(Test-Path -LiteralPath $agents -PathType Leaf){$directives['AGENTS.md del checkout']=([IO.File]::ReadAllText($agents).Length.ToString()+' caratteri')}
            Format-SBStartupReport $result $directives
            exit 0
        }
    }
    elseif($Compact){$result=Invoke-SBDossierCompaction -BrainRoot $brain -Dossier $Dossier -CandidatePath $CandidatePath -BackupRoot $config.backupRoot -Apply:$Apply -CheckoutPath $CheckoutPath -Budget $effectiveBudget}
    elseif($Search){$result=Find-SBKnowledge -BrainRoot $brain -Search $Search -Dossier $Dossier -Repository $Repository -Budget $effectiveBudget -Mode $Mode}
    elseif($UpdateTaskId){
        # Le scritture restano nel repository in lavoro: un -Repository diverso dal checkout corrente e rifiutato.
        $working=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$working){throw 'Repository in lavoro non risolvibile: eseguire dal checkout o indicare -CheckoutPath'}
        $repoId=if($Repository){$Repository}else{$working}
        $result=Set-SBTrackerTaskStatus -BrainRoot $brain -Identity $repoId -WorkingRepository $working -TaskId $UpdateTaskId -Status $Status -StateReason $StateReason -BackupRoot $config.backupRoot
    }
    elseif($NewTask -or $RenumberTasks){
        # Creazione e numerazione restano nel repository in lavoro, come gli aggiornamenti di stato.
        $working=Resolve-SBWorkingRepository $CheckoutPath @($config.bindings)
        if(!$working){throw 'Repository in lavoro non risolvibile: eseguire dal checkout o indicare -CheckoutPath'}
        $repoId=if($Repository){$Repository}else{$working}
        $result=if($NewTask){
            New-SBTrackerTaskEntry -BrainRoot $brain -Identity $repoId -WorkingRepository $working -Title $NewTask -Id $TaskId -Description $Description -Priority $Priority -Execution $Execution -DependsOn $DependsOn -Acceptance $Acceptance -ProvenanceReference $Provenance -ProvenancePointer $ProvenancePointer -BackupRoot $config.backupRoot
        }else{
            Invoke-SBTrackerRenumber -BrainRoot $brain -Identity $repoId -WorkingRepository $working -BackupRoot $config.backupRoot -Apply:$Apply
        }
        $result.Remove('data')
    }
    elseif($All){
        if($Repository){throw 'Parametri incompatibili: -All e -Repository'}
        $result=@(Get-SBGlobalTasks -BrainRoot $brain -All -ReadyOnly:$ReadyOnly)
    }
    else{$result=@(Get-SBGlobalTasks -BrainRoot $brain -Repository (& $resolveWorking) -ReadyOnly:$ReadyOnly)}
    ConvertTo-SBJson $result
    if($Startup -and !$result.withinBudget){exit 1}
}catch{
    if(Test-SBBusyError $_){Write-Output $_.Exception.Message;exit 3}
    Write-Error $_ -ErrorAction Continue;exit 2
}finally{Exit-SBOperation $lock}
