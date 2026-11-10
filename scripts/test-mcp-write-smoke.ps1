# Fast contract checks only. The complete unchanged operation/CLI/wire matrix runs
# in test-mcp-writes.ps1 through -Only mcp-writes and Full.
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.McpWrites.psm1')
$mcpSmokeId=[guid]::NewGuid().ToString('N')
$mcpSmokeMemory=Join-Path $dossier memory.md
$mcpSmokeHash=Get-SBFileHash $mcpSmokeMemory
$mcpSmokeQueue=@(Get-SBPendingWrites $brain).Count
$mcpSmokePlan=New-SBMcpWritePlan $brain $configPath $identity $repo $mcpSmokeId 'memory.append' @{content='synthetic smoke only'}
Check ($mcpSmokePlan.pending.expected.hash -ceq $mcpSmokeHash -and $mcpSmokePlan.dossierPath -ceq $dossier) 'Fast MCP preview binds the exact destination and hash'
Reject {Submit-SBMcpWrite $brain $configPath $identity $repo $mcpSmokeId $mcpSmokePlan.planHash} 'Fast MCP denies a missing approval receipt'
Reject {New-SBMcpWritePlan $brain $configPath $identity $repo ('f'*32) 'memory.append' @{content='x';approved=$true}} 'Fast MCP refuses model-supplied approval'
Reject {New-SBMcpWritePlan $brain $configPath $identity $repo ('e'*32) 'memory.append' @{content='<private>synthetic</private>'}} 'Fast MCP refuses explicitly private content'
$mcpSmokeReply=Invoke-SBMcpMessage $brain @{jsonrpc='2.0';id=99;method='tools/call';params=@{name='submit_dossier_write';arguments=@{repository=$identity;checkoutPath=$repo;requestId=$mcpSmokeId;planHash=$mcpSmokePlan.planHash;noRecovery=$true}}}|ConvertFrom-Json -AsHashtable
Check $mcpSmokeReply.result.isError 'Fast MCP NoRecovery denies a write on the wire'
Check ((Get-SBFileHash $mcpSmokeMemory) -ceq $mcpSmokeHash -and @(Get-SBPendingWrites $brain).Count -eq $mcpSmokeQueue) 'Fast MCP denials do not change memory or queue'
Check (@(Get-SBMcpKnowledgeToolNames|Where-Object {$_ -in @('preview_dossier_write','submit_dossier_write')}).Count -eq 0) 'Fast MCP write tools remain outside knowledge preauthorization'