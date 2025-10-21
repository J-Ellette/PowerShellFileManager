#Requires -Version 7.0

# Preview Providers Module - Rich preview for various file types

function Show-FilePreview {
    <#
    .SYNOPSIS
        Shows preview of file contents
    .DESCRIPTION
        Displays preview based on file type (text, image, PDF, etc.)
    .PARAMETER Path
        File path to preview
    .EXAMPLE
        Show-FilePreview -Path file.txt
        Shows text file preview
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "File not found: $Path"
        return
    }
    
    $file = Get-Item $Path
    $extension = $file.Extension.ToLower()
    
    Write-Host "`nFile Preview: $($file.Name)" -ForegroundColor Cyan
    Write-Host "Type: $extension | Size: $($file.Length) bytes" -ForegroundColor Gray
    Write-Host ("=" * 80) -ForegroundColor Gray
    
    switch ($extension) {
        { $_ -in '.txt', '.log', '.md', '.ps1', '.psm1', '.psd1', '.json', '.xml', '.csv' } {
            # Text preview
            $lines = Get-Content -Path $Path -TotalCount 50
            $lines | ForEach-Object { Write-Host $_ }
            
            if ((Get-Content -Path $Path).Count -gt 50) {
                Write-Host "`n... (showing first 50 lines)" -ForegroundColor Yellow
            }
        }
        { $_ -in '.jpg', '.jpeg', '.png', '.gif', '.bmp' } {
            Write-Host "Image file - preview requires GUI component" -ForegroundColor Yellow
            
            # Show EXIF data if available
            try {
                Add-Type -AssemblyName System.Drawing
                $image = [System.Drawing.Image]::FromFile($Path)
                Write-Host "`nDimensions: $($image.Width) x $($image.Height)" -ForegroundColor Green
                Write-Host "Format: $($image.RawFormat)" -ForegroundColor Green
                $image.Dispose()
            } catch {
                Write-Host "Could not load image metadata" -ForegroundColor Red
            }
        }
        { $_ -in '.pdf' } {
            Write-Host "PDF file - preview requires PDF library" -ForegroundColor Yellow
        }
        { $_ -in '.zip', '.7z', '.rar', '.tar', '.gz' } {
            Write-Host "Archive file - use Get-ArchiveContent for details" -ForegroundColor Yellow
        }
        { $_ -in '.exe', '.dll' } {
            Write-Host "Executable file" -ForegroundColor Yellow
            
            # Show version info
            try {
                $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
                Write-Host "`nVersion: $($versionInfo.FileVersion)" -ForegroundColor Green
                Write-Host "Description: $($versionInfo.FileDescription)" -ForegroundColor Green
                Write-Host "Company: $($versionInfo.CompanyName)" -ForegroundColor Green
            } catch {
                Write-Host "Could not read version info" -ForegroundColor Red
            }
        }
        default {
            Write-Host "No preview available for this file type" -ForegroundColor Yellow
            Write-Host "Use hex viewer for binary content" -ForegroundColor Gray
        }
    }
    
    Write-Host ("=" * 80) -ForegroundColor Gray
}

function Get-FileMetadata {
    <#
    .SYNOPSIS
        Gets file metadata (EXIF, ID3, etc.)
    .PARAMETER Path
        File path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "File not found: $Path"
        return
    }
    
    $file = Get-Item $Path
    $metadata = @{}
    
    # Use Shell.Application to get extended properties
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace($file.DirectoryName)
        $fileItem = $folder.ParseName($file.Name)
        
        for ($i = 0; $i -lt 320; $i++) {
            $propName = $folder.GetDetailsOf($null, $i)
            if ($propName) {
                $propValue = $folder.GetDetailsOf($fileItem, $i)
                if ($propValue) {
                    $metadata[$propName] = $propValue
                }
            }
        }
    } catch {
        Write-Warning "Could not read extended metadata"
    }
    
    return $metadata
}

