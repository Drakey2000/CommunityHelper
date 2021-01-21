#################################################################################     Comments       #################################################################################
<#
.SYNOPSIS
    A graphical and html Build Summary Report

.DESCRIPTION
    Can be executed standalone or used as part of SCCM Task Sequence to create a Build Report. Logging Computer info, Bios, Network, Task Sequence Variables,
    Application, Drivers, Hotfixes, Driver Warning

.EXAMPLEa

.NOTES
    Author     : STEVEN DRAKE
    Version    : 07 Jan  2021 - Updated
#>
######################################################################################################################################################################################

    # Add Assembly
    Add-Type -AssemblyName System.Windows.Forms

    # Get Primary Monitor
    $PrimaryMonitor = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize

    # Set Default (Reapplied on restart) : Enable Cursor Suppression:  0 = Disabled: Mouse cursor is not suppressed 1 = Enabled: Mouse cursor is suppressed (default) - https://support.microsoft.com/en-us/help/4494800/no-mouse-cursor-during-configuration-manager-osd-task-sequence
    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableCursorSuppression /t REG_DWORD /d 1 /f

    # Get report date
    $ReportDate = Get-Date

    # Set Report file path
    $LogFile = "$env:SystemRoot\Logs\CommunityHelper\BuildSummary.log"

    # Create Report folder if it does not exists
    if (-not (Test-Path -Path (Split-Path -Path $LogFile))){New-Item -ItemType "directory" -Path (Split-Path -Path $LogFile)}

    # Set HTML file path
    $HTMLPath =  "$env:SystemRoot\Logs\CommunityHelper\BuildReport.html"

    # Create HTML folder if it does not exists
    if (-not (Test-Path -Path (Split-Path -Path $HTMLPath))){New-Item -ItemType "directory" -Path (Split-Path -Path $HTMLPath)}


