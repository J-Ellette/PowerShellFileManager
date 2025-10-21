<#
.SYNOPSIS
    Pester tests for AlwaysOnTop PowerToys module

.DESCRIPTION
    Unit tests for the Always On Top window pinning functionality
#>

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot "..\..\src\Modules\PowerToys\AlwaysOnTop.psm1"
    Import-Module $ModulePath -Force
}

Describe "AlwaysOnTop Module" {
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }

        It "Should export Set-WindowAlwaysOnTop function" {
            Get-Command Set-WindowAlwaysOnTop -Module AlwaysOnTop | Should -Not -BeNullOrEmpty
        }

        It "Should export Switch-WindowAlwaysOnTop function" {
            Get-Command Switch-WindowAlwaysOnTop -Module AlwaysOnTop | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-WindowTopMostStatus function" {
            Get-Command Get-WindowTopMostStatus -Module AlwaysOnTop | Should -Not -BeNullOrEmpty
        }

        It "Should export Show-WindowPinIndicator function" {
            Get-Command Show-WindowPinIndicator -Module AlwaysOnTop | Should -Not -BeNullOrEmpty
        }
    }

    Context "Set-WindowAlwaysOnTop" {
        It "Should have proper parameter sets" {
            $command = Get-Command Set-WindowAlwaysOnTop
            $command.ParameterSets.Name | Should -Contain 'Current'
            $command.ParameterSets.Name | Should -Contain 'Handle'
            $command.ParameterSets.Name | Should -Contain 'ProcessId'
            $command.ParameterSets.Name | Should -Contain 'Title'
        }

        It "Should accept Enable switch parameter" {
            $command = Get-Command Set-WindowAlwaysOnTop
            $command.Parameters['Enable'].SwitchParameter | Should -Be $true
        }

        It "Should accept WindowHandle parameter" {
            $command = Get-Command Set-WindowAlwaysOnTop
            $command.Parameters['WindowHandle'].ParameterType.Name | Should -Be 'IntPtr'
        }

        It "Should accept ProcessId parameter" {
            $command = Get-Command Set-WindowAlwaysOnTop
            $command.Parameters['ProcessId'].ParameterType.Name | Should -Be 'Int32'
        }

        It "Should accept WindowTitle parameter" {
            $command = Get-Command Set-WindowAlwaysOnTop
            $command.Parameters['WindowTitle'].ParameterType.Name | Should -Be 'String'
        }
    }

    Context "Switch-WindowAlwaysOnTop" {
        It "Should have proper parameter sets" {
            $command = Get-Command Switch-WindowAlwaysOnTop
            $command.ParameterSets.Name | Should -Contain 'Current'
            $command.ParameterSets.Name | Should -Contain 'Handle'
            $command.ParameterSets.Name | Should -Contain 'ProcessId'
            $command.ParameterSets.Name | Should -Contain 'Title'
        }
    }

    Context "Get-WindowTopMostStatus" {
        It "Should have proper parameter sets" {
            $command = Get-Command Get-WindowTopMostStatus
            $command.ParameterSets.Name | Should -Contain 'Current'
            $command.ParameterSets.Name | Should -Contain 'Handle'
            $command.ParameterSets.Name | Should -Contain 'ProcessId'
            $command.ParameterSets.Name | Should -Contain 'Title'
        }

        It "Should return object with required properties when targeting valid window" {
            # Get current PowerShell window
            $result = Get-WindowTopMostStatus

            if ($result) {
                $result | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties.Name | Should -Contain 'WindowHandle'
                $result.PSObject.Properties.Name | Should -Contain 'WindowTitle'
                $result.PSObject.Properties.Name | Should -Contain 'IsTopMost'
                $result.PSObject.Properties.Name | Should -Contain 'ProcessId'
                $result.PSObject.Properties.Name | Should -Contain 'Status'
            }
        }
    }

    Context "Show-WindowPinIndicator" {
        It "Should accept WindowTitle parameter" {
            $command = Get-Command Show-WindowPinIndicator
            $command.Parameters['WindowTitle'].ParameterType.Name | Should -Be 'String'
        }

        It "Should accept IsPinned parameter" {
            $command = Get-Command Show-WindowPinIndicator
            $command.Parameters['IsPinned'].ParameterType.Name | Should -Be 'Boolean'
        }

        It "Should have mandatory parameters" {
            $command = Get-Command Show-WindowPinIndicator
            $command.Parameters['WindowTitle'].Attributes.Mandatory | Should -Be $true
            $command.Parameters['IsPinned'].Attributes.Mandatory | Should -Be $true
        }

        It "Should not throw when displaying notification" {
            { Show-WindowPinIndicator -WindowTitle "Test Window" -IsPinned $true } | Should -Not -Throw
        }
    }

    Context "WindowHelper Class" {
        It "Should have WindowHelper type available" {
            [WindowHelper] | Should -Not -BeNullOrEmpty
        }

        It "Should have GetForegroundWindow method" {
            [WindowHelper].GetMethod('GetForegroundWindow') | Should -Not -BeNullOrEmpty
        }

        It "Should have IsWindowTopMost method" {
            [WindowHelper].GetMethod('IsWindowTopMost') | Should -Not -BeNullOrEmpty
        }

        It "Should have SetTopMost method" {
            [WindowHelper].GetMethod('SetTopMost') | Should -Not -BeNullOrEmpty
        }

        It "Should have GetWindowTitle method" {
            [WindowHelper].GetMethod('GetWindowTitle') | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling" {
        It "Should handle invalid process ID gracefully" {
            { Set-WindowAlwaysOnTop -ProcessId 999999 -Enable -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should handle non-existent window title gracefully" {
            { Set-WindowAlwaysOnTop -WindowTitle "ThisWindowDoesNotExist123456789" -Enable -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should handle zero window handle gracefully" {
            { Set-WindowAlwaysOnTop -WindowHandle ([IntPtr]::Zero) -Enable -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Clean up - remove module
    Remove-Module AlwaysOnTop -Force -ErrorAction SilentlyContinue
}
