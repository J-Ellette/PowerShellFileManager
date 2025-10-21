#Requires -Version 7.0

<#
.SYNOPSIS
    Color Picker - Screen color picker and palette manager
    PowerToys Integration

.DESCRIPTION
    Provides color picking from screen, color format conversion,
    and color palette management functionality.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
    Requires: Windows OS with System.Drawing support
#>

function Get-ColorFromScreen {
    <#
    .SYNOPSIS
        Pick a color from anywhere on the screen
    
    .DESCRIPTION
        Interactive color picker that allows selecting a color from screen
    
    .PARAMETER Format
        Output format (HEX, RGB, HSL, HSV)
    
    .EXAMPLE
        Get-ColorFromScreen -Format HEX
        Pick a color and return as HEX value
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('HEX', 'RGB', 'HSL', 'HSV')]
        [string]$Format = 'HEX'
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    Write-Host "Color Picker - Move mouse to desired color and press Enter" -ForegroundColor Cyan
    Write-Host "Press Esc to cancel" -ForegroundColor Yellow
    
    $picked = $false
    $color = $null
    
    while (-not $picked) {
        $pos = [System.Windows.Forms.Cursor]::Position
        $screen = [System.Drawing.Bitmap]::new(1, 1)
        $graphics = [System.Drawing.Graphics]::FromImage($screen)
        $graphics.CopyFromScreen($pos.X, $pos.Y, 0, 0, $screen.Size)
        $color = $screen.GetPixel(0, 0)
        
        Write-Host "`rCurrent: RGB($($color.R),$($color.G),$($color.B)) HEX(#$($color.R.ToString('X2'))$($color.G.ToString('X2'))$($color.B.ToString('X2')))  " -NoNewline
        
        if ([System.Console]::KeyAvailable) {
            $key = [System.Console]::ReadKey($true)
            if ($key.Key -eq 'Enter') {
                $picked = $true
            } elseif ($key.Key -eq 'Escape') {
                $graphics.Dispose()
                $screen.Dispose()
                return
            }
        }
        
        $graphics.Dispose()
        $screen.Dispose()
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host ""
    
    $result = switch ($Format) {
        'HEX' { "#$($color.R.ToString('X2'))$($color.G.ToString('X2'))$($color.B.ToString('X2'))" }
        'RGB' { "rgb($($color.R), $($color.G), $($color.B))" }
        'HSL' {
            $h = $color.GetHue()
            $s = $color.GetSaturation() * 100
            $l = $color.GetBrightness() * 100
            "hsl($([math]::Round($h)), $([math]::Round($s))%, $([math]::Round($l))%)"
        }
        'HSV' {
            $h = $color.GetHue()
            $s = $color.GetSaturation() * 100
            $v = $color.GetBrightness() * 100
            "hsv($([math]::Round($h)), $([math]::Round($s))%, $([math]::Round($v))%)"
        }
    }
    
    # Copy to clipboard
    try {
        Set-Clipboard -Value $result
        Write-Host "Color copied to clipboard: $result" -ForegroundColor Green
    } catch {
        Write-Verbose "Could not copy to clipboard: $_"
    }
    
    return [PSCustomObject]@{
        Format = $Format
        Value = $result
        R = $color.R
        G = $color.G
        B = $color.B
        HEX = "#$($color.R.ToString('X2'))$($color.G.ToString('X2'))$($color.B.ToString('X2'))"
    }
}

function Convert-ColorFormat {
    <#
    .SYNOPSIS
        Convert color between different formats
    
    .DESCRIPTION
        Convert between HEX, RGB, HSL, and HSV color formats
    
    .PARAMETER Color
        Input color value
    
    .PARAMETER FromFormat
        Source color format
    
    .PARAMETER ToFormat
        Target color format
    
    .EXAMPLE
        Convert-ColorFormat -Color "#FF5733" -FromFormat HEX -ToFormat RGB
        Convert HEX color to RGB
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Color,
        
        [ValidateSet('HEX', 'RGB')]
        [string]$FromFormat = 'HEX',
        
        [ValidateSet('HEX', 'RGB', 'HSL', 'HSV')]
        [string]$ToFormat = 'RGB'
    )
    
    Add-Type -AssemblyName System.Drawing
    
    # Parse input color
    $sysColor = if ($FromFormat -eq 'HEX') {
        $hex = $Color -replace '#', ''
        [System.Drawing.Color]::FromArgb(
            [Convert]::ToInt32($hex.Substring(0, 2), 16),
            [Convert]::ToInt32($hex.Substring(2, 2), 16),
            [Convert]::ToInt32($hex.Substring(4, 2), 16)
        )
    } else {
        $rgb = $Color -replace '[^\d,]', '' -split ','
        [System.Drawing.Color]::FromArgb([int]$rgb[0], [int]$rgb[1], [int]$rgb[2])
    }
    
    # Convert to target format
    switch ($ToFormat) {
        'HEX' { "#$($sysColor.R.ToString('X2'))$($sysColor.G.ToString('X2'))$($sysColor.B.ToString('X2'))" }
        'RGB' { "rgb($($sysColor.R), $($sysColor.G), $($sysColor.B))" }
        'HSL' {
            $h = $sysColor.GetHue()
            $s = $sysColor.GetSaturation() * 100
            $l = $sysColor.GetBrightness() * 100
            "hsl($([math]::Round($h)), $([math]::Round($s))%, $([math]::Round($l))%)"
        }
        'HSV' {
            $h = $sysColor.GetHue()
            $s = $sysColor.GetSaturation() * 100
            $v = $sysColor.GetBrightness() * 100
            "hsv($([math]::Round($h)), $([math]::Round($s))%, $([math]::Round($v))%)"
        }
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-ColorFromScreen'
    'Convert-ColorFormat'
)
