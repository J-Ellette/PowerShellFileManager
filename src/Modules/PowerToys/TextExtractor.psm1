#Requires -Version 7.0

<#
.SYNOPSIS
    Text Extractor (OCR) - Optical Character Recognition module
    PowerToys Integration

.DESCRIPTION
    Provides OCR functionality to extract text from images and screenshots.
    Uses Windows.Media.Ocr for Windows or Tesseract wrapper for cross-platform support.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
    Cross-Platform: Limited OCR on non-Windows systems
#>

function Get-TextFromImage {
    <#
    .SYNOPSIS
        Extract text from image files using OCR
    
    .DESCRIPTION
        Uses Optical Character Recognition to extract text content from images.
        On Windows, uses Windows.Media.Ocr. On other platforms, requires tesseract.
    
    .PARAMETER Path
        Path to image file(s) to process
    
    .PARAMETER Language
        OCR language code (e.g., 'en' for English, 'es' for Spanish)
    
    .PARAMETER OutputFile
        Optional output file to save extracted text
    
    .EXAMPLE
        Get-TextFromImage -Path "screenshot.png"
        Extract text from a screenshot
    
    .EXAMPLE
        Get-TextFromImage -Path "document.jpg" -Language "en" -OutputFile "extracted.txt"
        Extract English text and save to file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path,
        
        [string]$Language = 'en',
        
        [string]$OutputFile
    )
    
    begin {
        $isWindowsOS = $IsWindows -or $PSVersionTable.PSVersion.Major -le 5
        
        if ($isWindowsOS) {
            # Try to load Windows OCR
            try {
                Add-Type -AssemblyName System.Runtime.WindowsRuntime
                $null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
                $null = [Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
                $hasWindowsOcr = $true
                Write-Verbose "Windows OCR available"
            } catch {
                $hasWindowsOcr = $false
                Write-Warning "Windows OCR not available: $_"
            }
        } else {
            # Check for tesseract on Unix-like systems
            try {
                $tesseractPath = Get-Command tesseract -ErrorAction Stop
                $hasTesseract = $true
                Write-Verbose "Tesseract found at: $($tesseractPath.Source)"
            } catch {
                $hasTesseract = $false
                Write-Warning "Tesseract not found. Please install tesseract-ocr."
            }
        }
        
        $allText = @()
    }
    
    process {
        foreach ($imgPath in $Path) {
            try {
                $file = Get-Item -Path $imgPath -ErrorAction Stop
                Write-Verbose "Processing: $($file.Name)"
                
                if ($isWindowsOS -and $hasWindowsOcr) {
                    # Use Windows OCR
                    $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage(
                        [Windows.Globalization.Language]::new($Language)
                    )
                    
                    if (-not $ocrEngine) {
                        Write-Warning "OCR engine for language '$Language' not available, using default"
                        $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
                    }
                    
                    # Load image
                    $fileStream = [System.IO.File]::OpenRead($file.FullName)
                    $decoder = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($fileStream.AsRandomAccessStream()).GetResults()
                    $softwareBitmap = $decoder.GetSoftwareBitmapAsync().GetResults()
                    
                    # Perform OCR
                    $ocrResult = $ocrEngine.RecognizeAsync($softwareBitmap).GetResults()
                    $text = $ocrResult.Text
                    
                    $fileStream.Dispose()
                    
                } elseif ($hasTesseract) {
                    # Use tesseract
                    $tempOutput = [System.IO.Path]::GetTempFileName()
                    $result = & tesseract $file.FullName $tempOutput -l $Language 2>&1
                    
                    # Check for tesseract errors
                    if ($LASTEXITCODE -ne 0) {
                        throw "Tesseract OCR failed: $($result -join ' ')"
                    }
                    
                    $text = Get-Content "$tempOutput.txt" -Raw -ErrorAction SilentlyContinue
                    Remove-Item "$tempOutput.txt" -ErrorAction SilentlyContinue
                    Remove-Item $tempOutput -ErrorAction SilentlyContinue
                    
                } else {
                    throw "No OCR engine available. Install tesseract-ocr or use Windows 10+"
                }
                
                $allText += $text
                
                [PSCustomObject]@{
                    SourceFile = $file.FullName
                    TextLength = $text.Length
                    Text = $text
                    Status = 'Success'
                }
                
            } catch {
                Write-Error "Failed to extract text from $imgPath : $_"
                [PSCustomObject]@{
                    SourceFile = $imgPath
                    Status = 'Failed'
                    Error = $_.Exception.Message
                }
            }
        }
    }
    
    end {
        if ($OutputFile -and $allText) {
            try {
                $allText -join "`n`n" | Out-File -FilePath $OutputFile -Encoding UTF8
                Write-Verbose "Text saved to: $OutputFile"
            } catch {
                Write-Error "Failed to save output file: $_"
            }
        }
    }
}

function Start-ScreenTextExtractor {
    <#
    .SYNOPSIS
        Launch interactive screen text extraction tool
    
    .DESCRIPTION
        Starts an interactive tool to select screen regions and extract text via OCR
    
    .PARAMETER Language
        OCR language code
    
    .EXAMPLE
        Start-ScreenTextExtractor
        Launch the screen text extractor
    #>
    [CmdletBinding()]
    param(
        [string]$Language = 'en'
    )
    
    Write-Host "Screen Text Extractor" -ForegroundColor Cyan
    Write-Host "Instructions:" -ForegroundColor Yellow
    Write-Host "1. Press PrtScn to capture screen"
    Write-Host "2. Save screenshot to temp location"
    Write-Host "3. Extract text from screenshot"
    Write-Host ""
    
    # Capture screenshot (basic implementation)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    
    $tempFile = [System.IO.Path]::GetTempFileName() + ".png"
    $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $graphics.Dispose()
    $bitmap.Dispose()
    
    Write-Host "Screenshot captured, extracting text..." -ForegroundColor Green
    
    $result = Get-TextFromImage -Path $tempFile -Language $Language
    
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    
    if ($result.Status -eq 'Success') {
        Write-Host "`nExtracted Text:" -ForegroundColor Green
        Write-Host "=" * 60
        Write-Host $result.Text
        Write-Host "=" * 60
        
        # Copy to clipboard if available
        try {
            Set-Clipboard -Value $result.Text
            Write-Host "`nText copied to clipboard!" -ForegroundColor Cyan
        } catch {
            Write-Verbose "Could not copy to clipboard: $_"
        }
    } else {
        Write-Error "Text extraction failed"
    }
    
    return $result
}

# Export module members
Export-ModuleMember -Function @(
    'Get-TextFromImage'
    'Start-ScreenTextExtractor'
)
