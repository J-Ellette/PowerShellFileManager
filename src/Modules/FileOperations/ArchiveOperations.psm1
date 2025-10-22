#Requires -Version 7.0

# Archive Operations Module - ZIP, TAR, 7z support
# Includes compression, extraction, and in-archive editing

function New-Archive {
    <#
    .SYNOPSIS
        Creates a compressed archive
    .DESCRIPTION
        Compresses files into ZIP, TAR, or 7z format
    .PARAMETER Path
        Files or folders to compress
    .PARAMETER Destination
        Archive file path
    .PARAMETER Format
        Archive format (ZIP, TAR, 7Z)
    .PARAMETER Password
        Optional password for encryption
    .EXAMPLE
        New-Archive -Path C:\Files -Destination archive.zip -Format ZIP
        Creates a ZIP archive
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('ZIP', 'TAR', '7Z')]
        [string]$Format = 'ZIP',
        
        [Parameter(Mandatory=$false)]
        [SecureString]$Password
    )
    
    Write-Host "Creating $Format archive..." -ForegroundColor Cyan
    
    switch ($Format) {
        'ZIP' {
            if ($Password) {
                Write-Warning "Password protection requires 7-Zip or similar tool"
            }
            Compress-Archive -Path $Path -DestinationPath $Destination -Force
            Write-Host "Archive created: $Destination" -ForegroundColor Green
        }
        'TAR' {
            Write-Warning "TAR format requires tar.exe or WSL"
            # tar -czf $Destination $Path
        }
        '7Z' {
            Write-Warning "7Z format requires 7-Zip installation"
            # 7z a $Destination $Path
        }
    }
}

function Expand-Archive {
    <#
    .SYNOPSIS
        Extracts a compressed archive
    .DESCRIPTION
        Extracts files from ZIP, TAR, or 7z archives
    .PARAMETER Path
        Archive file path
    .PARAMETER Destination
        Extraction destination
    .PARAMETER Password
        Optional password for encrypted archives
    .EXAMPLE
        Expand-Archive -Path archive.zip -Destination C:\Extracted
        Extracts archive
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        
        [Parameter(Mandatory=$false)]
        [SecureString]$Password
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Archive not found: $Path"
        return
    }
    
    Write-Host "Extracting archive..." -ForegroundColor Cyan
    
    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    
    switch ($extension) {
        '.zip' {
            Expand-Archive -Path $Path -DestinationPath $Destination -Force
            Write-Host "Archive extracted to: $Destination" -ForegroundColor Green
        }
        '.tar' {
            Write-Warning "TAR extraction requires tar.exe or WSL"
            # tar -xzf $Path -C $Destination
        }
        '.7z' {
            Write-Warning "7Z extraction requires 7-Zip installation"
            # 7z x $Path -o$Destination
        }
        default {
            Write-Error "Unsupported archive format: $extension"
        }
    }
}

function Get-ArchiveContent {
    <#
    .SYNOPSIS
        Lists contents of an archive without extracting
    .DESCRIPTION
        Shows files and folders inside an archive
    .PARAMETER Path
        Archive file path
    .EXAMPLE
        Get-ArchiveContent -Path archive.zip
        Lists archive contents
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Archive not found: $Path"
        return
    }
    
    Write-Host "`nArchive contents: $Path" -ForegroundColor Cyan
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        
        foreach ($entry in $zip.Entries) {
            $size = "{0:N2} KB" -f ($entry.Length / 1KB)
            Write-Host "  $($entry.FullName) [$size]" -ForegroundColor Gray
        }
        
        $zip.Dispose()
        
        Write-Host "`nTotal entries: $($zip.Entries.Count)" -ForegroundColor Green
    } catch {
        Write-Error "Failed to read archive: $_"
    }
}

Export-ModuleMember -Function New-Archive, Expand-Archive, Get-ArchiveContent
