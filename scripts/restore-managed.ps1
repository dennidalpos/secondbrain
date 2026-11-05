#requires -Version 7.5
<#
.SYNOPSIS
Lists backups of files replaced by SecondBrain and restores a file from its backup.
.DESCRIPTION
-List (read-only) shows backups by original path, with date and hash, searching the workstation backupRoot and .runtime/backups/mcp-pairing. -Path filters by original file.
-MetadataPath restores a file from its <guid>.bin.json: the backup must match the recorded hash and the current file must match the file deployed by SecondBrain.
.EXAMPLE
pwsh -NoProfile -File scripts/restore-managed.ps1 -List -Path "$HOME/.claude/CLAUDE.md"
.EXAMPLE
pwsh -NoProfile -File scripts/restore-managed.ps1 -MetadataPath .runtime/hosts/<id>/backups/<guid>.bin.json
#>
[CmdletBinding(DefaultParameterSetName='Restore')]
param(
    [Parameter(Mandatory,ParameterSetName='Restore')][string]$MetadataPath,
    [Parameter(Mandatory,ParameterSetName='List')][switch]$List,
    [Parameter(ParameterSetName='List')][string]$Path,
    [string]$ConfigPath,
    [Parameter(ParameterSetName='Restore')][string]$SessionId
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Access.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'restore.metadata.invalid' = @{ it = 'Metadati di ripristino non validi'; en = 'Invalid restore metadata' }
    'restore.backup.altered' = @{ it = 'Backup alterato: ripristino rifiutato'; en = 'Backup altered: restore refused' }
}
# Writer busy beyond the wait limit: exit 3 (the message identifies the owner).
trap { if (Test-SBWriteDeniedError $_) { Write-SBWriteDeniedDiagnostic $_ $PSCommandPath $PSBoundParameters; exit 4 }; if (Test-SBBusyError $_) { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }; break }
if($List){
    $config=Read-SBConfiguration $ConfigPath -ReadOnly
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $roots=@($config.backupRoot,(Join-Path $brain '.runtime/backups/mcp-pairing'))|Where-Object {$_ -and (Test-Path -LiteralPath $_ -PathType Container)}|Select-Object -Unique
    $wanted=if($Path){[IO.Path]::GetFullPath($Path)}else{$null}
    $found=foreach($root in $roots){
        foreach($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.bin.json'){
            $item=Read-SBJson $file.FullName $null
            if(!$item -or !$item.path -or !$item.backup){continue}
            if($wanted -and [IO.Path]::GetFullPath([string]$item.path) -ine $wanted){continue}
            [pscustomobject]@{Original=[string]$item.path;Data=$file.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss')+'Z';HashPrecedente=[string]$item.previousHash;Backup=[string]$item.backup;Metadati=$file.FullName}
        }
    }
    @($found|Sort-Object Original,@{Expression='Data';Descending=$true})
    exit 0
}
$config=Read-SBConfiguration $ConfigPath
$lock=Enter-SBOperation $config $SessionId
try {
$metadata=Read-SBJson $MetadataPath $null
if(!$metadata -or !$metadata.path -or !$metadata.backup -or !$metadata.previousHash -or !$metadata.deployedHash){throw (New-SBError 'restore.metadata.invalid')}
if((Get-SBFileHash $metadata.backup) -ne $metadata.previousHash){throw (New-SBError 'restore.backup.altered')}
$backupRoot=$config.backupRoot
Assert-SBPlainPath $metadata.backup
    Write-SBFile $metadata.path ([IO.File]::ReadAllBytes($metadata.backup)) $metadata.deployedHash $backupRoot -BackupDirty | Out-Null
    'Ripristinato: '+$metadata.path+'. Eseguire secondbrain.ps1 -Check per riconciliare lo stato.'
}finally{Exit-SBOperation $lock}
