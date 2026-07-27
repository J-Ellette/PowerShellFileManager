#Requires -Version 7.0

<#
.SYNOPSIS
    Image Resizer - Batch image processing module
    PowerToys Integration

.DESCRIPTION
    Provides batch image resizing and processing functionality.
    Allows users to resize multiple images at once with various options
    including custom dimensions, file format conversion, and quality settings.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
    Requires: Windows OS
#>

function Resize-Image {
    <#
    .SYNOPSIS
        Resize one or more images
    
    .DESCRIPTION
        Batch resize images with custom dimensions, maintaining aspect ratio or custom sizes.
        Supports multiple output formats and quality settings.
    
    .PARAMETER Path
        Path to image file(s) to resize
    
    .PARAMETER Width
        Target width in pixels
    
    .PARAMETER Height
        Target height in pixels
    
    .PARAMETER Percent
        Resize by percentage (e.g., 50 for 50% of original size)
    
    .PARAMETER OutputPath
        Output directory for resized images (defaults to source directory)
    
    .PARAMETER Format
        Output format (JPEG, PNG, BMP, GIF, TIFF)
    
    .PARAMETER Quality
        JPEG quality (1-100, default 90)
    
    .PARAMETER KeepAspectRatio
        Maintain original aspect ratio when resizing
    
    .EXAMPLE
        Resize-Image -Path "C:\Photos\*.jpg" -Width 800 -KeepAspectRatio
        Resize all JPEGs to 800px width, maintaining aspect ratio
    
    .EXAMPLE
        Resize-Image -Path "photo.png" -Percent 50 -Format JPEG -Quality 85
        Reduce image to 50% size and convert to JPEG
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path,
        
        [Parameter(ParameterSetName='Dimensions')]
        [int]$Width,
        
        [Parameter(ParameterSetName='Dimensions')]
        [int]$Height,
        
        [Parameter(ParameterSetName='Percent')]
        [ValidateRange(1, 500)]
        [int]$Percent,
        
        [string]$OutputPath,
        
        [ValidateSet('JPEG', 'PNG', 'BMP', 'GIF', 'TIFF')]
        [string]$Format,
        
        [ValidateRange(1, 100)]
        [int]$Quality = 90,
        
        [switch]$KeepAspectRatio
    )
    
    begin {
        Add-Type -AssemblyName System.Drawing
        $processedCount = 0
    }
    
    process {
        foreach ($imgPath in $Path) {
            try {
                $files = Get-Item -Path $imgPath -ErrorAction Stop
                
                foreach ($file in $files) {
                    if ($PSCmdlet.ShouldProcess($file.FullName, "Resize image")) {
                        Write-Verbose "Resizing: $($file.Name)"
                        
                        # Load image
                        $img = [System.Drawing.Image]::FromFile($file.FullName)
                        
                        # Calculate new dimensions
                        if ($Percent) {
                            $newWidth = [int]($img.Width * ($Percent / 100))
                            $newHeight = [int]($img.Height * ($Percent / 100))
                        } else {
                            if ($KeepAspectRatio) {
                                $ratio = $img.Width / $img.Height
                                if ($Width -and -not $Height) {
                                    $newWidth = $Width
                                    $newHeight = [int]($Width / $ratio)
                                } elseif ($Height -and -not $Width) {
                                    $newHeight = $Height
                                    $newWidth = [int]($Height * $ratio)
                                } else {
                                    $newWidth = $Width
                                    $newHeight = $Height
                                }
                            } else {
                                $newWidth = if ($Width) { $Width } else { $img.Width }
                                $newHeight = if ($Height) { $Height } else { $img.Height }
                            }
                        }
                        
                        # Create resized image
                        $resized = New-Object System.Drawing.Bitmap $newWidth, $newHeight
                        $graphics = [System.Drawing.Graphics]::FromImage($resized)
                        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                        $graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)
                        
                        # Determine output path and format
                        $outDir = if ($OutputPath) { $OutputPath } else { $file.DirectoryName }
                        $outFormat = if ($Format) { $Format } else { $file.Extension.TrimStart('.').ToUpper() }
                        $outExt = $outFormat.ToLower()
                        $outFile = Join-Path $outDir "$($file.BaseName)_resized.$outExt"
                        
                        # Save with appropriate encoder
                        switch ($outFormat) {
                            'JPEG' {
                                $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
                                $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
                                $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $Quality)
                                $resized.Save($outFile, $encoder, $encoderParams)
                            }
                            default {
                                $resized.Save($outFile)
                            }
                        }
                        
                        # Cleanup
                        $graphics.Dispose()
                        $resized.Dispose()
                        $img.Dispose()
                        
                        $processedCount++
                        
                        [PSCustomObject]@{
                            SourceFile = $file.FullName
                            OutputFile = $outFile
                            OriginalSize = "$($img.Width)x$($img.Height)"
                            NewSize = "${newWidth}x${newHeight}"
                            Format = $outFormat
                            Status = 'Success'
                        }
                    }
                }
            } catch {
                Write-Error "Failed to resize $imgPath : $_"
                [PSCustomObject]@{
                    SourceFile = $imgPath
                    OutputFile = $null
                    Status = 'Failed'
                    Error = $_.Exception.Message
                }
            }
        }
    }
    
    end {
        Write-Verbose "Processed $processedCount image(s)"
    }
}

function Get-ImageInfo {
    <#
    .SYNOPSIS
        Get detailed information about image files
    
    .DESCRIPTION
        Retrieves dimensions, format, size, and other metadata from image files
    
    .PARAMETER Path
        Path to image file(s)
    
    .EXAMPLE
        Get-ImageInfo -Path "C:\Photos\*.jpg"
        Get information about all JPEG files in the Photos folder
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path
    )
    
    process {
        foreach ($imgPath in $Path) {
            try {
                $files = Get-Item -Path $imgPath -ErrorAction Stop
                
                foreach ($file in $files) {
                    Add-Type -AssemblyName System.Drawing
                    $img = [System.Drawing.Image]::FromFile($file.FullName)
                    
                    [PSCustomObject]@{
                        Name = $file.Name
                        Path = $file.FullName
                        Width = $img.Width
                        Height = $img.Height
                        Dimensions = "$($img.Width)x$($img.Height)"
                        Format = $img.RawFormat.ToString()
                        SizeMB = [math]::Round($file.Length / 1MB, 2)
                        HorizontalResolution = $img.HorizontalResolution
                        VerticalResolution = $img.VerticalResolution
                    }
                    
                    $img.Dispose()
                }
            } catch {
                Write-Error "Failed to get info for $imgPath : $_"
            }
        }
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Resize-Image'
    'Get-ImageInfo'
)
