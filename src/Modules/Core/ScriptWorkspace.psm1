#Requires -Version 7.0

# Script Workspace Module - Dedicated pane for writing and executing PowerShell scripts
# Features syntax highlighting and results integration

if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Windows Forms assembly not available"
    }
}

function New-ScriptWorkspace {
    <#
    .SYNOPSIS
        Opens the script workspace interface
    .DESCRIPTION
        Provides a dedicated environment for writing and executing PowerShell scripts
        with syntax highlighting and integrated results display
    .EXAMPLE
        New-ScriptWorkspace
        Opens the script workspace
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$InitialScript = ""
    )
    
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Script Workspace - PowerShell File Manager"
        Height="800" Width="1200"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="CaretBrush" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="TabControl">
            <Setter Property="Background" Value="#252526"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="300"/>
        </Grid.RowDefinitions>
        
        <!-- Toolbar -->
        <Border Grid.Row="0" Background="#2D2D30" Padding="5">
            <StackPanel Orientation="Horizontal">
                <Button Name="RunBtn" Content="▶ Run (F5)" Padding="10,5" Margin="0,0,5,0" Background="#007ACC"/>
                <Button Name="StopBtn" Content="⏹ Stop" Padding="10,5" Margin="0,0,5,0" IsEnabled="False"/>
                <Separator Margin="10,0"/>
                <Button Name="NewBtn" Content="📄 New" Padding="10,5" Margin="0,0,5,0"/>
                <Button Name="OpenBtn" Content="📂 Open" Padding="10,5" Margin="0,0,5,0"/>
                <Button Name="SaveBtn" Content="💾 Save" Padding="10,5" Margin="0,0,5,0"/>
                <Separator Margin="10,0"/>
                <Button Name="ClearOutputBtn" Content="🗑 Clear Output" Padding="10,5"/>
            </StackPanel>
        </Border>
        
        <!-- Script Editor -->
        <Border Grid.Row="1" Background="#252526" Margin="5">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="40"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                
                <!-- Line Numbers -->
                <Border Grid.Column="0" Background="#1E1E1E" BorderBrush="#3E3E42" BorderThickness="0,0,1,0">
                    <TextBox Name="LineNumbers" 
                             FontFamily="Consolas" FontSize="14"
                             Background="Transparent" Foreground="#858585"
                             IsReadOnly="True" BorderThickness="0"
                             Padding="5" TextAlignment="Right"
                             VerticalScrollBarVisibility="Hidden"/>
                </Border>
                
                <!-- Code Editor -->
                <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                    <TextBox Name="ScriptEditor" 
                             FontFamily="Consolas" FontSize="14"
                             Background="Transparent" Foreground="#D4D4D4"
                             AcceptsReturn="True" AcceptsTab="True"
                             BorderThickness="0" Padding="10"
                             TextWrapping="NoWrap"
                             Text="$InitialScript"/>
                </ScrollViewer>
            </Grid>
        </Border>
        
        <!-- Output Panel -->
        <Grid Grid.Row="2" Margin="5">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            
            <!-- Output Tabs -->
            <TabControl Grid.Row="0" Grid.RowSpan="2" Background="#252526">
                <TabItem Header="Output">
                    <Border Background="#1E1E1E">
                        <TextBox Name="OutputBox" 
                                 FontFamily="Consolas" FontSize="12"
                                 Background="Transparent" Foreground="#CCCCCC"
                                 IsReadOnly="True" TextWrapping="Wrap"
                                 VerticalScrollBarVisibility="Auto"
                                 Padding="10"/>
                    </Border>
                </TabItem>
                <TabItem Header="Errors">
                    <Border Background="#1E1E1E">
                        <TextBox Name="ErrorBox" 
                                 FontFamily="Consolas" FontSize="12"
                                 Background="Transparent" Foreground="#F48771"
                                 IsReadOnly="True" TextWrapping="Wrap"
                                 VerticalScrollBarVisibility="Auto"
                                 Padding="10"/>
                    </Border>
                </TabItem>
                <TabItem Header="Warnings">
                    <Border Background="#1E1E1E">
                        <TextBox Name="WarningBox" 
                                 FontFamily="Consolas" FontSize="12"
                                 Background="Transparent" Foreground="#CCA700"
                                 IsReadOnly="True" TextWrapping="Wrap"
                                 VerticalScrollBarVisibility="Auto"
                                 Padding="10"/>
                    </Border>
                </TabItem>
                <TabItem Header="Verbose">
                    <Border Background="#1E1E1E">
                        <TextBox Name="VerboseBox" 
                                 FontFamily="Consolas" FontSize="12"
                                 Background="Transparent" Foreground="#4EC9B0"
                                 IsReadOnly="True" TextWrapping="Wrap"
                                 VerticalScrollBarVisibility="Auto"
                                 Padding="10"/>
                    </Border>
                </TabItem>
            </TabControl>
        </Grid>
    </Grid>
