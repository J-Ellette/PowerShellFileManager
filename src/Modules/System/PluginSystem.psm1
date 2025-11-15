#Requires -Version 7.0

# Plugin System Module - Extensibility framework

$script:LoadedPlugins = @{}
$script:PluginDirectory = Join-Path $PSScriptRoot "../../Plugins"

function Get-PluginList {
    <#
    .SYNOPSIS
        Lists available plugins
    .EXAMPLE
        Get-PluginList
        Shows all plugins
    #>
    [CmdletBinding()]
    param()
    
    if (-not (Test-Path $script:PluginDirectory)) {
        New-Item -ItemType Directory -Path $script:PluginDirectory -Force | Out-Null
    }
    
    $plugins = Get-ChildItem -Path $script:PluginDirectory -Filter "*.psm1" -ErrorAction SilentlyContinue
    
    Write-Host "`nAvailable Plugins:" -ForegroundColor Cyan
    
    foreach ($plugin in $plugins) {
        $status = if ($script:LoadedPlugins.ContainsKey($plugin.BaseName)) { 
            "✓ Loaded" 
        } else { 
            "  Not Loaded" 
        }
        
        $color = if ($script:LoadedPlugins.ContainsKey($plugin.BaseName)) { 
            'Green' 
        } else { 
            'Gray' 
        }
        
        Write-Host "  [$status] $($plugin.BaseName)" -ForegroundColor $color
    }
    
    return $plugins
}

function Install-Plugin {
    <#
    .SYNOPSIS
        Installs and loads a plugin
    .PARAMETER Path
        Plugin file path
    .EXAMPLE
        Install-Plugin -Path C:\plugin.psm1
        Installs plugin
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Plugin not found: $Path"
        return
    }
    
    $pluginFile = Get-Item $Path
    $pluginName = $pluginFile.BaseName
    
    Write-Host "Installing plugin: $pluginName" -ForegroundColor Cyan
    
    try {
        # Copy to plugin directory
        $destPath = Join-Path $script:PluginDirectory $pluginFile.Name
        Copy-Item -Path $Path -Destination $destPath -Force
        
        # Load plugin
        Import-Module -Name $destPath -Force
        $script:LoadedPlugins[$pluginName] = $destPath
        
        Write-Host "Plugin installed and loaded successfully" -ForegroundColor Green
    } catch {
        Write-Error "Failed to install plugin: $_"
    }
}

function Uninstall-Plugin {
    <#
    .SYNOPSIS
        Uninstalls a plugin
    .PARAMETER Name
        Plugin name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    if ($script:LoadedPlugins.ContainsKey($Name)) {
        $path = $script:LoadedPlugins[$Name]
        Remove-Module -Name $Name -ErrorAction SilentlyContinue
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
        $script:LoadedPlugins.Remove($Name)
        Write-Host "Plugin uninstalled: $Name" -ForegroundColor Green
    } else {
        Write-Warning "Plugin not loaded: $Name"
    }
}

Export-ModuleMember -Function Get-PluginList, Install-Plugin, Uninstall-Plugin
