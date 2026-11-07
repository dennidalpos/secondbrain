#requires -Version 7.5
Set-StrictMode -Version Latest
foreach($m in 'Core','Access','Host','Pending','Tracker','Knowledge','Para'){Import-Module (Join-Path $PSScriptRoot ('SecondBrain.'+$m+'.psm1'))}
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'mcpwrite.invalid' = @{it='Scrittura MCP: input non valido ({0})';en='MCP write: invalid input ({0})'}
    'mcpwrite.approval' = @{it='Scrittura MCP: ricevuta locale assente, scaduta o non valida';en='MCP write: local approval is missing, expired or invalid'}
    'mcpwrite.stale' = @{it='Scrittura MCP: piano o precondizioni cambiati; preparare e approvare una nuova richiesta';en='MCP write: plan or preconditions changed; preview and approve a new request'}
    'mcpwrite.activity' = @{it='Registro attività reale disabilitato: completare la procedura di attivazione F6/F11; nessuna scrittura';en='Real activity log disabled: complete F6/F11 activation procedure; no write'}
    'mcpwrite.disabled' = @{it='Nuove scritture MCP disabilitate in modalità NoRecovery';en='New MCP writes disabled in NoRecovery mode'}
}
function Assert-SBMcpWriteFields($Value,[string[]]$Allowed,[string[]]$Required) {
    if($Value -isnot [Collections.IDictionary] -or @($Value.Keys|Where-Object {$_ -cnotin $Allowed}).Count -or
       @($Required|Where-Object {!$Value.ContainsKey($_)}).Count){throw (New-SBError 'mcpwrite.invalid' @('fields'))}
}
function Assert-SBMcpWriteText($Value,[int]$Maximum=65536) {
    if($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt $Maximum){throw (New-SBError 'mcpwrite.invalid' @('text'))}
}
function Get-SBMcpWriteHash($Value,[string]$HashField) {
    $copy=@{}+$Value;[void]$copy.Remove($HashField)
    Get-SBTextHash (ConvertTo-SBJson $copy)
}
function Get-SBMcpWriteContext([string]$BrainRoot,[string]$ConfigPath,[string]$Repository,[string]$CheckoutPath,[string]$RequestId) {
    if($RequestId -cnotmatch '^[a-f0-9]{32}$' -or !(Test-SBRepositoryIdentity $Repository) -or
       ![IO.Path]::IsPathFullyQualified($CheckoutPath)){throw (New-SBError 'mcpwrite.invalid' @('scope/ID'))}
    $config=Read-SBConfiguration -ConfigPath $ConfigPath -BrainRoot $BrainRoot -ReadOnly
    $asset=Get-SBCheckoutAsset $CheckoutPath $config.bindings
    $matches=@($config.bindings|Where-Object {$_.identity -ceq $Repository -and (Test-SBSamePath $_.path $asset.path)})
    if($asset.identity -cne $Repository -or $matches.Count -ne 1){throw (New-SBError 'mcpwrite.invalid' @('checkout binding'))}
    $dossier=Join-Path $BrainRoot (Resolve-SBWorkingDossier $BrainRoot $Repository)
    $approval=Join-Path $config.localStateRoot ('mcp-write-approvals/'+(Get-SBRuntimeRepoSegment $Repository)+'/'+$RequestId+'.json')
    Assert-SBPlainPath $approval
    @{config=$config;checkout=$asset.path;dossier=$dossier;approvalPath=$approval}
}
function New-SBMcpWritePlan {
    param([string]$BrainRoot,[string]$ConfigPath,[string]$Repository,[string]$CheckoutPath,[string]$RequestId,[string]$Operation,$Payload)
    $ctx=Get-SBMcpWriteContext $BrainRoot $ConfigPath $Repository $CheckoutPath $RequestId
    if((ConvertTo-SBJson $Payload).Length -gt 131072 -or (ConvertTo-SBJson $Payload) -match '(?is)<\s*/?\s*private\b|<\s*/?\s*do[-_]not[-_]memorize\b'){
        throw (New-SBError 'mcpwrite.invalid' @('size/private content'))
    }
    $args=@{};$expected=@{};$pendingOperation=''
    switch($Operation){
        'task.status' {
            Assert-SBMcpWriteFields $Payload @('taskId','status','reason') @('taskId','status')
            Assert-SBMcpWriteText $Payload.taskId 128
            if($Payload.status -cnotin @('todo','in_progress','blocked','done','cancelled','unknown')){throw (New-SBError 'mcpwrite.invalid' @('status'))}
            $args=@{TaskId=$Payload.taskId;Status=$Payload.status}
            if($Payload.ContainsKey('reason')){Assert-SBMcpWriteText $Payload.reason 4096;$args.StateReason=$Payload.reason}
            $pendingOperation='task.status'
        }
        'task.new' {
            Assert-SBMcpWriteFields $Payload @('title','description','priority','acceptance','provenance','pointer') @('title','acceptance','provenance')
            Assert-SBMcpWriteText $Payload.title 200
            if($Payload.acceptance -isnot [array] -or !$Payload.acceptance.Count -or $Payload.acceptance.Count -gt 32){throw (New-SBError 'mcpwrite.invalid' @('acceptance'))}
            foreach($item in $Payload.acceptance){Assert-SBMcpWriteText $item 4096}
            Assert-SBMcpWriteText $Payload.provenance 512
            if($Payload.provenance -cnotmatch '^history/[a-zA-Z0-9][a-zA-Z0-9_-]*/report\.md$'){throw (New-SBError 'mcpwrite.invalid' @('provenance path'))}
            [void](Resolve-SBParaPath $ctx.dossier $Payload.provenance)
            $args=@{Title=$Payload.title;Id=('MCP-'+$RequestId);Acceptance=$Payload.acceptance;ProvenanceReference=$Payload.provenance;Priority='P2';Execution='autonomous'}
            if($Payload.ContainsKey('priority')){if($Payload.priority -cnotin @('P0','P1','P2','P3')){throw (New-SBError 'mcpwrite.invalid' @('priority'))};$args.Priority=$Payload.priority}
            if($Payload.ContainsKey('description')){Assert-SBMcpWriteText $Payload.description 8192;$args.Description=$Payload.description}
            if($Payload.ContainsKey('pointer')){Assert-SBMcpWriteText $Payload.pointer 512;$args.ProvenancePointer=$Payload.pointer}
            $pendingOperation='task.new'
        }
        'memory.append' {
            Assert-SBMcpWriteFields $Payload @('content') @('content');Assert-SBMcpWriteText $Payload.content
            $args=@{relativePath='memory.md';content=$Payload.content};$pendingOperation='file.append'
        }
        'history.save' {
            Assert-SBMcpWriteFields $Payload @('path','content') @('path','content')
            Assert-SBMcpWriteText $Payload.path 256;Assert-SBMcpWriteText $Payload.content
            if($Payload.path -cnotmatch '^history/[a-zA-Z0-9][a-zA-Z0-9_-]*/report\.md$' -or $Payload.path -ceq 'history/activity/report.md'){throw (New-SBError 'mcpwrite.invalid' @('history path'))}
            $args=@{relativePath=$Payload.path;content=$Payload.content};$expected.hash=Get-SBFileHash (Resolve-SBParaPath $ctx.dossier $Payload.path);$pendingOperation='file.save'
        }
        'activity.append' {
            Assert-SBMcpWriteFields $Payload @('taskId','sessionId','when','outcome','detail') @('taskId','sessionId','when','outcome','detail')
            foreach($key in 'taskId','sessionId','when','detail'){Assert-SBMcpWriteText $Payload[$key] 8192}
            if($Payload.outcome -cnotin @('started','progress','completed','blocked','failed')){throw (New-SBError 'mcpwrite.invalid' @('outcome'))}
            $when=[DateTimeOffset]::MinValue
            if(![DateTimeOffset]::TryParse($Payload.when,[ref]$when)){throw (New-SBError 'mcpwrite.invalid' @('when'))}
            $tracker=Read-SBJson (Join-Path $ctx.dossier tracker.json) $null
            $archived=(Read-SBTrackerArchive (Join-Path $ctx.dossier tracker.json) $Repository).data
            if($Payload.taskId -cnotin @(@($tracker.tasks)+@($archived.tasks)|ForEach-Object id)){throw (New-SBError 'mcpwrite.invalid' @('activity task'))}
            $record=@{schemaVersion=1;eventId=$RequestId;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;repository=$Repository;taskId=$Payload.taskId;session=$Payload.sessionId;
                when=$when.ToUniversalTime().ToString('o');where=$ctx.checkout;computer=[Environment]::MachineName;outcome=$Payload.outcome;detail=$Payload.detail}
            $args=@{relativePath='history/activity/report.md';content=((ConvertTo-SBStableValue $record|ConvertTo-Json -Depth 15 -Compress)+"`n")};$pendingOperation='file.append'
        }
        default {throw (New-SBError 'mcpwrite.invalid' @('operation'))}
    }
    $prepared=New-SBPendingWrite -BrainRoot $BrainRoot -Repository $Repository -Operation $pendingOperation -Arguments $args -Expected $expected -Config $ctx.config -RequestId $RequestId -PrepareOnly -StrictPreconditions
    $plan=@{schemaVersion=1;repository=$Repository;checkoutPath=$ctx.checkout;dossierPath=$ctx.dossier;requestId=$RequestId;operation=$Operation;payload=$Payload;
        workstationId=$ctx.config.workstationId;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;
        pending=@{operation=$prepared.request.operation;arguments=$prepared.request.arguments;expected=$prepared.request.expected};
        pendingHash=$prepared.contentHash}
    $plan.planHash=Get-SBMcpWriteHash $plan planHash
    if([Text.Encoding]::UTF8.GetByteCount((ConvertTo-SBJson $plan)) -gt 256KB){throw (New-SBError 'mcpwrite.invalid' @('plan size'))}
    $plan
}
function Read-SBMcpWriteApproval($Context,[string]$PlanHash) {
    $receipt=Read-SBJson $Context.approvalPath $null
    if(!$receipt -or $receipt.schemaVersion -ne 1 -or $receipt.planHash -cne $PlanHash -or
       $receipt.receiptHash -cne (Get-SBMcpWriteHash $receipt receiptHash) -or
       $receipt.plan.planHash -cne (Get-SBMcpWriteHash $receipt.plan planHash) -or $receipt.plan.planHash -cne $PlanHash -or
       $receipt.workstationId -cne $Context.config.workstationId -or $receipt.user -cne [Security.Principal.WindowsIdentity]::GetCurrent().Name -or
       (!(Test-SBSamePath $receipt.plan.checkoutPath $Context.checkout) -or !(Test-SBSamePath $receipt.plan.dossierPath $Context.dossier))){
        throw (New-SBError 'mcpwrite.approval')
    }
    $receipt
}
function Approve-SBMcpWritePlan {
    param([string]$BrainRoot,[string]$ConfigPath,$Plan,[string]$ExpectedPlanHash,[string]$Authorization,[string]$SessionId)
    if(!$Authorization -or !$ExpectedPlanHash -or $Plan.planHash -cne $ExpectedPlanHash -or
       (Get-SBMcpWriteHash $Plan planHash) -cne $ExpectedPlanHash){throw (New-SBError 'mcpwrite.approval')}
    $ctx=Get-SBMcpWriteContext $BrainRoot $ConfigPath $Plan.repository $Plan.checkoutPath $Plan.requestId
    $session=Assert-SBSession $ctx.config $SessionId
    if($session.repository -cne $Plan.repository){throw (New-SBError 'mcpwrite.approval')}
    $fresh=New-SBMcpWritePlan $BrainRoot $ConfigPath $Plan.repository $Plan.checkoutPath $Plan.requestId $Plan.operation $Plan.payload
    if($fresh.planHash -cne $ExpectedPlanHash){throw (New-SBError 'mcpwrite.stale')}
    if([IO.File]::Exists($ctx.approvalPath)){
        $existing=Read-SBMcpWriteApproval $ctx $ExpectedPlanHash
        if([DateTimeOffset]::Parse($existing.expiresAt) -le [DateTimeOffset]::UtcNow){throw (New-SBError 'mcpwrite.approval')}
        return @{approved=$true;planHash=$ExpectedPlanHash;requestId=$Plan.requestId;expiresAt=$existing.expiresAt;receiptPath=$ctx.approvalPath}
    }
    $now=[DateTimeOffset]::UtcNow
    $receipt=@{schemaVersion=1;plan=$fresh;planHash=$ExpectedPlanHash;workstationId=$ctx.config.workstationId;
        user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;approvedAt=$now.ToString('o');expiresAt=$now.AddMinutes(10).ToString('o');authorization=$Authorization}
    $receipt.receiptHash=Get-SBMcpWriteHash $receipt receiptHash
    [void](Write-SBFile $ctx.approvalPath ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SBJson $receipt))) 'absent' $ctx.config.localStateBackupRoot)
    @{approved=$true;planHash=$ExpectedPlanHash;requestId=$Plan.requestId;expiresAt=$receipt.expiresAt;receiptPath=$ctx.approvalPath}
}
function Submit-SBMcpWrite {
    param([string]$BrainRoot,[string]$ConfigPath,[string]$Repository,[string]$CheckoutPath,[string]$RequestId,[string]$PlanHash)
    $ctx=Get-SBMcpWriteContext $BrainRoot $ConfigPath $Repository $CheckoutPath $RequestId
    $receipt=Read-SBMcpWriteApproval $ctx $PlanHash;$plan=$receipt.plan
    if($plan.repository -cne $Repository -or $plan.requestId -cne $RequestId){throw (New-SBError 'mcpwrite.approval')}
    $queuedPath=Join-Path $BrainRoot ('.runtime/access/pending-writes/'+$RequestId+'.json')
    Assert-SBPlainPath $queuedPath
    $queued=[IO.File]::Exists($queuedPath)
    if(!$queued){
        if([DateTimeOffset]::Parse($receipt.approvedAt) -gt [DateTimeOffset]::UtcNow -or
           [DateTimeOffset]::Parse($receipt.expiresAt) -le [DateTimeOffset]::UtcNow){throw (New-SBError 'mcpwrite.approval')}
        if($plan.operation -eq 'activity.append' -and (!$ctx.config.ContainsKey('activityLogEnabled') -or $ctx.config.activityLogEnabled -ne $true)){throw (New-SBError 'mcpwrite.activity')}
        $fresh=New-SBMcpWritePlan $BrainRoot $ConfigPath $Repository $CheckoutPath $RequestId $plan.operation $plan.payload
        if($fresh.planHash -cne $PlanHash){throw (New-SBError 'mcpwrite.stale')}
    }
    $submission=New-SBPendingWrite -BrainRoot $BrainRoot -Repository $Repository -Operation $plan.pending.operation -Arguments $plan.pending.arguments -Expected $plan.pending.expected -Config $ctx.config -RequestId $RequestId -PreparedHash $plan.pendingHash -StrictPreconditions
    Complete-SBPendingSubmission $submission $ctx.config -OnlySubmission
}
Export-ModuleMember -Function New-SBMcpWritePlan,Approve-SBMcpWritePlan,Submit-SBMcpWrite,Assert-SBMcpWriteFields