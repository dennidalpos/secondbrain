@{
    # Usage: Invoke-ScriptAnalyzer -Path scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
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