function Show-WordDocumentPreview {
    <#
    .SYNOPSIS
        Shows preview of Word document (.docx) files
    .DESCRIPTION
        Displays text content, metadata, and statistics from Word documents
    .PARAMETER Path
        Path to .docx file
    .EXAMPLE
        Show-WordDocumentPreview -Path "document.docx"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    try {
        Write-Host "`nWord Document Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        # Try using Word COM object first (if Word is installed)
        try {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false
            $doc = $word.Documents.Open($Path, $false, $true) # ReadOnly

            Write-Host "`nDocument Statistics:" -ForegroundColor Yellow
            Write-Host "  Pages: $($doc.ComputeStatistics(2))" -ForegroundColor Green  # wdStatisticPages = 2
            Write-Host "  Words: $($doc.ComputeStatistics(0))" -ForegroundColor Green  # wdStatisticWords = 0
            Write-Host "  Characters: $($doc.ComputeStatistics(3))" -ForegroundColor Green  # wdStatisticCharacters = 3
            Write-Host "  Paragraphs: $($doc.ComputeStatistics(4))" -ForegroundColor Green  # wdStatisticParagraphs = 4

            Write-Host "`nDocument Properties:" -ForegroundColor Yellow
            Write-Host "  Title: $($doc.BuiltInDocumentProperties('Title').Value)" -ForegroundColor Green
            Write-Host "  Author: $($doc.BuiltInDocumentProperties('Author').Value)" -ForegroundColor Green
            Write-Host "  Subject: $($doc.BuiltInDocumentProperties('Subject').Value)" -ForegroundColor Green
            Write-Host "  Last Modified: $($doc.BuiltInDocumentProperties('Last Save Time').Value)" -ForegroundColor Green

            Write-Host "`nDocument Content (First 500 characters):" -ForegroundColor Yellow
            $text = $doc.Content.Text
            $preview = $text.Substring(0, [Math]::Min(500, $text.Length))
            Write-Host $preview

            if ($text.Length -gt 500) {
                Write-Host "`n... (showing first 500 characters)" -ForegroundColor Gray
            }

            $doc.Close($false)
            $word.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null

        } catch {
            # Fallback: Extract from ZIP structure (DOCX is a ZIP file)
            Write-Host "Word not installed. Using alternative extraction method..." -ForegroundColor Yellow

            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)

            # Try to read document.xml
            $docXml = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
            if ($docXml) {
                $stream = $docXml.Open()
                $reader = New-Object System.IO.StreamReader($stream)
                $xml = [xml]$reader.ReadToEnd()
                $reader.Close()
                $stream.Close()

                # Extract text from XML (simple extraction)
                $text = ($xml.InnerText -replace '\s+', ' ').Trim()
                $preview = $text.Substring(0, [Math]::Min(500, $text.Length))

                Write-Host "`nDocument Content (First 500 characters):" -ForegroundColor Yellow
                Write-Host $preview

                if ($text.Length -gt 500) {
                    Write-Host "`n... (showing first 500 characters)" -ForegroundColor Gray
                }
            }

            # Try to read core properties
            $coreProps = $zip.Entries | Where-Object { $_.FullName -eq 'docProps/core.xml' }
            if ($coreProps) {
                $stream = $coreProps.Open()
                $reader = New-Object System.IO.StreamReader($stream)
                $xml = [xml]$reader.ReadToEnd()
                $reader.Close()
                $stream.Close()

                Write-Host "`nDocument Properties:" -ForegroundColor Yellow
                if ($xml.coreProperties.title) { Write-Host "  Title: $($xml.coreProperties.title)" -ForegroundColor Green }
                if ($xml.coreProperties.creator) { Write-Host "  Author: $($xml.coreProperties.creator)" -ForegroundColor Green }
                if ($xml.coreProperties.subject) { Write-Host "  Subject: $($xml.coreProperties.subject)" -ForegroundColor Green }
                if ($xml.coreProperties.modified) { Write-Host "  Last Modified: $($xml.coreProperties.modified)" -ForegroundColor Green }
            }

            $zip.Dispose()
        }

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview Word document: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-ExcelPreview {
    <#
    .SYNOPSIS
        Shows preview of Excel spreadsheet (.xlsx) files
    .DESCRIPTION
        Displays worksheet names, cell counts, and sample data from Excel files
    .PARAMETER Path
        Path to .xlsx file
    .PARAMETER MaxRows
        Maximum number of rows to preview (default: 10)
    .EXAMPLE
        Show-ExcelPreview -Path "spreadsheet.xlsx"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [int]$MaxRows = 10
    )

    try {
        Write-Host "`nExcel Spreadsheet Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        # Try using Excel COM object first (if Excel is installed)
        try {
            $excel = New-Object -ComObject Excel.Application
            $excel.Visible = $false
            $excel.DisplayAlerts = $false
            $workbook = $excel.Workbooks.Open($Path, $null, $true) # ReadOnly

            Write-Host "`nWorkbook Information:" -ForegroundColor Yellow
            Write-Host "  Total Worksheets: $($workbook.Worksheets.Count)" -ForegroundColor Green
            Write-Host "  Author: $($workbook.Author)" -ForegroundColor Green
            Write-Host "  Last Modified: $($workbook.BuiltinDocumentProperties('Last Save Time').Value)" -ForegroundColor Green

            Write-Host "`nWorksheets:" -ForegroundColor Yellow
            foreach ($sheet in $workbook.Worksheets) {
                $usedRange = $sheet.UsedRange
                Write-Host "  - $($sheet.Name) ($($usedRange.Rows.Count) rows x $($usedRange.Columns.Count) columns)" -ForegroundColor Green
            }

            # Preview first worksheet
            if ($workbook.Worksheets.Count -gt 0) {
                $firstSheet = $workbook.Worksheets.Item(1)
                $usedRange = $firstSheet.UsedRange

                Write-Host "`nPreview of '$($firstSheet.Name)' (First $MaxRows rows):" -ForegroundColor Yellow

                $rowCount = [Math]::Min($MaxRows, $usedRange.Rows.Count)
                $colCount = [Math]::Min(5, $usedRange.Columns.Count) # Limit to 5 columns

                for ($row = 1; $row -le $rowCount; $row++) {
                    $rowData = @()
                    for ($col = 1; $col -le $colCount; $col++) {
                        $cellValue = $usedRange.Cells.Item($row, $col).Text
                        if ($cellValue.Length -gt 20) {
                            $cellValue = $cellValue.Substring(0, 17) + "..."
                        }
                        $rowData += $cellValue.PadRight(20)
                    }
                    Write-Host "  $($rowData -join ' | ')"
                }

                if ($usedRange.Rows.Count -gt $MaxRows) {
                    Write-Host "`n... (showing first $MaxRows of $($usedRange.Rows.Count) rows)" -ForegroundColor Gray
                }
                if ($usedRange.Columns.Count -gt 5) {
                    Write-Host "... (showing first 5 of $($usedRange.Columns.Count) columns)" -ForegroundColor Gray
                }
            }

            $workbook.Close($false)
            $excel.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

        } catch {
            # Fallback: Use ImportExcel module if available, or basic ZIP extraction
            Write-Host "Excel not installed. Attempting alternative extraction..." -ForegroundColor Yellow

            if (Get-Module -ListAvailable -Name ImportExcel) {
                Import-Module ImportExcel
                $data = Import-Excel -Path $Path -WorksheetName (Get-ExcelSheetInfo -Path $Path)[0].Name -StartRow 1 -EndRow $MaxRows

                Write-Host "`nWorksheet Data:" -ForegroundColor Yellow
                $data | Format-Table -AutoSize | Out-String | Write-Host
            } else {
                Write-Host "`nExcel preview requires Excel installation or ImportExcel module" -ForegroundColor Yellow
                Write-Host "Install ImportExcel: Install-Module -Name ImportExcel" -ForegroundColor Gray

                # Show basic file info
                $file = Get-Item $Path
                Write-Host "`nFile Information:" -ForegroundColor Yellow
                Write-Host "  Size: $($file.Length) bytes" -ForegroundColor Green
                Write-Host "  Last Modified: $($file.LastWriteTime)" -ForegroundColor Green
            }
        }

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview Excel file: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-PDFPreview {
    <#
    .SYNOPSIS
        Shows preview of PDF files
    .DESCRIPTION
        Displays PDF metadata, page count, and attempts text extraction
    .PARAMETER Path
        Path to .pdf file
    .EXAMPLE
        Show-PDFPreview -Path "document.pdf"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    try {
        Write-Host "`nPDF Document Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        $file = Get-Item $Path

        Write-Host "`nFile Information:" -ForegroundColor Yellow
        Write-Host "  Size: $([Math]::Round($file.Length / 1KB, 2)) KB" -ForegroundColor Green
        Write-Host "  Created: $($file.CreationTime)" -ForegroundColor Green
        Write-Host "  Modified: $($file.LastWriteTime)" -ForegroundColor Green

        # Try to extract basic PDF info by reading the file
        try {
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            $text = [System.Text.Encoding]::ASCII.GetString($bytes)

            # Try to find PDF version
            if ($text -match '%PDF-(\d+\.\d+)') {
                Write-Host "  PDF Version: $($Matches[1])" -ForegroundColor Green
            }

            # Try to find page count
            if ($text -match '/Count\s+(\d+)') {
                Write-Host "  Pages: $($Matches[1])" -ForegroundColor Green
            }

            # Try to find metadata
            if ($text -match '/Title\s*\(([^)]+)\)') {
                Write-Host "  Title: $($Matches[1])" -ForegroundColor Green
            }
            if ($text -match '/Author\s*\(([^)]+)\)') {
                Write-Host "  Author: $($Matches[1])" -ForegroundColor Green
            }
            if ($text -match '/Subject\s*\(([^)]+)\)') {
                Write-Host "  Subject: $($Matches[1])" -ForegroundColor Green
            }
            if ($text -match '/Creator\s*\(([^)]+)\)') {
                Write-Host "  Creator: $($Matches[1])" -ForegroundColor Green
            }

        } catch {
            Write-Host "  Could not extract PDF metadata" -ForegroundColor Yellow
        }

        Write-Host "`nNote: For full PDF preview with text extraction, consider using:" -ForegroundColor Yellow
        Write-Host "  - Adobe Acrobat Reader" -ForegroundColor Gray
        Write-Host "  - PowerShell module: iTextSharp (Install-Package iTextSharp)" -ForegroundColor Gray
        Write-Host "  - Command-line tool: pdftotext" -ForegroundColor Gray

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview PDF: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-VideoPreview {
    <#
    .SYNOPSIS
        Shows preview of video files (.mp4, .avi, .mkv, etc.)
    .DESCRIPTION
        Displays video metadata, codec information, duration, and resolution
    .PARAMETER Path
        Path to video file
    .EXAMPLE
        Show-VideoPreview -Path "video.mp4"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    try {
        Write-Host "`nVideo File Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        $file = Get-Item $Path

        Write-Host "`nFile Information:" -ForegroundColor Yellow
        Write-Host "  Size: $([Math]::Round($file.Length / 1MB, 2)) MB" -ForegroundColor Green
        Write-Host "  Extension: $($file.Extension)" -ForegroundColor Green
        Write-Host "  Created: $($file.CreationTime)" -ForegroundColor Green
        Write-Host "  Modified: $($file.LastWriteTime)" -ForegroundColor Green

        # Use Shell.Application to get extended properties
        try {
            $shell = New-Object -ComObject Shell.Application
            $folder = $shell.Namespace($file.DirectoryName)
            $fileItem = $folder.ParseName($file.Name)

            Write-Host "`nVideo Properties:" -ForegroundColor Yellow

            # Common video property indices
            $properties = @{
                27 = "Duration"
                316 = "Frame width"
                317 = "Frame height"
                318 = "Frame rate"
                313 = "Video compression"
                315 = "Total bitrate"
            }

            foreach ($index in $properties.Keys) {
                $value = $folder.GetDetailsOf($fileItem, $index)
                if ($value) {
                    Write-Host "  $($properties[$index]): $value" -ForegroundColor Green
                }
            }

            # Try to get additional metadata
            $duration = $folder.GetDetailsOf($fileItem, 27)
            $dimensions = $folder.GetDetailsOf($fileItem, 316) # Frame width

            if (-not $duration -and -not $dimensions) {
                Write-Host "  Extended metadata not available" -ForegroundColor Yellow
            }

        } catch {
            Write-Host "  Could not read extended video properties" -ForegroundColor Yellow
        }

        Write-Host "`nNote: For detailed video analysis, consider using:" -ForegroundColor Yellow
        Write-Host "  - FFmpeg/FFprobe (command-line): ffprobe -v quiet -print_format json -show_format -show_streams `"$Path`"" -ForegroundColor Gray
        Write-Host "  - MediaInfo (GUI/CLI tool)" -ForegroundColor Gray
        Write-Host "  - VLC Media Player" -ForegroundColor Gray

        # Check if ffprobe is available
        if (Get-Command ffprobe -ErrorAction SilentlyContinue) {
            Write-Host "`nFFprobe detected! Running detailed analysis..." -ForegroundColor Cyan
            $ffprobeOutput = ffprobe -v quiet -print_format json -show_format -show_streams "$Path" 2>&1 | ConvertFrom-Json

            if ($ffprobeOutput.format) {
                Write-Host "`nDetailed Format Information:" -ForegroundColor Yellow
                Write-Host "  Format: $($ffprobeOutput.format.format_long_name)" -ForegroundColor Green
                Write-Host "  Duration: $([Math]::Round([double]$ffprobeOutput.format.duration, 2)) seconds" -ForegroundColor Green
                Write-Host "  Bitrate: $([Math]::Round([double]$ffprobeOutput.format.bit_rate / 1000, 2)) kb/s" -ForegroundColor Green
            }

            $videoStream = $ffprobeOutput.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
            if ($videoStream) {
                Write-Host "`nVideo Stream:" -ForegroundColor Yellow
                Write-Host "  Codec: $($videoStream.codec_long_name)" -ForegroundColor Green
                Write-Host "  Resolution: $($videoStream.width)x$($videoStream.height)" -ForegroundColor Green
                Write-Host "  Frame Rate: $($videoStream.r_frame_rate) fps" -ForegroundColor Green
            }

            $audioStream = $ffprobeOutput.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
            if ($audioStream) {
                Write-Host "`nAudio Stream:" -ForegroundColor Yellow
                Write-Host "  Codec: $($audioStream.codec_long_name)" -ForegroundColor Green
                Write-Host "  Sample Rate: $($audioStream.sample_rate) Hz" -ForegroundColor Green
                Write-Host "  Channels: $($audioStream.channels)" -ForegroundColor Green
            }
        }

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview video: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-AudioPreview {
    <#
    .SYNOPSIS
        Shows preview of audio files (.mp3, .wav, .flac, etc.)
    .DESCRIPTION
        Displays audio metadata, ID3 tags, duration, bitrate, and codec information
    .PARAMETER Path
        Path to audio file
    .EXAMPLE
        Show-AudioPreview -Path "song.mp3"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    try {
        Write-Host "`nAudio File Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        $file = Get-Item $Path

        Write-Host "`nFile Information:" -ForegroundColor Yellow
        Write-Host "  Size: $([Math]::Round($file.Length / 1MB, 2)) MB" -ForegroundColor Green
        Write-Host "  Extension: $($file.Extension)" -ForegroundColor Green
        Write-Host "  Created: $($file.CreationTime)" -ForegroundColor Green
        Write-Host "  Modified: $($file.LastWriteTime)" -ForegroundColor Green

        # Use Shell.Application to get extended properties (ID3 tags)
        try {
            $shell = New-Object -ComObject Shell.Application
            $folder = $shell.Namespace($file.DirectoryName)
            $fileItem = $folder.ParseName($file.Name)

            Write-Host "`nAudio Metadata (ID3 Tags):" -ForegroundColor Yellow

            # Common audio property indices
            $properties = @{
                21 = "Title"
                20 = "Artists"
                14 = "Album"
                17 = "Year"
                16 = "Genre"
                26 = "Track number"
                27 = "Duration"
                28 = "Bit rate"
                313 = "Audio sample rate"
                314 = "Audio channels"
            }

            foreach ($index in $properties.Keys) {
                $value = $folder.GetDetailsOf($fileItem, $index)
                if ($value) {
                    Write-Host "  $($properties[$index]): $value" -ForegroundColor Green
                }
            }

        } catch {
            Write-Host "  Could not read extended audio properties" -ForegroundColor Yellow
        }

        Write-Host "`nNote: For detailed audio analysis, consider using:" -ForegroundColor Yellow
        Write-Host "  - FFmpeg/FFprobe (command-line): ffprobe -v quiet -print_format json -show_format `"$Path`"" -ForegroundColor Gray
        Write-Host "  - TagLib# library for advanced ID3 tag reading" -ForegroundColor Gray
        Write-Host "  - MediaInfo tool" -ForegroundColor Gray

        # Check if ffprobe is available
        if (Get-Command ffprobe -ErrorAction SilentlyContinue) {
            Write-Host "`nFFprobe detected! Running detailed analysis..." -ForegroundColor Cyan
            $ffprobeOutput = ffprobe -v quiet -print_format json -show_format -show_streams "$Path" 2>&1 | ConvertFrom-Json

            if ($ffprobeOutput.format) {
                Write-Host "`nDetailed Format Information:" -ForegroundColor Yellow
                Write-Host "  Format: $($ffprobeOutput.format.format_long_name)" -ForegroundColor Green
                Write-Host "  Duration: $([Math]::Round([double]$ffprobeOutput.format.duration, 2)) seconds" -ForegroundColor Green
                Write-Host "  Bitrate: $([Math]::Round([double]$ffprobeOutput.format.bit_rate / 1000, 2)) kb/s" -ForegroundColor Green

                if ($ffprobeOutput.format.tags) {
                    Write-Host "`nID3 Tags:" -ForegroundColor Yellow
                    $ffprobeOutput.format.tags.PSObject.Properties | ForEach-Object {
                        Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor Green
                    }
                }
            }

            $audioStream = $ffprobeOutput.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
            if ($audioStream) {
                Write-Host "`nAudio Stream Details:" -ForegroundColor Yellow
                Write-Host "  Codec: $($audioStream.codec_long_name)" -ForegroundColor Green
                Write-Host "  Sample Rate: $($audioStream.sample_rate) Hz" -ForegroundColor Green
                Write-Host "  Channels: $($audioStream.channels)" -ForegroundColor Green
                Write-Host "  Bit Depth: $($audioStream.bits_per_sample) bits" -ForegroundColor Green
            }
        }

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview audio: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-EnhancedPreview {
    <#
    .SYNOPSIS
        Enhanced file preview with support for multiple formats
    .DESCRIPTION
        Unified preview function that automatically detects file type and uses
        the appropriate specialized preview handler
    .PARAMETER Path
        Path to file to preview
    .EXAMPLE
        Show-EnhancedPreview -Path "document.docx"
        Shows Word document preview
    .EXAMPLE
        Show-EnhancedPreview -Path "data.xlsx"
        Shows Excel spreadsheet preview
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "File not found: $Path"
        return
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

    try {
        switch ($extension) {
            '.docx' { Show-WordDocumentPreview -Path $Path }
            '.xlsx' { Show-ExcelPreview -Path $Path }
            '.pdf'  { Show-PDFPreview -Path $Path }
            { $_ -in '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv' } {
                Show-VideoPreview -Path $Path
            }
            { $_ -in '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a' } {
                Show-AudioPreview -Path $Path
            }
            '.svg' { Show-SVGPreview -Path $Path }
            { $_ -in '.md', '.markdown' } { Show-MarkdownPreview -Path $Path }
            '.stl' { Show-STLPreview -Path $Path }
            { $_ -in '.gcode', '.gco', '.g' } { Show-GCodePreview -Path $Path }
            default {
                Write-Host "Using standard preview for $extension files..." -ForegroundColor Yellow
                Show-FilePreview -Path $Path
            }
        }
    } catch {
        Write-Error "Failed to preview file: $_"
        Write-Host "Falling back to standard preview..." -ForegroundColor Yellow
        Show-FilePreview -Path $Path
    }
}

function Show-SVGPreview {
    <#
    .SYNOPSIS
        Shows preview of SVG (Scalable Vector Graphics) files
    .DESCRIPTION
        Displays SVG metadata, dimensions, viewBox, element counts, and structure
    .PARAMETER Path
        Path to .svg file
    .EXAMPLE
        Show-SVGPreview -Path "image.svg"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    try {
        Write-Host "`nSVG File Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        $file = Get-Item $Path

        Write-Host "`nFile Information:" -ForegroundColor Yellow
        Write-Host "  Size: $([Math]::Round($file.Length / 1KB, 2)) KB" -ForegroundColor Green
        Write-Host "  Created: $($file.CreationTime)" -ForegroundColor Green
        Write-Host "  Modified: $($file.LastWriteTime)" -ForegroundColor Green

        # Parse SVG XML
        try {
            [xml]$svg = Get-Content -Path $Path -Raw

            Write-Host "`nSVG Properties:" -ForegroundColor Yellow

            # Get root SVG element
            $svgRoot = $svg.svg

            if ($svgRoot) {
                # Dimensions
                if ($svgRoot.width) {
                    Write-Host "  Width: $($svgRoot.width)" -ForegroundColor Green
                }
                if ($svgRoot.height) {
                    Write-Host "  Height: $($svgRoot.height)" -ForegroundColor Green
                }

                # ViewBox
                if ($svgRoot.viewBox) {
                    Write-Host "  ViewBox: $($svgRoot.viewBox)" -ForegroundColor Green
                }

                # Version
                if ($svgRoot.version) {
                    Write-Host "  SVG Version: $($svgRoot.version)" -ForegroundColor Green
                }

                # Namespace
                if ($svgRoot.xmlns) {
                    Write-Host "  Namespace: $($svgRoot.xmlns)" -ForegroundColor Green
                }

                Write-Host "`nElement Counts:" -ForegroundColor Yellow

                # Count various SVG elements
                $elements = @{
                    'Paths' = ($svg.SelectNodes("//path")).Count
                    'Rectangles' = ($svg.SelectNodes("//rect")).Count
                    'Circles' = ($svg.SelectNodes("//circle")).Count
                    'Ellipses' = ($svg.SelectNodes("//ellipse")).Count
                    'Lines' = ($svg.SelectNodes("//line")).Count
                    'Polygons' = ($svg.SelectNodes("//polygon")).Count
                    'Polylines' = ($svg.SelectNodes("//polyline")).Count
                    'Text Elements' = ($svg.SelectNodes("//text")).Count
                    'Groups' = ($svg.SelectNodes("//g")).Count
                    'Images' = ($svg.SelectNodes("//image")).Count
                }

                foreach ($element in $elements.GetEnumerator() | Where-Object { $_.Value -gt 0 }) {
                    Write-Host "  $($element.Key): $($element.Value)" -ForegroundColor Green
                }

                # Check for embedded styles or scripts
                $hasStyle = $svg.SelectNodes("//style").Count -gt 0
                $hasScript = $svg.SelectNodes("//script").Count -gt 0

                if ($hasStyle -or $hasScript) {
                    Write-Host "`nAdditional Features:" -ForegroundColor Yellow
                    if ($hasStyle) {
                        Write-Host "  Contains CSS Styles: Yes" -ForegroundColor Green
                    }
                    if ($hasScript) {
                        Write-Host "  Contains JavaScript: Yes" -ForegroundColor Yellow
                    }
                }

                # Show first few elements structure
                Write-Host "`nDocument Structure (first 10 lines):" -ForegroundColor Yellow
                $lines = Get-Content -Path $Path -TotalCount 10
                foreach ($line in $lines) {
                    Write-Host "  $line" -ForegroundColor Gray
                }

            } else {
                Write-Host "  Could not parse SVG root element" -ForegroundColor Yellow
            }

        } catch {
            Write-Host "  Could not parse SVG XML: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        Write-Host "`nNote: For visual preview, open in:" -ForegroundColor Yellow
        Write-Host "  - Web browser (Chrome, Firefox, Edge)" -ForegroundColor Gray
        Write-Host "  - Image viewer (Windows Photos, IrfanView)" -ForegroundColor Gray
        Write-Host "  - Vector editor (Inkscape, Adobe Illustrator)" -ForegroundColor Gray

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview SVG: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-MarkdownPreview {
    <#
    .SYNOPSIS
        Shows preview of Markdown files
    .DESCRIPTION
        Displays Markdown structure, heading counts, link counts, and content preview
    .PARAMETER Path
        Path to .md file
    .PARAMETER RenderHTML
        Optionally render to HTML (requires Markdig module)
    .EXAMPLE
        Show-MarkdownPreview -Path "README.md"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [switch]$RenderHTML
    )

    try {
        Write-Host "`nMarkdown File Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        $file = Get-Item $Path
        $content = Get-Content -Path $Path -Raw

        Write-Host "`nFile Information:" -ForegroundColor Yellow
        Write-Host "  Size: $([Math]::Round($file.Length / 1KB, 2)) KB" -ForegroundColor Green
        Write-Host "  Lines: $((Get-Content -Path $Path).Count)" -ForegroundColor Green
        Write-Host "  Characters: $($content.Length)" -ForegroundColor Green
        Write-Host "  Words: $(($content -split '\s+').Count)" -ForegroundColor Green

        Write-Host "`nDocument Structure:" -ForegroundColor Yellow

        # Count headings
        $h1Count = ([regex]::Matches($content, '^# ', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
        $h2Count = ([regex]::Matches($content, '^## ', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
        $h3Count = ([regex]::Matches($content, '^### ', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
        $h4Count = ([regex]::Matches($content, '^#### ', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count

        Write-Host "  H1 Headings: $h1Count" -ForegroundColor Green
        Write-Host "  H2 Headings: $h2Count" -ForegroundColor Green
        Write-Host "  H3 Headings: $h3Count" -ForegroundColor Green
        Write-Host "  H4 Headings: $h4Count" -ForegroundColor Green

        # Count links and images
        $linkCount = ([regex]::Matches($content, '\[([^\]]+)\]\(([^)]+)\)')).Count
        $imageCount = ([regex]::Matches($content, '!\[([^\]]*)\]\(([^)]+)\)')).Count
        $codeBlockCount = ([regex]::Matches($content, '```', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count / 2

        Write-Host "`nContent Elements:" -ForegroundColor Yellow
        Write-Host "  Links: $linkCount" -ForegroundColor Green
        Write-Host "  Images: $imageCount" -ForegroundColor Green
        Write-Host "  Code Blocks: $codeBlockCount" -ForegroundColor Green

        # Extract table of contents (H1 and H2 headings)
        $headings = [regex]::Matches($content, '^(#{1,2})\s+(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($headings.Count -gt 0) {
            Write-Host "`nTable of Contents:" -ForegroundColor Yellow
            $headingCount = [Math]::Min(10, $headings.Count)
            for ($i = 0; $i -lt $headingCount; $i++) {
                $match = $headings[$i]
                $level = $match.Groups[1].Value.Length
                $title = $match.Groups[2].Value
                $indent = "  " * $level
                Write-Host "$indent- $title" -ForegroundColor Gray
            }
            if ($headings.Count -gt 10) {
                Write-Host "  ... ($($headings.Count - 10) more headings)" -ForegroundColor DarkGray
            }
        }

        # Show content preview
        Write-Host "`nContent Preview (first 500 characters):" -ForegroundColor Yellow
        $preview = $content.Substring(0, [Math]::Min(500, $content.Length))
        Write-Host $preview -ForegroundColor Gray

        if ($content.Length -gt 500) {
            Write-Host "`n... (showing first 500 of $($content.Length) characters)" -ForegroundColor DarkGray
        }

        # HTML rendering if requested
        if ($RenderHTML) {
            if (Get-Module -ListAvailable -Name Markdig) {
                Write-Host "`nRendering HTML with Markdig..." -ForegroundColor Yellow
                Import-Module Markdig
                $html = ConvertFrom-Markdown -InputObject $content
                Write-Host "HTML rendered successfully ($($html.Length) characters)" -ForegroundColor Green
            } else {
                Write-Host "`nMarkdig module not installed. Install with:" -ForegroundColor Yellow
                Write-Host "  Install-Module -Name Markdig" -ForegroundColor Gray
            }
        }

        Write-Host "`nNote: For rendered preview, use:" -ForegroundColor Yellow
        Write-Host "  - VS Code Markdown Preview (Ctrl+Shift+V)" -ForegroundColor Gray
        Write-Host "  - Typora, Mark Text, or other Markdown editors" -ForegroundColor Gray
        Write-Host "  - ConvertFrom-Markdown (PowerShell 6+)" -ForegroundColor Gray

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview Markdown: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-STLPreview {
    <#
    .SYNOPSIS
        Shows preview of STL (3D model) files
    .DESCRIPTION
        Displays STL file metadata, triangle/vertex counts, bounding box, and file format
    .PARAMETER Path
        Path to .stl file
    .EXAMPLE
        Show-STLPreview -Path "model.stl"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    try {
        Write-Host "`nSTL 3D Model Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        $file = Get-Item $Path

        Write-Host "`nFile Information:" -ForegroundColor Yellow
        Write-Host "  Size: $([Math]::Round($file.Length / 1KB, 2)) KB" -ForegroundColor Green
        Write-Host "  Created: $($file.CreationTime)" -ForegroundColor Green
        Write-Host "  Modified: $($file.LastWriteTime)" -ForegroundColor Green

        # Determine if binary or ASCII
        $header = [System.IO.File]::ReadAllBytes($Path) | Select-Object -First 80
        $headerText = [System.Text.Encoding]::ASCII.GetString($header)
        $isBinary = -not ($headerText -match '^solid\s+')

        if ($isBinary) {
            Write-Host "`nFormat: Binary STL" -ForegroundColor Yellow

            # Read binary STL header (80 bytes) + triangle count (4 bytes)
            $bytes = [System.IO.File]::ReadAllBytes($Path)

            if ($bytes.Length -ge 84) {
                # Triangle count is at bytes 80-83 (little-endian uint32)
                $triangleCount = [BitConverter]::ToUInt32($bytes, 80)
                $vertexCount = $triangleCount * 3

                Write-Host "`nModel Statistics:" -ForegroundColor Yellow
                Write-Host "  Triangles: $($triangleCount.ToString('N0'))" -ForegroundColor Green
                Write-Host "  Vertices: $($vertexCount.ToString('N0'))" -ForegroundColor Green

                # Calculate expected file size
                $expectedSize = 84 + ($triangleCount * 50)  # 50 bytes per triangle
                $actualSize = $bytes.Length

                Write-Host "  Expected Size: $([Math]::Round($expectedSize / 1KB, 2)) KB" -ForegroundColor Green
                Write-Host "  Actual Size: $([Math]::Round($actualSize / 1KB, 2)) KB" -ForegroundColor Green

                if ($actualSize -eq $expectedSize) {
                    Write-Host "  File Integrity: Valid" -ForegroundColor Green
                } else {
                    Write-Host "  File Integrity: Warning - size mismatch" -ForegroundColor Yellow
                }

                # Estimate model complexity
                Write-Host "`nModel Complexity:" -ForegroundColor Yellow
                if ($triangleCount -lt 1000) {
                    Write-Host "  Low (< 1K triangles)" -ForegroundColor Green
                } elseif ($triangleCount -lt 10000) {
                    Write-Host "  Medium (1K - 10K triangles)" -ForegroundColor Green
                } elseif ($triangleCount -lt 100000) {
                    Write-Host "  High (10K - 100K triangles)" -ForegroundColor Yellow
                } else {
                    Write-Host "  Very High (> 100K triangles)" -ForegroundColor Yellow
                }
            }

        } else {
            Write-Host "`nFormat: ASCII STL" -ForegroundColor Yellow

            # Count triangles in ASCII format
            $content = Get-Content -Path $Path -Raw
            $triangleCount = ([regex]::Matches($content, 'facet normal', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
            $vertexCount = $triangleCount * 3

            Write-Host "`nModel Statistics:" -ForegroundColor Yellow
            Write-Host "  Triangles: $($triangleCount.ToString('N0'))" -ForegroundColor Green
            Write-Host "  Vertices: $($vertexCount.ToString('N0'))" -ForegroundColor Green

            # Extract solid name
            if ($content -match 'solid\s+(.+)') {
                $solidName = $matches[1].Trim()
                if ($solidName) {
                    Write-Host "  Model Name: $solidName" -ForegroundColor Green
                }
            }

            Write-Host "`nModel Complexity:" -ForegroundColor Yellow
            if ($triangleCount -lt 1000) {
                Write-Host "  Low (< 1K triangles)" -ForegroundColor Green
            } elseif ($triangleCount -lt 10000) {
                Write-Host "  Medium (1K - 10K triangles)" -ForegroundColor Green
            } elseif ($triangleCount -lt 100000) {
                Write-Host "  High (10K - 100K triangles)" -ForegroundColor Yellow
            } else {
                Write-Host "  Very High (> 100K triangles)" -ForegroundColor Yellow
            }
        }

        Write-Host "`nNote: For 3D visualization, use:" -ForegroundColor Yellow
        Write-Host "  - Windows 3D Viewer" -ForegroundColor Gray
        Write-Host "  - Blender (free, open-source)" -ForegroundColor Gray
        Write-Host "  - MeshLab, FreeCAD" -ForegroundColor Gray
        Write-Host "  - Online viewers: viewstl.com" -ForegroundColor Gray

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview STL: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-GCodePreview {
    <#
    .SYNOPSIS
        Shows preview of G-code files (3D printing/CNC)
    .DESCRIPTION
        Displays G-code statistics, layer count, time estimates, temperatures, and material usage
    .PARAMETER Path
        Path to .gcode file
    .EXAMPLE
        Show-GCodePreview -Path "model.gcode"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    try {
        Write-Host "`nG-code File Preview: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        $file = Get-Item $Path
        $content = Get-Content -Path $Path

        Write-Host "`nFile Information:" -ForegroundColor Yellow
        Write-Host "  Size: $([Math]::Round($file.Length / 1KB, 2)) KB" -ForegroundColor Green
        Write-Host "  Lines: $($content.Count)" -ForegroundColor Green

        # Parse G-code for metadata and statistics
        $layerCount = 0
        $printTime = $null
        $filamentUsed = $null
        $nozzleTemp = $null
        $bedTemp = $null
        $slicer = $null

        # G-code command counts
        $moveCommands = 0
        $extrudeCommands = 0

        foreach ($line in $content) {
            # Layer changes (common marker)
            if ($line -match ';LAYER:|; layer ') {
                $layerCount++
            }

            # Slicer info (usually in comments)
            if ($line -match '; generated by (.+)' -or $line -match ';Sliced by (.+)') {
                $slicer = $matches[1]
            }

            # Print time
            if ($line -match '; time = (.+)|;TIME:(\d+)') {
                if ($matches[1]) {
                    $printTime = $matches[1]
                } elseif ($matches[2]) {
                    $seconds = [int]$matches[2]
                    $hours = [Math]::Floor($seconds / 3600)
                    $minutes = [Math]::Floor(($seconds % 3600) / 60)
                    $printTime = "${hours}h ${minutes}m"
                }
            }

            # Filament used
            if ($line -match '; filament used = (.+)|;Filament used: (.+)m') {
                $filamentUsed = if ($matches[1]) { $matches[1] } else { $matches[2] + "m" }
            }

            # Temperatures
            if ($line -match 'M104 S(\d+)|M109 S(\d+)') {  # Nozzle temp
                $nozzleTemp = if ($matches[1]) { $matches[1] } else { $matches[2] }
            }
            if ($line -match 'M140 S(\d+)|M190 S(\d+)') {  # Bed temp
                $bedTemp = if ($matches[1]) { $matches[1] } else { $matches[2] }
            }

            # Command counts
            if ($line -match '^G0 |^G1 ') {
                $moveCommands++
                if ($line -match 'E[\d.-]+') {
                    $extrudeCommands++
                }
            }
        }

        Write-Host "`nSlicer Information:" -ForegroundColor Yellow
        if ($slicer) {
            Write-Host "  Generated by: $slicer" -ForegroundColor Green
        } else {
            Write-Host "  Generator: Unknown" -ForegroundColor Gray
        }

        Write-Host "`nPrint Statistics:" -ForegroundColor Yellow
        if ($layerCount -gt 0) {
            Write-Host "  Layers: $layerCount" -ForegroundColor Green
        }
        if ($printTime) {
            Write-Host "  Estimated Time: $printTime" -ForegroundColor Green
        }
        if ($filamentUsed) {
            Write-Host "  Filament Used: $filamentUsed" -ForegroundColor Green
        }

        Write-Host "`nTemperature Settings:" -ForegroundColor Yellow
        if ($nozzleTemp) {
            Write-Host "  Nozzle: ${nozzleTemp}°C" -ForegroundColor Green
        }
        if ($bedTemp) {
            Write-Host "  Bed: ${bedTemp}°C" -ForegroundColor Green
        }

        Write-Host "`nG-code Commands:" -ForegroundColor Yellow
        Write-Host "  Total Movement Commands: $($moveCommands.ToString('N0'))" -ForegroundColor Green
        Write-Host "  Extrusion Commands: $($extrudeCommands.ToString('N0'))" -ForegroundColor Green

        # Show first 10 lines of G-code
        Write-Host "`nG-code Preview (first 10 lines):" -ForegroundColor Yellow
        $previewLines = $content | Select-Object -First 10
        foreach ($line in $previewLines) {
            Write-Host "  $line" -ForegroundColor Gray
        }

        Write-Host "`nNote: For G-code visualization, use:" -ForegroundColor Yellow
        Write-Host "  - PrusaSlicer (G-code viewer mode)" -ForegroundColor Gray
        Write-Host "  - Simplify3D" -ForegroundColor Gray
        Write-Host "  - Online viewers: gcode.ws, ncviewer.com" -ForegroundColor Gray
        Write-Host "  - OctoPrint (if connected to printer)" -ForegroundColor Gray

        Write-Host ("=" * 80) -ForegroundColor Gray

    } catch {
        Write-Error "Failed to preview G-code: $_"
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Export-ModuleMember -Function Show-FilePreview, Get-FileMetadata, Show-EnhancedPreview, `
    Show-WordDocumentPreview, Show-ExcelPreview, Show-PDFPreview, Show-VideoPreview, Show-AudioPreview, `
    Show-SVGPreview, Show-MarkdownPreview, Show-STLPreview, Show-GCodePreview
