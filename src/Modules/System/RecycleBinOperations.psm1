#Requires -Version 7.0

# Recycle Bin Operations Module
# Provides safe deletion with recycle bin integration

function Remove-ItemToRecycleBin {
    <#
    .SYNOPSIS
        Moves item to Recycle Bin instead of permanent deletion
    .DESCRIPTION
        Uses Microsoft.VisualBasic.FileIO for safe deletion with recycle bin on Windows
        Falls back to permanent deletion with confirmation on other platforms
    .PARAMETER Path
        Path to item to delete
    .PARAMETER Force
        Suppress confirmation prompts
    .EXAMPLE
        Remove-ItemToRecycleBin -Path "C:\temp\file.txt"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [switch]$Force
    )
    
    process {
        try {
            if (-not (Test-Path $Path)) {
                Write-Error "Path not found: $Path"
                return
            }
            
            $item = Get-Item -Path $Path
            $itemType = if ($item.PSIsContainer) { "Directory" } else { "File" }
            
            if ($PSCmdlet.ShouldProcess($Path, "Move to Recycle Bin")) {
                if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
                    # Windows: Use Visual Basic FileIO for Recycle Bin
                    try {
                        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
                        
                        if ($item.PSIsContainer) {
                            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                                $Path,
                                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
                            )
                        }
                        else {
                            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                                $Path,
                                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
                            )
                        }
                        
                        Write-Host "✓ Moved to Recycle Bin: $Path" -ForegroundColor Green
                        
                        return [PSCustomObject]@{
                            Success = $true
                            Path = $Path
                            Type = $itemType
                            Method = "RecycleBin"
                        }
                    }
                    catch {
                        Write-Warning "Failed to use Recycle Bin, attempting permanent deletion: $_"
                        
                        # Fallback to permanent deletion with explicit confirmation
                        if ($Force -or $PSCmdlet.ShouldContinue($Path, "Permanently delete (Recycle Bin failed)?")) {
                            Remove-Item -Path $Path -Recurse -Force
                            Write-Host "⚠ Permanently deleted: $Path" -ForegroundColor Yellow
                            
                            return [PSCustomObject]@{
                                Success = $true
                                Path = $Path
                                Type = $itemType
                                Method = "Permanent"
                            }
                        }
                        else {
                            Write-Host "✗ Deletion cancelled" -ForegroundColor Red
                            return [PSCustomObject]@{
                                Success = $false
                                Path = $Path
                                Cancelled = $true
                            }
                        }
                    }
                }
                else {
                    # Non-Windows: No recycle bin, use permanent deletion with warning
                    Write-Warning "Recycle Bin not available on this platform. File will be permanently deleted."
                    
                    if ($Force -or $PSCmdlet.ShouldContinue($Path, "Permanently delete?")) {
                        Remove-Item -Path $Path -Recurse -Force
                        Write-Host "⚠ Permanently deleted: $Path" -ForegroundColor Yellow
                        
                        return [PSCustomObject]@{
                            Success = $true
                            Path = $Path
                            Type = $itemType
                            Method = "Permanent"
                        }
                    }
                    else {
                        Write-Host "✗ Deletion cancelled" -ForegroundColor Red
                        return [PSCustomObject]@{
                            Success = $false
                            Path = $Path
                            Cancelled = $true
                        }
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to delete item: $_"
            return [PSCustomObject]@{
                Success = $false
                Path = $Path
                Error = $_.Exception.Message
            }
        }
    }
}

function Get-RecycleBinItems {
    <#
    .SYNOPSIS
        Lists items in the Recycle Bin
    .DESCRIPTION
        Retrieves items currently in the Recycle Bin (Windows only)
    .EXAMPLE
        Get-RecycleBinItems
    #>
    [CmdletBinding()]
    param()
    
    if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6)) {
        Write-Warning "Recycle Bin is only available on Windows"
        return @()
    }
    
    try {
        # Use shell COM object to access Recycle Bin
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.NameSpace(10) # 10 = Recycle Bin
        
        if ($recycleBin) {
            $items = $recycleBin.Items()
            $results = @()
            
            foreach ($item in $items) {
                $results += [PSCustomObject]@{
                    Name = $item.Name
                    Path = $item.Path
                    Size = $item.Size
                    DateDeleted = $item.ModifyDate
                    Type = $item.Type
                }
            }
            
            return $results
        }
        else {
            Write-Warning "Could not access Recycle Bin"
            return @()
        }
    }
    catch {
        Write-Error "Failed to retrieve Recycle Bin items: $_"
        return @()
    }
}

function Restore-RecycleBinItem {
    <#
    .SYNOPSIS
        Restores an item from the Recycle Bin
    .DESCRIPTION
        Restores a deleted item from the Recycle Bin to its original location
    .PARAMETER Name
        Name of the item to restore
    .EXAMPLE
        Restore-RecycleBinItem -Name "document.txt"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6)) {
        Write-Error "Recycle Bin is only available on Windows"
        return
    }
    
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.NameSpace(10)
        
        if ($recycleBin) {
            $items = $recycleBin.Items()
            $found = $false
            
            foreach ($item in $items) {
                if ($item.Name -eq $Name) {
                    if ($PSCmdlet.ShouldProcess($Name, "Restore from Recycle Bin")) {
                        # Invoke the restore verb
                        $item.InvokeVerb("restore")
                        Write-Host "✓ Restored: $Name" -ForegroundColor Green
                        $found = $true
                        
                        return [PSCustomObject]@{
                            Success = $true
                            Name = $Name
                            Restored = $true
                        }
                    }
                    break
                }
            }
            
            if (-not $found) {
                Write-Warning "Item not found in Recycle Bin: $Name"
                return [PSCustomObject]@{
                    Success = $false
                    Name = $Name
                    NotFound = $true
                }
            }
        }
    }
    catch {
        Write-Error "Failed to restore item: $_"
        return [PSCustomObject]@{
            Success = $false
            Name = $Name
            Error = $_.Exception.Message
        }
    }
}

function Clear-RecycleBin {
    <#
    .SYNOPSIS
        Empties the Recycle Bin
    .DESCRIPTION
        Permanently deletes all items in the Recycle Bin
    .EXAMPLE
        Clear-RecycleBin -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param()
    
    if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6)) {
        Write-Error "Recycle Bin is only available on Windows"
        return
    }
    
    if ($PSCmdlet.ShouldProcess("Recycle Bin", "Empty all items permanently")) {
        try {
            # Use Clear-RecycleBin cmdlet if available (Windows 10+)
            if (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue) {
                Clear-RecycleBin -Force -ErrorAction Stop
                Write-Host "✓ Recycle Bin emptied successfully" -ForegroundColor Green
            }
            else {
                # Fallback: Use shell COM object
                $shell = New-Object -ComObject Shell.Application
                $recycleBin = $shell.NameSpace(10)
                
                if ($recycleBin) {
                    $items = $recycleBin.Items()
                    foreach ($item in $items) {
                        $item.InvokeVerb("delete")
                    }
                    Write-Host "✓ Recycle Bin emptied successfully" -ForegroundColor Green
                }
            }
            
            return [PSCustomObject]@{
                Success = $true
                Emptied = $true
            }
        }
        catch {
            Write-Error "Failed to empty Recycle Bin: $_"
            return [PSCustomObject]@{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
}

Export-ModuleMember -Function Remove-ItemToRecycleBin, Get-RecycleBinItems, Restore-RecycleBinItem, Clear-RecycleBin
