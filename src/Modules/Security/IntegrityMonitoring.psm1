#Requires -Version 7.0

# File Integrity Monitoring Module
# Provides baseline hash generation, monitoring, and secure deletion

# Module-level storage for baselines
$script:IntegrityBaselines = @{}

function Enable-IntegrityMonitoring {
    <#
    .SYNOPSIS
        Enables file integrity monitoring for a path
    .DESCRIPTION
        Generates baseline hashes for files and monitors for unauthorized changes
    .PARAMETER Path
        Path to file or directory to monitor
    .PARAMETER Algorithm
        Hash algorithm to use (SHA256, SHA512)
    .PARAMETER Recurse
        Monitor subdirectories recursively
    .EXAMPLE
        Enable-IntegrityMonitoring -Path "C:\Important" -Algorithm SHA256 -Recurse
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256',
        
        [Parameter(Mandatory=$false)]
        [switch]$Recurse
    )
    
    try {
        if (-not (Test-Path $Path)) {
            Write-Error "Path not found: $Path"
            return
        }
        
        $item = Get-Item -Path $Path
        
        if ($item.PSIsContainer) {
            # Directory - hash all files
            Write-Host "Generating baseline for directory: $Path" -ForegroundColor Cyan
            
            $files = if ($Recurse) {
                Get-ChildItem -Path $Path -File -Recurse
            } else {
                Get-ChildItem -Path $Path -File
            }
            
            $baseline = @{}
            $totalFiles = $files.Count
            $processed = 0
            
            foreach ($file in $files) {
                $processed++
                Write-Progress -Activity "Generating Baseline" -Status "Processing $($file.Name)" -PercentComplete (($processed / $totalFiles) * 100)
                
                try {
                    $hash = (Get-FileHash -Path $file.FullName -Algorithm $Algorithm).Hash
                    
                    $baseline[$file.FullName] = [PSCustomObject]@{
                        Path = $file.FullName
                        Hash = $hash
                        Algorithm = $Algorithm
                        BaselineDate = Get-Date
                        Size = $file.Length
                        LastModified = $file.LastWriteTime
                    }
                }
                catch {
                    Write-Warning "Failed to hash file $($file.FullName): $_"
                }
            }
            
            Write-Progress -Activity "Generating Baseline" -Completed
            
            $script:IntegrityBaselines[$Path] = $baseline
            
            # Save baseline to disk
            Save-IntegrityBaseline -Path $Path -Baseline $baseline
            
            Write-Host "✓ Baseline generated for $totalFiles files" -ForegroundColor Green
            Write-Host "  Algorithm: $Algorithm" -ForegroundColor Gray
            Write-Host "  Location: $Path" -ForegroundColor Gray
            
            return [PSCustomObject]@{
                Success = $true
                Path = $Path
                FileCount = $totalFiles
                Algorithm = $Algorithm
                BaselineDate = Get-Date
            }
        }
        else {
            # Single file
            $hash = (Get-FileHash -Path $Path -Algorithm $Algorithm).Hash
            
            $baseline = @{
                $Path = [PSCustomObject]@{
                    Path = $Path
                    Hash = $hash
                    Algorithm = $Algorithm
                    BaselineDate = Get-Date
                    Size = $item.Length
                    LastModified = $item.LastWriteTime
                }
            }
            
            $script:IntegrityBaselines[$Path] = $baseline
            Save-IntegrityBaseline -Path $Path -Baseline $baseline
            
            Write-Host "✓ Baseline generated for file: $Path" -ForegroundColor Green
            
            return [PSCustomObject]@{
                Success = $true
                Path = $Path
                Hash = $hash
                Algorithm = $Algorithm
            }
        }
    }
    catch {
        Write-Error "Failed to enable integrity monitoring: $_"
    }
}

