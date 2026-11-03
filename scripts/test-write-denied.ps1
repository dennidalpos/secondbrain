# Included by concurrency. ACLs are applied only to newly created fixture directories
# and restored in finally; artifacts remain available with SECONDBRAIN_TEST_KEEP=1.
function Invoke-WriteDeniedAcl([string]$Directory,[scriptblock]$Body) {
    [IO.Directory]::CreateDirectory($Directory)|Out-Null
    $originalAcl=Get-Acl -LiteralPath $Directory
    $deniedAcl=Get-Acl -LiteralPath $Directory
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule=[Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::Write,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Deny)
    $deniedAcl.AddAccessRule($rule)
    try{Set-Acl -LiteralPath $Directory -AclObject $deniedAcl;& $Body}finally{Set-Acl -LiteralPath $Directory -AclObject $originalAcl}
}
Invoke-Case 'write-denied' (Join-Path $root 'denied') {
    $deniedRoot=Join-Path $root 'denied';[IO.Directory]::CreateDirectory($deniedRoot)|Out-Null
    $blocked=Join-Path $deniedRoot 'blocked';$backups=Join-Path $deniedRoot 'backups'
    Invoke-WriteDeniedAcl $blocked {
        $failure=$null
        try{Write-SBFile (Join-Path $blocked 'new/target.txt') ([Text.Encoding]::UTF8.GetBytes('new')) 'absent' $backups|Out-Null}catch{$failure=$_}
        Assert-Conc ($failure -and (Get-ErrorCode $failure.Exception) -eq 'core.write.denied' -and (Get-SBWriteDeniedException $failure.Exception)) 'ACL denies directory creation: stable code and original exception'
        Assert-Conc (!(Test-Path -LiteralPath (Join-Path $blocked 'new'))) 'denied directory creation leaves destination absent'
    }
    $target=Join-Path $deniedRoot 'original.txt';[IO.File]::WriteAllText($target,'original')
    Invoke-WriteDeniedAcl $backups {
        $failure=$null
        try{Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('changed')) (Get-SBFileHash $target) $backups|Out-Null}catch{$failure=$_}
        Assert-Conc ($failure -and (Get-ErrorCode $failure.Exception) -eq 'core.write.denied' -and (Read-SBText $target) -ceq 'original') 'ACL denies backup: original destination remains intact'
    }
    [IO.File]::SetAttributes($target,[IO.FileAttributes]::ReadOnly)
    try{
        $failure=$null
        try{Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('changed')) (Get-SBFileHash $target) $backups|Out-Null}catch{$failure=$_}
        Assert-Conc ($failure -and (Get-ErrorCode $failure.Exception) -eq 'core.write.denied' -and (Read-SBText $target) -ceq 'original') 'read-only file: denied replace and original bytes preserved'
    }finally{[IO.File]::SetAttributes($target,[IO.FileAttributes]::Normal)}
    $guardState=@{calls=0};$originalBackupAcl=Get-Acl -LiteralPath $backups
    $guard={
        $guardState.calls++
        if($guardState.calls -eq 2){
            $acl=Get-Acl -LiteralPath $backups
            $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.AccessControl.FileSystemRights]::Write,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Deny))
            Set-Acl -LiteralPath $backups -AclObject $acl
            throw 'primary-fixture-error'
        }
    }.GetNewClosure()
    try{
        Set-SBWriteGuard $guard
        $failure=$null
        try{Write-SBFile $target ([Text.Encoding]::UTF8.GetBytes('changed')) (Get-SBFileHash $target) $backups -WarningVariable finalWarnings|Out-Null}catch{$failure=$_}
        Assert-Conc ($failure -and $failure.Exception.Message -match 'primary-fixture-error' -and !(Get-SBWriteDeniedException $failure.Exception)) 'secondary journal denial never replaces the primary error'
    }finally{Set-SBWriteGuard $null;Set-Acl -LiteralPath $backups -AclObject $originalBackupAcl}
    $transactionBrain=Join-Path $deniedRoot 'transaction';$transactionTarget=Join-Path $transactionBrain 'blocked/target.txt'
    [IO.Directory]::CreateDirectory((Split-Path $transactionTarget))|Out-Null
    Invoke-WriteDeniedAcl (Split-Path $transactionTarget) {
        $failure=$null
        try{Invoke-SBParaTransaction @(@{path=$transactionTarget;expected='absent';bytes=[Text.Encoding]::UTF8.GetBytes('new')}) (Join-Path $transactionBrain '.runtime/backup') $transactionBrain|Out-Null}catch{$failure=$_}
        Assert-Conc ($failure -and (Test-SBError $failure 'core.write.denied') -and (Test-Path -LiteralPath (Join-Path $transactionBrain '.runtime/para-transaction.json'))) 'transaction preserves denied classification and pending recovery marker'
    }
    # Actual CLI, copied brain and synthetic profile: lock-directory denial happens before pairing.
    $cliBrain=Join-Path $deniedRoot 'cli';$cliScripts=Join-Path $cliBrain 'scripts'
    [IO.Directory]::CreateDirectory($cliScripts)|Out-Null
    Get-ChildItem -LiteralPath $PSScriptRoot -File|Copy-Item -Destination $cliScripts
    $profileBefore=$env:USERPROFILE
    try{
        $env:USERPROFILE=Join-Path $deniedRoot 'profile'
        Invoke-WriteDeniedAcl (Join-Path $cliBrain '.runtime/access') {
            foreach($language in @('it','en')){
                $diagnostic=& pwsh -NoProfile -File (Join-Path $cliScripts 'mcp-server.ps1') -Pair -Target cursor -Apply -Language $language 2>&1|Out-String
                Assert-Conc ($LASTEXITCODE -eq 4 -and $diagnostic -match '\[core.write.denied\]' -and $diagnostic -match "-Target 'cursor'" -and $diagnostic -match 'sandbox') ('CLI exit 4 and quoted retry command: '+$language) $diagnostic
            }
        }
    }finally{$env:USERPROFILE=$profileBefore}
}
