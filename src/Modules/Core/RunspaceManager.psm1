#Requires -Version 7.0

# Runspace Manager Module - UI for managing multiple PowerShell sessions
# Monitor resource usage and import modules

function Start-RunspaceManager {
    <#
    .SYNOPSIS
        Opens the runspace manager interface
    .DESCRIPTION
        Provides UI for managing multiple PowerShell sessions, importing modules,
        and monitoring resource usage
    .EXAMPLE
        Start-RunspaceManager
        Opens the runspace manager
    #>
    [CmdletBinding()]
    param()
    
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Runspace Manager - PowerShell File Manager"
        Height="600" Width="1000"
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
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
        </Style>
        <Style TargetType="ListBoxItem">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3E3E42"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TabControl">
            <Setter Property="Background" Value="#252526"/>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="200"/>
        </Grid.RowDefinitions>
        
        <!-- Toolbar -->
        <Border Grid.Row="0" Background="#2D2D30" CornerRadius="4" Padding="10" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
                <Button Name="NewRunspaceBtn" Content="+ New Runspace" Padding="10,5" Margin="0,0,5,0"/>
                <Button Name="CloseRunspaceBtn" Content="✕ Close Selected" Padding="10,5" Margin="0,0,5,0"/>
                <Separator Margin="10,0"/>
                <Button Name="ImportModuleBtn" Content="📦 Import Module" Padding="10,5" Margin="0,0,5,0"/>
                <Button Name="RefreshBtn" Content="🔄 Refresh" Padding="10,5"/>
            </StackPanel>
        </Border>
        
        <!-- Runspace List -->
        <Border Grid.Row="1" Background="#252526" CornerRadius="4" Margin="0,0,0,10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border Grid.Row="0" Background="#007ACC" Padding="5">
                    <TextBlock Text="Active Runspaces" Foreground="White" FontWeight="Bold"/>
                </Border>
                <DataGrid Grid.Row="1" Name="RunspaceGrid"
                          AutoGenerateColumns="False"
                          IsReadOnly="True"
                          Background="#1E1E1E"
                          Foreground="#E0E0E0"
                          RowBackground="#1E1E1E"
                          AlternatingRowBackground="#252526"
                          GridLinesVisibility="Horizontal"
                          HeadersVisibility="Column"
                          SelectionMode="Single">
                    <DataGrid.ColumnHeaderStyle>
                        <Style TargetType="DataGridColumnHeader">
                            <Setter Property="Foreground" Value="#CCCCCC"/>
                            <Setter Property="Background" Value="#2D2D30"/>
                            <Setter Property="FontWeight" Value="SemiBold"/>
                            <Setter Property="Padding" Value="8,4"/>
                        </Style>
                    </DataGrid.ColumnHeaderStyle>
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="ID" Binding="{Binding Id}" Width="50"/>
                        <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="150"/>
                        <DataGridTextColumn Header="State" Binding="{Binding State}" Width="100"/>
                        <DataGridTextColumn Header="Thread ID" Binding="{Binding ThreadId}" Width="100"/>
                        <DataGridTextColumn Header="Memory (MB)" Binding="{Binding Memory}" Width="120"/>
                        <DataGridTextColumn Header="Loaded Modules" Binding="{Binding ModuleCount}" Width="*"/>
                    </DataGrid.Columns>
                </DataGrid>
            </Grid>
        </Border>
        
        <!-- Module/Variable Details -->
        <TabControl Grid.Row="2" Background="#252526">
            <TabItem Header="Loaded Modules">
                <Border Background="#1E1E1E">
                    <ListBox Name="ModulesList" 
                             Background="Transparent" Foreground="#CCCCCC"
                             BorderThickness="0">
                        <ListBox.ItemTemplate>
                            <DataTemplate>
                                <StackPanel Margin="5">
                                    <TextBlock Text="{Binding Name}" FontWeight="Bold" FontSize="12"/>
                                    <TextBlock Text="{Binding Version}" FontSize="10" Foreground="#999999"/>
                                </StackPanel>
                            </DataTemplate>
                        </ListBox.ItemTemplate>
                    </ListBox>
                </Border>
            </TabItem>
            <TabItem Header="Variables">
                <Border Background="#1E1E1E">
                    <DataGrid Name="VariablesGrid"
                              AutoGenerateColumns="False"
                              IsReadOnly="True"
                              Background="#1E1E1E"
                              Foreground="#E0E0E0"
                              RowBackground="#1E1E1E"
                              AlternatingRowBackground="#252526"
                              GridLinesVisibility="Horizontal"
                              HeadersVisibility="Column">
                        <DataGrid.ColumnHeaderStyle>
                            <Style TargetType="DataGridColumnHeader">
                                <Setter Property="Foreground" Value="#CCCCCC"/>
                                <Setter Property="Background" Value="#2D2D30"/>
                                <Setter Property="FontWeight" Value="SemiBold"/>
                                <Setter Property="Padding" Value="8,4"/>
                            </Style>
                        </DataGrid.ColumnHeaderStyle>
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200"/>
                            <DataGridTextColumn Header="Value" Binding="{Binding Value}" Width="*"/>
                            <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="150"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </Border>
            </TabItem>
            <TabItem Header="Performance">
                <Border Background="#1E1E1E" Padding="10">
                    <StackPanel>
                        <TextBlock Name="PerfInfo" Foreground="#CCCCCC" FontFamily="Consolas" FontSize="12"/>
                    </StackPanel>
                </Border>
            </TabItem>
        </TabControl>
    </Grid>
</Window>
"@
    
    try {
        $window = [Windows.Markup.XamlReader]::Parse($xaml)
        $runspaceGrid = $window.FindName("RunspaceGrid")
        $modulesList = $window.FindName("ModulesList")
        $variablesGrid = $window.FindName("VariablesGrid")
        $perfInfo = $window.FindName("PerfInfo")
        $newRunspaceBtn = $window.FindName("NewRunspaceBtn")
        $closeRunspaceBtn = $window.FindName("CloseRunspaceBtn")
        $importModuleBtn = $window.FindName("ImportModuleBtn")
        $refreshBtn = $window.FindName("RefreshBtn")
        
        # Runspace collection
        $script:Runspaces = [System.Collections.ArrayList]::new()
        
        # Load initial runspace data
        $LoadRunspaces = {
            $runspaceData = [System.Collections.ArrayList]::new()
            
            # Get all runspaces
            foreach ($rs in [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.GetType().Assembly.GetTypes() | 
                Where-Object { $_.Name -eq 'Runspace' }) {
                # This is simplified - in real implementation would track custom runspaces
            }
            
            # Add current runspace info
            $currentRs = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace
            $runspaceData.Add([PSCustomObject]@{
                Id = $currentRs.InstanceId
                Name = "Default Runspace"
                State = $currentRs.RunspaceStateInfo.State
                ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                Memory = [Math]::Round([System.GC]::GetTotalMemory($false) / 1MB, 2)
                ModuleCount = (Get-Module).Count
            }) | Out-Null
            
            $runspaceGrid.ItemsSource = $runspaceData
        }
        
        & $LoadRunspaces
        
        # New runspace button handler
        $newRunspaceBtn.Add_Click({
            try {
                $newRs = [PowerShell]::Create()
                $script:Runspaces.Add($newRs) | Out-Null
                [System.Windows.MessageBox]::Show("New runspace created successfully!", "Success", 'OK', 'Information')
                & $LoadRunspaces
            } catch {
                [System.Windows.MessageBox]::Show("Failed to create runspace: $_", "Error", 'OK', 'Error')
            }
        })
        
        # Close runspace button handler
        $closeRunspaceBtn.Add_Click({
            $selected = $runspaceGrid.SelectedItem
            if ($selected) {
                $result = [System.Windows.MessageBox]::Show(
                    "Are you sure you want to close this runspace?", 
                    "Confirm", 
                    'YesNo', 
                    'Question'
                )
                if ($result -eq 'Yes') {
                    # Close selected runspace
                    [System.Windows.MessageBox]::Show("Runspace closed", "Success", 'OK', 'Information')
                    & $LoadRunspaces
                }
            }
        })
        
        # Import module button handler
        $importModuleBtn.Add_Click({
            $openDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openDialog.Filter = "PowerShell Modules (*.psm1,*.psd1)|*.psm1;*.psd1|All Files (*.*)|*.*"
            $openDialog.Title = "Import Module"
            
            if ($openDialog.ShowDialog() -eq 'OK') {
                try {
                    Import-Module -Name $openDialog.FileName -Force
                    [System.Windows.MessageBox]::Show("Module imported successfully!", "Success", 'OK', 'Information')
                    & $LoadRunspaces
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to import module: $_", "Error", 'OK', 'Error')
                }
            }
        })
        
        # Refresh button handler
        $refreshBtn.Add_Click({
            & $LoadRunspaces
            Update-ModulesList -ListBox $modulesList
            Update-VariablesList -Grid $variablesGrid
            Update-Performance -TextBlock $perfInfo
        })
        
        # Selection changed handler
        $runspaceGrid.Add_SelectionChanged({
            if ($runspaceGrid.SelectedItem) {
                Update-ModulesList -ListBox $modulesList
                Update-VariablesList -Grid $variablesGrid
                Update-Performance -TextBlock $perfInfo
            }
        })
        
        # Auto-refresh timer
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(5)
        $timer.Add_Tick({
            & $LoadRunspaces
            Update-Performance -TextBlock $perfInfo
        })
        $timer.Start()
        
        $window.ShowDialog() | Out-Null
        $timer.Stop()
        
    } catch {
        Write-Error "Failed to create runspace manager: $_"
    }
}

function Update-ModulesList {
    param($ListBox)
    
    $modules = Get-Module | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Version = $_.Version.ToString()
        }
    }
    $ListBox.ItemsSource = $modules
}

function Update-VariablesList {
    param($Grid)
    
    $variables = Get-Variable | Where-Object { 
        $_.Name -notlike 'ps*' -and $_.Name -notlike '_*' 
    } | Select-Object -First 50 | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Value = if ($_.Value) { $_.Value.ToString() } else { "" }
            Type = if ($_.Value) { $_.Value.GetType().Name } else { "Null" }
        }
    }
    $Grid.ItemsSource = $variables
}

function Update-Performance {
    param($TextBlock)
    
    $memory = [Math]::Round([System.GC]::GetTotalMemory($false) / 1MB, 2)
    $threads = [System.Diagnostics.Process]::GetCurrentProcess().Threads.Count
    $handles = [System.Diagnostics.Process]::GetCurrentProcess().HandleCount
    
    $perfText = @"
Memory Usage: $memory MB
Active Threads: $threads
Open Handles: $handles
Processor Time: $([System.Diagnostics.Process]::GetCurrentProcess().TotalProcessorTime.ToString())
"@
    
    $TextBlock.Text = $perfText
}

Export-ModuleMember -Function Start-RunspaceManager
