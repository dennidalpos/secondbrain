#requires -Version 7.5
# Task runner: pure selection of autonomous tracker tasks and the fixed prompt given to each fresh agent session.
# No file I/O here: scripts/run-ready-tasks.ps1 owns process launch, work folders and reports.
# The read-scope guard (#382) reads only the two session variables that the runner sets in the agent's environment.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Add-SBMessages @{
    'isolation.cross.refused' = @{it='Isolamento per progetto: la vista globale o la ricerca senza progetto risolto e rifiutata; indicare il repository in lavoro (o abilitare crossProjectReads in config/shared.json)';en='Project isolation: the global view or a search without a resolved project is refused; give the working repository (or enable crossProjectReads in config/shared.json)'}
    'runner.scope.global' = @{it='Lettura globale rifiutata in una sessione del runner per {0}: -All, -AllDossiers e all=true non sono consentiti; usare il repository del task o uno della sua allowlist di lettura';en='Global read refused in a runner session for {0}: -All, -AllDossiers and all=true are not allowed; use the task repository or one from its read allowlist'}
    'runner.scope.repository' = @{it='Lettura rifiutata in una sessione del runner: {0} non e il repository del task ({1}) e non e nella sua allowlist di lettura';en='Read refused in a runner session: {0} is neither the task repository ({1}) nor in its read allowlist'}
    'runner.scope.write' = @{it='Scrittura rifiutata in una sessione del runner: {0} non e il repository del task ({1})';en='Write refused in a runner session: {0} is not the task repository ({1})'}
    'runner.scope.dossier' = @{it='Dossier rifiutato in una sessione del runner: {0} non appartiene al repository del task ({1}) ne alla sua allowlist di lettura';en='Dossier refused in a runner session: {0} belongs neither to the task repository ({1}) nor to its read allowlist'}
}
$script:SBRunnerScopeVariables = @{repository='SECONDBRAIN_RUNNER_REPOSITORY';reads='SECONDBRAIN_RUNNER_READS'}
$script:SBRunnerExcludedStreams = @('qualifica-finale','intervento-su-richiesta','coordinamento-prodotti')
function Get-SBRunnerScopeVariables { $script:SBRunnerScopeVariables.Clone() }
function Get-SBRunnerReadScope {
    # Set by run-ready-tasks.ps1 in the agent process only; absent in sessions started by a person, where nothing is restricted.
    $repo=[Environment]::GetEnvironmentVariable($script:SBRunnerScopeVariables.repository)
    if([string]::IsNullOrWhiteSpace($repo)){return $null}
    $reads=@(([string][Environment]::GetEnvironmentVariable($script:SBRunnerScopeVariables.reads)) -split ';'|ForEach-Object {$_.Trim()}|Where-Object {$_})
    @{repository=$repo.Trim();reads=$reads}
}
function Assert-SBRunnerReadScope([switch]$Global,[string]$Repository,[string]$Dossier,[string]$BrainRoot,[switch]$Write){
    # Code-level perimeter of a runner session: no global views, reads only of the task repository or its allowlist, writes only to the task repository.
    $scope=Get-SBRunnerReadScope
    if(!$scope){return}
    if($Global){throw (New-SBError 'runner.scope.global' @($scope.repository))}
    if($Repository -and $Repository -ine $scope.repository){
        if($Write){throw (New-SBError 'runner.scope.write' @($Repository,$scope.repository))}
        if($Repository -inotin $scope.reads){throw (New-SBError 'runner.scope.repository' @($Repository,$scope.repository))}
    }
    if($Dossier){
        $full=if([IO.Path]::IsPathRooted($Dossier)){$Dossier}else{Join-Path $BrainRoot $Dossier}
        $full=[IO.Path]::GetFullPath($full).TrimEnd('\','/')
        $allowed=@(@($scope.repository)+$(if($Write){@()}else{$scope.reads})|ForEach-Object {
            try{[IO.Path]::GetFullPath((Join-Path $BrainRoot (Resolve-SBWorkingDossier $BrainRoot $_))).TrimEnd('\','/')}catch{$null}
        }|Where-Object {$_})
        if(@($allowed|Where-Object {[string]::Equals($_,$full,[StringComparison]::OrdinalIgnoreCase)}).Count -eq 0){throw (New-SBError 'runner.scope.dossier' @($Dossier,$scope.repository))}
    }
}
function Test-SBProjectIsolation([string]$BrainRoot){
    # Strict isolation per project (default): reads stay in the working project; shared PARA resources are the only common area.
    # config/shared.json "crossProjectReads": true re-enables the global views (-All, -AllDossiers, all=true) on this brain.
    $path=Join-Path $BrainRoot 'config/shared.json'
    if(!(Test-Path -LiteralPath $path -PathType Leaf)){return $true}
    try{$shared=[IO.File]::ReadAllText($path)|ConvertFrom-Json -AsHashtable}catch{return $true}
    !($shared -is [hashtable] -and $shared.ContainsKey('crossProjectReads') -and $shared.crossProjectReads -eq $true)
}
function Assert-SBProjectIsolation([string]$BrainRoot){
    if(Test-SBProjectIsolation $BrainRoot){throw (New-SBError 'isolation.cross.refused')}
}
function Get-SBRunnerTaskReads($Task){
    # Per-task read-only allowlist written by REP16 (extensions.readRepositories).
    # Callers wrap the result in @(): an empty allowlist yields nothing, never a nested array.
    @(Get-SBRunnerValue (Get-SBRunnerValue $Task 'extensions') 'readRepositories'|Where-Object {$_}|ForEach-Object {[string]$_})
}
function Get-SBRunnerValue($Object,[string]$Name){
    if($null -eq $Object){return $null}
    $p=$Object.PSObject.Properties[$Name]
    if($null -eq $p){return $null}
    $p.Value
}
function Get-SBRunnerExcludedStreams { ,$script:SBRunnerExcludedStreams }
function Get-SBRunnerExclusionReason($Task,[switch]$AllowComputerUse){
    # Why a task is not runnable, as a stable code ($null when it is): status, execution, stream:<name> or awaiting:<value>.
    $status=Get-SBRunnerValue $Task 'status'
    if($status -ne 'todo'){return "status:$status"}
    $execution=Get-SBRunnerValue $Task 'execution'
    if($execution -ne 'autonomous'){return "execution:$(if($execution){$execution}else{'unset'})"}
    $ext=Get-SBRunnerValue $Task 'extensions'
    $stream=Get-SBRunnerValue $ext 'stream'
    if($stream -in $script:SBRunnerExcludedStreams){return "stream:$stream"}
    $awaiting=Get-SBRunnerValue $ext 'awaiting'
    if($awaiting -and $awaiting -notin @('structural-completion')){return "awaiting:$awaiting"}
    # Computer use needs an attended session: `claude -p` cannot approve apps, and no IDE documents a persistent pre-approval for it (Codex on Windows aside).
    # A task that declares extensions.requires=computer-use is left for an attended session instead of failing midway.
    $requires=@(Get-SBRunnerValue $ext 'requires'|Where-Object {$_}|ForEach-Object {[string]$_})
    # -AllowComputerUse comes from the preflight of the capability table (SecondBrain.ComputerUse.psm1): the agent has a documented, present pre-approval.
    if('computer-use' -in $requires -and !$AllowComputerUse){return 'requires:computer-use'}
    $null
}
function Test-SBRunnableTask($Task,[switch]$AllowComputerUse){
    # A task is runnable only when it is todo, explicitly autonomous, outside final qualification/on-request/product streams and not waiting on a person.
    $null -eq (Get-SBRunnerExclusionReason $Task -AllowComputerUse:$AllowComputerUse)
}
function Get-SBRunnerExclusions($Tasks,[switch]$AllowComputerUse){
    # Ready tasks the runner will not run, each with its reason, for the preview report.
    @($Tasks|ForEach-Object {$r=Get-SBRunnerExclusionReason $_ -AllowComputerUse:$AllowComputerUse;if($r){[ordered]@{id=[string](Get-SBRunnerValue $_ 'id');seq=Get-SBRunnerValue $_ 'seq';reason=$r}}})
}
function Select-SBRunnableTasks($Tasks,[int]$MaxTasks=3,[switch]$AllowComputerUse){
    $rank=@{P0=0;P1=1;P2=2;P3=3;P4=4}
    $sel=@($Tasks|Where-Object {Test-SBRunnableTask $_ -AllowComputerUse:$AllowComputerUse}|Sort-Object @{e={$r=$rank[[string](Get-SBRunnerValue $_ 'priority')];if($null -eq $r){9}else{$r}}},@{e={[int](Get-SBRunnerValue $_ 'seq')}})
    if($MaxTasks -gt 0 -and $sel.Count -gt $MaxTasks){$sel=@($sel[0..($MaxTasks-1)])}
    ,$sel
}
function New-SBTaskRunPrompt($Task,[string]$ScriptsRoot,[string]$CheckoutPath){
    $id=Get-SBRunnerValue $Task 'id'
    # With a scripts root and a checkout (multi-repository run) the agent starts in a product checkout, where scripts/knowledge.ps1 does not exist:
    # the extra line gives it the absolute SecondBrain tools and the checkout that resolves the dossier.
    $where=if($ScriptsRoot -and $CheckoutPath){"Strumenti SecondBrain in $ScriptsRoot (usa $ScriptsRoot\knowledge.ps1 con -CheckoutPath `"$CheckoutPath`" al posto di scripts/knowledge.ps1), oppure i tool MCP secondbrain."}else{$null}
    # Per-task read-only allowlist written by REP16 (extensions.readRepositories): the only other repositories the agent may read.
    $reads=@(Get-SBRunnerTaskReads $Task)
    $readLine=if($reads.Count){'Letture consentite solo in sola lettura, per questo task: '+($reads -join ', ')+'. Nessuna scrittura e nessun task di quei repository.'}else{$null}
    @(
        "Esegui SOLO il task $id (#$(Get-SBRunnerValue $Task 'seq')) del tracker SecondBrain, in questa sessione nuova.",
        $where,
        'Procedura: leggi AGENTS.md, carica il contesto con scripts/knowledge.ps1 -Startup, leggi il task con scripts/knowledge.ps1 -Task, esegui il lavoro, verifica ogni criterio di accettazione con strumenti disponibili e funzionanti, poi aggiorna lo stato con scripts/knowledge.ps1 -UpdateTaskId.',
        'Perimetro: lavora solo sul repository di questo checkout e sul suo tracker; non leggere, prendere o aggiornare task di altri repository e non usare -All, -AllDossiers, all=true e non indicare -Repository di un altro repository.',
        $readLine,
        'Divieti: nessun commit, push, pubblicazione o cancellazione; nessuna applicazione di SYS05 o di pulizie; nessun altro task. Se serve una conferma o una prova live, fermati e riporta il limite nello stato del task senza chiuderlo.',
        'Chiudi con un riepilogo breve: esito per criterio, verifiche eseguite, limiti.'
    ).Where({$_}) -join "`n"
}
Export-ModuleMember -Function @('Test-SBProjectIsolation','Assert-SBProjectIsolation','Get-SBRunnerExcludedStreams','Test-SBRunnableTask','Get-SBRunnerExclusionReason','Get-SBRunnerExclusions','Select-SBRunnableTasks','New-SBTaskRunPrompt','Get-SBRunnerScopeVariables','Get-SBRunnerReadScope','Assert-SBRunnerReadScope','Get-SBRunnerTaskReads')
