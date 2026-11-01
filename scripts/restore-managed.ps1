#requires -Version 7.5
<#
.SYNOPSIS
Elenca i backup dei file sostituiti da SecondBrain e ripristina un file dal suo backup.
.DESCRIPTION
-List (sola lettura) mostra i backup per percorso originale, con data e hash, cercando in backupRoot della postazione e in .runtime/backup/mcp-pairing. -Path filtra per file originale.
-MetadataPath ripristina un file dal suo <guid>.bin.json: il backup deve avere l'hash registrato e il file attuale deve coincidere con quello distribuito da SecondBrain.
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
if($List){
    $config=Read-SBConfiguration $ConfigPath -ReadOnly
    $brain=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $roots=@($config.backupRoot,(Join-Path $brain '.runtime/backup/mcp-pairing'))|Where-Object {$_ -and (Test-Path -LiteralPath $_ -PathType Container)}|Select-Object -Unique
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
if(!$metadata -or !$metadata.path -or !$metadata.backup -or !$metadata.previousHash -or !$metadata.deployedHash){throw 'Metadati di ripristino non validi'}
if((Get-SBFileHash $metadata.backup) -ne $metadata.previousHash){throw 'Backup alterato: ripristino rifiutato'}
$backupRoot=$config.backupRoot
Assert-SBPlainPath $metadata.backup
    Write-SBFile $metadata.path ([IO.File]::ReadAllBytes($metadata.backup)) $metadata.deployedHash $backupRoot|Out-Null
    'Ripristinato: '+$metadata.path+'. Eseguire secondbrain.ps1 -Check per riconciliare lo stato.'
}finally{Exit-SBOperation $lock}
