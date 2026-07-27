#Requires -Version 7.0

# Configuration Management Module
# Provides robust configuration system for File Manager

# Helper function to get config path
function Get-ConfigBasePath {
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        return Join-Path $env:APPDATA "PowerShellFileManager\config.json"
    } else {
        return Join-Path $HOME ".config/PowerShellFileManager/config.json"
    }
}

class FileManagerConfig {
    [string] $Theme
    [hashtable] $KeyBindings
    [hashtable] $PreviewSettings
    [int] $MaxCacheSize
    [string] $ConfigPath
    [hashtable] $PluginSettings
    [hashtable] $UISettings
    
    FileManagerConfig() {
        $this.Theme = "Dark"
        $this.MaxCacheSize = 104857600  # 100MB
        $this.ConfigPath = ""  # Will be set after construction
        $this.KeyBindings = @{}
        $this.PreviewSettings = @{}
        $this.PluginSettings = @{}
        $this.UISettings = @{
            WindowWidth = 1200
            WindowHeight = 800
            SplitPaneEnabled = $false
            TabbedInterface = $false
            ShowBreadcrumbs = $true
            ShowStatusBar = $true
        }
    }
    
    [void] Save() {
        try {
            $configDir = Split-Path $this.ConfigPath -Parent
            if (-not (Test-Path $configDir)) {
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            }
            
            $configData = @{
                Theme = $this.Theme
                KeyBindings = $this.KeyBindings
                PreviewSettings = $this.PreviewSettings
                MaxCacheSize = $this.MaxCacheSize
                PluginSettings = $this.PluginSettings
                UISettings = $this.UISettings
            }
            
            $json = $configData | ConvertTo-Json -Depth 10
            $json | Set-Content -Path $this.ConfigPath -Encoding UTF8
            Write-Verbose "Configuration saved to $($this.ConfigPath)"
        }
        catch {
            Write-Error "Failed to save configuration: $_"
        }
    }
    
    [void] Load() {
        try {
            if (Test-Path $this.ConfigPath) {
                $json = Get-Content -Path $this.ConfigPath -Raw -Encoding UTF8
                $configData = $json | ConvertFrom-Json
                
                # Apply loaded configuration with fallbacks
                if ($configData.Theme) { $this.Theme = $configData.Theme }
                if ($configData.MaxCacheSize) { $this.MaxCacheSize = $configData.MaxCacheSize }
                
                # Convert PSCustomObject to hashtable for KeyBindings
                if ($configData.KeyBindings) {
                    $this.KeyBindings = @{}
                    $configData.KeyBindings.PSObject.Properties | ForEach-Object {
                        $this.KeyBindings[$_.Name] = $_.Value
                    }
                }
                
                # Convert PSCustomObject to hashtable for PreviewSettings
                if ($configData.PreviewSettings) {
                    $this.PreviewSettings = @{}
                    $configData.PreviewSettings.PSObject.Properties | ForEach-Object {
                        $this.PreviewSettings[$_.Name] = $_.Value
                    }
                }
                
                # Convert PSCustomObject to hashtable for PluginSettings
                if ($configData.PluginSettings) {
                    $this.PluginSettings = @{}
                    $configData.PluginSettings.PSObject.Properties | ForEach-Object {
                        $this.PluginSettings[$_.Name] = $_.Value
                    }
                }
                
                # Convert PSCustomObject to hashtable for UISettings
                if ($configData.UISettings) {
                    $this.UISettings = @{}
                    $configData.UISettings.PSObject.Properties | ForEach-Object {
                        $this.UISettings[$_.Name] = $_.Value
                    }
                }
                
                Write-Verbose "Configuration loaded from $($this.ConfigPath)"
            }
            else {
                Write-Verbose "No configuration file found, using defaults"
                $this.Save()
            }
        }
        catch {
            Write-Warning "Failed to load configuration, using defaults: $_"
        }
    }
    
    [void] Reset() {
        $this.Theme = "Dark"
        $this.KeyBindings = @{}
        $this.PreviewSettings = @{}
        $this.MaxCacheSize = 100MB
        $this.PluginSettings = @{}
        $this.UISettings = @{
            WindowWidth = 1200
            WindowHeight = 800
            SplitPaneEnabled = $false
            TabbedInterface = $false
            ShowBreadcrumbs = $true
            ShowStatusBar = $true
        }
        $this.Save()
    }
}

# Module-level configuration instance
$script:GlobalConfig = [FileManagerConfig]::new()
$script:GlobalConfig.ConfigPath = Get-ConfigBasePath
$script:GlobalConfig.Load()

function Get-FileManagerConfig {
    <#
    .SYNOPSIS
        Gets the current File Manager configuration
    .DESCRIPTION
        Returns the global configuration object for the File Manager
    .EXAMPLE
        $config = Get-FileManagerConfig
        $config.Theme
    #>
    [CmdletBinding()]
    param()
    
    return $script:GlobalConfig
}

function Set-FileManagerConfig {
    <#
    .SYNOPSIS
        Updates File Manager configuration
    .DESCRIPTION
        Updates one or more configuration settings and saves them
    .PARAMETER Theme
        Theme to use (Dark, Light, etc.)
    .PARAMETER MaxCacheSize
        Maximum cache size in bytes
    .PARAMETER KeyBindings
        Custom key bindings hashtable
    .PARAMETER Save
        Whether to save configuration immediately
    .EXAMPLE
        Set-FileManagerConfig -Theme "Light" -Save
    #>
    [CmdletBinding()]
    param(
        [string]$Theme,
        [int]$MaxCacheSize,
        [hashtable]$KeyBindings,
        [hashtable]$PreviewSettings,
        [hashtable]$UISettings,
        [switch]$Save
    )
    
    if ($Theme) { $script:GlobalConfig.Theme = $Theme }
    if ($MaxCacheSize) { $script:GlobalConfig.MaxCacheSize = $MaxCacheSize }
    if ($KeyBindings) { $script:GlobalConfig.KeyBindings = $KeyBindings }
    if ($PreviewSettings) { $script:GlobalConfig.PreviewSettings = $PreviewSettings }
    if ($UISettings) { $script:GlobalConfig.UISettings = $UISettings }
    
    if ($Save) {
        $script:GlobalConfig.Save()
    }
}

function Reset-FileManagerConfig {
    <#
    .SYNOPSIS
        Resets File Manager configuration to defaults
    .DESCRIPTION
        Resets all configuration settings to their default values
    .EXAMPLE
        Reset-FileManagerConfig
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    if ($PSCmdlet.ShouldProcess("File Manager Configuration", "Reset to defaults")) {
        $script:GlobalConfig.Reset()
        Write-Host "Configuration reset to defaults" -ForegroundColor Green
    }
}

Export-ModuleMember -Function Get-FileManagerConfig, Set-FileManagerConfig, Reset-FileManagerConfig
