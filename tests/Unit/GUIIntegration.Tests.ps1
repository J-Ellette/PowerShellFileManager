# Test to verify GUI XAML syntax and menu items

Describe "Start-FileManager GUI Integration" {
    BeforeAll {
        # Import the module (skip GUI script loading in headless environment)
        $modulePath = Join-Path $PSScriptRoot ".." ".." "PowerShellFileManager.psd1"
        Import-Module $modulePath -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        
        # Don't try to load the GUI script in headless environment
        # We'll just verify the script content and function availability
        $script:scriptPath = Join-Path $PSScriptRoot ".." ".." "src" "Scripts" "Start-FileManager.ps1"
    }
    
    Context "Menu Items Exist" {
        It "Should have all Archive Operations menu items defined" {
            # We can't test GUI instantiation in headless environment
            # but we can verify the XAML contains the menu items
            $scriptContent = Get-Content $script:scriptPath -Raw
            
            $scriptContent | Should -Match 'Name="MenuCreateArchive"'
            $scriptContent | Should -Match 'Name="MenuExtractArchive"'
            $scriptContent | Should -Match 'Name="MenuViewArchive"'
        }
        
        It "Should have all Security menu items defined" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            
            $scriptContent | Should -Match 'Name="MenuViewACL"'
            $scriptContent | Should -Match 'Name="MenuEditACL"'
            $scriptContent | Should -Match 'Name="MenuSecureDelete"'
        }
        
        It "Should have PowerToys submenu defined" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            
            $scriptContent | Should -Match 'Name="MenuPowerToys"'
            $scriptContent | Should -Match 'Name="MenuImageResizer"'
        }
        
        It "Should have Metadata Editor menu item defined" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            
            $scriptContent | Should -Match 'Name="MenuMetadataEditor"'
        }
        
        It "Should have Advanced Search menu item defined" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            
            $scriptContent | Should -Match 'Name="MenuAdvancedSearch"'
        }
    }
    
    Context "Event Handlers Exist" {
        It "Should have handlers for all new menu items" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            
            # Archive handlers
            $scriptContent | Should -Match 'FindName\("MenuCreateArchive"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuExtractArchive"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuViewArchive"\)\.Add_Click'
            
            # Security handlers
            $scriptContent | Should -Match 'FindName\("MenuViewACL"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuEditACL"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuSecureDelete"\)\.Add_Click'
            
            # Other handlers
            $scriptContent | Should -Match 'FindName\("MenuMetadataEditor"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuAdvancedSearch"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuBatchOps"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuSyncDirs"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuConnect"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuPlugins"\)\.Add_Click'
            $scriptContent | Should -Match 'FindName\("MenuDocs"\)\.Add_Click'
        }
    }
    
    Context "Required Functions Available" {
        It "Should have Archive Operations functions available" {
            Get-Command -Name New-Archive -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name Expand-Archive -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name Get-ArchiveContent -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Security Operations functions available" {
            Get-Command -Name Get-FileACL -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name Set-FileACL -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name Remove-SecureFile -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have PowerToys functions available" {
            Get-Command -Name Resize-Image -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name Get-ColorFromScreen -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name Invoke-PowerRename -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Metadata Editor function available" {
            Get-Command -Name Edit-FileMetadata -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Search functions available" {
            Get-Command -Name Search-Files -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Batch Operations function available" {
            Get-Command -Name Start-BatchOperation -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Sync Directories function available" {
            Get-Command -Name Sync-Directories -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Network functions available" {
            Get-Command -Name Connect-FTP -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name Connect-SFTP -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Plugin functions available" {
            Get-Command -Name Get-PluginList -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
