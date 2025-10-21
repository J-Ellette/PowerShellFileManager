# Testing Guide - PowerShell File Manager V2.0

This document describes how to run and write tests for the PowerShell File Manager V2.0 project using the Pester testing framework.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Continuous Integration](#continuous-integration)
- [Code Coverage](#code-coverage)
- [Best Practices](#best-practices)

---

## Prerequisites

### Installing Pester

The project uses Pester 5.x for testing. Install it with:

```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
```

### Verify Installation

```powershell
Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0' }
```

---

## Test Structure

Tests are organized in the `tests/` directory:

```
tests/
├── Unit/                          # Unit tests
│   ├── AlwaysOnTop.Tests.ps1     # AlwaysOnTop module tests
│   ├── FileLocksmith.Tests.ps1   # FileLocksmith module tests
│   └── PreviewProviders.Tests.ps1 # PreviewProviders module tests
├── Integration/                   # Integration tests (future)
└── Invoke-Tests.ps1              # Main test runner script
```

### Test File Naming Convention

- Test files must end with `.Tests.ps1`
- Test files should be named after the module they test
- Example: `AlwaysOnTop.psm1` → `AlwaysOnTop.Tests.ps1`

---

## Running Tests

### Run All Tests

```powershell
.\tests\Invoke-Tests.ps1
```

### Run Only Unit Tests

```powershell
.\tests\Invoke-Tests.ps1 -Type Unit
```

### Run with Detailed Output

```powershell
.\tests\Invoke-Tests.ps1 -Output Detailed
```

### Run with Code Coverage

```powershell
.\tests\Invoke-Tests.ps1 -CodeCoverage
```

### Run Specific Test File

```powershell
Invoke-Pester -Path .\tests\Unit\AlwaysOnTop.Tests.ps1
```

### Common Test Runner Options

| Parameter | Values | Description |
|-----------|--------|-------------|
| `-Type` | All, Unit, Integration | Type of tests to run |
| `-Output` | None, Normal, Detailed, Diagnostic | Output verbosity level |
| `-CodeCoverage` | (switch) | Generate code coverage report |
| `-PassThru` | (switch) | Return Pester result object |

---

## Writing Tests

### Test File Template

```powershell
<#
.SYNOPSIS
    Pester tests for YourModule

.DESCRIPTION
    Unit tests for YourModule functionality
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot "..\..\src\Modules\Category\YourModule.psm1"
    Import-Module $ModulePath -Force
}

Describe "YourModule" {
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }

        It "Should export expected functions" {
            Get-Command Your-Function -Module YourModule | Should -Not -BeNullOrEmpty
        }
    }

    Context "Your-Function" {
        It "Should have required parameters" {
            $command = Get-Command Your-Function
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
        }

        It "Should not throw for valid input" {
            { Your-Function -Path "C:\test.txt" } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Module YourModule -Force -ErrorAction SilentlyContinue
}
```

### Common Pester Assertions

```powershell
# Existence checks
$result | Should -Not -BeNullOrEmpty
$result | Should -BeNullOrEmpty

# Type checking
$result | Should -BeOfType [string]
$result | Should -BeOfType [int]

# Value comparison
$result | Should -Be $expectedValue
$result | Should -BeGreaterThan 0
$result | Should -BeLessThan 100

# Collection checks
$result | Should -Contain 'expectedItem'
@('a', 'b', 'c') | Should -Contain 'b'

# Exception handling
{ Get-Item "C:\NonExistent.txt" } | Should -Throw
{ Get-Process } | Should -Not -Throw

# String matching
$result | Should -Match 'regex pattern'
$result | Should -BeLike '*pattern*'

# File existence
'C:\temp\test.txt' | Should -Exist
'C:\temp\nonexistent.txt' | Should -Not -Exist
```

### Test Organization

Organize tests using `Describe`, `Context`, and `It` blocks:

```powershell
Describe "Module or Feature Name" {
    Context "Specific Scenario or Function" {
        It "Should do something specific" {
            # Test code here
        }

        It "Should handle error case" {
            # Error handling test
        }
    }

    Context "Another Scenario" {
        It "Should behave correctly" {
            # Test code
        }
    }
}
```

### BeforeAll and AfterAll

Use lifecycle hooks for setup and teardown:

```powershell
BeforeAll {
    # Runs once before all tests in this block
    $script:TestFile = New-Item -Path "TestDrive:\test.txt" -Force
}

BeforeEach {
    # Runs before each test
}

AfterEach {
    # Runs after each test
}

AfterAll {
    # Runs once after all tests in this block
    Remove-Item $script:TestFile -Force -ErrorAction SilentlyContinue
}
```

### Using TestDrive

Pester provides `TestDrive:` for temporary file operations:

```powershell
It "Should create a file" {
    $testFile = "TestDrive:\example.txt"
    "content" | Out-File $testFile

    $testFile | Should -Exist
    Get-Content $testFile | Should -Be "content"
}
# TestDrive is automatically cleaned up after tests
```

---

## Continuous Integration

### GitHub Actions

The project includes a GitHub Actions workflow (`.github/workflows/test.yml`) that:

- Runs automatically on push to `main` or `develop` branches
- Runs on pull requests
- Executes unit tests with code coverage
- Uploads test results and coverage reports

### Workflow Triggers

- **Push Events**: Runs tests on `main` and `develop` branches
- **Pull Requests**: Runs tests on PRs targeting `main` or `develop`
- **Manual**: Can be triggered manually via GitHub Actions UI

### CI Test Commands

```yaml
# Install Pester
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck

# Run unit tests
.\tests\Invoke-Tests.ps1 -Type Unit -Output Detailed

# Run with coverage
.\tests\Invoke-Tests.ps1 -Type Unit -CodeCoverage
```

---

## Code Coverage

### Generating Coverage Reports

```powershell
.\tests\Invoke-Tests.ps1 -CodeCoverage
```

This generates:
- `coverage.xml` - JaCoCo format coverage report
- Console output showing coverage percentage

### Coverage Configuration

Coverage is configured in `PesterConfiguration.psd1`:

```powershell
CodeCoverage = @{
    Enabled = $true
    OutputFormat = 'JaCoCo'
    OutputPath = 'coverage.xml'
    Path = @(
        '.\src\Modules\PowerToys\*.psm1'
        '.\src\Modules\Preview\*.psm1'
        '.\src\Modules\Core\*.psm1'
    )
    CoveragePercentTarget = 75
}
```

### Viewing Coverage

- **Console**: Coverage percentage displayed after test run
- **CI Artifacts**: Download `coverage.xml` from GitHub Actions
- **Tools**: Use coverage visualization tools that support JaCoCo format

---

## Best Practices

### 1. Test One Thing Per `It` Block

```powershell
# Good
It "Should accept Path parameter" { }
It "Should return correct type" { }

# Bad
It "Should accept Path and return correct type" { }
```

### 2. Use Descriptive Test Names

```powershell
# Good
It "Should throw ArgumentException when path does not exist" { }

# Bad
It "Should fail" { }
```

### 3. Arrange-Act-Assert Pattern

```powershell
It "Should calculate correct total" {
    # Arrange
    $items = @(10, 20, 30)

    # Act
    $result = Get-Total $items

    # Assert
    $result | Should -Be 60
}
```

### 4. Mock External Dependencies

```powershell
BeforeAll {
    Mock Get-Process { return @{ Name = "test"; Id = 1234 } }
}

It "Should use mocked process" {
    $result = Get-Process
    $result.Name | Should -Be "test"
}
```

### 5. Test Error Conditions

```powershell
It "Should throw for invalid input" {
    { Your-Function -Path $null } | Should -Throw
}

It "Should write warning for missing file" {
    Your-Function -Path "C:\nonexistent.txt" 3>&1 |
        Should -BeLike "*not found*"
}
```

### 6. Use Parameter Validation Tests

```powershell
It "Should have mandatory Path parameter" {
    $command = Get-Command Your-Function
    $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
}

It "Should validate Path exists" {
    $command = Get-Command Your-Function
    $command.Parameters['Path'].Attributes.Where({
        $_.TypeId.Name -eq 'ValidateScriptAttribute'
    }) | Should -Not -BeNullOrEmpty
}
```

### 7. Clean Up After Tests

```powershell
AfterAll {
    # Remove test files
    Remove-Item "TestDrive:\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Remove modules
    Remove-Module YourModule -Force -ErrorAction SilentlyContinue
}
```

---

## Test Results

Test results are saved in:
- `testResults.xml` - NUnit format test results
- Console output with pass/fail statistics
- GitHub Actions artifacts (in CI)

### Test Result Formats

```
═══════════════════════════════════════
Test Results Summary
═══════════════════════════════════════
Total Tests:      92
Passed:           77
Failed:           15
Skipped:          0
Duration:         00:00:14.36
Code Coverage:    85%
═══════════════════════════════════════
```

---

## Troubleshooting

### Pester Not Found

```powershell
# Install Pester 5.x
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
```

### Module Import Errors

Ensure module paths are correct:
```powershell
$ModulePath = Join-Path $PSScriptRoot "..\..\src\Modules\Category\Module.psm1"
Test-Path $ModulePath  # Should be True
```

### Tests Not Running

Check that:
1. Test files end with `.Tests.ps1`
2. Test files are in `tests/Unit` or `tests/Integration`
3. Pester 5.x is imported: `Import-Module Pester -MinimumVersion 5.0`

### Type Not Found Errors

Some tests check for types defined in modules. These may fail if:
- The module hasn't fully loaded
- Add-Type hasn't executed yet
- The type is in a different scope

---

## Resources

- [Pester Documentation](https://pester.dev/)
- [Pester GitHub](https://github.com/pester/Pester)
- [PowerShell Testing Guide](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/using-vscode-for-debugging-compiled-cmdlets)

---

*Last Updated: October 19, 2025*