</Window>
"@
    
    try {
        $window = [Windows.Markup.XamlReader]::Parse($xaml)
        $scriptEditor = $window.FindName("ScriptEditor")
        $lineNumbers = $window.FindName("LineNumbers")
        $outputBox = $window.FindName("OutputBox")
        $errorBox = $window.FindName("ErrorBox")
        $warningBox = $window.FindName("WarningBox")
        $verboseBox = $window.FindName("VerboseBox")
        $runBtn = $window.FindName("RunBtn")
        $stopBtn = $window.FindName("StopBtn")
        $newBtn = $window.FindName("NewBtn")
        $openBtn = $window.FindName("OpenBtn")
        $saveBtn = $window.FindName("SaveBtn")
        $clearOutputBtn = $window.FindName("ClearOutputBtn")
        
        # Current script path
        $script:CurrentScriptPath = $null
        $script:CurrentRunspace = $null
        
        # Update line numbers
        $UpdateLineNumbers = {
            $lines = $scriptEditor.Text -split "`n"
            $lineNumbers.Text = (1..$lines.Count) -join "`n"
        }
        
        & $UpdateLineNumbers
        $scriptEditor.Add_TextChanged($UpdateLineNumbers)
        
        # Run button handler
        $runBtn.Add_Click({
            $scriptText = $scriptEditor.Text
            if ([string]::IsNullOrWhiteSpace($scriptText)) {
                [System.Windows.MessageBox]::Show("Please enter a script to run.", "No Script", 'OK', 'Warning')
                return
            }
            
            $outputBox.Text = ""
            $errorBox.Text = ""
            $warningBox.Text = ""
            $verboseBox.Text = ""
            
            $runBtn.IsEnabled = $false
            $stopBtn.IsEnabled = $true
            
            try {
                # Create a new runspace for isolated execution
                $script:CurrentRunspace = [PowerShell]::Create()
                $script:CurrentRunspace.AddScript($scriptText) | Out-Null
                
                # Capture streams
                $script:CurrentRunspace.Streams.Information.Add_DataAdded({
                    param($streamSender, $e)
                    $outputBox.Dispatcher.Invoke([Action]{
                        $outputBox.AppendText($streamSender[$e.Index].ToString() + "`n")
                    })
                })
                
                $script:CurrentRunspace.Streams.Error.Add_DataAdded({
                    param($streamSender, $e)
                    $errorBox.Dispatcher.Invoke([Action]{
                        $errorBox.AppendText($streamSender[$e.Index].ToString() + "`n")
                    })
                })
                
                $script:CurrentRunspace.Streams.Warning.Add_DataAdded({
                    param($streamSender, $e)
                    $warningBox.Dispatcher.Invoke([Action]{
                        $warningBox.AppendText($streamSender[$e.Index].ToString() + "`n")
                    })
                })
                
                $script:CurrentRunspace.Streams.Verbose.Add_DataAdded({
                    param($streamSender, $e)
                    $verboseBox.Dispatcher.Invoke([Action]{
                        $verboseBox.AppendText($streamSender[$e.Index].ToString() + "`n")
                    })
                })
                
                # Execute asynchronously
                $asyncResult = $script:CurrentRunspace.BeginInvoke()
                
                # Wait for completion in background
                $timer = New-Object System.Windows.Threading.DispatcherTimer
                $timer.Interval = [TimeSpan]::FromMilliseconds(100)
                $timer.Add_Tick({
                    if ($asyncResult.IsCompleted) {
                        try {
                            $results = $script:CurrentRunspace.EndInvoke($asyncResult)
                            if ($results) {
                                $outputBox.AppendText(($results | Out-String))
                            }
                            $outputBox.AppendText("`n--- Execution completed ---`n")
                        } catch {
                            $errorBox.AppendText("Execution error: $_`n")
                        } finally {
                            $script:CurrentRunspace.Dispose()
                            $script:CurrentRunspace = $null
                            $runBtn.IsEnabled = $true
                            $stopBtn.IsEnabled = $false
                            $timer.Stop()
                        }
                    }
                })
                $timer.Start()
                
            } catch {
                $errorBox.Text = "Error starting script: $_"
                $runBtn.IsEnabled = $true
                $stopBtn.IsEnabled = $false
            }
        })
        
        # Stop button handler
        $stopBtn.Add_Click({
            if ($script:CurrentRunspace) {
                $script:CurrentRunspace.Stop()
                $script:CurrentRunspace.Dispose()
                $script:CurrentRunspace = $null
                $outputBox.AppendText("`n--- Execution stopped ---`n")
                $runBtn.IsEnabled = $true
                $stopBtn.IsEnabled = $false
            }
        })
        
        # New button handler
        $newBtn.Add_Click({
            if (-not [string]::IsNullOrWhiteSpace($scriptEditor.Text)) {
                $result = [System.Windows.MessageBox]::Show("Save current script?", "New Script", 'YesNoCancel', 'Question')
                if ($result -eq 'Yes') {
                    Save-CurrentScript -Editor $scriptEditor -Path ([ref]$script:CurrentScriptPath)
                } elseif ($result -eq 'Cancel') {
                    return
                }
            }
            $scriptEditor.Text = "# New PowerShell Script`n"
            $script:CurrentScriptPath = $null
            $window.Title = "Script Workspace - PowerShell File Manager [Untitled]"
        })
        
        # Open button handler
        $openBtn.Add_Click({
            $openDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
            $openDialog.Title = "Open Script"
            
            if ($openDialog.ShowDialog() -eq 'OK') {
                $scriptEditor.Text = Get-Content -Path $openDialog.FileName -Raw
                $script:CurrentScriptPath = $openDialog.FileName
                $window.Title = "Script Workspace - PowerShell File Manager [$($openDialog.FileName)]"
            }
        })
        
        # Save button handler
        $saveBtn.Add_Click({
            Save-CurrentScript -Editor $scriptEditor -Path ([ref]$script:CurrentScriptPath) -Window $window
        })
        
        # Clear output button handler
        $clearOutputBtn.Add_Click({
            $outputBox.Clear()
            $errorBox.Clear()
            $warningBox.Clear()
            $verboseBox.Clear()
        })
        
        # F5 key handler for running script
        $window.Add_KeyDown({
            param($eventSender, $e)
            if ($e.Key -eq 'F5') {
                $runBtn.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
            }
        })
        
        $window.ShowDialog() | Out-Null
        
    } catch {
        Write-Error "Failed to create script workspace: $_"
    }
}

function Save-CurrentScript {
    param($Editor, [ref]$Path, $Window)
    
    if ($Path.Value) {
        $Editor.Text | Out-File -FilePath $Path.Value -Encoding UTF8
        if ($Window) {
            $Window.Title = "Script Workspace - PowerShell File Manager [$($Path.Value)]"
        }
    } else {
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
        $saveDialog.Title = "Save Script"
        
        if ($saveDialog.ShowDialog() -eq 'OK') {
            $Editor.Text | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
            $Path.Value = $saveDialog.FileName
            if ($Window) {
                $Window.Title = "Script Workspace - PowerShell File Manager [$($saveDialog.FileName)]"
            }
        }
    }
}

Export-ModuleMember -Function New-ScriptWorkspace
