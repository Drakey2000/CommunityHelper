##################################################################       Comments        ##################################################################
<#
.SYNOPSIS
    A graphical and html Operating System Deployment Build Report

.DESCRIPTION
    Used with Configuration Manager Deployment Task Sequence to provide an end user summary report. Providing details of
    Computer info, Bios, Network, Task Sequence Variables, Application, Drivers, Hotfixes, Driver Warnings.

.EXAMPLE

.NOTES
    Author     : STEVEN DRAKE - https://ourcommunityhelper.com/2020/11/27/operating-system-deployment-summary-screen/
    Version    : 12 Feb  2021 - Updated Try Catch BitLocker Get-BitLockerVolume
#>
##################################################################  Set Startup Parameters  ##################################################################

    # Set Script Source Folder
    $Source = $PSScriptRoot

    # Add Assembly
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing,System.DirectoryServices.AccountManagement

    # Add MahApps Framework - https://mahapps.com/
    Add-Type -Path "$Source\bin\MahApps.Metro.dll"
    Add-Type -Path "$Source\bin\System.Windows.Interactivity.dll"

    # Get Primary Monitor
    $PrimaryMonitor = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize

    # Set Log Folder
    $LogFolder = "$env:SystemRoot\Logs\CommunityHelper"

    # Create Log Folder
    New-Item -Path $LogFolder -ItemType Directory -Force

    # Get Report Date
    $ReportDate = Get-Date

    # Set Report File Path
    $LogFile = "$LogFolder\DeploymentReport.log"

    # Create Report Folder if it does not exist
    if (-not (Test-Path -Path (Split-Path -Path $LogFile))){New-Item -ItemType "directory" -Path (Split-Path -Path $LogFile)}

    # Set HTML File Path
    $HTMLPath =  "$LogFolder\DeploymentReport.html"

    # Create HTML folder if it does not exist
    if (-not (Test-Path -Path (Split-Path -Path $HTMLPath))){New-Item -ItemType "directory" -Path (Split-Path -Path $HTMLPath)}

    # Set Default (Reapplied on restart) : Enable Cursor Suppression:  0 = Disabled: Mouse cursor is not suppressed 1 = Enabled: Mouse cursor is suppressed (default) - https://support.microsoft.com/en-us/help/4494800/no-mouse-cursor-during-configuration-manager-osd-task-sequence
    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableCursorSuppression /t REG_DWORD /d 1 /f


    ##################################################################  Gather Reporting Information  ##################################################################

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
    Try{

        $SystemBitLocker = Get-BitLockerVolume | Select-Object MountPoint,VolumeType,VolumeStatus,EncryptionMethod,EncryptionPercentage,@{Name = "KeyProtector"; Expression = {$_.KeyProtector -join ", "}},AutoUnlockKeyStored,AutoUnlockEnabled,ProtectionStatus | Sort-Object MountPoint
    
    }Catch{Add-Content $LogFile -Value $_.Exception.Message}

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
        "Site Name" = $type.InvokeMember('SiteName','GetProperty',$null,$ADSystemInfo,$null)}

    }Catch{$RunAD = $False}

    # Get Network Adapter
    $NetworkAdpaters = Get-NetAdapter | Select-Object Name, MediaConnectionState ,MacAddress, LinkSpeed, MediaType | Sort-Object MediaConnectionState, Name

    # Add information text
    $Info = "`r`n"

    # Add Information Details
    $Info += "Information`r`n`r`n`t`t"
    $Info += $SystemInfo.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Add Envionment Details
    $Info += "Environment`r`n`r`n`t`t"
    $Info += $SystemEnv.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Addd Partion Volumes Details
    $Info += "Volumes`r`n`r`n"

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
    $Info += "BitLocker`r`n`r`n"

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
    $Info += "Hardware`r`n`r`n`t`t"
    $Info += $SystemHardware.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Add BIOS Details
    $Info += "Bios`r`n`r`n`t`t"
    $Info += $SystemBios.psobject.Properties | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    # Add Network Details
    $Info += "Network`r`n`r`n`t`t"
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

    $Info += "Task Sequence Variables`r`n`r`n`t"
    $Info += $SMSEnv.GetEnumerator() | Sort-Object Name | ForEach-Object {$_.Name, " : " ,$_.Value + "`r`n`t`t"}
    $Info += "`r`n"

    }

    # Gather Error Report : Failed Drivers
    $FailedDevices = Get-CimInstance -ClassName Win32_PNPEntity | Select-Object Name,Description,PNPClass,Manufacturer,@{Name = "HardwareID"; Expression = {$_.HardwareID -join ", "}},Status,ConfigManagerErrorCode | Where-Object {$_.ConfigManagerErrorCode -ne 0 }

    ##################################################################  Create WPF Window  ##################################################################

    # Load the main window XAML code
    [XML]$Xaml = [System.IO.File]::ReadAllLines("$Source\xaml\SplashScreen.xaml")

    # Create a synchronized hash table and add the WPF window and its named elements to it
    $UI = [System.Collections.Hashtable]::Synchronized(@{})
    $UI.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
    $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") |

        ForEach-Object -Process {
            $UI.$($_.Name) = $UI.Window.FindName($_.Name)
        }


    # Set Title Text Properties
    $UI.TitleTextBlock.MaxWidth = $PrimaryMonitor.Width
    $UI.TitleTextBlock.Text = "Deployment Complete - $($ComputerInfo.CsDNSHostName)"

    # Set Info Tab Properties
    $UI.InfoTextBlock.MaxWidth = $PrimaryMonitor.Width
    $UI.InfoTextBlock.Text = $Info

    # Create Applictaion Row List
    $Apps = Get-Package | Select-Object Name, Version | Sort-Object Name

    foreach ($App in $Apps){

    $row= New-Object PSObject
    Add-Member -inputObject $row -memberType NoteProperty -name “Name” -value $App.Name
    Add-Member -inputObject $row -memberType NoteProperty -name “Version” -value $App.Version

    $UI.AppDataGrid.AddChild($row)
    }

    # Create Drivers Row List
    $Drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver | Select-Object  DeviceClass, DeviceName, FriendlyName,DriverVersion, DriverProviderName, HardwareID | Sort-Object DeviceClass, DeviceName, DriverProviderName, DriverVersion

     foreach ($Driver in $Drivers){

    $row= New-Object PSObject
    Add-Member -inputObject $row -memberType NoteProperty -name “DeviceClass” -value $Driver.DeviceClass
    Add-Member -inputObject $row -memberType NoteProperty -name “DeviceName” -value $Driver.DeviceName
    Add-Member -inputObject $row -memberType NoteProperty -name “FriendlyName” -value $Driver.FriendlyName
    Add-Member -inputObject $row -memberType NoteProperty -name “DriverVersion” -value $Driver.DriverVersion
    Add-Member -inputObject $row -memberType NoteProperty -name “DriverProviderName” -value $Driver.DriverProviderName
    Add-Member -inputObject $row -memberType NoteProperty -name “HardwareID” -value $Driver.HardwareID

    $UI.DriverDataGrid.AddChild($row)
    }


    # Create Hotfix Row List
    $Hotfixes = Get-HotFix | Select-Object HotFixID, Description, InstalledOn | Sort-Object InstalledOn, HotFixID -Descending

    foreach ($HotFix in $Hotfixes){

    $row= New-Object PSObject
    Add-Member -inputObject $row -memberType NoteProperty -name “Hotfix” -value $HotFix.HotFixID
    Add-Member -inputObject $row -memberType NoteProperty -name “Description” -value $Hotfix.Description
    Add-Member -inputObject $row -memberType NoteProperty -name “Installed” -value $Hotfix.InstalledOn

    $UI.HotfixDataGrid.AddChild($row)
    }

    # Build warning text
    $Warning = "`r`n"

    if ($null -ne $FailedDevices ) {
        $Warning +="Please check drivers are installed and working correctly"
        $Warning += $FailedDevices | Out-String

        $UI.TabControl.SelectedIndex = 4

        }else{$UI.WarningTab.Visibility = "Hidden"}


    $UI.WarningTextBlock.MaxWidth = $PrimaryMonitor.Width
    $UI.WarningTextBlock.Text = $Warning

    $UI.LogTextBlock.MaxWidth = $PrimaryMonitor.Width
    $UI.LogTextBlock.Text = $LogFile

    ##################################################################  Create HTML Report  ##################################################################

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
        $SMSEnv.GetEnumerator() | Select-Object Name, Value | Sort-Object Name | ConvertTo-Html -As Table -Fragment | Add-Content $HTMLPath
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


    ##################################################################  Load WPF Window  ##################################################################


    # Close Button Action : Cleanup tasks, remove OSDReport directory, Set EnableCursorSuppression and close Form
    $UI.Button1.Add_Click({$UI.Window.Close()})

    # Event: Window loaded
    $UI.Window.Add_Loaded({

    # Activate the window to bring it to the fore
    $UI.Window.Activate()

    $UI.Window.Height = $PrimaryMonitor.Height
    $UI.Window.Width = $PrimaryMonitor.Width
    $UI.Window.TopMost = $True

    })

    # Display the window
    $UI.Window.ShowDialog()

}catch{Add-Content $LogFile -Value $_.Exception.Message}