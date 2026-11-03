# Included by trace: the hook and all output are inside the copied fixture brain.
$traceDirectory=Join-Path (Get-SBTraceRoot $brain) (Get-SBHostId)
[IO.Directory]::CreateDirectory($traceDirectory)|Out-Null
$originalAcl=Get-Acl -LiteralPath $traceDirectory
$deniedAcl=Get-Acl -LiteralPath $traceDirectory
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
$rule=[Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::Write,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Deny)
$deniedAcl.AddAccessRule($rule)
try{
    Set-Acl -LiteralPath $traceDirectory -AclObject $deniedAcl
    foreach($language in @('it','en')){
        $lost='{}'|& pwsh -NoProfile -File $cli -Event stop -Language $language 2>&1|Out-String
        Assert-Trace ($LASTEXITCODE -eq 0 -and $lost -match '\[trace.event.lost\]') ('denied hook reports a lost event, remains fail-open: '+$language)
    }
}finally{Set-Acl -LiteralPath $traceDirectory -AclObject $originalAcl}
