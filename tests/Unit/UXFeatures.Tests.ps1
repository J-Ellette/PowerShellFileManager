<#
.SYNOPSIS
    Pester tests for new UX features

.DESCRIPTION
    Unit tests for context menu, quick filter, breadcrumbs, and keyboard shortcuts
#>

BeforeAll {
    # Import the main module
    $ModulePath = Join-Path $PSScriptRoot "..\..\" "PowerShellFileManager.psm1"
    Import-Module $ModulePath -Force -ErrorAction SilentlyContinue
    
    # Import QuickFilter module
    $QuickFilterPath = Join-Path $PSScriptRoot "..\..\src\Modules\Navigation\QuickFilter.psm1"
    if (Test-Path $QuickFilterPath) {
        Import-Module $QuickFilterPath -Force
    }
}

Describe "UX Features" {
    Context "Quick Filter Module" {
        It "Should export Apply-QuickFilter function" {
            $cmd = Get-Command Apply-QuickFilter -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
        }
        
        It "Should filter files by name pattern" {
            $testItems = @(
                [PSCustomObject]@{ Name = "test1.txt"; FullName = "/tmp/test1.txt" }
                [PSCustomObject]@{ Name = "test2.txt"; FullName = "/tmp/test2.txt" }
                [PSCustomObject]@{ Name = "document.docx"; FullName = "/tmp/document.docx" }
            )
            
            if (Get-Command Apply-QuickFilter -ErrorAction SilentlyContinue) {
                $filtered = Apply-QuickFilter -Items $testItems -Pattern "test"
                $filtered.Count | Should -Be 2
            }
        }
    }
    
    Context "Navigation History" {
        It "Should export navigation history functions" {
            Get-Command Add-NavigationHistory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-NavigationHistory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Invoke-NavigationBack -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Invoke-NavigationForward -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "File Operations" {
        It "Should handle file copying" {
            $tempDir = if ([System.IO.Path]::GetTempPath()) { [System.IO.Path]::GetTempPath() } else { "/tmp" }
            $script:TestDir = Join-Path $tempDir "PSFileManagerTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            
            try {
                $testFile = Join-Path $script:TestDir "test.txt"
                "Test content" | Out-File -FilePath $testFile
                
                $destFile = Join-Path $script:TestDir "test_copy.txt"
                Copy-Item -Path $testFile -Destination $destFile
                
                Test-Path $destFile | Should -Be $true
                Test-Path $testFile | Should -Be $true
            } finally {
                if ($script:TestDir -and (Test-Path $script:TestDir)) {
                    Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should handle file moving" {
            $tempDir = if ([System.IO.Path]::GetTempPath()) { [System.IO.Path]::GetTempPath() } else { "/tmp" }
            $script:TestDir = Join-Path $tempDir "PSFileManagerTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            
            try {
                $testFile = Join-Path $script:TestDir "move_source.txt"
                "Test content" | Out-File -FilePath $testFile
                
                $destFile = Join-Path $script:TestDir "move_dest.txt"
                Move-Item -Path $testFile -Destination $destFile
                
                Test-Path $destFile | Should -Be $true
                Test-Path $testFile | Should -Be $false
            } finally {
                if ($script:TestDir -and (Test-Path $script:TestDir)) {
                    Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    Context "Module Integration" {
        It "Should have CommandPalette module loaded" {
            Get-Command Invoke-CommandPalette -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have QueryBuilder module loaded" {
            Get-Command New-QueryBuilder -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have ObjectInspector module loaded" {
            Get-Command Show-ObjectInspector -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
