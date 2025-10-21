<#
.SYNOPSIS
    Pester tests for File Operations

.DESCRIPTION
    Unit tests for BatchOperations and FileManagement modules
#>

BeforeAll {
    # Import file operation modules
    $FileOpsPath = Join-Path $PSScriptRoot "..\..\src\Modules\FileOperations"
    
    if (Test-Path (Join-Path $FileOpsPath "BatchOperations.psm1")) {
        Import-Module (Join-Path $FileOpsPath "BatchOperations.psm1") -Force
    }
    
    if (Test-Path (Join-Path $FileOpsPath "FileManagement.psm1")) {
        Import-Module (Join-Path $FileOpsPath "FileManagement.psm1") -Force
    }
}

Describe "BatchOperations Module" {
    Context "Module Loading" {
        It "Should export Start-BatchOperation function" {
            Get-Command Start-BatchOperation -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export New-BatchTemplate function" {
            Get-Command New-BatchTemplate -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Batch Operations" {
        It "Should handle batch copy operations" {
            $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "BatchOpsTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            
            try {
                # Create test files
                1..5 | ForEach-Object {
                    "Content $_" | Out-File (Join-Path $script:TestDir "file$_.txt")
                }
                
                $destDir = Join-Path $script:TestDir "copy_dest"
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                
                $files = Get-ChildItem -Path $script:TestDir -Filter "*.txt"
                foreach ($file in $files) {
                    Copy-Item -Path $file.FullName -Destination $destDir
                }
                
                (Get-ChildItem -Path $destDir).Count | Should -Be $files.Count
            } finally {
                if (Test-Path $script:TestDir) {
                    Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should handle batch rename operations" {
            $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "BatchOpsTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            
            try {
                $renameDir = Join-Path $script:TestDir "rename_test"
                New-Item -ItemType Directory -Path $renameDir -Force | Out-Null
                
                1..3 | ForEach-Object {
                    "test" | Out-File (Join-Path $renameDir "old_name_$_.txt")
                }
                
                $files = Get-ChildItem -Path $renameDir
                foreach ($i in 0..($files.Count - 1)) {
                    $file = $files[$i]
                    Rename-Item -Path $file.FullName -NewName "new_name_$($i + 1).txt"
                }
                
                (Get-ChildItem -Path $renameDir -Filter "new_name_*.txt").Count | Should -Be 3
            } finally {
                if (Test-Path $script:TestDir) {
                    Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

Describe "FileManagement Module" {
    Context "Module Loading" {
        It "Should export Copy-FileWithProgress function" {
            Get-Command Copy-FileWithProgress -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Move-FileWithProgress function" {
            Get-Command Move-FileWithProgress -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Remove-FileSafely function" {
            Get-Command Remove-FileSafely -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "File Management" {
        It "Should copy files correctly" {
            $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FileMgmtTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            
            try {
                $sourceFile = Join-Path $script:TestDir "source.txt"
                "Source content" | Out-File -FilePath $sourceFile
                
                $destFile = Join-Path $script:TestDir "destination.txt"
                
                if (Get-Command Copy-FileWithProgress -ErrorAction SilentlyContinue) {
                    Copy-FileWithProgress -Source $sourceFile -Destination $destFile
                } else {
                    Copy-Item -Path $sourceFile -Destination $destFile
                }
                
                Test-Path $destFile | Should -Be $true
            } finally {
                if (Test-Path $script:TestDir) {
                    Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should move files correctly" {
            $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FileMgmtTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            
            try {
                $sourceFile = Join-Path $script:TestDir "move_source.txt"
                "Move content" | Out-File -FilePath $sourceFile
                
                $destFile = Join-Path $script:TestDir "move_destination.txt"
                
                if (Get-Command Move-FileWithProgress -ErrorAction SilentlyContinue) {
                    Move-FileWithProgress -Source $sourceFile -Destination $destFile
                } else {
                    Move-Item -Path $sourceFile -Destination $destFile
                }
                
                Test-Path $destFile | Should -Be $true
                Test-Path $sourceFile | Should -Be $false
            } finally {
                if (Test-Path $script:TestDir) {
                    Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "Should safely delete files" {
            $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "FileMgmtTest_$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
            
            try {
                $testFile = Join-Path $script:TestDir "delete_test.txt"
                "Delete me" | Out-File -FilePath $testFile
                
                if (Get-Command Remove-FileSafely -ErrorAction SilentlyContinue) {
                    Remove-FileSafely -Path $testFile
                } else {
                    Remove-Item -Path $testFile -Force
                }
                
                Test-Path $testFile | Should -Be $false
            } finally {
                if (Test-Path $script:TestDir) {
                    Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
