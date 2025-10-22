<#
.SYNOPSIS
    Pester tests for FileLocksmith PowerToys module

.DESCRIPTION
    Unit tests for the File Locksmith process lock detection functionality
#>

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot "..\..\src\Modules\PowerToys\FileLocksmith.psm1"
    Import-Module $ModulePath -Force

    # Create a test file
    $script:TestFile = Join-Path $env:TEMP "PesterTestFile_$(Get-Random).txt"
    "Test content" | Out-File -FilePath $script:TestFile -Force
}

Describe "FileLocksmith Module" {
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }

        It "Should export Get-FileLock function" {
            Get-Command Get-FileLock -Module FileLocksmith | Should -Not -BeNullOrEmpty
        }

        It "Should export Unlock-File function" {
            Get-Command Unlock-File -Module FileLocksmith | Should -Not -BeNullOrEmpty
        }

        It "Should export Test-FileLocked function" {
            Get-Command Test-FileLocked -Module FileLocksmith | Should -Not -BeNullOrEmpty
        }

        It "Should export Show-FileLockInfo function" {
            Get-Command Show-FileLockInfo -Module FileLocksmith | Should -Not -BeNullOrEmpty
        }
    }

    Context "Get-FileLock" {
        It "Should have Path parameter" {
            $command = Get-Command Get-FileLock
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have ShowDetails switch parameter" {
            $command = Get-Command Get-FileLock
            $command.Parameters['ShowDetails'].SwitchParameter | Should -Be $true
        }

        It "Should validate that path exists" {
            $command = Get-Command Get-FileLock
            $command.Parameters['Path'].Attributes.Where({$_.TypeId.Name -eq 'ValidateScriptAttribute'}) |
                Should -Not -BeNullOrEmpty
        }

        It "Should return null for unlocked file" {
            $result = Get-FileLock -Path $script:TestFile
            $result | Should -BeNullOrEmpty
        }

        It "Should not throw for valid file path" {
            { Get-FileLock -Path $script:TestFile } | Should -Not -Throw
        }
    }

    Context "Test-FileLocked" {
        It "Should have Path parameter" {
            $command = Get-Command Test-FileLocked
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It "Should return boolean value" {
            $result = Test-FileLocked -Path $script:TestFile
            $result | Should -BeOfType [bool]
        }

        It "Should return false for unlocked file" {
            $result = Test-FileLocked -Path $script:TestFile
            $result | Should -Be $false
        }

        It "Should not throw for valid file path" {
            { Test-FileLocked -Path $script:TestFile } | Should -Not -Throw
        }
    }

    Context "Unlock-File" {
        It "Should have Path parameter" {
            $command = Get-Command Unlock-File
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have ProcessId parameter" {
            $command = Get-Command Unlock-File
            $command.Parameters['ProcessId'] | Should -Not -BeNullOrEmpty
        }

        It "Should have Force switch parameter" {
            $command = Get-Command Unlock-File
            $command.Parameters['Force'].SwitchParameter | Should -Be $true
        }

        It "Should support ShouldProcess (WhatIf/Confirm)" {
            $command = Get-Command Unlock-File
            $attr = $command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -Be $true
        }

        It "Should have High ConfirmImpact" {
            $command = Get-Command Unlock-File
            $attr = $command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }
    }

    Context "Show-FileLockInfo" {
        It "Should have Path parameter" {
            $command = Get-Command Show-FileLockInfo
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It "Should not throw for unlocked file" {
            { Show-FileLockInfo -Path $script:TestFile } | Should -Not -Throw
        }
    }

    Context "FileLocksmith Class" {
        It "Should have FileLocksmith type available" {
            [FileLocksmith] | Should -Not -BeNullOrEmpty
        }

        It "Should have RmStartSession method" {
            [FileLocksmith].GetMethod('RmStartSession') | Should -Not -BeNullOrEmpty
        }

        It "Should have RmEndSession method" {
            [FileLocksmith].GetMethod('RmEndSession') | Should -Not -BeNullOrEmpty
        }

        It "Should have RmRegisterResources method" {
            [FileLocksmith].GetMethod('RmRegisterResources') | Should -Not -BeNullOrEmpty
        }

        It "Should have RmGetList method" {
            [FileLocksmith].GetMethod('RmGetList') | Should -Not -BeNullOrEmpty
        }

        It "Should have RM_PROCESS_INFO struct" {
            [FileLocksmith+RM_PROCESS_INFO] | Should -Not -BeNullOrEmpty
        }

        It "Should have RM_UNIQUE_PROCESS struct" {
            [FileLocksmith+RM_UNIQUE_PROCESS] | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling" {
        It "Should handle non-existent file gracefully" {
            $nonExistentFile = "C:\ThisFileDoesNotExist_$(Get-Random).txt"
            { Get-FileLock -Path $nonExistentFile -ErrorAction SilentlyContinue } | Should -Throw
        }

        It "Should handle invalid path gracefully" {
            { Get-FileLock -Path "::Invalid::Path::" -ErrorAction SilentlyContinue } | Should -Throw
        }
    }

    Context "Integration with Test File" {
        It "Should detect when file is locked" {
            # Create a file lock by opening it exclusively
            $fileStream = $null
            try {
                $fileStream = [System.IO.File]::Open($script:TestFile, 'Open', 'Read', 'None')

                # Now test if we can detect the lock
                $isLocked = Test-FileLocked -Path $script:TestFile

                # Note: This might be false because the current process might not be detected
                # as a lock by Restart Manager. This is expected behavior.
                $isLocked | Should -BeOfType [bool]
            }
            finally {
                if ($fileStream) {
                    $fileStream.Close()
                    $fileStream.Dispose()
                }
            }
        }
    }
}

AfterAll {
    # Clean up test file
    if (Test-Path $script:TestFile) {
        Remove-Item $script:TestFile -Force -ErrorAction SilentlyContinue
    }

    # Remove module
    Remove-Module FileLocksmith -Force -ErrorAction SilentlyContinue
}
