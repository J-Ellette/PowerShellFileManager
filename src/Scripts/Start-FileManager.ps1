#Requires -Version 7.0

<#
.SYNOPSIS
    PowerShell File Manager V2.0 - Main Application
.DESCRIPTION
    Command-centric file manager with rich PowerShell integration
    Features GUI with command palette, query builder, and extensive file operations
.EXAMPLE
    Start-FileManager
    Launches the file manager application
#>

# Import required assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

function Start-FileManager {
    <#
    .SYNOPSIS
        Launches the PowerShell File Manager V2.0
    .DESCRIPTION
        Opens the main file manager GUI with all features
    .EXAMPLE
        Start-FileManager
        Starts the file manager
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$InitialPath = $pwd
    )
    
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell File Manager V2.0" 
        Height="900" Width="1400"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="2"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="Menu">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="MenuItem">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="ContextMenu">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
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
    </Window.Resources>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="250"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Menu Bar -->
        <Menu Grid.Row="0">
            <MenuItem Header="File">
                <MenuItem Header="Open Command Palette (Ctrl+P)" Name="MenuCommandPalette"/>
                <MenuItem Header="Query Builder" Name="MenuQueryBuilder"/>
                <MenuItem Header="Script Workspace" Name="MenuScriptWorkspace"/>
                <Separator/>
                <MenuItem Header="Exit" Name="MenuExit"/>
            </MenuItem>
            <MenuItem Header="View">
                <MenuItem Header="Object Inspector" Name="MenuObjectInspector"/>
                <MenuItem Header="Runspace Manager" Name="MenuRunspaceManager"/>
                <MenuItem Header="Refresh (F5)" Name="MenuRefresh"/>
            </MenuItem>
            <MenuItem Header="Operations">
                <MenuItem Header="Batch Operations" Name="MenuBatchOps"/>
                <MenuItem Header="Find Duplicates" Name="MenuFindDuplicates"/>
                <MenuItem Header="Sync Directories" Name="MenuSyncDirs"/>
                <MenuItem Header="Disk Space Analyzer" Name="MenuDiskAnalyzer"/>
                <Separator/>
                <MenuItem Header="Archive Operations" Name="MenuArchive">
                    <MenuItem Header="Create Archive" Name="MenuCreateArchive"/>
                    <MenuItem Header="Extract Archive" Name="MenuExtractArchive"/>
                    <MenuItem Header="View Archive Contents" Name="MenuViewArchive"/>
                </MenuItem>
                <MenuItem Header="Advanced Search" Name="MenuAdvancedSearch"/>
            </MenuItem>
            <MenuItem Header="Tools">
                <MenuItem Header="Git Status" Name="MenuGitStatus"/>
                <MenuItem Header="Connect FTP/SFTP" Name="MenuConnect"/>
                <MenuItem Header="Metadata Editor" Name="MenuMetadataEditor"/>
                <Separator/>
                <MenuItem Header="PowerToys" Name="MenuPowerToys">
                    <MenuItem Header="Image Resizer" Name="MenuImageResizer"/>
                    <MenuItem Header="Text Extractor (OCR)" Name="MenuTextExtractor"/>
                    <MenuItem Header="Color Picker" Name="MenuColorPicker"/>
                    <MenuItem Header="Hosts File Editor" Name="MenuHostsEditor"/>
                    <MenuItem Header="Quick Accent" Name="MenuQuickAccent"/>
                    <MenuItem Header="Keyboard Shortcuts" Name="MenuShortcutGuide"/>
                    <MenuItem Header="Workspace Layouts" Name="MenuWorkspaceLayouts"/>
                    <MenuItem Header="Template Manager" Name="MenuTemplateManager"/>
                    <MenuItem Header="Awake Mode" Name="MenuAwakeMode"/>
                    <MenuItem Header="PowerRename" Name="MenuPowerRename"/>
                </MenuItem>
                <Separator/>
                <MenuItem Header="Security" Name="MenuSecurity">
                    <MenuItem Header="View File ACL" Name="MenuViewACL"/>
                    <MenuItem Header="Edit File ACL" Name="MenuEditACL"/>
                    <MenuItem Header="Secure Delete" Name="MenuSecureDelete"/>
                </MenuItem>
                <Separator/>
                <MenuItem Header="Plugins" Name="MenuPlugins"/>
            </MenuItem>
            <MenuItem Header="Help">
                <MenuItem Header="About" Name="MenuAbout"/>
                <MenuItem Header="Documentation" Name="MenuDocs"/>
            </MenuItem>
        </Menu>
        
        <!-- Toolbar -->
        <Border Grid.Row="1" Background="#2D2D30" Padding="5">
            <StackPanel Orientation="Horizontal">
                <Button Name="BtnBack" Content="← Back" ToolTip="Navigate back (Alt+Left)"/>
                <Button Name="BtnForward" Content="Forward →" ToolTip="Navigate forward (Alt+Right)"/>
                <Button Name="BtnUp" Content="↑ Up" ToolTip="Go up one level (Backspace)"/>
                <Separator Margin="10,0"/>
                <Button Name="BtnCommandPalette" Content="🔍 Command Palette (Ctrl+P)" Background="#007ACC" ToolTip="Open Command Palette (Ctrl+P)"/>
                <Button Name="BtnQueryBuilder" Content="🔧 Query Builder" ToolTip="Build complex queries"/>
                <Button Name="BtnRefresh" Content="🔄 Refresh" ToolTip="Refresh current directory (F5)"/>
                <Separator Margin="10,0"/>
                <TextBlock Text="Filter:" VerticalAlignment="Center" Margin="5,0"/>
                <TextBox Name="QuickFilter" Width="200" Margin="5,0" 
                         Background="#1E1E1E" Foreground="#CCCCCC" BorderThickness="1" 
                         BorderBrush="#3E3E42" Padding="5"
                         ToolTip="Filter files as you type"/>
                <Button Name="BtnClearFilter" Content="✖" ToolTip="Clear filter" Padding="5"/>
                <Separator Margin="10,0"/>
                <Button Name="BtnNewFolder" Content="📁 New Folder" ToolTip="Create a new folder"/>
                <Button Name="BtnDelete" Content="🗑 Delete" ToolTip="Delete selected items (Delete)"/>
                <Button Name="BtnProperties" Content="ℹ Properties" ToolTip="Show properties of selected item"/>
            </StackPanel>
        </Border>
        
        <!-- Address Bar -->
        <Border Grid.Row="2" Background="#252526" Padding="5">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="Path:" VerticalAlignment="Center" Margin="5,0"/>
                <Border Grid.Column="1" Background="#1E1E1E" BorderBrush="#3E3E42" BorderThickness="1" Margin="5,0">
                    <StackPanel Name="BreadcrumbPanel" Orientation="Horizontal" Background="Transparent">
                        <TextBox Name="AddressBar" FontFamily="Consolas" FontSize="14"
                                 Background="Transparent" Foreground="#CCCCCC" BorderThickness="0" 
                                 Padding="5" Visibility="Collapsed"/>
                    </StackPanel>
                </Border>
                <Button Grid.Column="2" Name="BtnGo" Content="Go" Padding="15,5" ToolTip="Navigate to path"/>
            </Grid>
        </Border>
        
        <!-- Main Content Area -->
        <Grid Grid.Row="3">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="300"/>
            </Grid.ColumnDefinitions>
            
            <!-- File List -->
            <Border Grid.Column="0" Background="#252526" Margin="5">
                <DataGrid Name="FileGrid"
                          AutoGenerateColumns="False"
                          IsReadOnly="True"
                          AllowDrop="True"
                          Background="#1E1E1E"
                          Foreground="#E0E0E0"
                          GridLinesVisibility="Horizontal"
                          HeadersVisibility="Column"
                          RowBackground="#1E1E1E"
                          AlternatingRowBackground="#252526"
                          SelectionMode="Extended">
                    <DataGrid.ContextMenu>
                        <ContextMenu>
                            <MenuItem Header="Open" Name="CtxOpen"/>
                            <MenuItem Header="Preview" Name="CtxPreview"/>
                            <Separator/>
                            <MenuItem Header="Copy (Ctrl+C)" Name="CtxCopy"/>
                            <MenuItem Header="Cut (Ctrl+X)" Name="CtxCut"/>
                            <MenuItem Header="Paste (Ctrl+V)" Name="CtxPaste"/>
                            <Separator/>
                            <MenuItem Header="Delete (Del)" Name="CtxDelete"/>
                            <MenuItem Header="Rename (F2)" Name="CtxRename"/>
                            <Separator/>
                            <MenuItem Header="Properties" Name="CtxProperties"/>
                        </ContextMenu>
                    </DataGrid.ContextMenu>
                    <DataGrid.ColumnHeaderStyle>
                        <Style TargetType="DataGridColumnHeader">
                            <Setter Property="Foreground" Value="#CCCCCC"/>
                            <Setter Property="Background" Value="#2D2D30"/>
                            <Setter Property="FontWeight" Value="SemiBold"/>
                            <Setter Property="Padding" Value="8,4"/>
                        </Style>
                    </DataGrid.ColumnHeaderStyle>
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="*">
                            <DataGridTextColumn.ElementStyle>
                                <Style TargetType="TextBlock">
                                    <Setter Property="Foreground" Value="#E0E0E0"/>
                                    <Setter Property="ToolTip" Value="{Binding Name}"/>
                                </Style>
                            </DataGridTextColumn.ElementStyle>
                        </DataGridTextColumn>
                        <DataGridTextColumn Header="Type" Binding="{Binding Extension}" Width="100">
                            <DataGridTextColumn.ElementStyle>
                                <Style TargetType="TextBlock">
                                    <Setter Property="Foreground" Value="#E0E0E0"/>
                                </Style>
                            </DataGridTextColumn.ElementStyle>
                        </DataGridTextColumn>
                        <DataGridTextColumn Header="Size" Binding="{Binding Size}" Width="120">
                            <DataGridTextColumn.ElementStyle>
                                <Style TargetType="TextBlock">
                                    <Setter Property="Foreground" Value="#E0E0E0"/>
                                </Style>
                            </DataGridTextColumn.ElementStyle>
                        </DataGridTextColumn>
                        <DataGridTextColumn Header="Modified" Binding="{Binding LastWriteTime}" Width="150">
                            <DataGridTextColumn.ElementStyle>
                                <Style TargetType="TextBlock">
                                    <Setter Property="Foreground" Value="#E0E0E0"/>
                                </Style>
                            </DataGridTextColumn.ElementStyle>
                        </DataGridTextColumn>
                        <DataGridTextColumn Header="Attributes" Binding="{Binding Attributes}" Width="150">
                            <DataGridTextColumn.ElementStyle>
                                <Style TargetType="TextBlock">
                                    <Setter Property="Foreground" Value="#E0E0E0"/>
                                </Style>
                            </DataGridTextColumn.ElementStyle>
                        </DataGridTextColumn>
                    </DataGrid.Columns>
                </DataGrid>
            </Border>
            
            <GridSplitter Grid.Column="1" Width="5" Background="#3E3E42" HorizontalAlignment="Center"/>
            
            <!-- Side Panel -->
            <TabControl Grid.Column="2" Background="#252526" Margin="5">
                <TabItem Header="Preview">
                    <Border Background="#1E1E1E" Padding="10">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <TextBlock Name="PreviewPanel" FontFamily="Consolas" FontSize="12"
                                     TextWrapping="Wrap" Text="Select a file to preview"/>
                        </ScrollViewer>
                    </Border>
                </TabItem>
                <TabItem Header="Properties">
                    <Border Background="#1E1E1E" Padding="10">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel Name="PropertiesPanel">
                                <TextBlock Text="Select a file to view properties"/>
                            </StackPanel>
                        </ScrollViewer>
                    </Border>
                </TabItem>
                <TabItem Header="History">
                    <Border Background="#1E1E1E" Padding="10">
                        <ListBox Name="HistoryList" Background="Transparent" Foreground="#CCCCCC"
                                BorderThickness="0"/>
                    </Border>
                </TabItem>
            </TabControl>
        </Grid>
        
        <!-- Output Panel -->
        <TabControl Grid.Row="4" Background="#252526" Margin="5">
            <TabItem Header="Console Output">
                <Border Background="#1E1E1E">
                    <TextBox Name="ConsoleOutput" 
                             FontFamily="Consolas" FontSize="12"
                             Background="Transparent" Foreground="#CCCCCC"
                             IsReadOnly="True" TextWrapping="Wrap"
                             VerticalScrollBarVisibility="Auto"
                             Padding="10"
                             Text="PowerShell File Manager V2.0 initialized..."/>
                </Border>
            </TabItem>
            <TabItem Header="Background Operations">
                <Border Background="#1E1E1E">
                    <DataGrid Name="BackgroundOpsGrid"
                              AutoGenerateColumns="True"
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
                    </DataGrid>
                </Border>
            </TabItem>
        </TabControl>
        
        <!-- Status Bar -->
        <Border Grid.Row="5" Background="#007ACC" Padding="5">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Name="StatusText" Text="Ready" Foreground="White"/>
                <TextBlock Grid.Column="1" Name="ItemCountText" Text="0 items" Foreground="White" Margin="20,0"/>
                <TextBlock Grid.Column="2" Name="SelectionText" Text="" Foreground="White" Margin="20,0"/>
                <TextBlock Grid.Column="3" Name="FilterStatusText" Text="" Foreground="White" Margin="20,0"/>
                <TextBlock Grid.Column="4" Name="BackgroundOpsText" Text="" Foreground="White" Margin="20,0"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@
    
    try {
        $window = [Windows.Markup.XamlReader]::Parse($xaml)
        
        # Get UI controls
        $fileGrid = $window.FindName("FileGrid")
        $addressBar = $window.FindName("AddressBar")
        $breadcrumbPanel = $window.FindName("BreadcrumbPanel")
        $consoleOutput = $window.FindName("ConsoleOutput")
        $statusText = $window.FindName("StatusText")
        $itemCountText = $window.FindName("ItemCountText")
        $selectionText = $window.FindName("SelectionText")
        $filterStatusText = $window.FindName("FilterStatusText")
        $backgroundOpsText = $window.FindName("BackgroundOpsText")
        $previewPanel = $window.FindName("PreviewPanel")
        $historyList = $window.FindName("HistoryList")
        $quickFilter = $window.FindName("QuickFilter")
        
        # Get context menu items
        $ctxOpen = $fileGrid.ContextMenu.Items | Where-Object { $_.Name -eq "CtxOpen" }
        $ctxPreview = $fileGrid.ContextMenu.Items | Where-Object { $_.Name -eq "CtxPreview" }
        $ctxCopy = $fileGrid.ContextMenu.Items | Where-Object { $_.Name -eq "CtxCopy" }
        $ctxCut = $fileGrid.ContextMenu.Items | Where-Object { $_.Name -eq "CtxCut" }
        $ctxPaste = $fileGrid.ContextMenu.Items | Where-Object { $_.Name -eq "CtxPaste" }
        $ctxDelete = $fileGrid.ContextMenu.Items | Where-Object { $_.Name -eq "CtxDelete" }
        $ctxRename = $fileGrid.ContextMenu.Items | Where-Object { $_.Name -eq "CtxRename" }
        $ctxProperties = $fileGrid.ContextMenu.Items | Where-Object { $_.Name -eq "CtxProperties" }
        
        # Clipboard for copy/cut/paste operations
        $script:ClipboardItems = @()
        $script:ClipboardOperation = $null  # 'Copy' or 'Cut'
        $script:AllItems = @()  # Store all items for filtering
        
        # Function to update breadcrumb navigation
        function Update-Breadcrumbs {
            param([string]$Path)
            
            $breadcrumbPanel.Children.Clear()
            
            # Split path into segments
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
                # Windows path: C:\Users\Documents
                $parts = @()
                $current = $Path
                while ($current) {
                    $parent = Split-Path $current -Parent
                    if ($parent) {
                        $parts += Split-Path $current -Leaf
                        $current = $parent
                    } else {
                        $parts += $current
                        break
                    }
                }
                $parts = $parts[$parts.Length..0]  # Reverse
            } else {
                # Unix path: /home/user/documents
                $parts = $Path -split '/' | Where-Object { $_ }
                $parts = @('/') + $parts
            }
            
            $fullPath = ""
            foreach ($i in 0..($parts.Length - 1)) {
                $part = $parts[$i]
                
                # Build full path for this segment
                if ($i -eq 0 -and ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6)) {
                    $fullPath = $part
                } elseif ($i -eq 0) {
                    $fullPath = $part
                } else {
                    $fullPath = Join-Path $fullPath $part
                }
                
                # Create button for each segment
                $btn = New-Object System.Windows.Controls.Button
                $btn.Content = $part
                $btn.Background = [System.Windows.Media.Brushes]::Transparent
                $btn.Foreground = [System.Windows.Media.Brushes]::LightGray
                $btn.BorderThickness = 0
                $btn.Padding = "5,2"
                $btn.Cursor = [System.Windows.Input.Cursors]::Hand
                $btn.Tag = $fullPath
                
                $btn.Add_Click({
                    param($btnSender, $e)
                    $clickedPath = $btnSender.Tag
                    $script:CurrentPath = $clickedPath
                    $addressBar.Text = $clickedPath
                    & $LoadDirectory $clickedPath
                })
                
                $breadcrumbPanel.Children.Add($btn) | Out-Null
                
                # Add separator if not last
                if ($i -lt $parts.Length - 1) {
                    $sep = New-Object System.Windows.Controls.TextBlock
                    $sep.Text = ">"
                    $sep.Foreground = [System.Windows.Media.Brushes]::Gray
                    $sep.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                    $sep.Margin = "2,0"
                    $breadcrumbPanel.Children.Add($sep) | Out-Null
                }
            }
        }
        
        # Navigation state
        $script:CurrentPath = $InitialPath
        $addressBar.Text = $script:CurrentPath
        
        # Helper function for formatting file sizes
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
        
        # Load initial directory
        $LoadDirectory = {
            param($path)
            
            try {
                $items = Get-ChildItem -Path $path -ErrorAction Stop | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.Name
                        FullName = $_.FullName
                        Extension = $_.Extension
                        Size = if ($_.PSIsContainer) { "<DIR>" } else { Format-FileSize $_.Length }
                        SizeBytes = if ($_.PSIsContainer) { 0 } else { $_.Length }
                        LastWriteTime = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                        Attributes = $_.Attributes.ToString()
                        IsDirectory = $_.PSIsContainer
                    }
                }
                
                $script:AllItems = $items
                $fileGrid.ItemsSource = $items
                $itemCountText.Text = "$($items.Count) items"
                $statusText.Text = "Loaded: $path"
                $consoleOutput.AppendText("`nNavigated to: $path")
                
                # Update breadcrumbs
                Update-Breadcrumbs -Path $path
                $addressBar.Text = $path
                
                # Clear filter
                $quickFilter.Text = ""
                $filterStatusText.Text = ""
                
                # Add to history
                Add-NavigationHistory -Path $path
                $historyList.ItemsSource = Get-NavigationHistory
                
            } catch {
                $statusText.Text = "Error: $_"
                $consoleOutput.AppendText("`nError loading directory: $_")
            }
        }
        
        & $LoadDirectory $script:CurrentPath
        
        # Click on breadcrumb panel to edit path manually
        $breadcrumbPanel.Add_MouseLeftButtonDown({
            param($control, $e)
            $breadcrumbPanel.Visibility = [System.Windows.Visibility]::Collapsed
            $addressBar.Visibility = [System.Windows.Visibility]::Visible
            $addressBar.Focus()
            $addressBar.SelectAll()
        })
        # When addressbar loses focus, switch back to breadcrumbs
        $addressBar.Add_LostFocus({
            param($control, $e)
            $breadcrumbPanel.Visibility = [System.Windows.Visibility]::Visible
            $addressBar.Visibility = [System.Windows.Visibility]::Collapsed
        })
        # Enter key in address bar
        $addressBar.Add_KeyDown({
            param($control, $e)
            if ($e.Key -eq 'Return' -or $e.Key -eq 'Enter') {
                $path = $addressBar.Text
                if (Test-Path $path) {
                    $script:CurrentPath = $path
                    & $LoadDirectory $path
                } else {
                    [System.Windows.MessageBox]::Show("Path not found: $path", "Error", 'OK', 'Error')
                }
                $breadcrumbPanel.Focus()
            }
        })
        
        # Button handlers
        $window.FindName("BtnCommandPalette").Add_Click({
            $consoleOutput.AppendText("`nOpening Command Palette...")
            Invoke-CommandPalette
        })
        
        $window.FindName("BtnQueryBuilder").Add_Click({
            $consoleOutput.AppendText("`nOpening Query Builder...")
            $results = New-QueryBuilder -InitialPath $script:CurrentPath
            if ($results) {
                $fileGrid.ItemsSource = $results
            }
        })
        
        $window.FindName("BtnRefresh").Add_Click({
            & $LoadDirectory $script:CurrentPath
        })
        
        $window.FindName("BtnBack").Add_Click({
            $path = Invoke-NavigationBack
            if ($path) {
                $script:CurrentPath = $path
                $addressBar.Text = $path
                & $LoadDirectory $path
            }
        })
        
        $window.FindName("BtnForward").Add_Click({
            $path = Invoke-NavigationForward
            if ($path) {
                $script:CurrentPath = $path
                $addressBar.Text = $path
                & $LoadDirectory $path
            }
        })
        
        $window.FindName("BtnUp").Add_Click({
            $parent = Split-Path $script:CurrentPath -Parent
            if ($parent) {
                $script:CurrentPath = $parent
                $addressBar.Text = $parent
                & $LoadDirectory $parent
            }
        })
        
        $window.FindName("BtnGo").Add_Click({
            $path = $addressBar.Text
            if (Test-Path $path) {
                $script:CurrentPath = $path
                & $LoadDirectory $path
            } else {
                [System.Windows.MessageBox]::Show("Path not found: $path", "Error", 'OK', 'Error')
            }
        })
        
        $window.FindName("BtnNewFolder").Add_Click({
            $folderName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter folder name:", "New Folder")
            if ($folderName) {
                $newPath = Join-Path $script:CurrentPath $folderName
                New-Item -ItemType Directory -Path $newPath -Force | Out-Null
                & $LoadDirectory $script:CurrentPath
            }
        })
        
        $window.FindName("BtnDelete").Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected) {
                $result = [System.Windows.MessageBox]::Show(
                    "Delete $($selected.Name)?",
                    "Confirm Delete",
                    'YesNo',
                    'Warning'
                )
                if ($result -eq 'Yes') {
                    Remove-Item -Path $selected.FullName -Recurse -Force
                    & $LoadDirectory $script:CurrentPath
                }
            }
        })
        
        $window.FindName("BtnProperties").Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected) {
                Show-ObjectInspector -Path $selected.FullName
            }
        })
        
        # Quick Filter functionality
        $quickFilter.Add_TextChanged({
            $filterText = $quickFilter.Text
            if ([string]::IsNullOrWhiteSpace($filterText)) {
                $fileGrid.ItemsSource = $script:AllItems
                $filterStatusText.Text = ""
                $itemCountText.Text = "$($script:AllItems.Count) items"
            } else {
                $filtered = $script:AllItems | Where-Object { $_.Name -like "*$filterText*" }
                $fileGrid.ItemsSource = $filtered
                $filterStatusText.Text = "Filtered: $($filtered.Count) of $($script:AllItems.Count)"
                $itemCountText.Text = "$($filtered.Count) items"
            }
        })
        
        $window.FindName("BtnClearFilter").Add_Click({
            $quickFilter.Text = ""
        })
        
        # Menu handlers
        $window.FindName("MenuCommandPalette").Add_Click({
            Invoke-CommandPalette
        })
        
        $window.FindName("MenuQueryBuilder").Add_Click({
            New-QueryBuilder -InitialPath $script:CurrentPath
        })
        
        $window.FindName("MenuScriptWorkspace").Add_Click({
            New-ScriptWorkspace
        })
        
        $window.FindName("MenuObjectInspector").Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected) {
                Show-ObjectInspector -Path $selected.FullName
            }
        })
        
        $window.FindName("MenuRunspaceManager").Add_Click({
            Start-RunspaceManager
        })
        
        $window.FindName("MenuRefresh").Add_Click({
            & $LoadDirectory $script:CurrentPath
        })
        
        $window.FindName("MenuFindDuplicates").Add_Click({
            $consoleOutput.AppendText("`nSearching for duplicates...")
            Find-DuplicateFiles -Path $script:CurrentPath
        })
        
        $window.FindName("MenuDiskAnalyzer").Add_Click({
            $consoleOutput.AppendText("`nAnalyzing disk space...")
            Get-DiskSpace -Path $script:CurrentPath
        })
        
        $window.FindName("MenuGitStatus").Add_Click({
            $consoleOutput.AppendText("`nGetting git status...")
            Get-GitStatus -Path $script:CurrentPath
        })
        
        $window.FindName("MenuBatchOps").Add_Click({
            $selected = $fileGrid.SelectedItems
            if ($selected -and $selected.Count -gt 0) {
                $consoleOutput.AppendText("`nOpening Batch Operations...")
                $files = $selected | ForEach-Object { Get-Item $_.FullName }
                Start-BatchOperation -Files $files -Operation "Copy"
            } else {
                [System.Windows.MessageBox]::Show(
                    "Please select files to perform batch operations",
                    "No Selection",
                    'OK',
                    'Information'
                )
            }
        })
        
        $window.FindName("MenuSyncDirs").Add_Click({
            $consoleOutput.AppendText("`nOpening Directory Synchronization...")
            # Get source directory (current path)
            $sourcePath = $script:CurrentPath
            
            # Prompt for destination directory
            $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderBrowser.Description = "Select destination directory to sync with"
            $folderBrowser.ShowNewFolderButton = $true
            
            if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $destPath = $folderBrowser.SelectedPath
                $consoleOutput.AppendText("`nSyncing: $sourcePath -> $destPath")
                Sync-Directories -SourcePath $sourcePath -DestinationPath $destPath -WhatIf
            }
        })
        
        $window.FindName("MenuConnect").Add_Click({
            $consoleOutput.AppendText("`nOpening Network Connection...")
            
            # Create a simple dialog for FTP/SFTP connection
            $connectionType = [System.Windows.MessageBox]::Show(
                "Connect to FTP (Yes) or SFTP (No)?",
                "Network Connection",
                'YesNoCancel',
                'Question'
            )
            
            if ($connectionType -eq 'Yes') {
                $server = [Microsoft.VisualBasic.Interaction]::InputBox("Enter FTP server address:", "FTP Connection")
                if ($server) {
                    $consoleOutput.AppendText("`nConnecting to FTP: $server")
                    Connect-FTP -Server $server
                }
            } elseif ($connectionType -eq 'No') {
                $server = [Microsoft.VisualBasic.Interaction]::InputBox("Enter SFTP server address:", "SFTP Connection")
                if ($server) {
                    $consoleOutput.AppendText("`nConnecting to SFTP: $server")
                    Connect-SFTP -Server $server
                }
            }
        })
        
        $window.FindName("MenuPlugins").Add_Click({
            $consoleOutput.AppendText("`nOpening Plugin Manager...")
            $plugins = Get-PluginList
            if ($plugins) {
                $pluginList = $plugins | ForEach-Object { "$($_.Name) - $($_.Version)" } | Out-String
                [System.Windows.MessageBox]::Show(
                    "Installed Plugins:`n`n$pluginList",
                    "Plugin Manager",
                    'OK',
                    'Information'
                )
            } else {
                [System.Windows.MessageBox]::Show(
                    "No plugins installed.",
                    "Plugin Manager",
                    'OK',
                    'Information'
                )
            }
        })
        
        $window.FindName("MenuDocs").Add_Click({
            $docsPath = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "README.md"
            if (Test-Path $docsPath) {
                Start-Process $docsPath
                $consoleOutput.AppendText("`nOpened documentation: $docsPath")
            } else {
                [System.Windows.MessageBox]::Show(
                    "Documentation not found. Please check the README.md file in the repository.",
                    "Documentation",
                    'OK',
                    'Warning'
                )
            }
        })
        
        # Archive Operations handlers
        $window.FindName("MenuCreateArchive").Add_Click({
            $selected = $fileGrid.SelectedItems
            if ($selected -and $selected.Count -gt 0) {
                $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
                $saveDialog.Filter = "ZIP Archive (*.zip)|*.zip|TAR Archive (*.tar)|*.tar|7-Zip Archive (*.7z)|*.7z"
                $saveDialog.Title = "Create Archive"
                
                if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $paths = $selected | ForEach-Object { $_.FullName }
                    $format = switch ($saveDialog.FilterIndex) {
                        1 { 'ZIP' }
                        2 { 'TAR' }
                        3 { '7Z' }
                    }
                    $consoleOutput.AppendText("`nCreating $format archive: $($saveDialog.FileName)")
                    New-Archive -Path $paths -Destination $saveDialog.FileName -Format $format
                    $consoleOutput.AppendText("`nArchive created successfully")
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "Please select files or folders to archive",
                    "No Selection",
                    'OK',
                    'Information'
                )
            }
        })
        
        $window.FindName("MenuExtractArchive").Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected -and -not $selected.IsDirectory) {
                $ext = [System.IO.Path]::GetExtension($selected.FullName).ToLower()
                if ($ext -in @('.zip', '.tar', '.7z', '.gz')) {
                    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                    $folderBrowser.Description = "Select destination folder for extraction"
                    $folderBrowser.ShowNewFolderButton = $true
                    
                    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $consoleOutput.AppendText("`nExtracting archive: $($selected.FullName)")
                        Expand-Archive -Path $selected.FullName -DestinationPath $folderBrowser.SelectedPath
                        $consoleOutput.AppendText("`nExtraction complete")
                    }
                } else {
                    [System.Windows.MessageBox]::Show(
                        "Please select a valid archive file (.zip, .tar, .7z)",
                        "Invalid File",
                        'OK',
                        'Warning'
                    )
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "Please select an archive file to extract",
                    "No Selection",
                    'OK',
                    'Information'
                )
            }
        })
        
        $window.FindName("MenuViewArchive").Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected -and -not $selected.IsDirectory) {
                $ext = [System.IO.Path]::GetExtension($selected.FullName).ToLower()
                if ($ext -in @('.zip', '.tar', '.7z', '.gz')) {
                    $consoleOutput.AppendText("`nViewing archive contents: $($selected.FullName)")
                    $contents = Get-ArchiveContent -Path $selected.FullName
                    if ($contents) {
                        $contentList = $contents | ForEach-Object { $_ } | Out-String
                        [System.Windows.MessageBox]::Show(
                            "Archive Contents:`n`n$contentList",
                            "Archive Viewer",
                            'OK',
                            'Information'
                        )
                    }
                } else {
                    [System.Windows.MessageBox]::Show(
                        "Please select a valid archive file (.zip, .tar, .7z)",
                        "Invalid File",
                        'OK',
                        'Warning'
                    )
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "Please select an archive file to view",
                    "No Selection",
                    'OK',
                    'Information'
                )
            }
        })
        
        # Advanced Search handler
        $window.FindName("MenuAdvancedSearch").Add_Click({
            $consoleOutput.AppendText("`nOpening Advanced Search...")
            $searchTerm = [Microsoft.VisualBasic.Interaction]::InputBox(
                "Enter search term (supports wildcards and regex):",
                "Advanced Search"
            )
            if ($searchTerm) {
                $consoleOutput.AppendText("`nSearching for: $searchTerm in $($script:CurrentPath)")
                $results = Search-Files -Path $script:CurrentPath -Pattern $searchTerm
                if ($results) {
                    $fileGrid.ItemsSource = $results | ForEach-Object {
                        [PSCustomObject]@{
                            Name = $_.Name
                            FullName = $_.FullName
                            Extension = $_.Extension
                            Size = if ($_.Length) { Format-FileSize $_.Length } else { "<DIR>" }
                            LastWriteTime = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                            Attributes = $_.Attributes.ToString()
                            IsDirectory = $_.PSIsContainer
                        }
                    }
                    $itemCountText.Text = "$($results.Count) results"
                    $consoleOutput.AppendText("`nFound $($results.Count) matching files")
                } else {
                    [System.Windows.MessageBox]::Show(
                        "No files found matching: $searchTerm",
                        "Search Results",
                        'OK',
                        'Information'
                    )
                }
            }
        })
        
        # Metadata Editor handler
        $window.FindName("MenuMetadataEditor").Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected -and -not $selected.IsDirectory) {
                $consoleOutput.AppendText("`nOpening Metadata Editor for: $($selected.Name)")
                
                $attribute = [Microsoft.VisualBasic.Interaction]::InputBox(
                    "Enter attribute to modify (ReadOnly, Hidden, Archive, System):",
                    "Metadata Editor"
                )
                
                if ($attribute -and $attribute -in @('ReadOnly', 'Hidden', 'Archive', 'System')) {
                    $value = [System.Windows.MessageBox]::Show(
                        "Set $attribute to True?",
                        "Metadata Editor",
                        'YesNo',
                        'Question'
                    )
                    
                    $setValue = $value -eq 'Yes'
                    Edit-FileMetadata -Path $selected.FullName -Properties @{ $attribute = $setValue }
                    $consoleOutput.AppendText("`nMetadata updated: $attribute = $setValue")
                    & $LoadDirectory $script:CurrentPath
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "Please select a file to edit metadata",
                    "No Selection",
                    'OK',
                    'Information'
                )
            }
        })
        
        # PowerToys menu handlers
        $window.FindName("MenuImageResizer").Add_Click({
            $consoleOutput.AppendText("`nOpening Image Resizer...")
            try {
                $selected = $fileGrid.SelectedItems | Where-Object { -not $_.IsDirectory -and $_.Extension -match '\.(jpg|jpeg|png|bmp|gif|tiff)$' }
                if ($selected) {
                    $width = [Microsoft.VisualBasic.Interaction]::InputBox("Enter target width (leave empty to keep aspect ratio):", "Image Resizer", "800")
                    if ($width) {
                        foreach ($item in $selected) {
                            Resize-Image -Path $item.FullName -Width ([int]$width) -KeepAspectRatio
                        }
                        $consoleOutput.AppendText("`nResized $($selected.Count) image(s)")
                        & $LoadDirectory $script:CurrentPath
                    }
                } else {
                    [System.Windows.MessageBox]::Show("Please select image files to resize", "Image Resizer", 'OK', 'Information')
                }
            } catch {
                $consoleOutput.AppendText("`nImage Resizer error: $_")
            }
        })
        
        $window.FindName("MenuTextExtractor").Add_Click({
            $consoleOutput.AppendText("`nOpening Text Extractor (OCR)...")
            try {
                $result = Start-ScreenTextExtractor
                if ($result.Status -eq 'Success') {
                    $consoleOutput.AppendText("`nExtracted text (length: $($result.TextLength))")
                }
            } catch {
                $consoleOutput.AppendText("`nText Extractor error: $_")
            }
        })
        
        $window.FindName("MenuColorPicker").Add_Click({
            $consoleOutput.AppendText("`nOpening Color Picker...")
            try {
                $color = Get-ColorFromScreen -Format HEX
                if ($color) {
                    $consoleOutput.AppendText("`nPicked color: $($color.HEX)")
                }
            } catch {
                $consoleOutput.AppendText("`nColor Picker error: $_")
            }
        })
        
        $window.FindName("MenuHostsEditor").Add_Click({
            $consoleOutput.AppendText("`nOpening Hosts File Editor...")
            try {
                $entries = Get-HostsEntry
                $consoleOutput.AppendText("`nCurrent hosts entries: $($entries.Count)")
                foreach ($entry in $entries | Select-Object -First 10) {
                    $consoleOutput.AppendText("`n  $($entry.IPAddress) -> $($entry.Hostname)")
                }
                [System.Windows.MessageBox]::Show(
                    "Hosts file has $($entries.Count) entries.`nUse Get-HostsEntry, Add-HostsEntry, Remove-HostsEntry cmdlets for editing.",
                    "Hosts File Editor",
                    'OK',
                    'Information'
                )
            } catch {
                $consoleOutput.AppendText("`nHosts Editor error: $_")
            }
        })
        
        $window.FindName("MenuQuickAccent").Add_Click({
            $consoleOutput.AppendText("`nOpening Quick Accent...")
            try {
                Show-QuickAccentMenu
            } catch {
                $consoleOutput.AppendText("`nQuick Accent error: $_")
            }
        })
        
        $window.FindName("MenuShortcutGuide").Add_Click({
            $consoleOutput.AppendText("`nOpening Keyboard Shortcut Guide...")
            try {
                Show-ShortcutGuide
            } catch {
                $consoleOutput.AppendText("`nShortcut Guide error: $_")
            }
        })
        
        $window.FindName("MenuWorkspaceLayouts").Add_Click({
            $consoleOutput.AppendText("`nOpening Workspace Layouts...")
            try {
                Show-WorkspaceLayoutMenu
            } catch {
                $consoleOutput.AppendText("`nWorkspace Layouts error: $_")
            }
        })
        
        $window.FindName("MenuTemplateManager").Add_Click({
            $consoleOutput.AppendText("`nOpening Template Manager...")
            try {
                Show-TemplateMenu
            } catch {
                $consoleOutput.AppendText("`nTemplate Manager error: $_")
            }
        })
        
        $window.FindName("MenuAwakeMode").Add_Click({
            $consoleOutput.AppendText("`nToggling Awake Mode...")
            try {
                $status = Get-AwakeStatus
                if ($status.IsActive) {
                    Disable-AwakeMode
                    $consoleOutput.AppendText("`nAwake Mode disabled")
                } else {
                    Enable-AwakeMode -Mode Both
                    $consoleOutput.AppendText("`nAwake Mode enabled")
                }
            } catch {
                $consoleOutput.AppendText("`nAwake Mode error: $_")
            }
        })
        
        $window.FindName("MenuPowerRename").Add_Click({
            $consoleOutput.AppendText("`nOpening PowerRename...")
            try {
                $selected = $fileGrid.SelectedItems
                if ($selected) {
                    $find = [Microsoft.VisualBasic.Interaction]::InputBox("Find text:", "PowerRename")
                    if ($find) {
                        $replace = [Microsoft.VisualBasic.Interaction]::InputBox("Replace with:", "PowerRename")
                        $paths = $selected | ForEach-Object { $_.FullName }
                        $results = Invoke-PowerRename -Path $paths -Find $find -Replace $replace -Preview
                        $consoleOutput.AppendText("`nPreview: $($results.Count) items would be renamed")
                    }
                } else {
                    [System.Windows.MessageBox]::Show("Please select files/folders to rename", "PowerRename", 'OK', 'Information')
                }
            } catch {
                $consoleOutput.AppendText("`nPowerRename error: $_")
            }
        })
        
        # Security Operations handlers
        $window.FindName("MenuViewACL").Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected) {
                $consoleOutput.AppendText("`nViewing ACL for: $($selected.Name)")
                $acl = Get-FileACL -Path $selected.FullName
                if ($acl) {
                    $aclInfo = "Owner: $($acl.Owner)`nGroup: $($acl.Group)`n`nAccess Rules:`n"
                    foreach ($rule in $acl.Access) {
                        $aclInfo += "$($rule.AccessControlType) - $($rule.IdentityReference) - $($rule.FileSystemRights)`n"
                    }
                    [System.Windows.MessageBox]::Show(
                        $aclInfo,
                        "File ACL - $($selected.Name)",
                        'OK',
                        'Information'
                    )
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "Please select a file or folder to view ACL",
                    "No Selection",
                    'OK',
                    'Information'
                )
            }
        })
        
        $window.FindName("MenuEditACL").Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected) {
                $consoleOutput.AppendText("`nEditing ACL for: $($selected.Name)")
                
                $identity = [Microsoft.VisualBasic.Interaction]::InputBox(
                    "Enter user/group identity (e.g., DOMAIN\User):",
                    "Edit ACL"
                )
                
                if ($identity) {
                    $rights = [Microsoft.VisualBasic.Interaction]::InputBox(
                        "Enter rights (e.g., FullControl, Read, Write):",
                        "Edit ACL",
                        "Read"
                    )
                    
                    if ($rights) {
                        try {
                            Set-FileACL -Path $selected.FullName -Identity $identity -Rights $rights
                            $consoleOutput.AppendText("`nACL updated successfully")
                            [System.Windows.MessageBox]::Show(
                                "ACL updated for: $($selected.Name)",
                                "Success",
                                'OK',
                                'Information'
                            )
                        } catch {
                            $consoleOutput.AppendText("`nACL update failed: $_")
                            [System.Windows.MessageBox]::Show(
                                "Failed to update ACL: $_",
                                "Error",
                                'OK',
                                'Error'
                            )
                        }
                    }
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "Please select a file or folder to edit ACL",
                    "No Selection",
                    'OK',
                    'Information'
                )
            }
        })
        
        $window.FindName("MenuSecureDelete").Add_Click({
            $selected = $fileGrid.SelectedItems
            if ($selected -and $selected.Count -gt 0) {
                $result = [System.Windows.MessageBox]::Show(
                    "Securely delete $($selected.Count) selected item(s)? This operation cannot be undone.",
                    "Secure Delete",
                    'YesNo',
                    'Warning'
                )
                
                if ($result -eq 'Yes') {
                    foreach ($item in $selected) {
                        $consoleOutput.AppendText("`nSecurely deleting: $($item.Name)")
                        Remove-SecureFile -Path $item.FullName
                    }
                    $consoleOutput.AppendText("`nSecure deletion complete")
                    & $LoadDirectory $script:CurrentPath
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "Please select files to securely delete",
                    "No Selection",
                    'OK',
                    'Information'
                )
            }
        })
        
        $window.FindName("MenuAbout").Add_Click({
            [System.Windows.MessageBox]::Show(
                "PowerShell File Manager V2.0`n`nCommand-centric file manager with rich PowerShell integration`n`nCopyright © 2025",
                "About",
                'OK',
                'Information'
            )
        })
        
        $window.FindName("MenuExit").Add_Click({
            $window.Close()
        })
        
        # Context Menu handlers
        $ctxOpen.Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected) {
                if ($selected.IsDirectory) {
                    $script:CurrentPath = $selected.FullName
                    $addressBar.Text = $script:CurrentPath
                    & $LoadDirectory $script:CurrentPath
                } else {
                    Start-Process $selected.FullName
                }
            }
        })
        
        $ctxPreview.Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected -and -not $selected.IsDirectory) {
                try {
                    $content = Get-Content -Path $selected.FullName -TotalCount 20 -ErrorAction SilentlyContinue
                    $previewPanel.Text = $content -join "`n"
                } catch {
                    $previewPanel.Text = "Preview not available"
                }
            }
        })
        
        $ctxCopy.Add_Click({
            $selected = $fileGrid.SelectedItems
            if ($selected -and $selected.Count -gt 0) {
                $script:ClipboardItems = $selected | ForEach-Object { $_.FullName }
                $script:ClipboardOperation = 'Copy'
                $consoleOutput.AppendText("`nCopied $($selected.Count) item(s) to clipboard")
                $statusText.Text = "Copied $($selected.Count) item(s)"
            }
        })
        
        $ctxCut.Add_Click({
            $selected = $fileGrid.SelectedItems
            if ($selected -and $selected.Count -gt 0) {
                $script:ClipboardItems = $selected | ForEach-Object { $_.FullName }
                $script:ClipboardOperation = 'Cut'
                $consoleOutput.AppendText("`nCut $($selected.Count) item(s) to clipboard")
                $statusText.Text = "Cut $($selected.Count) item(s)"
            }
        })
        
        $ctxPaste.Add_Click({
            if ($script:ClipboardItems -and $script:ClipboardItems.Count -gt 0) {
                try {
                    foreach ($item in $script:ClipboardItems) {
                        $destination = Join-Path $script:CurrentPath (Split-Path $item -Leaf)
                        if ($script:ClipboardOperation -eq 'Copy') {
                            Copy-Item -Path $item -Destination $destination -Recurse -Force
                        } else {
                            Move-Item -Path $item -Destination $destination -Force
                        }
                    }
                    $consoleOutput.AppendText("`n$($script:ClipboardOperation) completed: $($script:ClipboardItems.Count) item(s)")
                    $statusText.Text = "$($script:ClipboardOperation) completed"
                    & $LoadDirectory $script:CurrentPath
                    
                    # Clear clipboard if it was a cut operation
                    if ($script:ClipboardOperation -eq 'Cut') {
                        $script:ClipboardItems = @()
                        $script:ClipboardOperation = $null
                    }
                } catch {
                    [System.Windows.MessageBox]::Show("Error during paste: $_", "Error", 'OK', 'Error')
                }
            }
        })
        
        $ctxDelete.Add_Click({
            $selected = $fileGrid.SelectedItems
            if ($selected -and $selected.Count -gt 0) {
                $result = [System.Windows.MessageBox]::Show(
                    "Delete $($selected.Count) selected item(s)?",
                    "Confirm Delete",
                    'YesNo',
                    'Warning'
                )
                if ($result -eq 'Yes') {
                    foreach ($item in $selected) {
                        Remove-Item -Path $item.FullName -Recurse -Force
                    }
                    & $LoadDirectory $script:CurrentPath
                }
            }
        })
        
        $ctxRename.Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected) {
                $newName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter new name:", "Rename", $selected.Name)
                if ($newName -and $newName -ne $selected.Name) {
                    try {
                        Rename-Item -Path $selected.FullName -NewName $newName -ErrorAction Stop
                        $consoleOutput.AppendText("`nRenamed: $($selected.Name) -> $newName")
                        & $LoadDirectory $script:CurrentPath
                    } catch {
                        [System.Windows.MessageBox]::Show("Error renaming file: $_", "Error", 'OK', 'Error')
                        $consoleOutput.AppendText("`nRename failed: $_")
                    }
                }
            }
        })
        
        $ctxProperties.Add_Click({
            $selected = $fileGrid.SelectedItem
            if ($selected) {
                Show-ObjectInspector -Path $selected.FullName
            }
        })
        
        # File grid double-click handler
        $fileGrid.Add_MouseDoubleClick({
            $selected = $fileGrid.SelectedItem
            if ($selected -and $selected.IsDirectory) {
                $script:CurrentPath = $selected.FullName
                $addressBar.Text = $script:CurrentPath
                & $LoadDirectory $script:CurrentPath
            }
        })
        
        # File grid selection changed handler
        $fileGrid.Add_SelectionChanged({
            $selected = $fileGrid.SelectedItems
            if ($selected.Count -gt 0) {
                # Calculate total size of selected items
                $totalSize = 0
                foreach ($item in $selected) {
                    if (-not $item.IsDirectory -and $item.SizeBytes) {
                        $totalSize += $item.SizeBytes
                    }
                }
                
                if ($totalSize -gt 0) {
                    $sizeText = Format-FileSize $totalSize
                    $selectionText.Text = "$($selected.Count) selected ($sizeText)"
                } else {
                    $selectionText.Text = "$($selected.Count) selected"
                }
                
                # Show preview for single selection
                if ($selected.Count -eq 1) {
                    $item = $selected[0]
                    if (-not $item.IsDirectory) {
                        try {
                            $content = Get-Content -Path $item.FullName -TotalCount 20 -ErrorAction SilentlyContinue
                            $previewPanel.Text = $content -join "`n"
                        } catch {
                            $previewPanel.Text = "Preview not available"
                        }
                    }
                }
            } else {
                $selectionText.Text = ""
                $previewPanel.Text = "Select a file to preview"
            }
        })
        $fileGrid.Add_PreviewMouseLeftButtonDown({
            param($control, $e)
            $script:DragStartPoint = $e.GetPosition($null)
        })
        
        $fileGrid.Add_PreviewMouseMove({
            param($control, $e)
            
            if ($e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
                $mousePos = $e.GetPosition($null)
                $diff = $script:DragStartPoint - $mousePos
                
                if ([Math]::Abs($diff.X) -gt [System.Windows.SystemParameters]::MinimumHorizontalDragDistance -or
                    [Math]::Abs($diff.Y) -gt [System.Windows.SystemParameters]::MinimumVerticalDragDistance) {
                    
                    $selected = $fileGrid.SelectedItems
                    if ($selected -and $selected.Count -gt 0) {
                        $files = New-Object System.Collections.Specialized.StringCollection
                        foreach ($item in $selected) {
                            $files.Add($item.FullName) | Out-Null
                        }
                        
                        $dataObject = New-Object System.Windows.DataObject
                        $dataObject.SetFileDropList($files)
                        
                        # Check if Ctrl is pressed for copy, otherwise move
                        $effect = if ([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl) -or 
                                     [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightCtrl)) {
                            [System.Windows.DragDropEffects]::Copy
                        } else {
                            [System.Windows.DragDropEffects]::Move
                        }
                        
                        try {
                            [System.Windows.DragDrop]::DoDragDrop($fileGrid, $dataObject, $effect) | Out-Null
                        } catch {
                            # Ignore drag-drop errors
                        }
                    }
                }
            }
        })
        $fileGrid.Add_DragEnter({
            param($control, $e)
            if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
                $e.Effects = [System.Windows.DragDropEffects]::Copy
            } else {
                $e.Effects = [System.Windows.DragDropEffects]::None
            }
            $e.Handled = $true
        })
        
        $fileGrid.Add_DragOver({
            param($control, $e)
            if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
                # Check if Ctrl is pressed
                if ($e.KeyStates -band [System.Windows.DragDropKeyStates]::ControlKey) {
                    $e.Effects = [System.Windows.DragDropEffects]::Copy
                } else {
                    $e.Effects = [System.Windows.DragDropEffects]::Move
                }
            } else {
                $e.Effects = [System.Windows.DragDropEffects]::None
            }
            $e.Handled = $true
        })
            
        $fileGrid.Add_Drop({
            param($control, $e)
            
            if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
                $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
                $isCopy = ($e.KeyStates -band [System.Windows.DragDropKeyStates]::ControlKey) -ne 0
                
                try {
                    foreach ($file in $files) {
                        $fileName = Split-Path $file -Leaf
                        $destination = Join-Path $script:CurrentPath $fileName
                        
                        if ($isCopy) {
                            Copy-Item -Path $file -Destination $destination -Recurse -Force
                            $consoleOutput.AppendText("`nCopied: $fileName")
                        } else {
                            Move-Item -Path $file -Destination $destination -Force
                            $consoleOutput.AppendText("`nMoved: $fileName")
                        }
                    }
                    
                    $statusText.Text = if ($isCopy) { "Copied $($files.Count) item(s)" } else { "Moved $($files.Count) item(s)" }
                    & $LoadDirectory $script:CurrentPath
                } catch {
                    [System.Windows.MessageBox]::Show("Error during drag-drop: $_", "Error", 'OK', 'Error')
                }
            }
            $e.Handled = $true
        })
            
        # Keyboard shortcuts
        $window.Add_KeyDown({
            param($control, $e)
            
            # Ctrl+P - Command Palette
            if ($e.Key -eq 'P' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
                Invoke-CommandPalette
                $e.Handled = $true
            }
            # F5 - Refresh
            elseif ($e.Key -eq 'F5') {
                & $LoadDirectory $script:CurrentPath
                $e.Handled = $true
            }
            # Delete - Delete selected items
            elseif ($e.Key -eq 'Delete') {
                $selected = $fileGrid.SelectedItems
                if ($selected -and $selected.Count -gt 0) {
                    $result = [System.Windows.MessageBox]::Show(
                        "Delete $($selected.Count) selected item(s)?",
                        "Confirm Delete",
                        'YesNo',
                        'Warning'
                    )
                    if ($result -eq 'Yes') {
                        foreach ($item in $selected) {
                            Remove-Item -Path $item.FullName -Recurse -Force
                        }
                        & $LoadDirectory $script:CurrentPath
                    }
                }
                $e.Handled = $true
            }
            # F2 - Rename
            elseif ($e.Key -eq 'F2') {
                $selected = $fileGrid.SelectedItem
                if ($selected) {
                    $newName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter new name:", "Rename", $selected.Name)
                    if ($newName -and $newName -ne $selected.Name) {
                        Rename-Item -Path $selected.FullName -NewName $newName
                        & $LoadDirectory $script:CurrentPath
                    }
                }
                $e.Handled = $true
            }
            # Enter - Open/Navigate
            elseif ($e.Key -eq 'Enter' -or $e.Key -eq 'Return') {
                $selected = $fileGrid.SelectedItem
                if ($selected) {
                    if ($selected.IsDirectory) {
                        $script:CurrentPath = $selected.FullName
                        $addressBar.Text = $script:CurrentPath
                        & $LoadDirectory $script:CurrentPath
                    } else {
                        Start-Process $selected.FullName
                    }
                }
                $e.Handled = $true
            }
            # Backspace - Go up one level
            elseif ($e.Key -eq 'Back') {
                $parent = Split-Path $script:CurrentPath -Parent
                if ($parent) {
                    $script:CurrentPath = $parent
                    $addressBar.Text = $parent
                    & $LoadDirectory $parent
                }
                $e.Handled = $true
            }
            # Ctrl+C - Copy
            elseif ($e.Key -eq 'C' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
                $selected = $fileGrid.SelectedItems
                if ($selected -and $selected.Count -gt 0) {
                    $script:ClipboardItems = $selected | ForEach-Object { $_.FullName }
                    $script:ClipboardOperation = 'Copy'
                    $consoleOutput.AppendText("`nCopied $($selected.Count) item(s) to clipboard")
                    $statusText.Text = "Copied $($selected.Count) item(s)"
                }
                $e.Handled = $true
            }
            # Ctrl+X - Cut
            elseif ($e.Key -eq 'X' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
                $selected = $fileGrid.SelectedItems
                if ($selected -and $selected.Count -gt 0) {
                    $script:ClipboardItems = $selected | ForEach-Object { $_.FullName }
                    $script:ClipboardOperation = 'Cut'
                    $consoleOutput.AppendText("`nCut $($selected.Count) item(s) to clipboard")
                    $statusText.Text = "Cut $($selected.Count) item(s)"
                }
                $e.Handled = $true
            }
            # Ctrl+V - Paste
            elseif ($e.Key -eq 'V' -and $e.KeyboardDevice.Modifiers -eq 'Control') {
                if ($script:ClipboardItems -and $script:ClipboardItems.Count -gt 0) {
                    try {
                        foreach ($item in $script:ClipboardItems) {
                            $destination = Join-Path $script:CurrentPath (Split-Path $item -Leaf)
                            if ($script:ClipboardOperation -eq 'Copy') {
                                Copy-Item -Path $item -Destination $destination -Recurse -Force
                            } else {
                                Move-Item -Path $item -Destination $destination -Force
                            }
                        }
                        $consoleOutput.AppendText("`n$($script:ClipboardOperation) completed: $($script:ClipboardItems.Count) item(s)")
                        $statusText.Text = "$($script:ClipboardOperation) completed"
                        & $LoadDirectory $script:CurrentPath
                        
                        # Clear clipboard if it was a cut operation
                        if ($script:ClipboardOperation -eq 'Cut') {
                            $script:ClipboardItems = @()
                            $script:ClipboardOperation = $null
                        }
                    } catch {
                        [System.Windows.MessageBox]::Show("Error during paste: $_", "Error", 'OK', 'Error')
                    }
                }
                $e.Handled = $true
            }
        })
        
        # Create a timer for background operations
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
            # Update background operations status
            try {
                # Check for any active background operations (placeholder logic)
                $activeOps = 0  # This would normally check actual background operations
                $backgroundOpsText.Text = "Background: $activeOps active"
            }
            catch {
                $backgroundOpsText.Text = "Background: Error"
            }
        })
        
        $timer.Start()
        
        $window.ShowDialog() | Out-Null
        $timer.Stop()
    } catch {
        Write-Error "Failed to start file manager: $_"
        Write-Error $_.ScriptStackTrace
    }
}

# Helper function for InputBox
if (-not ([System.Management.Automation.PSTypeName]'Microsoft.VisualBasic.Interaction').Type) {
    Add-Type -AssemblyName Microsoft.VisualBasic
}

# Export the function
Export-ModuleMember -Function Start-FileManager
