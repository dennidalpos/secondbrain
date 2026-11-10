#requires -Version 7.5
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Host.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Knowledge.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'sandbox.checkout' = @{it='Checkout gestito non verificabile per il repository richiesto';en='Managed checkout cannot be verified for the requested repository'}
    'sandbox.output' = @{it='Destinazione richiesta: cartella work propria, aperta e inizializzata con work.ps1 per questa sessione';en='Destination must be an owned, open work folder initialized with work.ps1 for this session'}
    'sandbox.broad' = @{it='Radice troppo ampia per la configurazione minima: {0}';en='Root is too broad for minimal configuration: {0}'}
    'sandbox.unsupported' = @{it='Configurazione automatica non supportata: {0}. Nessun file modificato';en='Automatic configuration unsupported: {0}. No files changed'}
    'sandbox.stale' = @{it='Anteprima assente o cambiata: rivedere il piano e il suo hash prima di Apply';en='Preview missing or changed: review the plan and its hash before Apply'}
    'sandbox.shared' = @{it='Coordinamento e backup possono contenere dati di altri repository. Le directory aggiuntive Claude consentono anche letture. Le regole non sono una barriera OS per i sottoprocessi';en='Coordination and backups may contain other repositories data. Claude additional directories also allow reads. Rules are not an OS boundary for subprocesses'}
    'sandbox.scope' = @{it='Configurazione per le operazioni dossier di knowledge.ps1. Non abilita Sync, Setup, PARA o manutenzione globale. Le policy IDE esistenti possono limitare o ampliare gli accessi effettivi; verificare in una nuova sessione';en='Configuration for knowledge.ps1 dossier operations. Does not enable Sync, Setup, PARA or global maintenance. Existing IDE policies may restrict or broaden effective access; verify in a new session'}
}
function Get-SBSandboxPlan {
    param($Config,[string]$Repository,[string]$CheckoutPath,[string]$Target,[string]$OutputDirectory)
    $checkout=Get-SBCheckoutAsset $CheckoutPath $Config.bindings
    $bindings=@($Config.bindings|Where-Object {$_.identity -ceq $Repository -and (Test-SBSamePath $_.path $checkout.path)})
    if($bindings.Count -ne 1 -or $checkout.identity -cne $Repository){throw (New-SBError 'sandbox.checkout')}
    $dossier=Join-Path $Config.brainRoot (Resolve-SBWorkingDossier $Config.brainRoot $Repository)
    $repoRuntime=Join-Path $Config.runtimeRoot ('repos/'+(Get-SBRuntimeRepoSegment $Repository))
    $roots=@(
        @{path=$dossier;purpose='dossier';shared=$false}
        @{path=$Config.coordinationRoot;purpose='coordination';shared=$true}
        @{path=$Config.backupRoot;purpose='backups';shared=$true}
        @{path=$repoRuntime;purpose='repository-runtime';shared=$false}
    )
    $forbidden=@($Config.brainRoot,(Join-Path $Config.brainRoot '.runtime'),$Config.runtimeRoot)
    foreach($root in $roots){
        $root.path=[IO.Path]::GetFullPath($root.path)
        # Refuse unsupported Claude UNC roots by syntax; do not probe the remote
        # host just to report an unsupported configuration.
        if(!($Target -eq 'claude-code' -and $root.path.StartsWith('\\'))){Assert-SBPlainPath $root.path}
        foreach($boundary in $forbidden){
            $relative=[IO.Path]::GetRelativePath($root.path,[IO.Path]::GetFullPath($boundary))
            if($relative -eq '.' -or (!$relative.StartsWith('..') -and ![IO.Path]::IsPathRooted($relative))){throw (New-SBError 'sandbox.broad' @($root.path))}
        }
    }
    $output=[IO.Path]::GetFullPath($OutputDirectory)
    Assert-SBPlainPath $output
    $relative=[IO.Path]::GetRelativePath((Join-Path $repoRuntime 'work'),$output)
    if($relative -eq '.' -or $relative.StartsWith('..') -or [IO.Path]::IsPathRooted($relative) -or $relative -match '[\\/]'){throw (New-SBError 'sandbox.output')}
    $status='supported';$reason='';$files=@();$nativeArgs=@();$executable=''
    $paths=@($roots|ForEach-Object path|Select-Object -Unique)
    if($Target -notin @('codex','claude-code')){$status='unsupported';$reason='no-verified-configuration-adapter'}
    elseif($Target -eq 'claude-code' -and @($paths|Where-Object {$_.StartsWith('\\') -or $_ -match '[*?\[\]()!\x00-\x1f]'}).Count){
        # UNC working directories are not supported by Claude. Do not map drives or
        # turn paths into wildcard permission patterns.
        $status='unsupported';$reason='unc-or-rule-metacharacters'
    }
    elseif($Target -eq 'codex'){
        $executable='codex'
        # JSON string/array encoding is also valid TOML for these path strings.
        $array=ConvertTo-Json -InputObject $paths -Compress
        $nativeArgs=@('--cd',$checkout.path,'--sandbox','workspace-write','--config',('sandbox_workspace_write.writable_roots='+$array))
        $files+=@{name='codex-config.toml';text=("sandbox_mode = `"workspace-write`"`n[sandbox_workspace_write]`nwritable_roots = "+$array+"`n")}
        $files+=@{name='codex-arguments.json';text=(ConvertTo-SBJson @{executable=$executable;arguments=$nativeArgs;workingDirectory=$checkout.path})}
    } else {
        $executable='claude'
        $rules=@(foreach($path in $paths){
            $posix=$path.Replace('\','/')
            if($posix -match '^([A-Za-z]):/(.*)$'){$posix='/'+$Matches[1].ToLowerInvariant()+'/'+$Matches[2]}
            'Edit(/'+$posix.TrimEnd('/')+'/**)'
        })
        $settings=@{permissions=@{additionalDirectories=$paths;allow=$rules}}
        $files+=@{name='claude-settings.json';text=(ConvertTo-SBJson $settings)}
        $nativeArgs=@('--settings',(Join-Path $output 'claude-settings.json'))
    }
    foreach($file in $files){
        $file.path=Join-Path $output $file.name
        Assert-SBPlainPath $file.path
        $file.expectedHash=Get-SBFileHash $file.path
    }
    $plan=@{schemaVersion=1;repository=$Repository;checkout=$checkout.path;target=$Target;status=$status;reason=$reason;
        roots=$roots;outputDirectory=$output;manifestHash=(Get-SBFileHash (Join-Path $output 'MANIFEST.json'));
        files=$files;executable=$executable;arguments=$nativeArgs;clientSessionVerified=$false;
        warnings=@((Get-SBMessage 'sandbox.shared'),(Get-SBMessage 'sandbox.scope'));
        legacyTransactionMarker=(Test-Path -LiteralPath (Join-Path $Config.brainRoot '.runtime/para-transaction.json'))}
    if($plan.legacyTransactionMarker){$plan.status='unsupported';$plan.reason='legacy-transaction-requires-recovery';$plan.files=@();$plan.arguments=@()}
    $plan.planHash=Get-SBTextHash (ConvertTo-SBJson $plan)
    $plan
}
function Set-SBSandboxConfiguration {
    param($Config,[string]$Repository,[string]$CheckoutPath,[string]$Target,[string]$OutputDirectory,[string]$ExpectedPlanHash,[string]$SessionId)
    $plan=Get-SBSandboxPlan $Config $Repository $CheckoutPath $Target $OutputDirectory
    if(!$ExpectedPlanHash -or $plan.planHash -cne $ExpectedPlanHash){throw (New-SBError 'sandbox.stale')}
    if($plan.status -ne 'supported'){throw (New-SBError 'sandbox.unsupported' @($plan.reason))}
    $manifest=Read-SBJson (Join-Path $plan.outputDirectory 'MANIFEST.json') $null
    if(!$manifest -or $manifest.schemaVersion -ne 1 -or $manifest.category -ne 'work' -or $manifest.status -ne 'open' -or
       $manifest.hostId -cne $Config.workstationId -or $manifest.repository -cne (Get-SBRuntimeRepoSegment $Repository) -or
       !$SessionId -or $manifest.sessionId -cne $SessionId -or $manifest.owner.user -ine $env:USERNAME -or $manifest.owner.computer -ine $env:COMPUTERNAME){
        throw (New-SBError 'sandbox.output')
    }
    foreach($file in $plan.files){
        [void](Write-SBFile $file.path ([Text.Encoding]::UTF8.GetBytes($file.text)) $file.expectedHash $Config.backupRoot)
    }
    @{applied=$true;planHash=$plan.planHash;files=@($plan.files|ForEach-Object path);executable=$plan.executable;arguments=$plan.arguments;workingDirectory=$plan.checkout;clientSessionVerified=$false}
}
Export-ModuleMember -Function Get-SBSandboxPlan,Set-SBSandboxConfiguration