# Outer Try Catch
try{

    # Clear error logs: Used in testing
    $Error.Clear()

    # Get Computer Information
    $ComputerInfo = Get-ComputerInfo

    # Get System Info
    $SystemInfo = $ComputerInfo | Select-Object `
        @{Name = "Product"; Expression = {$_.OsName}},
        @{Name = "Version"; Expression = {$_.WindowsVersion}},
        @{Name = "Architecture"; Expression = {$_.OsArchitecture}},
        @{Name = "Memory GB"; Expression = {$_.CsPhyicallyInstalledMemory /1024 /1024}}

    # Get Fixed Disk Volumes
    $SystemVolumes = Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystemType,DriveType,HealthStatus,OperationalStatus,@{Name = "SizeGB"; Expression = {[math]::round($_.size/1GB, 1)}} |  Where-Object {($_.DriveType -eq 'Fixed') -and ($_.DriveLetter -ne $Null)} | Sort-Object DriveLetter

    # Get Environment Info
    $SystemEnv = $ComputerInfo | Select-Object `
        @{Name = "Local Language"; Expression = {$_.OsLocale}},
        @{Name = "Mui Languages"; Expression = {$_.OsMuiLanguages -join ", "}},
        @{Name = "TimeZone"; Expression = {$_.TimeZone}},
        @{Name = "System Root"; Expression = {$_.WindowsSystemRoot}},
        @{Name = "Registered Owner"; Expression = {$_.WindowsRegisteredOwner}},
        @{Name = "Registered Organization"; Expression = {$_.WindowsRegisteredOrganization}}

    # Import SMS Environment Variables
    If ((Test-Path -Path "$env:SystemRoot\Temp\OSDReport\TSEnv.xml") -eq $True) {$SMSEnv = Import-Clixml -Path "$env:SystemRoot\Temp\OSDReport\TSEnv.xml" }

    # Get BitLocker Info
    $SystemBitLocker = Get-BitLockerVolume | Select-Object MountPoint,VolumeType,VolumeStatus,EncryptionMethod,EncryptionPercentage,@{Name = "KeyProtector"; Expression = {$_.KeyProtector -join ", "}},AutoUnlockKeyStored,AutoUnlockEnabled,ProtectionStatus | Sort-Object MountPoint

    # Get Hardware Info
    $SystemHardware = $ComputerInfo | Select-Object `
        @{Name = "Manufacturer"; Expression = {$_.CsManufacturer}},
        @{Name = "Model"; Expression = {$_.CsModel}},
        @{Name = "System SKU"; Expression = {$_.CsSystemSKUNumber}}

    # Get Bios Info
    $SystemBios = $ComputerInfo  | Select-Object `
        @{Name = "Bios Version"; Expression = {$_.BiosSMBIOSBIOSVersion}},
        @{Name = "Bios Release Date"; Expression = {$_.BiosReleaseDate}},
        @{Name = "Bios Serial Number"; Expression = {$_.BiosSeralNumber}}


    # Get Network Info
    $SystemNetwork = $ComputerInfo  | Select-Object `
        @{Name = "Hostname"; Expression = {$_.CsDNSHostName}},
        @{Name = "Domain"; Expression = {$_.CsDomain}}

    # Get AD Info
    Try{
        $ADSystemInfo = New-Object -ComObject ADSystemInfo
        $type = $ADSystemInfo.GetType()

        $SystemADInfo = @{
        "Computer Distinguished Name" = $type.InvokeMember('ComputerName','GetProperty',$null,$ADSystemInfo,$null)
        "Site Name" = $type.InvokeMember('SiteName','GetProperty',$null,$ADSystemInfo,$null)
        }

    }Catch{$RunAD = $False}

    # Get Network Adapter
    $NetworkAdpaters = Get-NetAdapter | Select-Object Name, MediaConnectionState ,MacAddress, LinkSpeed, MediaType | Sort-Object MediaConnectionState, Name

    # Add information text
    $Info = "`r`n"

    # Add Information Details
    $Info += "`tInformation`r`n`r`n`t`t"
    $Info += $SystemInfo.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Add Envionment Details
    $Info += "`tEnvironment`r`n`r`n`t`t"
    $Info += $SystemEnv.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Addd Partion Volumes Details
    $Info += "`tVolumes`r`n`r`n"

    $SystemVolumes | ForEach-Object {

    $Info += "`t`t" + "Drive Letter : " + $_.DriveLetter + "`r`n"
    $Info += "`t`t" + "File System Label  : " + $_.FileSystemLabel + "`r`n"
    $Info += "`t`t" + "File System Type : " + $_.FileSystemType + "`r`n"
    $Info += "`t`t" + "Drive Type : " + $_.DriveType + "`r`n"
    $Info += "`t`t" + "Health Status : " + $_.HealthStatus + "`r`n"
    $Info += "`t`t" + "Operational Status : " + $_.OperationalStatus + "`r`n"
    $Info += "`t`t" + "Size GB : " + $_.sizeGB + "`r`n"
    $Info += "`r`n"

    }

    # Add BitLocker Details
    $Info += "`tBitLocker`r`n`r`n"

    $SystemBitLocker | ForEach-Object {

    $Info += "`t`t" + "Mount Point : " + $_.MountPoint + "`r`n"
    $Info += "`t`t" + "Volume Type  : " + $_.VolumeType  + "`r`n"
    $Info += "`t`t" + "Volume Status : " + $_.VolumeStatus  + "`r`n"
    $Info += "`t`t" + "Encryption Method : " + $_.EncryptionMethod  + "`r`n"
    $Info += "`t`t" + "Encryption Percentages : " + $_.EncryptionPercentage  + "`r`n"
    $Info += "`t`t" + "Key Protector : " + $_.KeyProtector  + "`r`n"
    $Info += "`t`t" + "AutoUnlock Key Stored : " + $_.AutoUnlockKeyStored  + "`r`n"
    $Info += "`t`t" + "AutoUnlock Enabled : " + $_.AutoUnlockEnabled  + "`r`n"
    $Info += "`t`t" + "Protection Status : " + $_.ProtectionStatus  + "`r`n"
    $Info += "`r`n"

    }

    # Add Hardware Details
    $Info += "`tHardware`r`n`r`n`t`t"
    $Info += $SystemHardware.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Add BIOS Details
    $Info += "`tBios`r`n`r`n`t`t"
    $Info += $SystemBios.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Add Network Details
    $Info += "`tNetwork`r`n`r`n`t`t"
    $Info += $SystemNetwork.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Add AD Details
    if ($Null -ne $SystemADInfo) {

    $Info += "`t`t"
    $Info += $SystemADInfo.GetEnumerator() | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    }

    $NetworkAdpaters | ForEach-Object {

    $Info += "`t`t" + $_.Name + "`r`n"
    $Info += "`t`t" + "Status : " + $_.MediaConnectionState + "`r`n"
    $Info += "`t`t" + "Mac Address : " + $_.MacAddress + "`r`n"
    $Info += "`t`t" + "Link Speed : " + $_.LinkSpeed + "`r`n"
    $Info += "`t`t" + "Media Type : " + $_.MediaType  + "`r`n"
    $Info += "`r`n"

    }

    # Add CM Variables Details
    if ($Null -ne $SMSEnv) {

    $Info += "`tTask Sequence Variables`r`n`r`n`t`t"
    $Info += $SMSEnv.GetEnumerator() | Sort-Object Name | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    }

    # Add report path
    $Info += "`tBuild Summary Report`r`n`r`n"
    $Info += "`t`t" + $HTMLPath

    # Gather Error Report : Failed Drivers
    $FailedDevices = Get-CimInstance -ClassName Win32_PNPEntity | Select-Object Name,Description,PNPClass,Manufacturer,@{Name = "HardwareID"; Expression = {$_.HardwareID -join ", "}},Status,ConfigManagerErrorCode | Where-Object {$_.ConfigManagerErrorCode -ne 0 }

    # Build warning text
    $Warning = "`r`n"

    if ($null -ne $FailedDevices ) {
        $Warning +="Please check drivers are installed and working correctly"
        $Warning += $FailedDevices | Out-String
        }

    # Build Splash-Screen Function
    Add-Type -AssemblyName System.Windows.Forms

    # Form
    $script:Form = New-Object system.Windows.Forms.Form
    $Form.Height = $PrimaryMonitor.Height
    $Form.Width = $PrimaryMonitor.Width
    $Form.TopMost = $True
    $Form.BackColor = "White"
    $Form.FormBorderStyle = 'None'
    $Form.StartPosition = "CenterScreen"
    $TabControl = New-object System.Windows.Forms.TabControl
    $InfoPage = New-Object System.Windows.Forms.TabPage
    $AppPage = New-Object System.Windows.Forms.TabPage
    $DriverPage = New-Object System.Windows.Forms.TabPage
    $HotFixPage = New-Object System.Windows.Forms.TabPage
    $WarningPage = New-Object System.Windows.Forms.TabPage

    #Tab Control
    $TabControl.DataBindings.DefaultDataSourceUpdateMode = 0
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 50
    $System_Drawing_Point.Y = 100
    $TabControl.Location = $System_Drawing_Point
    $TabControl.Location
    $TabControl.Name = "tabControl"
    $TabControl.Dock = 'Fill'
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Height = 350
    $System_Drawing_Size.Width = 700
    $tabControl.Size = $System_Drawing_Size
    $TabControl.Font = New-Object System.Drawing.Font("Corbel",14,[System.Drawing.FontStyle]::Regular)
    $Form.Controls.Add($tabControl)

    #Warning Page
    $WarningPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $WarningPage.UseVisualStyleBackColor = $True
    $WarningPage.Name = "WarningPage"
    $WarningPage.Text = "Warning”
    if ($null -ne $FailedDevices ) { $tabControl.Controls.Add($WarningPage)}

    #Info Page
    $InfoPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $InfoPage.UseVisualStyleBackColor = $True
    $InfoPage.Name = "InfoPage"
    $InfoPage.Text = "Info”
    $tabControl.Controls.Add($InfoPage)

    #App Page
    $AppPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $AppPage.UseVisualStyleBackColor = $True
    $AppPage.Name = "AppPage"
    $AppPage.Text = "Apps”
    $tabControl.Controls.Add($AppPage)

    #Driver Page
    $DriverPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $DriverPage.UseVisualStyleBackColor = $True
    $DriverPage.Name = "DriverPage"
    $DriverPage.Text = "Drivers”
    $tabControl.Controls.Add($DriverPage)

    #Hotfix Page
    $HotFixPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $HotFixPage.UseVisualStyleBackColor = $True
    $HotFixPage.Name = "HotFixPage"
    $HotFixPage.Text = "Hotfix”
    $tabControl.Controls.Add($HotFixPage)

    # Text for Info Page
    $TextInfo = New-Object System.Windows.Forms.TextBox
    $TextInfo.Dock = 'Fill'
    $TextInfo.Multiline = $True
    $TextInfo.AutoSize = $True
    $TextInfo.Text = $Info
    $TextInfo.ScrollBars = 'Both'
    $TextInfo.Font = New-Object System.Drawing.Font("Helvetica",11,[System.Drawing.FontStyle]::Regular)
    $TextInfo.ReadOnly = $True
    $InfoPage.Controls.Add($TextInfo)

    # Gridview for Application Page
    $AppGridView = New-Object system.Windows.Forms.DataGridView
    $AppGridView.Dock = 'Fill'
    $AppGridView.AutoSizeColumnsMode = 'Fill'
    $AppGridView.ColumnHeadersHeightSizeMode = 'AutoSize'
    $AppGridView.RowHeadersVisible = $False
    $AppGridView.ColumnCount = 2
    $AppGridView.ColumnHeadersVisible = $True
    $AppGridView.Columns[0].Name = "Name"
    $AppGridView.Columns[1].Name = "Version"
    $AppGridView.BorderStyle ='None'
    $AppGridView.ReadOnly = $True
    $AppGridView.Font = New-Object System.Drawing.Font("Helvetica",10,[System.Drawing.FontStyle]::Regular)
    $AppPage.Controls.Add($AppGridView)

    # Create rows list
    $Apps = Get-Package | Select-Object Name, Version | Sort-Object Name

    foreach ($App in $Apps){$AppGridView.Rows.Add($APP.Name,$App.Version)}

    # Gridview for Driver Page
    $DrivertGridView = New-Object system.Windows.Forms.DataGridView
    $DrivertGridView.Dock = 'Fill'
    $DrivertGridView.AutoSizeColumnsMode = 'Fill'
    $DrivertGridView.ColumnHeadersHeightSizeMode = 'AutoSize'
    $DrivertGridView.RowHeadersVisible = $False
    $DrivertGridView.ColumnCount = 6
    $DrivertGridView.ColumnHeadersVisible = $True
    $DrivertGridView.Columns[0].Name = "Device Class"
    $DrivertGridView.Columns[1].Name = "Device Name"
    $DrivertGridView.Columns[2].Name = "Friendly Name"
    $DrivertGridView.Columns[3].Name = "Driver Version"
    $DrivertGridView.Columns[4].Name = "Driver Provider Name"
    $DrivertGridView.Columns[5].Name = "Hardware ID"
    $DrivertGridView.BorderStyle ='None'
    $DrivertGridView.ReadOnly = $True
    $DrivertGridView.Font = New-Object System.Drawing.Font("Helvetica",10,[System.Drawing.FontStyle]::Regular)
    $DriverPage.Controls.Add($DrivertGridView)

    # Create rows list
    $Drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver | Select-Object  DeviceClass, DeviceName, FriendlyName,DriverVersion, DriverProviderName, HardwareID | Sort-Object DeviceClass, DeviceName, DriverProviderName, DriverVersion

    foreach ($Driver in $Drivers){$DrivertGridView.Rows.Add($Driver.DeviceClass, $Driver.DeviceName, $Driver.FriendlyName, $Driver.DriverVersion, $Driver.DriverProviderName,$Driver.HardwareID )}

    # Gridview for Hotfix Page
    $HotFixGridView = New-Object system.Windows.Forms.DataGridView
    $HotFixGridView.Dock = 'Fill'
    $HotFixGridView.AutoSizeColumnsMode = 'Fill'
    $HotFixGridView.ColumnHeadersHeightSizeMode = 'AutoSize'
    $HotFixGridView.RowHeadersVisible = $False
    $HotFixGridView.ColumnCount = 3
    $HotFixGridView.ColumnHeadersVisible = $True
    $HotFixGridView.Columns[0].Name = "HotFix ID"
    $HotFixGridView.Columns[1].Name = "Description"
    $HotFixGridView.Columns[2].Name = "Installed On"
    $HotFixGridView.BorderStyle ='None'
    $HotFixGridView.ReadOnly = $True
    $HotFixGridView.Font = New-Object System.Drawing.Font("Helvetica",10,[System.Drawing.FontStyle]::Regular)
    $HotFixPage.Controls.Add($HotFixGridView)

    # Create rows list
    $Hotfixes = Get-HotFix | Select-Object HotFixID, Description, InstalledOn | Sort-Object InstalledOn, HotFixID -Descending

    foreach ($HotFix in $Hotfixes){$HotFixGridView.Rows.Add($HotFix.HotFixID,$Hotfix.Description,$Hotfix.InstalledOn)}

    # Text for Warning Page
    $TextWarning = New-Object System.Windows.Forms.TextBox
    $TextWarning.Dock = 'Fill'
    $TextWarning.Multiline = $True
    $TextWarning.AutoSize = $True
    $TextWarning.Text = $Warning
    $TextWarning.ScrollBars = 'Both'
    $TextWarning.Font = New-Object System.Drawing.Font("Helvetica",11,[System.Drawing.FontStyle]::Regular)
    $TextWarning.ReadOnly = $True
    $TextWarning.BackColor = 'Gold'
    $WarningPage.Controls.Add($TextWarning)

    # Title - Dont change order as will push title to top
    $LabelTitle = New-Object System.Windows.Forms.Label
    $LabelTitle.Dock = 'Top'
    $LabelTitle.AutoSize = $False
    $LabelTitle.Text = "Deployment Complete"
    $LabelTitle.BackColor = 'Gray'
    $LabelTitle.ForeColor = 'White'
    $LabelTitle.Height = 50
    $LabelTitle.Font = New-Object System.Drawing.Font("Corbel",30,[System.Drawing.FontStyle]::Regular)
    $Form.Controls.Add($LabelTitle)

    # Close Button - Dont change order as will push Button to top
    $Button = New-Object System.Windows.Forms.Button
    $Button.Dock = 'Bottom'
    $Button.AutoSize = $True
    $Button.Text = 'Close Window'
    $Button.Height = 50
    $Button.BackColor = 'DarkGray'
    $Button.FlatStyle = 'Flat'
    $Button.Font = New-Object System.Drawing.Font("Corbel",30,[System.Drawing.FontStyle]::Regular)
    $Form.Controls.Add($Button)

    # Close Button Action : Cleanup tasks, remove OSDReport directory, Set EnableCursorSuppression and close Form
    $Button.Add_Click({if(Test-Path "$env:SystemRoot\Temp\OSDReport"){Remove-Item -Path "$env:SystemRoot\Temp\OSDReport" -Recurse}; $Form.Close()})

    #################################### Create HTML Report ####################################

    # Build HTML Header
    $Header = @"
    <style>
    TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse; margin-left: auto; margin-right: auto}
    TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: lightgrey}
    TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
    TR:nth-child(odd) {background-color: #F0F0F0}
    TR:hover {background-color: #ffff00}
    H1,H2 {text-align: center}
    </style>
"@


    # Write html header to disk
    $Header |  Out-File $HTMLPath

    # Write header
    "<H1 style='text-align:center;'>Build Report<br>$($ComputerInfo.CsDNSHostName)   -    $ReportDate</H1><br>" | Add-Content $HTMLPath

    # Write System Information
    "<H2>Info</H2>" | Add-Content $HTMLPath
    $SystemInfo | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath

    # Write Environment Information
    "<H2>Environment</H2>" | Add-Content $HTMLPath
    $SystemEnv | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath

    # Write Volume Information
    "<H2>Volumes</H2>" | Add-Content $HTMLPath
    $SystemVolumes | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath

    # Write BitLocker Information
    "<H2>BitLocker</H2>" | Add-Content $HTMLPath
    $SystemBitLocker | ConvertTo-Html -Fragment | Add-Content $HTMLPath

    # Write Hardware Information
    "<H2>Hardware</H2>" | Add-Content $HTMLPath
    $SystemHardware | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath

    # Write Bios Information
    "<H2>Bios</H2>" | Add-Content $HTMLPath
    $SystemBios | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath

    # Write Network Information
    "<H2>Network</H2>" | Add-Content $HTMLPath
    $SystemNetwork | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath

    '<br>' | Add-Content $HTMLPath

    # Write AD Information - ( If avaliable )
    if ($Null -ne $SystemADInfo){
        [PSCustomObject]$SystemADInfo | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath
    }

    '<br>' | Add-Content $HTMLPath

    $NetworkAdpaters | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath

    # Write Task Sequence Variables - ( If avaliable )
    if ($Null -ne $SMSEnv){
        "<H2>Task Sequence Variables</H2>" | Add-Content $HTMLPath
        $SMSEnv.GetEnumerator() | Select Name, Value | Sort-Object Name | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath
    }

    # Write Apps Information
    "<H2>Applictaions</H2>" | Add-Content $HTMLPath
    $Apps | ConvertTo-Html -Fragment | Add-Content $HTMLPath

    # Write Driver Information
    "<H2>Drivers</H2>" | Add-Content $HTMLPath
    $Drivers  |  ConvertTo-Html -Fragment| Add-Content $HTMLPath

    # Write Hotfix Information
    "<H2>Hotifx</H2>" | Add-Content $HTMLPath
    $Hotfixes  |  ConvertTo-Html -Fragment | Add-Content $HTMLPath

    # Write Warning Information   (How do I get rid a string Array ...arrrr)
    "<H2>Warnings</H2>" | Add-Content $HTMLPath
    $FailedDevices | ConvertTo-Html -Fragment | Add-Content $HTMLPath

    # Write Post Contents
    ConvertTo-Html -PostContent "$HTMLPATH" | Add-Content $HTMLPath

    ################################################################################################################################################

    # Show Form
    $Form.ShowDialog()

}catch{Add-Content $LogFile -Value $_.Exception.Message}


