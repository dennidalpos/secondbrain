# Fixtures isolated from the main suite; no access to application checkouts.
$revisionFixture = Join-Path $root 'directive-revision'
Put (Join-Path $revisionFixture 'direttive/AGENTS.global_ide.md') "# Common fixture`nRevisione 3.0 — 2026-10-19."
Put (Join-Path $revisionFixture 'direttive/workstation.template.md') 'Postazione fixture'
$revisionApproval = @{authorization='fixture isolata';files=@{}}
foreach($relative in @('direttive/AGENTS.global_ide.md','direttive/workstation.template.md')){
    $revisionApproval.files[$relative] = Get-SBFileHash (Join-Path $revisionFixture $relative)
}
Put (Join-Path $revisionFixture 'direttive/approved.json') (ConvertTo-SBJson $revisionApproval)
$revision = Get-SBApprovedDirectiveRevision $revisionFixture
Assert ($revision.version -eq '3.0' -and $revision.globalHash.Length -eq 64) 'direttive: versione derivata dai testi approvati'
$approvalFixture = Join-Path $root 'directive-approval'
Put (Join-Path $approvalFixture 'direttive/AGENTS.global_ide.md') 'Fonte senza revisione'
Put (Join-Path $approvalFixture 'direttive/workstation.template.md') 'Postazione'
$fixtureApproval = @{authorization='fixture';files=@{}}
foreach($relative in @('direttive/AGENTS.global_ide.md','direttive/workstation.template.md')) { $fixtureApproval.files[$relative] = Get-SBFileHash (Join-Path $approvalFixture $relative) }
Put (Join-Path $approvalFixture 'direttive/approved.json') (ConvertTo-SBJson $fixtureApproval)
Assert ($null -eq (Get-SBApprovedDirectiveRevision $approvalFixture)) 'direttive: sorgente approvata senza versione non produce marcature'
Put (Join-Path $approvalFixture 'direttive/AGENTS.global_ide.md') "Revisione 9.9 — 2026-10-19. Non approvata"
Assert ($null -eq (Get-SBApprovedDirectiveRevision $approvalFixture)) 'direttive: sorgente alterata non produce marcature'
