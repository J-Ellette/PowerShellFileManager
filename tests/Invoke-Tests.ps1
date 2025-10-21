<#
.SYNOPSIS
    Run all Pester tests for PowerShell File Manager V2.0

.DESCRIPTION
    Executes unit and integration tests using Pester 5.x framework
    Generates test results and code coverage reports

.PARAMETER Type
    Type of tests to run: All, Unit, Integration
.PARAMETER CodeCoverage
    Generate code coverage report

.PARAMETER Output
    Output format: None, Normal, Detailed, Diagnostic

.PARAMETER PassThru
    Return the Pester result object

.EXAMPLE
    .\Invoke-Tests.ps1
    Run all tests with normal output

.EXAMPLE
    .\Invoke-Tests.ps1 -Type Unit -Output Detailed
    Run only unit tests with detailed output

.EXAMPLE
    .\Invoke-Tests.ps1 -CodeCoverage
    Run all tests and generate code coverage report
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('All', 'Unit', 'Integration')]
    [string]$Type = 'All',

    [Parameter()]
    [switch]$CodeCoverage,

    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Normal',

    [Parameter()]
    [switch]$PassThru
)

# Ensure Pester 5.x is available
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0' } | Select-Object -First 1

if (-not $pesterModule) {
    Write-Error "Pester 5.x or higher is required. Install with: Install-Module -Name Pester -Force -SkipPublisherCheck"
    exit 1
}

Import-Module Pester -MinimumVersion 5.0 -Force

# Set up paths
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$TestsPath = Join-Path $ProjectRoot 'tests'
$ModulesPath = Join-Path $ProjectRoot 'src\Modules'

# Determine which tests to run
$testPaths = @()
switch ($Type) {
    'All' {
        $testPaths += Join-Path $TestsPath 'Unit'
        if (Test-Path (Join-Path $TestsPath 'Integration')) {
            $testPaths += Join-Path $TestsPath 'Integration'
        }
    }
    'Unit' {
        $testPaths += Join-Path $TestsPath 'Unit'
    }
    'Integration' {
        $testPaths += Join-Path $TestsPath 'Integration'
    }
}

# Configure Pester
$configuration = [PesterConfiguration]::Default

# Set test paths
$configuration.Run.Path = $testPaths

# Configure output
$configuration.Output.Verbosity = $Output

# Configure code coverage if requested
if ($CodeCoverage) {
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.Path = @(
        (Join-Path $ModulesPath 'PowerToys\*.psm1'),
        (Join-Path $ModulesPath 'Preview\*.psm1'),
        (Join-Path $ModulesPath 'Core\*.psm1')
    )
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    $configuration.CodeCoverage.OutputPath = Join-Path $ProjectRoot 'coverage.xml'
}

# Configure test result output
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.TestResult.OutputPath = Join-Path $ProjectRoot 'testResults.xml'

# ✅ FIX: Only set PassThru if switch is present
if ($PassThru.IsPresent) {
    $configuration.Run.PassThru = $true
}

# Display configuration
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "PowerShell File Manager V2.0 - Test Suite" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Test Type:        $Type" -ForegroundColor White
Write-Host "Output Level:     $Output" -ForegroundColor White
Write-Host "Code Coverage:    $($CodeCoverage.IsPresent)" -ForegroundColor White
Write-Host "Pester Version:   $($pesterModule.Version)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Run tests
$result = Invoke-Pester -Configuration $configuration

# Display summary
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Total Tests:      $($result.TotalCount)" -ForegroundColor White
Write-Host "Passed:           $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed:           $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped:          $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration:         $($result.Duration)" -ForegroundColor White

if ($CodeCoverage -and $result.CodeCoverage) {
    $coveragePercent = [math]::Round(($result.CodeCoverage.CoveragePercent), 2)
    $coverageColor = if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' }
    Write-Host "Code Coverage:    $coveragePercent%" -ForegroundColor $coverageColor
    Write-Host "Coverage Report:  $(Join-Path $ProjectRoot 'coverage.xml')" -ForegroundColor White
}

Write-Host "Test Results:     $(Join-Path $ProjectRoot 'testResults.xml')" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Exit with appropriate code
if ($result.FailedCount -gt 0) {
    Write-Host "Tests FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All tests PASSED" -ForegroundColor Green
    exit 0
}