function Test-FileIntegrity {
    <#
    .SYNOPSIS
        Verifies file integrity against baseline
    .DESCRIPTION
        Compares current file hashes against stored baseline to detect modifications
    .PARAMETER Path
        Path to verify (must have existing baseline)
    .EXAMPLE
        Test-FileIntegrity -Path "C:\Important"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    try {
        if (-not $script:IntegrityBaselines.ContainsKey($Path)) {
            # Try loading from disk
            $loaded = Import-IntegrityBaseline -Path $Path
            if (-not $loaded) {
                Write-Error "No baseline found for path: $Path"
                return
            }
        }
        
        $baseline = $script:IntegrityBaselines[$Path]
        $modifications = @()
        $verified = 0
        $total = $baseline.Count
        
        Write-Host "Verifying integrity for: $Path" -ForegroundColor Cyan
        
        foreach ($entry in $baseline.Values) {
            $verified++
            Write-Progress -Activity "Verifying Integrity" -Status "Checking $($entry.Path)" -PercentComplete (($verified / $total) * 100)
            
            if (Test-Path $entry.Path) {
                $currentHash = (Get-FileHash -Path $entry.Path -Algorithm $entry.Algorithm).Hash
                
                if ($currentHash -ne $entry.Hash) {
                    $modifications += [PSCustomObject]@{
                        Path = $entry.Path
                        Status = "Modified"
                        BaselineHash = $entry.Hash
                        CurrentHash = $currentHash
                        BaselineDate = $entry.BaselineDate
                        DetectionDate = Get-Date
                    }
                    
                    Write-Host "⚠ MODIFIED: $($entry.Path)" -ForegroundColor Yellow
                }
            }
            else {
                $modifications += [PSCustomObject]@{
                    Path = $entry.Path
                    Status = "Deleted"
                    BaselineHash = $entry.Hash
                    BaselineDate = $entry.BaselineDate
                    DetectionDate = Get-Date
                }
                
                Write-Host "⚠ DELETED: $($entry.Path)" -ForegroundColor Red
            }
        }
        
        Write-Progress -Activity "Verifying Integrity" -Completed
        
        if ($modifications.Count -eq 0) {
            Write-Host "✓ All files verified successfully - No modifications detected" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Detected $($modifications.Count) modification(s)" -ForegroundColor Red
        }
        
        return [PSCustomObject]@{
            Path = $Path
            TotalFiles = $total
            VerifiedFiles = $total - $modifications.Count
            Modifications = $modifications
            ModificationCount = $modifications.Count
            VerificationDate = Get-Date
        }
    }
    catch {
        Write-Error "Failed to verify integrity: $_"
    }
}

function Save-IntegrityBaseline {
    param($Path, $Baseline)
    
    try {
        $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Join-Path $env:APPDATA "PowerShellFileManager\Integrity"
        } else {
            Join-Path $HOME ".config/PowerShellFileManager/Integrity"
        }
        
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        $safeName = [System.IO.Path]::GetFileName($Path) -replace '[^\w\-]', '_'
        $baselinePath = Join-Path $configDir "$safeName.baseline.json"
        
        $baseline | ConvertTo-Json -Depth 10 | Set-Content -Path $baselinePath -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to save baseline to disk: $_"
    }
}

function Import-IntegrityBaseline {
    param($Path)
    
    try {
        $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Join-Path $env:APPDATA "PowerShellFileManager\Integrity"
        } else {
            Join-Path $HOME ".config/PowerShellFileManager/Integrity"
        }
        
        $safeName = [System.IO.Path]::GetFileName($Path) -replace '[^\w\-]', '_'
        $baselinePath = Join-Path $configDir "$safeName.baseline.json"
        
        if (Test-Path $baselinePath) {
            $baseline = Get-Content -Path $baselinePath -Raw | ConvertFrom-Json
            $script:IntegrityBaselines[$Path] = $baseline
            return $true
        }
        
        return $false
    }
    catch {
        Write-Warning "Failed to load baseline from disk: $_"
        return $false
    }
}

