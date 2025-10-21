@{
    Run = @{
        Path = @(
            '.\tests\Unit'
            '.\tests\Integration'
        )
        ExcludePath = @()
        ScriptBlock = @()
        Container = @()
        TestExtension = '.Tests.ps1'
        Exit = $false
        Throw = $false
        PassThru = $true
        SkipRun = $false
    }

    Filter = @{
        Tag = @()
        ExcludeTag = @()
        Line = @()
        ExcludeLine = @()
        FullName = @()
    }

    CodeCoverage = @{
        Enabled = $false
        OutputFormat = 'JaCoCo'
        OutputPath = 'coverage.xml'
        OutputEncoding = 'UTF8'
        Path = @(
            '.\src\Modules\PowerToys\*.psm1'
            '.\src\Modules\Preview\*.psm1'
            '.\src\Modules\Core\*.psm1'
        )
        ExcludeTests = $true
        RecursePaths = $true
        CoveragePercentTarget = 75
    }

    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = 'testResults.xml'
        OutputEncoding = 'UTF8'
        TestSuiteName = 'PowerShell File Manager V2.0'
    }

    Should = @{
        ErrorAction = 'Stop'
    }

    Debug = @{
        ShowFullErrors = $false
        WriteDebugMessages = $false
        WriteDebugMessagesFrom = @()
        ShowNavigationMarkers = $false
        ReturnRawResultObject = $false
    }

    Output = @{
        Verbosity = 'Normal'
        StackTraceVerbosity = 'Filtered'
        CIFormat = 'Auto'
        CILogLevel = 'Error'
    }

    TestDrive = @{
        Enabled = $true
    }

    TestRegistry = @{
        Enabled = $true
    }
}
