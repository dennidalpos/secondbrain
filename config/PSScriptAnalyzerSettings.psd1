@{
    # Usage: Invoke-ScriptAnalyzer -Path scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    # Deferred findings (config/lint-baseline.json), classified (#440):
    # - PSAvoidUsingWriteHost: interactive console output of CLI tools (mcp-server.ps1, rollback-repo.ps1, setup prompts and previews in
    #   SecondBrain.Portable.psm1) and progress lines of manual tests (smb, mcp-handshake). The text goes through Get-SBMessage keys and the
    #   output is meant for a person, not for the pipeline; machine output uses JSON on the success stream. Admitted.
    # - PSUseApprovedVerbs: verbs of test-local helper functions (Put-*, Reject-*, F5-*, Resource-Audit, ...), never exported; renaming them
    #   would touch hundreds of call sites for no public effect. Visit-SBTrackerNode is a module-internal walker. Admitted.
    # - PSUseBOMForUnicodeEncodedFile: the repository writes UTF-8 without BOM on purpose (Write-SBFile, STDIO MCP). Admitted.
    # - PSAvoidDefaultValueSwitchParameter: two switches default to $true to keep a documented default. Admitted.
    # Empty catch blocks, unused variables, PSUseCmdletCorrectly and null comparisons are fixed and no longer in the baseline.
    Severity     = @('Error', 'Warning')
    IncludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidGlobalVars',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseApprovedVerbs',
        'PSUseCmdletCorrectly',
        'PSAvoidDefaultValueSwitchParameter',
        'PSPossibleIncorrectComparisonWithNull',
        'PSMisleadingBacktick',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSUseBOMForUnicodeEncodedFile'
    )
}
