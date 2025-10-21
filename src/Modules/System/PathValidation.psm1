#Requires -Version 7.0

# Path Validation and Normalization Module
# Provides validation, normalization, and safety checks for file paths

function Resolve-NormalizedPath {
    <#
    .SYNOPSIS
        Normalizes and validates file paths
    .DESCRIPTION
        Resolves full path, handles UNC and trailing separators, and validates against disallowed locations
    .PARAMETER Path
        Path to normalize and validate
    .PARAMETER AllowUNC
        Whether to allow UNC paths
    .PARAMETER DisallowedPaths
        Array of paths that should be rejected (e.g., system directories)
    .EXAMPLE
        Resolve-NormalizedPath -Path ".\file.txt"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [switch]$AllowUNC,
        
        [Parameter(Mandatory=$false)]
        [string[]]$DisallowedPaths = @()
    )
    
    try {
        # Expand any environment variables
        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($Path)
        
        # Resolve to absolute path if relative
        if (-not [System.IO.Path]::IsPathRooted($expandedPath)) {
            $expandedPath = Join-Path (Get-Location) $expandedPath
        }
        
        # Normalize path separators
        $normalizedPath = [System.IO.Path]::GetFullPath($expandedPath)
        
        # Check if it's a UNC path
        if ($normalizedPath.StartsWith("\\") -or $normalizedPath.StartsWith("//")) {
            if (-not $AllowUNC) {
                Write-Error "UNC paths are not allowed: $normalizedPath"
                return $null
            }
        }
        
        # Check against disallowed paths
        foreach ($disallowed in $DisallowedPaths) {
            $disallowedNormalized = [System.IO.Path]::GetFullPath($disallowed)
            if ($normalizedPath.StartsWith($disallowedNormalized, [StringComparison]::OrdinalIgnoreCase)) {
                Write-Error "Access to path is not allowed: $normalizedPath"
                return $null
            }
        }
        
        # Check for path traversal attempts
        if ($normalizedPath -match '\.\.[/\\]' -or $normalizedPath -match '[/\\]\.\.[/\\]') {
            Write-Warning "Potential path traversal detected in: $normalizedPath"
        }
        
        return $normalizedPath
    }
    catch {
        Write-Error "Failed to normalize path '$Path': $_"
        return $null
    }
}

function Test-PathTraversal {
    <#
    .SYNOPSIS
        Tests if a path contains traversal attempts
    .DESCRIPTION
        Detects potential path traversal attacks
    .PARAMETER Path
        Path to test
    .EXAMPLE
        Test-PathTraversal -Path "C:\test\..\..\..\windows"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    # Check for various traversal patterns
    $patterns = @(
        '\.\.[/\\]',           # ../
        '[/\\]\.\.[/\\]',      # /../
        '\.\.\\',              # ..\
        '/\.\./',              # /../
        '\.\./'                # ../
    )
    
    foreach ($pattern in $patterns) {
        if ($Path -match $pattern) {
            return $true
        }
    }
    
    return $false
}

function Test-SafePath {
    <#
    .SYNOPSIS
        Validates that a path is safe to operate on
    .DESCRIPTION
        Performs comprehensive safety checks on a path before file operations
    .PARAMETER Path
        Path to validate
    .PARAMETER RequireExists
        Whether the path must already exist
    .EXAMPLE
        Test-SafePath -Path "C:\temp\file.txt" -RequireExists
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [switch]$RequireExists
    )
    
    # Normalize the path
    $normalizedPath = Resolve-NormalizedPath -Path $Path
    if (-not $normalizedPath) {
        return $false
    }
    
    # Check if path traversal detected
    if (Test-PathTraversal -Path $Path) {
        Write-Warning "Path traversal detected: $Path"
        return $false
    }
    
    # Check existence if required
    if ($RequireExists -and -not (Test-Path $normalizedPath)) {
        Write-Error "Path does not exist: $normalizedPath"
        return $false
    }
    
    # Check for invalid characters
    $invalidChars = [System.IO.Path]::GetInvalidPathChars()
    foreach ($char in $invalidChars) {
        if ($Path.Contains($char)) {
            Write-Error "Path contains invalid character: $char"
            return $false
        }
    }
    
    return $true
}

