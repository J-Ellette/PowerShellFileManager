#Requires -Version 7.0

<#
.SYNOPSIS
    Hosts File Editor - Manage system hosts file
    PowerToys Integration

.DESCRIPTION
    Provides functionality to view, edit, and manage the system hosts file.
    Includes backup/restore, validation, and common hosts operations.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
    Requires: Administrator privileges for modifications
#>

function Get-HostsFilePath {
    <#
    .SYNOPSIS
        Get the path to the system hosts file
    #>
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        "$env:SystemRoot\System32\drivers\etc\hosts"
    } else {
        "/etc/hosts"
    }
}

function Get-HostsEntry {
    <#
    .SYNOPSIS
        Get entries from the hosts file
    
    .DESCRIPTION
        Reads and parses the system hosts file, returning structured objects
    
    .PARAMETER Name
        Filter by hostname
    
    .PARAMETER IPAddress
        Filter by IP address
    
    .EXAMPLE
        Get-HostsEntry
        Get all hosts file entries
    
    .EXAMPLE
        Get-HostsEntry -Name "example.com"
        Get entry for specific hostname
    #>
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$IPAddress
    )
    
    $hostsPath = Get-HostsFilePath
    
    if (-not (Test-Path $hostsPath)) {
        Write-Error "Hosts file not found: $hostsPath"
        return
    }
    
    $entries = Get-Content $hostsPath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ($line -and -not $line.StartsWith('#')) {
            $parts = $line -split '\s+', 2
            if ($parts.Count -eq 2) {
                [PSCustomObject]@{
                    IPAddress = $parts[0]
                    Hostname = $parts[1]
                    Enabled = $true
                }
            }
        } elseif ($line.StartsWith('#') -and $line -match '^\s*#\s*(\S+)\s+(\S+)') {
            # Disabled entry
            [PSCustomObject]@{
                IPAddress = $matches[1]
                Hostname = $matches[2]
                Enabled = $false
            }
        }
    }
    
    if ($Name) {
        $entries = $entries | Where-Object { $_.Hostname -like "*$Name*" }
    }
    
    if ($IPAddress) {
        $entries = $entries | Where-Object { $_.IPAddress -eq $IPAddress }
    }
    
    return $entries
}

function Add-HostsEntry {
    <#
    .SYNOPSIS
        Add a new entry to the hosts file
    
    .DESCRIPTION
        Adds a new hostname-to-IP mapping in the system hosts file
    
    .PARAMETER IPAddress
        IP address to map
    
    .PARAMETER Hostname
        Hostname to map
    
    .PARAMETER Force
        Overwrite existing entry
    
    .EXAMPLE
        Add-HostsEntry -IPAddress "127.0.0.1" -Hostname "test.local"
        Add a new hosts entry
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory=$true)]
        [string]$Hostname,
        
        [switch]$Force
    )
    
    $hostsPath = Get-HostsFilePath
    
    # Check if entry already exists
    $existing = Get-HostsEntry -Name $Hostname
    if ($existing -and -not $Force) {
        Write-Error "Entry for '$Hostname' already exists. Use -Force to overwrite."
        return
    }
    
    if ($PSCmdlet.ShouldProcess("$IPAddress -> $Hostname", "Add hosts entry")) {
        try {
            $entry = "$IPAddress`t$Hostname"
            Add-Content -Path $hostsPath -Value $entry -ErrorAction Stop
            Write-Verbose "Added hosts entry: $entry"
            
            [PSCustomObject]@{
                IPAddress = $IPAddress
                Hostname = $Hostname
                Status = 'Added'
            }
        } catch {
            Write-Error "Failed to add hosts entry: $_"
        }
    }
}

function Remove-HostsEntry {
    <#
    .SYNOPSIS
        Remove an entry from the hosts file
    
    .DESCRIPTION
        Removes a hostname mapping from the system hosts file
    
    .PARAMETER Hostname
        Hostname to remove
    
    .EXAMPLE
        Remove-HostsEntry -Hostname "test.local"
        Remove a hosts entry
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Hostname
    )
    
    $hostsPath = Get-HostsFilePath
    
    if ($PSCmdlet.ShouldProcess($Hostname, "Remove hosts entry")) {
        try {
            $content = Get-Content $hostsPath
            $newContent = $content | Where-Object {
                $_ -notmatch "\s+$([regex]::Escape($Hostname))\s*$"
            }
            
            Set-Content -Path $hostsPath -Value $newContent -ErrorAction Stop
            Write-Verbose "Removed hosts entry for: $Hostname"
            
            [PSCustomObject]@{
                Hostname = $Hostname
                Status = 'Removed'
            }
        } catch {
            Write-Error "Failed to remove hosts entry: $_"
        }
    }
}

function Backup-HostsFile {
    <#
    .SYNOPSIS
        Create a backup of the hosts file
    
    .DESCRIPTION
        Creates a timestamped backup copy of the system hosts file
    
    .PARAMETER BackupPath
        Directory to store backup (default: user's documents)
    
    .EXAMPLE
        Backup-HostsFile
        Create a backup of the hosts file
    #>
    [CmdletBinding()]
    param(
        [string]$BackupPath
    )
    
    $hostsPath = Get-HostsFilePath
    
    if (-not $BackupPath) {
        $BackupPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Join-Path $env:USERPROFILE "Documents\HostsBackups"
        } else {
            Join-Path $HOME "HostsBackups"
        }
    }
    
    if (-not (Test-Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $BackupPath "hosts_$timestamp.backup"
    
    try {
        Copy-Item -Path $hostsPath -Destination $backupFile -ErrorAction Stop
        Write-Host "Hosts file backed up to: $backupFile" -ForegroundColor Green
        
        [PSCustomObject]@{
            OriginalPath = $hostsPath
            BackupPath = $backupFile
            Timestamp = $timestamp
            Status = 'Success'
        }
    } catch {
        Write-Error "Failed to backup hosts file: $_"
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-HostsEntry'
    'Add-HostsEntry'
    'Remove-HostsEntry'
    'Backup-HostsFile'
)
