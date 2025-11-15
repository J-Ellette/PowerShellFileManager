#Requires -Version 7.0

# External Tool Integration Module
# Allows registration and execution of external tools for file operations

# Module-level tool registry
$script:ExternalTools = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()

function Register-ExternalTool {
    <#
    .SYNOPSIS
        Registers an external tool for file operations
    .DESCRIPTION
        Adds an external tool to the registry for use with specific file types
    .PARAMETER Name
        Unique name for the tool
    .PARAMETER Command
        Command to execute (can include {file} placeholder)
    .PARAMETER FileTypes
        Array of file extensions this tool supports
    .PARAMETER Description
        Optional description of what the tool does
    .PARAMETER Icon
        Optional icon path for GUI integration
    .EXAMPLE
        Register-ExternalTool -Name "Notepad++" -Command "notepad++.exe {file}" -FileTypes @("*.txt", "*.ps1", "*.xml")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,
        
        [Parameter(Mandatory=$true)]
        [string[]]$FileTypes,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = "",
        
        [Parameter(Mandatory=$false)]
        [string]$Icon = ""
    )
    
    try {
        $tool = [PSCustomObject]@{
            Name = $Name
            Command = $Command
            FileTypes = $FileTypes
            Description = $Description
            Icon = $Icon
            RegisteredDate = Get-Date
            ExecutionCount = 0
        }
        
        if ($script:ExternalTools.TryAdd($Name, $tool)) {
            Write-Host "✓ Tool registered: $Name" -ForegroundColor Green
            Write-Host "  Command: $Command" -ForegroundColor Gray
            Write-Host "  File Types: $($FileTypes -join ', ')" -ForegroundColor Gray
            
            # Save registry to disk
            Save-ToolRegistry
            
            return [PSCustomObject]@{
                Success = $true
                Name = $Name
                Tool = $tool
            }
        }
        else {
            Write-Warning "Tool '$Name' is already registered. Use Update-ExternalTool to modify."
            return [PSCustomObject]@{
                Success = $false
                Error = "Tool already exists"
            }
        }
    }
    catch {
        Write-Error "Failed to register tool: $_"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Invoke-ExternalTool {
    <#
    .SYNOPSIS
        Executes a registered external tool
    .DESCRIPTION
        Runs an external tool on specified file(s)
    .PARAMETER Name
        Name of the registered tool
    .PARAMETER FilePath
        Path to file(s) to process
    .PARAMETER Arguments
        Additional arguments to pass to the tool
    .PARAMETER Wait
        Wait for the tool to complete before returning
    .EXAMPLE
        Invoke-ExternalTool -Name "Notepad++" -FilePath "C:\test.txt"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [string]$Arguments = "",
        
        [Parameter(Mandatory=$false)]
        [switch]$Wait
    )
    
    begin {
        if (-not $script:ExternalTools.ContainsKey($Name)) {
            Write-Error "Tool '$Name' is not registered. Use Register-ExternalTool first."
            return
        }
        
        $tool = $script:ExternalTools[$Name]
        $results = @()
    }
    
    process {
        foreach ($file in $FilePath) {
            try {
                if (-not (Test-Path $file)) {
                    Write-Warning "File not found: $file"
                    continue
                }
                
                # Replace {file} placeholder in command
                $command = $tool.Command -replace '\{file\}', "`"$file`""
                
                # Add additional arguments
                if ($Arguments) {
                    $command = "$command $Arguments"
                }
                
                Write-Verbose "Executing: $command"
                
                # Parse command into executable and arguments
                $commandParts = $command -split '\s+', 2
                $executable = $commandParts[0]
                $execArgs = if ($commandParts.Count -gt 1) { $commandParts[1] } else { "" }
                
                # Start the process
                $processParams = @{
                    FilePath = $executable
                    ArgumentList = $execArgs
                    PassThru = $true
                }
                
                if (-not $Wait) {
                    $processParams.NoNewWindow = $false
                }
                
                $process = Start-Process @processParams
                
                # Update execution count
                $tool.ExecutionCount++
                Save-ToolRegistry
                
                $result = [PSCustomObject]@{
                    Success = $true
                    Tool = $Name
                    FilePath = $file
                    ProcessId = $process.Id
                }
                
                if ($Wait) {
                    $process.WaitForExit()
                    $result | Add-Member -MemberType NoteProperty -Name ExitCode -Value $process.ExitCode
                }
                
                $results += $result
                Write-Host "✓ Launched $Name for: $file" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to execute tool for ${file}: $_"
                $results += [PSCustomObject]@{
                    Success = $false
                    Tool = $Name
                    FilePath = $file
                    Error = $_.Exception.Message
                }
            }
        }
    }
    
    end {
        return $results
    }
}

function Get-ExternalTool {
    <#
    .SYNOPSIS
        Retrieves registered external tools
    .DESCRIPTION
        Gets information about registered tools, optionally filtered by name or file type
    .PARAMETER Name
        Name of specific tool to retrieve
    .PARAMETER FileType
        Filter tools by supported file type
    .EXAMPLE
        Get-ExternalTool
        Get-ExternalTool -Name "Notepad++"
        Get-ExternalTool -FileType "*.ps1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [string]$FileType
    )
    
    if ($Name) {
        if ($script:ExternalTools.ContainsKey($Name)) {
            return $script:ExternalTools[$Name]
        }
        else {
            Write-Warning "Tool '$Name' not found"
            return $null
        }
    }
    elseif ($FileType) {
        return $script:ExternalTools.Values | Where-Object {
            $_.FileTypes -contains $FileType
        }
    }
    else {
        return $script:ExternalTools.Values | Sort-Object Name
    }
}

function Unregister-ExternalTool {
    <#
    .SYNOPSIS
        Removes a registered external tool
    .DESCRIPTION
        Removes a tool from the registry
    .PARAMETER Name
        Name of the tool to remove
    .EXAMPLE
        Unregister-ExternalTool -Name "Notepad++"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    if ($PSCmdlet.ShouldProcess($Name, "Unregister external tool")) {
        $removed = $null
        if ($script:ExternalTools.TryRemove($Name, [ref]$removed)) {
            Write-Host "✓ Tool unregistered: $Name" -ForegroundColor Green
            Save-ToolRegistry
            
            return [PSCustomObject]@{
                Success = $true
                Name = $Name
            }
        }
        else {
            Write-Warning "Tool '$Name' not found"
            return [PSCustomObject]@{
                Success = $false
                Error = "Tool not found"
            }
        }
    }
}

function Update-ExternalTool {
    <#
    .SYNOPSIS
        Updates a registered external tool
    .DESCRIPTION
        Modifies an existing tool registration
    .PARAMETER Name
        Name of the tool to update
    .PARAMETER Command
        New command (optional)
    .PARAMETER FileTypes
        New file types (optional)
    .PARAMETER Description
        New description (optional)
    .EXAMPLE
        Update-ExternalTool -Name "Notepad++" -Command "notepad++.exe -multiInst {file}"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [string[]]$FileTypes,
        
        [Parameter(Mandatory=$false)]
        [string]$Description
    )
    
    if (-not $script:ExternalTools.ContainsKey($Name)) {
        Write-Error "Tool '$Name' not found"
        return [PSCustomObject]@{
            Success = $false
            Error = "Tool not found"
        }
    }
    
    if ($PSCmdlet.ShouldProcess($Name, "Update external tool")) {
        $tool = $script:ExternalTools[$Name]
        
        if ($Command) { $tool.Command = $Command }
        if ($FileTypes) { $tool.FileTypes = $FileTypes }
        if ($Description) { $tool.Description = $Description }
        
        Save-ToolRegistry
        
        Write-Host "✓ Tool updated: $Name" -ForegroundColor Green
        
        return [PSCustomObject]@{
            Success = $true
            Name = $Name
            Tool = $tool
        }
    }
}

function Save-ToolRegistry {
    try {
        $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Join-Path $env:APPDATA "PowerShellFileManager\Tools"
        } else {
            Join-Path $HOME ".config/PowerShellFileManager/Tools"
        }
        
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        $registryPath = Join-Path $configDir "ExternalTools.json"
        $script:ExternalTools.Values | ConvertTo-Json -Depth 10 | Set-Content -Path $registryPath -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to save tool registry: $_"
    }
}

function Import-ToolRegistry {
    try {
        $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Join-Path $env:APPDATA "PowerShellFileManager\Tools"
        } else {
            Join-Path $HOME ".config/PowerShellFileManager/Tools"
        }
        
        $registryPath = Join-Path $configDir "ExternalTools.json"
        
        if (Test-Path $registryPath) {
            $tools = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
            
            foreach ($tool in $tools) {
                $script:ExternalTools[$tool.Name] = $tool
            }
            
            Write-Verbose "Imported $($tools.Count) external tools"
        }
    }
    catch {
        Write-Warning "Failed to import tool registry: $_"
    }
}

# Auto-import tools on module import
Import-ToolRegistry

Export-ModuleMember -Function Register-ExternalTool, Invoke-ExternalTool, Get-ExternalTool, Unregister-ExternalTool, Update-ExternalTool
