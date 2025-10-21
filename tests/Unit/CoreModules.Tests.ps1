<#
.SYNOPSIS
    Pester tests for Core modules

.DESCRIPTION
    Unit tests for CommandPalette, QueryBuilder, and ObjectInspector
#>

BeforeAll {
    # Import core modules
    $CorePath = Join-Path $PSScriptRoot "..\..\src\Modules\Core"
    
    if (Test-Path (Join-Path $CorePath "CommandPalette.psm1")) {
        Import-Module (Join-Path $CorePath "CommandPalette.psm1") -Force
    }
    
    if (Test-Path (Join-Path $CorePath "QueryBuilder.psm1")) {
        Import-Module (Join-Path $CorePath "QueryBuilder.psm1") -Force
    }
    
    if (Test-Path (Join-Path $CorePath "ObjectInspector.psm1")) {
        Import-Module (Join-Path $CorePath "ObjectInspector.psm1") -Force
    }
}

Describe "CommandPalette Module" {
    Context "Module Loading" {
        It "Should export Invoke-CommandPalette function" {
            Get-Command Invoke-CommandPalette -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-CommandHistory function" {
            Get-Command Get-CommandHistory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Add-CommandToHistory function" {
            Get-Command Add-CommandToHistory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Command History" {
        It "Should be able to add commands to history" {
            if (Get-Command Add-CommandToHistory -ErrorAction SilentlyContinue) {
                { Add-CommandToHistory -Command "Get-ChildItem" } | Should -Not -Throw
            }
        }
        
        It "Should be able to retrieve command history" {
            if (Get-Command Get-CommandHistory -ErrorAction SilentlyContinue) {
                $history = Get-CommandHistory
                $history | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "QueryBuilder Module" {
    Context "Module Loading" {
        It "Should export New-QueryBuilder function" {
            Get-Command New-QueryBuilder -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Build-FileQuery function" {
            Get-Command Build-FileQuery -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Query Building" {
        It "Should build queries for file searches" {
            if (Get-Command Build-FileQuery -ErrorAction SilentlyContinue) {
                $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "QueryBuilderTest_$(Get-Random)"
                New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
                
                try {
                    # Create test files
                    "test1" | Out-File (Join-Path $script:TestDir "file1.txt")
                    "test2" | Out-File (Join-Path $script:TestDir "file2.log")
                    "test3" | Out-File (Join-Path $script:TestDir "file3.txt")
                    
                    $query = Build-FileQuery -Extension ".txt" -Path $script:TestDir
                    $query | Should -Not -BeNullOrEmpty
                } finally {
                    if (Test-Path $script:TestDir) {
                        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
}

Describe "ObjectInspector Module" {
    Context "Module Loading" {
        It "Should export Show-ObjectInspector function" {
            Get-Command Show-ObjectInspector -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-ObjectDetails function" {
            Get-Command Get-ObjectDetails -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Object Inspection" {
        It "Should be able to get object details" {
            if (Get-Command Get-ObjectDetails -ErrorAction SilentlyContinue) {
                $script:TestFile = Join-Path ([System.IO.Path]::GetTempPath()) "InspectorTest_$(Get-Random).txt"
                "Test content for inspection" | Out-File -FilePath $script:TestFile
                
                try {
                    $details = Get-ObjectDetails -Path $script:TestFile
                    $details | Should -Not -BeNullOrEmpty
                } finally {
                    if (Test-Path $script:TestFile) {
                        Remove-Item -Path $script:TestFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        
        It "Should include file properties in details" {
            if (Get-Command Get-ObjectDetails -ErrorAction SilentlyContinue) {
                $script:TestFile = Join-Path ([System.IO.Path]::GetTempPath()) "InspectorTest_$(Get-Random).txt"
                "Test content for inspection" | Out-File -FilePath $script:TestFile
                
                try {
                    $details = Get-ObjectDetails -Path $script:TestFile
                    $details.PSObject.Properties.Name | Should -Contain "Name"
                } finally {
                    if (Test-Path $script:TestFile) {
                        Remove-Item -Path $script:TestFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
}