function Convert-PathFormat {
    <#
    .SYNOPSIS
        Converts path format between different operating systems
    .DESCRIPTION
        Handles conversion between Windows, Linux, and macOS path formats
    .PARAMETER Path
        Path to convert
    .PARAMETER TargetOS
        Target operating system (Windows, Linux, macOS)
    .EXAMPLE
        Convert-PathFormat -Path "C:\Users\John" -TargetOS Linux
        Returns: /mnt/c/Users/John
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Windows', 'Linux', 'macOS')]
        [string]$TargetOS
    )
    
    try {
        switch ($TargetOS) {
            'Windows' {
                # Convert to Windows format
                $convertedPath = $Path -replace '/', '\'
                
                # Handle WSL paths (e.g., /mnt/c/ -> C:\)
                if ($convertedPath -match '^\\mnt\\([a-z])\\') {
                    $drive = $Matches[1].ToUpper()
                    $convertedPath = $convertedPath -replace '^\\mnt\\[a-z]\\', "${drive}:\"
                }
            }
            
            'Linux' {
                # Convert to Linux format
                $convertedPath = $Path -replace '\\', '/'
                
                # Handle Windows drives (e.g., C:\ -> /mnt/c/)
                if ($convertedPath -match '^([A-Z]):') {
                    $drive = $Matches[1].ToLower()
                    $convertedPath = $convertedPath -replace '^[A-Z]:', "/mnt/$drive"
                }
                
                # Ensure leading slash
                if (-not $convertedPath.StartsWith('/')) {
                    $convertedPath = "/$convertedPath"
                }
            }
            
            'macOS' {
                # Similar to Linux for most cases
                $convertedPath = $Path -replace '\\', '/'
                
                # Ensure leading slash
                if (-not $convertedPath.StartsWith('/')) {
                    $convertedPath = "/$convertedPath"
                }
            }
        }
        
        return $convertedPath
    }
    catch {
        Write-Error "Failed to convert path format: $_"
        return $Path
    }
}

function Test-ReparsePoint {
    <#
    .SYNOPSIS
        Tests if a path is a reparse point (symlink, junction, etc.)
    .DESCRIPTION
        Detects symlinks, junctions, and other reparse points to avoid recursion traps
    .PARAMETER Path
        Path to test
    .EXAMPLE
        Test-ReparsePoint -Path "C:\Link"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    try {
        if (-not (Test-Path $Path)) {
            return $false
        }
        
        $item = Get-Item -Path $Path -Force
        
        # Check if item has reparse point attribute
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            return $true
        }
        
        # Additional check for symlinks
        if ($item.LinkType -eq 'SymbolicLink' -or $item.LinkType -eq 'Junction') {
            return $true
        }
        
        return $false
    }
    catch {
        Write-Error "Failed to check reparse point: $_"
        return $false
    }
}

function Get-ReparsePointTarget {
    <#
    .SYNOPSIS
        Gets the target of a reparse point
    .DESCRIPTION
        Returns the target path for symlinks and junctions
    .PARAMETER Path
        Path to reparse point
    .EXAMPLE
        Get-ReparsePointTarget -Path "C:\Link"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    try {
        if (-not (Test-ReparsePoint -Path $Path)) {
            Write-Warning "Path is not a reparse point: $Path"
            return $null
        }
        
        $item = Get-Item -Path $Path -Force
        
        if ($item.Target) {
            return $item.Target
        }
        elseif ($item.LinkTarget) {
            return $item.LinkTarget
        }
        else {
            Write-Warning "Could not determine reparse point target"
            return $null
        }
    }
    catch {
        Write-Error "Failed to get reparse point target: $_"
        return $null
    }
}

Export-ModuleMember -Function Resolve-NormalizedPath, Test-PathTraversal, Test-SafePath, Convert-PathFormat, Test-ReparsePoint, Get-ReparsePointTarget
