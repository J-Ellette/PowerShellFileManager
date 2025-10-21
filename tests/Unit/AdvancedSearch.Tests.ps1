<#
.SYNOPSIS
    Pester tests for Advanced Search with fuzzy matching

.DESCRIPTION
    Unit tests for the AdvancedSearch module including fuzzy search capabilities
#>

BeforeAll {
    # Import the AdvancedSearch module
    $SearchModulePath = Join-Path $PSScriptRoot "..\..\src\Modules\Search\AdvancedSearch.psm1"
    if (Test-Path $SearchModulePath) {
        Import-Module $SearchModulePath -Force
    }
}

Describe "AdvancedSearch Module" {
    Context "Module Loading" {
        It "Should export Search-Files function" {
            Get-Command Search-Files -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Search-Content function" {
            Get-Command Search-Content -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-FuzzyMatch function" {
            Get-Command Get-FuzzyMatch -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Fuzzy Search" {
        It "Should find exact matches" {
            if (Get-Command Search-Files -ErrorAction SilentlyContinue) {
                $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FuzzySearchTest_$(Get-Random)"
                New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
                
                try {
                    # Create test files with various names
                    "content1" | Out-File (Join-Path $script:TestDir "document.txt")
                    "content2" | Out-File (Join-Path $script:TestDir "document_backup.txt")
                    "content3" | Out-File (Join-Path $script:TestDir "documant.txt")  # Typo
                    "content4" | Out-File (Join-Path $script:TestDir "report.log")
                    
                    $results = Search-Files -Path $script:TestDir -Pattern "document.txt"
                    $results | Should -Not -BeNullOrEmpty
                } finally {
                    if (Test-Path $script:TestDir) {
                        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        
        It "Should support wildcard patterns" {
            if (Get-Command Search-Files -ErrorAction SilentlyContinue) {
                $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FuzzySearchTest_$(Get-Random)"
                New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
                
                try {
                    "content1" | Out-File (Join-Path $script:TestDir "document.txt")
                    "content2" | Out-File (Join-Path $script:TestDir "report.txt")
                    
                    $results = Search-Files -Path $script:TestDir -Pattern "*.txt"
                    $results.Count | Should -BeGreaterThan 0
                } finally {
                    if (Test-Path $script:TestDir) {
                        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        
        It "Should support regex patterns" {
            if (Get-Command Search-Files -ErrorAction SilentlyContinue) {
                $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FuzzySearchTest_$(Get-Random)"
                New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
                
                try {
                    "content1" | Out-File (Join-Path $script:TestDir "document.txt")
                    
                    $results = Search-Files -Path $script:TestDir -Pattern "^doc.*\.txt$" -UseRegex
                    $results | Should -Not -BeNullOrEmpty
                } finally {
                    if (Test-Path $script:TestDir) {
                        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        
        It "Should perform fuzzy matching with typos" {
            if (Get-Command Get-FuzzyMatch -ErrorAction SilentlyContinue) {
                $score = Get-FuzzyMatch -String1 "document" -String2 "documant"
                $score | Should -BeGreaterThan 0
            }
        }
    }
    
    Context "Content Search" {
        It "Should search file contents" {
            if (Get-Command Search-Content -ErrorAction SilentlyContinue) {
                $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "ContentSearchTest_$(Get-Random)"
                New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
                
                try {
                    # Create test files with specific content
                    "This file contains the search term PowerShell" | Out-File (Join-Path $script:TestDir "file1.txt")
                    "This file does not contain it" | Out-File (Join-Path $script:TestDir "file2.txt")
                    "PowerShell is awesome for automation" | Out-File (Join-Path $script:TestDir "file3.txt")
                    
                    $results = Search-Content -Path $script:TestDir -SearchText "PowerShell"
                    $results.Count | Should -BeGreaterThan 0
                } finally {
                    if (Test-Path $script:TestDir) {
                        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        
        It "Should find multiple matches across files" {
            if (Get-Command Search-Content -ErrorAction SilentlyContinue) {
                $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "ContentSearchTest_$(Get-Random)"
                New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
                
                try {
                    "This file contains the search term PowerShell" | Out-File (Join-Path $script:TestDir "file1.txt")
                    "PowerShell is awesome for automation" | Out-File (Join-Path $script:TestDir "file3.txt")
                    
                    $results = Search-Content -Path $script:TestDir -SearchText "PowerShell"
                    $results.Count | Should -BeGreaterOrEqual 2
                } finally {
                    if (Test-Path $script:TestDir) {
                        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
    
    Context "Search Performance" {
        It "Should complete searches in reasonable time" {
            if (Get-Command Search-Files -ErrorAction SilentlyContinue) {
                $measure = Measure-Command {
                    Search-Files -Path ([System.IO.Path]::GetTempPath()) -Pattern "*.txt" -ErrorAction SilentlyContinue | Out-Null
                }
                
                $measure.TotalSeconds | Should -BeLessThan 30
            }
        }
    }
}
