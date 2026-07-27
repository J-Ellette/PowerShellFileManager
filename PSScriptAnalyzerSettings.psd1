@{
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        # The interactive console output style is intentional for now; converting
        # the ~600 Write-Host call sites to Write-Information/Verbose is tracked
        # as a separate cleanup.
        'PSAvoidUsingWriteHost'
    )
}
