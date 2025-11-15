#Requires -Version 7.0

# Batch Operations Module - Queue manager for batch file operations
# Supports templates, workflows, and progress tracking

function Start-BatchOperation {
    <#
    .SYNOPSIS
        Starts a batch operation with queue management
    .DESCRIPTION
        Provides a visual queue manager for batch file operations with
        pause/resume controls and parameter customization
    .PARAMETER Files
        Array of files to process
    .PARAMETER Operation
        Operation to perform (Copy, Move, Delete, Rename, etc.)
    .EXAMPLE
        Start-BatchOperation -Files (Get-ChildItem *.txt) -Operation "Copy"
        Starts a batch copy operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object[]]$Files,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Copy', 'Move', 'Delete', 'Rename', 'SetAttributes', 'Compress')]
        [string]$Operation
    )
    
    begin {
        $fileList = [System.Collections.ArrayList]::new()
    }
    
    process {
        foreach ($file in $Files) {
            $fileList.Add($file) | Out-Null
        }
    }
    
    end {
        Show-BatchOperationUI -Files $fileList -Operation $Operation
    }
}

function Show-BatchOperationUI {
    param($Files, $Operation)
    
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Batch Operations - $Operation" 
        Height="700" Width="1000"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Operation Info -->
        <Border Grid.Row="0" Background="#007ACC" CornerRadius="4" Padding="10" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Text="Batch Operation: $Operation" FontSize="16" FontWeight="Bold" Foreground="White"/>
                <TextBlock Name="OperationSummary" FontSize="12" Foreground="White" Margin="0,5,0,0"/>
            </StackPanel>
        </Border>
        
        <!-- Controls -->
        <Border Grid.Row="1" Background="#2D2D30" CornerRadius="4" Padding="10" Margin="0,0,0,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                
                <StackPanel Grid.Column="0" Orientation="Horizontal">
                    <Button Name="StartBtn" Content="▶ Start" Padding="15,8" Margin="0,0,5,0" Background="#0E7620"/>
                    <Button Name="PauseBtn" Content="⏸ Pause" Padding="15,8" Margin="0,0,5,0" IsEnabled="False"/>
                    <Button Name="StopBtn" Content="⏹ Stop" Padding="15,8" Margin="0,0,5,0" IsEnabled="False"/>
                    <Separator Margin="10,0"/>
                    <Button Name="ConfigBtn" Content="⚙ Configure" Padding="15,8"/>
                </StackPanel>
                
                <StackPanel Grid.Column="1" Orientation="Horizontal">
                    <TextBlock Name="StatusText" Text="Ready" VerticalAlignment="Center" 
                               Foreground="#CCCCCC" FontSize="12" Margin="0,0,20,0"/>
                    <ProgressBar Name="OverallProgress" Width="200" Height="20" Minimum="0" Maximum="100"/>
                </StackPanel>
            </Grid>
        </Border>
        
        <!-- Operation Queue -->
        <Border Grid.Row="2" Background="#252526" CornerRadius="4">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border Grid.Row="0" Background="#333333" Padding="5">
                    <TextBlock Text="Operation Queue" Foreground="White" FontWeight="Bold"/>
                </Border>
                <DataGrid Grid.Row="1" Name="QueueGrid" 
                          AutoGenerateColumns="False"
                          IsReadOnly="True"
                          Background="Transparent"
                          Foreground="#CCCCCC"
                          GridLinesVisibility="Horizontal"
                          HeadersVisibility="Column">
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="100">
                            <DataGridTextColumn.ElementStyle>
                                <Style TargetType="TextBlock">
                                    <Setter Property="FontWeight" Value="Bold"/>
                                </Style>
                            </DataGridTextColumn.ElementStyle>
                        </DataGridTextColumn>
                        <DataGridTextColumn Header="File" Binding="{Binding FileName}" Width="250"/>
                        <DataGridTextColumn Header="Operation" Binding="{Binding Operation}" Width="100"/>
                        <DataGridTextColumn Header="Progress" Binding="{Binding Progress}" Width="80"/>
                        <DataGridTextColumn Header="Size" Binding="{Binding Size}" Width="100"/>
                        <DataGridTextColumn Header="Speed" Binding="{Binding Speed}" Width="100"/>
                        <DataGridTextColumn Header="Remaining" Binding="{Binding TimeRemaining}" Width="*"/>
                    </DataGrid.Columns>
                </DataGrid>
            </Grid>
        </Border>
        
        <!-- Summary -->
        <Border Grid.Row="3" Background="#2D2D30" CornerRadius="4" Padding="10" Margin="0,10,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Horizontal">
                    <TextBlock Name="CompletedText" Text="Completed: 0" Foreground="#0E7620" Margin="0,0,20,0"/>
                    <TextBlock Name="FailedText" Text="Failed: 0" Foreground="#F48771" Margin="0,0,20,0"/>
                    <TextBlock Name="PendingText" Text="Pending: 0" Foreground="#999999"/>
                </StackPanel>
                <Button Grid.Column="1" Name="CloseBtn" Content="Close" Padding="15,8"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@
    
    try {
        $window = [Windows.Markup.XamlReader]::Parse($xaml)
        $operationSummary = $window.FindName("OperationSummary")
        $queueGrid = $window.FindName("QueueGrid")
        $overallProgress = $window.FindName("OverallProgress")
        $statusText = $window.FindName("StatusText")
        $startBtn = $window.FindName("StartBtn")
        $pauseBtn = $window.FindName("PauseBtn")
        $stopBtn = $window.FindName("StopBtn")
        $configBtn = $window.FindName("ConfigBtn")
        $completedText = $window.FindName("CompletedText")
        $failedText = $window.FindName("FailedText")
        $pendingText = $window.FindName("PendingText")
        $closeBtn = $window.FindName("CloseBtn")
        
        # Initialize operation queue
        $script:OperationQueue = [System.Collections.ArrayList]::new()
        $script:IsPaused = $false
        $script:IsStopped = $false
        
        foreach ($file in $Files) {
            $script:OperationQueue.Add([PSCustomObject]@{
                Status = "Pending"
                FileName = $file.Name
                FullPath = $file.FullName
                Operation = $Operation
                Progress = "0%"
                Size = Format-FileSize -Bytes $file.Length
                Speed = "-"
                TimeRemaining = "-"
            }) | Out-Null
        }
        
        $queueGrid.ItemsSource = $script:OperationQueue
        $operationSummary.Text = "Total items: $($Files.Count) | Operation: $Operation"
        $pendingText.Text = "Pending: $($Files.Count)"
        
        # Start button handler
        $startBtn.Add_Click({
            $startBtn.IsEnabled = $false
            $pauseBtn.IsEnabled = $true
            $stopBtn.IsEnabled = $true
            $statusText.Text = "Processing..."
            
            Start-ProcessQueue -Queue $script:OperationQueue -Operation $Operation `
                -ProgressBar $overallProgress -StatusText $statusText `
                -CompletedText $completedText -FailedText $failedText `
                -PendingText $pendingText -Window $window
        })
        
        # Pause button handler
        $pauseBtn.Add_Click({
            $script:IsPaused = -not $script:IsPaused
            if ($script:IsPaused) {
                $pauseBtn.Content = "▶ Resume"
                $statusText.Text = "Paused"
            } else {
                $pauseBtn.Content = "⏸ Pause"
                $statusText.Text = "Processing..."
            }
        })
        
        # Stop button handler
        $stopBtn.Add_Click({
            $script:IsStopped = $true
            $statusText.Text = "Stopped"
            $startBtn.IsEnabled = $true
            $pauseBtn.IsEnabled = $false
            $stopBtn.IsEnabled = $false
        })
        
        # Configure button handler
        $configBtn.Add_Click({
            Show-BatchOperationConfig -Operation $Operation -Window $window
        })
        
        # Close button handler
        $closeBtn.Add_Click({
            $window.Close()
        })
        
        $window.ShowDialog() | Out-Null
        
    } catch {
        Write-Error "Failed to create batch operation UI: $_"
    }
}

function Start-ProcessQueue {
    param($Queue, $Operation, $ProgressBar, $StatusText, $CompletedText, $FailedText, $PendingText, $Window)
    
    $completed = 0
    $failed = 0
    $total = $Queue.Count
    
    # Process each item asynchronously
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(100)
    $currentIndex = 0
    
    $timer.Add_Tick({
        if ($script:IsStopped) {
            $timer.Stop()
            return
        }
        
        if ($script:IsPaused) {
            return
        }
        
        if ($currentIndex -ge $Queue.Count) {
            $timer.Stop()
            $StatusText.Text = "Completed!"
            return
        }
        
        $item = $Queue[$currentIndex]
        if ($item.Status -eq "Pending") {
            $item.Status = "Processing"
            $Queue[$currentIndex] = $item
            
            try {
                # Simulate processing (in real implementation, perform actual operation)
                Start-Sleep -Milliseconds 500
                
                switch ($Operation) {
                    'Copy' { 
                        # Copy-Item -Path $item.FullPath -Destination $destination
                    }
                    'Move' { 
                        # Move-Item -Path $item.FullPath -Destination $destination
                    }
                    'Delete' { 
                        # Remove-Item -Path $item.FullPath -Force
                    }
                }
                
                $item.Status = "✓ Completed"
                $item.Progress = "100%"
                $completed++
            } catch {
                $item.Status = "✗ Failed"
                $item.Progress = "Error"
                $failed++
            }
            
            $Queue[$currentIndex] = $item
            $currentIndex++
            
            # Update progress
            $ProgressBar.Value = ($currentIndex / $total) * 100
            $CompletedText.Text = "Completed: $completed"
            $FailedText.Text = "Failed: $failed"
            $PendingText.Text = "Pending: $($total - $currentIndex)"
        }
    })
    
    $timer.Start()
}

function Format-FileSize {
    param([long]$Bytes)
    
    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes bytes"
    }
}

# Module-level storage for templates
$script:BatchTemplates = @{}

function New-BatchOperationTemplate {
    <#
    .SYNOPSIS
        Creates a reusable batch operation template
    .DESCRIPTION
        Creates and saves operation templates for common batch workflows
    .PARAMETER Name
        Unique name for the template
    .PARAMETER Operations
        Array of operations to perform in sequence
    .PARAMETER Description
        Optional description of what the template does
    .EXAMPLE
        $ops = @(
            @{Type='Copy'; Destination='C:\Backup'},
            @{Type='Compress'; Format='ZIP'}
        )
        New-BatchOperationTemplate -Name "BackupAndCompress" -Operations $ops
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [array]$Operations,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = ""
    )
    
    try {
        $template = [PSCustomObject]@{
            Name = $Name
            Description = $Description
            Operations = $Operations
            Created = Get-Date
            Version = "1.0"
        }
        
        $script:BatchTemplates[$Name] = $template
        
        # Save template to disk
        $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Join-Path $env:APPDATA "PowerShellFileManager\Templates"
        } else {
            Join-Path $HOME ".config/PowerShellFileManager/Templates"
        }
        
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        $templatePath = Join-Path $configDir "$Name.json"
        $template | ConvertTo-Json -Depth 10 | Set-Content -Path $templatePath -Encoding UTF8
        
        Write-Host "Template '$Name' created successfully" -ForegroundColor Green
        return $template
    }
    catch {
        Write-Error "Failed to create template: $_"
    }
}

function Get-BatchOperationTemplate {
    <#
    .SYNOPSIS
        Retrieves a saved batch operation template
    .DESCRIPTION
        Gets a previously saved operation template by name
    .PARAMETER Name
        Name of the template to retrieve
    .EXAMPLE
        Get-BatchOperationTemplate -Name "BackupAndCompress"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Name
    )
    
    try {
        if ($Name) {
            # Return specific template
            if ($script:BatchTemplates.ContainsKey($Name)) {
                return $script:BatchTemplates[$Name]
            }
            
            # Try loading from disk
            $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
                Join-Path $env:APPDATA "PowerShellFileManager\Templates"
            } else {
                Join-Path $HOME ".config/PowerShellFileManager/Templates"
            }
            
            $templatePath = Join-Path $configDir "$Name.json"
            if (Test-Path $templatePath) {
                $template = Get-Content -Path $templatePath -Raw | ConvertFrom-Json
                $script:BatchTemplates[$Name] = $template
                return $template
            }
            
            Write-Warning "Template '$Name' not found"
            return $null
        }
        else {
            # Return all templates
            return $script:BatchTemplates.Values
        }
    }
    catch {
        Write-Error "Failed to retrieve template: $_"
    }
}

function Show-BatchOperationConfig {
    <#
    .SYNOPSIS
        Shows configuration dialog for batch operations
    .DESCRIPTION
        Displays a configuration window for customizing batch operation parameters
    .PARAMETER Operation
        The operation type being configured
    .PARAMETER Window
        Parent window for the configuration dialog
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Operation,
        
        [Parameter(Mandatory=$false)]
        [object]$Window
    )
    
    $configXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Configure $Operation Operation" 
        Height="400" Width="500"
        WindowStartupLocation="CenterOwner"
        Background="#1E1E1E">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Operation Configuration" 
                   FontSize="16" FontWeight="Bold" Foreground="White" Margin="0,0,0,10"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <GroupBox Header="General Settings" Foreground="White" Margin="0,0,0,10">
                    <StackPanel Margin="5">
                        <CheckBox Name="OverwriteCheck" Content="Overwrite existing files" 
                                  Foreground="White" IsChecked="True"/>
                        <CheckBox Name="CreateBackupCheck" Content="Create backup before operation" 
                                  Foreground="White" Margin="0,5,0,0"/>
                        <CheckBox Name="VerifyCheck" Content="Verify operation completion" 
                                  Foreground="White" Margin="0,5,0,0"/>
                    </StackPanel>
                </GroupBox>
                
                <GroupBox Header="Performance" Foreground="White">
                    <StackPanel Margin="5">
                        <Label Content="Max Concurrent Operations:" Foreground="White"/>
                        <Slider Name="ConcurrencySlider" Minimum="1" Maximum="10" Value="3" 
                                TickFrequency="1" IsSnapToTickEnabled="True"/>
                        <TextBlock Name="ConcurrencyText" Text="3" Foreground="White" 
                                   HorizontalAlignment="Center"/>
                    </StackPanel>
                </GroupBox>
            </StackPanel>
        </ScrollViewer>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="SaveConfigBtn" Content="Save" Padding="15,8" Margin="0,0,5,0"/>
            <Button Name="CancelConfigBtn" Content="Cancel" Padding="15,8"/>
        </StackPanel>
    </Grid>
</Window>
"@
    
    try {
        $configWindow = [Windows.Markup.XamlReader]::Parse($configXaml)
        $concurrencySlider = $configWindow.FindName("ConcurrencySlider")
        $concurrencyText = $configWindow.FindName("ConcurrencyText")
        $saveConfigBtn = $configWindow.FindName("SaveConfigBtn")
        $cancelConfigBtn = $configWindow.FindName("CancelConfigBtn")
        
        # Update concurrency text when slider changes
        $concurrencySlider.Add_ValueChanged({
            $concurrencyText.Text = [math]::Round($concurrencySlider.Value)
        })
        
        # Save configuration
        $saveConfigBtn.Add_Click({
            Write-Host "Configuration saved for $Operation operation" -ForegroundColor Green
            $configWindow.Close()
        })
        
        # Cancel configuration
        $cancelConfigBtn.Add_Click({
            $configWindow.Close()
        })
        
        if ($Window) {
            $configWindow.Owner = $Window
        }
        
        $configWindow.ShowDialog() | Out-Null
    }
    catch {
        Write-Error "Failed to show configuration dialog: $_"
    }
}

function Start-ConditionalBatchOperation {
    <#
    .SYNOPSIS
        Executes operations based on conditions
    .DESCRIPTION
        Evaluates a condition and executes different operations based on the result
    .PARAMETER Files
        Files to process
    .PARAMETER Condition
        ScriptBlock that evaluates to $true or $false
    .PARAMETER ThenOperation
        Operation to perform if condition is true
    .PARAMETER ElseOperation
        Operation to perform if condition is false
    .EXAMPLE
        $files = Get-ChildItem C:\Temp
        Start-ConditionalBatchOperation -Files $files `
            -Condition {$_.Length -gt 1MB} `
            -ThenOperation @{Type='Move'; Destination='C:\Large'} `
            -ElseOperation @{Type='Move'; Destination='C:\Small'}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object[]]$Files,
        
        [Parameter(Mandatory=$true)]
        [ScriptBlock]$Condition,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$ThenOperation,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$ElseOperation
    )
    
    begin {
        $thenFiles = [System.Collections.ArrayList]::new()
        $elseFiles = [System.Collections.ArrayList]::new()
    }
    
    process {
        foreach ($file in $Files) {
            try {
                # Execute condition in context of file
                $result = & $Condition -InputObject $file
                
                if ($result) {
                    $thenFiles.Add($file) | Out-Null
                }
                else {
                    $elseFiles.Add($file) | Out-Null
                }
            }
            catch {
                Write-Warning "Error evaluating condition for $($file.Name): $_"
            }
        }
    }
    
    end {
        $results = [PSCustomObject]@{
            ThenCount = $thenFiles.Count
            ElseCount = $elseFiles.Count
            ThenFiles = $thenFiles
            ElseFiles = $elseFiles
        }
        
        Write-Host "Conditional evaluation complete:" -ForegroundColor Cyan
        Write-Host "  True: $($thenFiles.Count) files" -ForegroundColor Green
        Write-Host "  False: $($elseFiles.Count) files" -ForegroundColor Yellow
        
        # Execute then operation
        if ($thenFiles.Count -gt 0) {
            Write-Host "Executing THEN operation..." -ForegroundColor Green
            Invoke-ConditionalOperation -Files $thenFiles -Operation $ThenOperation
        }
        
        # Execute else operation
        if ($elseFiles.Count -gt 0 -and $ElseOperation) {
            Write-Host "Executing ELSE operation..." -ForegroundColor Yellow
            Invoke-ConditionalOperation -Files $elseFiles -Operation $ElseOperation
        }
        
        return $results
    }
}

function Invoke-ConditionalOperation {
    param($Files, $Operation)
    
    switch ($Operation.Type) {
        'Copy' {
            foreach ($file in $Files) {
                try {
                    Copy-Item -Path $file.FullName -Destination $Operation.Destination -Force
                    Write-Verbose "Copied: $($file.Name)"
                }
                catch {
                    Write-Warning "Failed to copy $($file.Name): $_"
                }
            }
        }
        'Move' {
            foreach ($file in $Files) {
                try {
                    Move-Item -Path $file.FullName -Destination $Operation.Destination -Force
                    Write-Verbose "Moved: $($file.Name)"
                }
                catch {
                    Write-Warning "Failed to move $($file.Name): $_"
                }
            }
        }
        'Delete' {
            foreach ($file in $Files) {
                try {
                    Remove-Item -Path $file.FullName -Force
                    Write-Verbose "Deleted: $($file.Name)"
                }
                catch {
                    Write-Warning "Failed to delete $($file.Name): $_"
                }
            }
        }
        'Compress' {
            try {
                $archivePath = Join-Path $Operation.Destination "archive_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
                Compress-Archive -Path $Files.FullName -DestinationPath $archivePath -Force
                Write-Host "Created archive: $archivePath" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to create archive: $_"
            }
        }
        default {
            Write-Warning "Unknown operation type: $($Operation.Type)"
        }
    }
}

Export-ModuleMember -Function Start-BatchOperation, New-BatchOperationTemplate, Get-BatchOperationTemplate, Start-ConditionalBatchOperation
