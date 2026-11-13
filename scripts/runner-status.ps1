#requires -Version 7.5
<#
.SYNOPSIS
Shows whether the task runner of a repository is working, possibly stalled, finished or orphaned, and what the agent did last.
.DESCRIPTION
Reads status.json and events.jsonl of the active run (or of the newest run) in the repository's report work folders on this
workstation; it never touches the tracker or the agent. The repository is the checkout given with -CheckoutPath (default: the current
directory) or -Repository <identity>.
Verdict: working (alive, recent heartbeat and agent output), stalled (alive but silent past -StallMinutes of the run, or the heartbeat
stopped), waiting (alive and waiting for a plan limit to reset, status.quotaWait.resumeAt), finished (the run closed itself), orphaned (marked running but its process is gone: interrupted or killed), none (no run).
Default output is JSON with the status, the ages in seconds and the last -Tail events. -Follow prints each new event as it arrives
(JSON lines with -Json) until the run ends. -Stop creates the run's stop file: the runner ends after the current task.
-List prints the runs of the repository on this workstation, newest first (provider, model, effort, counts, stop reason, results,
folder; -Limit, default 50, 0 = all). -Note <text> appends a "ui" event to the events.jsonl of the given -RunFolder (a runner run folder
of this repository), so the notes of the desktop orchestrator survive a reattach.
Exit codes: 0 status shown, 2 repository not resolved or no run to stop.
#>
[CmdletBinding()]
param([string]$CheckoutPath='.',[string]$Repository,[int]$Tail=20,[switch]$Follow,[switch]$Json,[switch]$Stop,[switch]$List,[ValidateRange(0,1000)][int]$Limit=50,
    [ValidateLength(1,500)][string]$Note,[string]$RunFolder,[string]$ConfigPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.RunnerStatus.psm1')
Add-SBMessages @{
    'runnerstatus.repository' = @{it='Repository non risolto da {0}. Indica -CheckoutPath di un checkout gestito o -Repository <identita>';en='Repository not resolved from {0}. Give -CheckoutPath of a managed checkout or -Repository <identity>'}
    'runnerstatus.nostop' = @{it='Nessun run attivo da fermare per {0}';en='No active run to stop for {0}'}
    'runnerstatus.stop' = @{it='Arresto richiesto: il runner si ferma dopo il task corrente ({0})';en='Stop requested: the runner ends after the current task ({0})'}
    'runnerstatus.line' = @{it='[{0}] {1}';en='[{0}] {1}'}
    'runnerstatus.end' = @{it='Run concluso: {0}';en='Run ended: {0}'}
    'runnerstatus.folder' = @{it='Cartella di run non valida per {0}: {1}. Usa la cartella riportata da runner-status.ps1 -List';en='Invalid run folder for {0}: {1}. Use the folder reported by runner-status.ps1 -List'}
}
try{
    $config=Read-SBConfiguration $ConfigPath
    if(!$Repository){
        $full=[IO.Path]::GetFullPath($CheckoutPath)
        $Repository=try{Resolve-SBWorkingRepository $full @($config.bindings)}catch{$null}
        if(!$Repository){throw (New-SBError 'runnerstatus.repository' @($full))}
    }
    if($List){ConvertTo-SBJson (Get-SBRunnerRunList -BrainRoot $config.brainRoot -HostId $config.workstationId -Repository $Repository -Limit $Limit);exit 0}
    if($Note){
        # Only a run folder of this repository on this workstation (its status.json listed by the report root) accepts a note.
        $folders=@(Get-SBRunnerStatusFiles $config.brainRoot $config.workstationId $Repository|ForEach-Object {Split-Path $_ -Parent})
        $target=if($RunFolder){[IO.Path]::GetFullPath($RunFolder).TrimEnd('\','/')}else{''}
        if(!$target -or !@($folders|Where-Object {[string]::Equals($_.TrimEnd('\','/'),$target,[StringComparison]::OrdinalIgnoreCase)}).Count){throw (New-SBError 'runnerstatus.folder' @($Repository,$RunFolder))}
        $event=[ordered]@{event='ui';message=$Note;time=(Get-SBNow).ToString('o')}
        Add-SBRunnerEventLine (Join-Path $target 'events.jsonl') $event
        ConvertTo-SBJson ([ordered]@{repository=$Repository;folder=$target;event=$event})
        exit 0
    }
    $report=Get-SBRunnerStatus -BrainRoot $config.brainRoot -HostId $config.workstationId -Repository $Repository -Tail $Tail
    if($Stop){
        if(!$report.active -or !$report.status.stopFile){throw (New-SBError 'runnerstatus.nostop' @($Repository))}
        [IO.File]::WriteAllText([string]$report.status.stopFile,(Get-SBNow).ToString('o'),[Text.UTF8Encoding]::new($false))
        [Console]::Error.WriteLine((Get-SBMessage 'runnerstatus.stop' @($report.status.stopFile)))
        ConvertTo-SBJson ([ordered]@{repository=$Repository;stopRequested=$true;stopFile=$report.status.stopFile;verdict=$report.verdict})
        exit 0
    }
    if(!$Follow){ConvertTo-SBJson $report;exit 0}
    # Follow: print the tail, then every new line of events.jsonl, until the run is no longer active.
    $events=Join-Path ([string]$report.folder) 'events.jsonl'
    $seen=0
    while($true){
        $lines=@();if($report.folder -and (Test-Path -LiteralPath $events -PathType Leaf)){$lines=@([IO.File]::ReadAllLines($events,[Text.UTF8Encoding]::new($false))|Where-Object {$_})}
        $from=if($seen -eq 0){[math]::Max(0,$lines.Count-$Tail)}else{$seen}
        for($i=$from;$i -lt $lines.Count;$i++){
            if($Json){[Console]::Out.WriteLine($lines[$i])}
            else{$e=try{$lines[$i]|ConvertFrom-Json -AsHashtable}catch{@{time='';message=$lines[$i]}};[Console]::Out.WriteLine((Get-SBMessage 'runnerstatus.line' @(([string]$e.time -replace '^.*T(\d\d:\d\d:\d\d).*$','$1'),[string]$e.message)))}
        }
        $seen=$lines.Count
        if(!$report.active){break}
        Start-Sleep -Seconds 2
        $report=Get-SBRunnerStatus -BrainRoot $config.brainRoot -HostId $config.workstationId -Repository $Repository -Tail 0
        if(!$report.folder){break}
        $events=Join-Path ([string]$report.folder) 'events.jsonl'
    }
    [Console]::Error.WriteLine((Get-SBMessage 'runnerstatus.end' @($report.verdict)))
    exit 0
}catch{
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 2
}