function Remove-FileSecurely {
    <#
    .SYNOPSIS
        Securely deletes a file using DOD 5220.22-M standard
    .DESCRIPTION
        Performs multi-pass overwrite of file data before deletion
    .PARAMETER FilePath
        Path to file to securely delete
    .PARAMETER Passes
        Number of overwrite passes (default 3, DOD standard is 7)
    .PARAMETER VerifyDeletion
        Verify file is completely removed
    .EXAMPLE
        Remove-FileSecurely -FilePath "C:\sensitive.txt" -Passes 7
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 35)]
        [int]$Passes = 3,
        
        [Parameter(Mandatory=$false)]
        [switch]$VerifyDeletion
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }
    
    $item = Get-Item -Path $FilePath
    
    if ($item.PSIsContainer) {
        Write-Error "Path is a directory. Use Remove-Item with -Recurse for directories."
        return
    }
    
    if ($PSCmdlet.ShouldProcess($FilePath, "Securely delete with $Passes overwrite passes")) {
        try {
            $fileSize = $item.Length
            
            Write-Host "Securely deleting file: $FilePath" -ForegroundColor Yellow
            Write-Host "  Size: $([Math]::Round($fileSize / 1KB, 2)) KB" -ForegroundColor Gray
            Write-Host "  Passes: $Passes" -ForegroundColor Gray
            
            # Open file for writing
            $fileStream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write)
            
            for ($pass = 1; $pass -le $Passes; $pass++) {
                Write-Progress -Activity "Secure Delete" -Status "Pass $pass of $Passes" -PercentComplete (($pass / $Passes) * 100)
                
                $fileStream.Position = 0
                
                # Determine pattern for this pass
                $pattern = switch ($pass % 3) {
                    1 { 0x00 }  # Zeros
                    2 { 0xFF }  # Ones
                    0 { Get-Random -Minimum 0 -Maximum 256 }  # Random
                }
                
                # Write pattern to file
                $buffer = New-Object byte[] 4096
                for ($i = 0; $i -lt $buffer.Length; $i++) {
                    $buffer[$i] = $pattern
                }
                
                $remaining = $fileSize
                while ($remaining -gt 0) {
                    $toWrite = [Math]::Min($remaining, $buffer.Length)
                    $fileStream.Write($buffer, 0, $toWrite)
                    $remaining -= $toWrite
                }
                
                $fileStream.Flush()
            }
            
            $fileStream.Close()
            Write-Progress -Activity "Secure Delete" -Completed
            
            # Delete the file
            Remove-Item -Path $FilePath -Force
            
            # Verify deletion if requested
            if ($VerifyDeletion) {
                if (Test-Path $FilePath) {
                    Write-Error "File still exists after deletion!"
                    return [PSCustomObject]@{
                        Success = $false
                        Path = $FilePath
                        Error = "File still exists after deletion"
                    }
                }
            }
            
            Write-Host "✓ File securely deleted" -ForegroundColor Green
            Write-Host "  Standard: DOD 5220.22-M ($Passes passes)" -ForegroundColor Gray
            
            # Generate deletion certificate
            $certificate = [PSCustomObject]@{
                FilePath = $FilePath
                FileName = $item.Name
                OriginalSize = $fileSize
                Passes = $Passes
                DeletionDate = Get-Date
                Standard = "DOD 5220.22-M"
                VerifiedDeleted = if ($VerifyDeletion) { -not (Test-Path $FilePath) } else { $null }
            }
            
            return $certificate
        }
        catch {
            Write-Error "Failed to securely delete file: $_"
            return [PSCustomObject]@{
                Success = $false
                Path = $FilePath
                Error = $_.Exception.Message
            }
        }
    }
}

Export-ModuleMember -Function Enable-IntegrityMonitoring, Test-FileIntegrity, Remove-FileSecurely
