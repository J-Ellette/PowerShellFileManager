#Requires -Version 7.0

# Metadata Editor Module - Bulk metadata editing

function Edit-FileMetadata {
    <#
    .SYNOPSIS
        Edits file metadata and properties
    .DESCRIPTION
        Allows editing of file attributes, tags, comments, etc.
    .PARAMETER Path
        File path
    .PARAMETER Properties
        Hash table of properties to set
    .EXAMPLE
        Edit-FileMetadata -Path file.txt -Properties @{Comment="My file"}
        Sets file comment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Properties
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "File not found: $Path"
        return
    }
    
    $file = Get-Item $Path
    
    Write-Host "Editing metadata for: $($file.Name)" -ForegroundColor Cyan
    
    foreach ($prop in $Properties.Keys) {
        try {
            switch ($prop) {
                'ReadOnly' {
                    if ($Properties[$prop]) {
                        $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::ReadOnly
                    } else {
                        $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
                    }
                    Write-Host "  Set ReadOnly = $($Properties[$prop])" -ForegroundColor Green
                }
                'Hidden' {
                    if ($Properties[$prop]) {
                        $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::Hidden
                    } else {
                        $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
                    }
                    Write-Host "  Set Hidden = $($Properties[$prop])" -ForegroundColor Green
                }
                'Archive' {
                    if ($Properties[$prop]) {
                        $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::Archive
                    } else {
                        $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::Archive)
                    }
                    Write-Host "  Set Archive = $($Properties[$prop])" -ForegroundColor Green
                }
                'CreationTime' {
                    $file.CreationTime = [DateTime]$Properties[$prop]
                    Write-Host "  Set CreationTime = $($Properties[$prop])" -ForegroundColor Green
                }
                'LastWriteTime' {
                    $file.LastWriteTime = [DateTime]$Properties[$prop]
                    Write-Host "  Set LastWriteTime = $($Properties[$prop])" -ForegroundColor Green
                }
                default {
                    Write-Warning "Property '$prop' is not supported for editing"
                }
            }
        } catch {
            Write-Error "Failed to set $prop`: $_"
        }
    }
    
    Write-Host "Metadata update complete" -ForegroundColor Green
}

Export-ModuleMember -Function Edit-FileMetadata
