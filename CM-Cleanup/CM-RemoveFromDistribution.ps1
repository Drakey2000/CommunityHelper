<#
.SYNOPSIS
    Compliments the script CM-Cleanup.ps1 and parses exported .csv and removes Packages from All Distribution Points

.DESCRIPTION
    The script will parse the Application and Package .csv exported from CM-Cleanup.ps1 and remove the content from all Distribution Points,
    Distribution Groups and move the Configuration Manager object to the associated Object Type 'To Be Deleted' Folder

.INPUTS
    File Paths to exported Application and Packages .csv

.OUTPUTS
    Packages removed from All Distribution Points and Moved to Object Type 'To Be Deleted' Folder

.NOTES
    Author  :  Steven Drake
    Website : https://ourcommunityhelper.com
    Version :
       1.1  : Handling of superseded applications, remove content from DPs, but leave application in the existing folder and do not move to actioned folder 
       1.0  : Initial release

#>

# Set ErrorAction Variable
$ErrorActionPreference = 'SilentlyContinue'

# Browse Directory Import CSV Function
Function Get-FileName ($initialDirectory,$Title){

    [System.Reflection.Assembly]::LoadWithPartialName(“System.windows.forms”) | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = $Title
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = “CSV (*.csv)| *.csv”
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

# Confirm Distribution Content Removal Message
Function Get-Confirmation ($Title,$Message){

    Add-Type -AssemblyName Microsoft.VisualBasic
    $ButtonType = "YesNoCancel"
    $MessageIcon = "Exclamation"
    $MessageBody = $Message
    $MessageTitle = $Title

    $script:MessageResult = [Microsoft.VisualBasic.Interaction]::MsgBox($MessageBody,"$($ButtonType),SystemModal,MsgBoxSetForeground,$($MessageIcon)",$MessageTitle)

    If ($MessageResult -eq 'Cancel') {[Environment]::Exit(0)}
}
# Set To Be Deleted Date Folder
$Date = Get-Date -Format "dd MMM yyyy"

# Set Actioned Root Folder
$ActionedFolder = "To Be Deleted"

# Set PackageType Filter
$PackageTypeFilter = "RegularPackage|Driver|ImageDeployment|BootImage|OSInstallPackage"

# Set Suppress Confirmaton Prompt
[Bool]$SkipConfirmationPrompt = $false

# Read Application CSV
$ImportedApplictaionList = import-csv -Path (Get-FileName -initialDirectory “C:\Windows\Temp” -Title "Select Appplication .CSV") -Delimiter ','

# Read Packages CSV
$ImportedPackageList = import-csv -Path (Get-FileName -initialDirectory “C:\Windows\Temp” -Title "Select Package .CSV") -Delimiter ',' | Where-Object {$_.PackageType -match $PackageTypeFilter}

Write-Verbose "Get - distribution points" -Verbose

# Get All Distribution Point Servers
$allDPs = Get-CMDistributionPointInfo | Select-Object -ExpandProperty ServerName

# Get All Distribution Groups
$allDPGroups = Get-CMDistributionPointGroup | Select-Object -ExpandProperty Name

Write-Verbose "Get - distribution points groups" -Verbose

# Confirm Auto Removal of Content
Get-Confirmation -Title "Auto-Approval Confirmation" -Message "Do you wish to with suppress confirmation messages?"

    if($MessageResult -eq 'Yes'){

    $SkipConfirmationPrompt = $true

    }

# Initiate Progress Counter
[int]$i = 0

# Remove $ApplicationPackages
ForEach ($item in $ImportedApplictaionList) {

    # Percentage Caculator
    $Pecentage = [int][Math]::Round(($($i)/$($ImportedApplictaionList.Count))*100)

    Write-Progress -Activity "Application Content Removal Progress" -Status "$($Pecentage)% Complete:" -PercentComplete $Pecentage

    # Get ApplicationPackages List
    $Package = Get-CMApplication | Where-Object {$_.PackageID -eq $item.PackageID}

    # If Packages Found
    if ($null -ne $Package){
        
        # Check if Applictaion is Superseded
        If ($Package.IsSuperseded -eq $true){Write-Verbose "$($Package.LocalizedDisplayName) - is a superseded Application and may still be required" -Verbose}

        # Confirm Content Removal
        if ($SkipConfirmationPrompt-eq $false){Get-Confirmation -Title "Confirm Content Removal" -Message "Remove - Application`r`n`r`n$($Package.PackageID) : $($Package.LocalizedDisplayName)`r`n`r`nFrom all Distribution Points?"}

        # Remove Package From All DPs
        if($MessageResult -eq 'Yes' -or $SkipConfirmationPrompt -eq $true){

            # Array of DPs fails if Package already removed
            ForEach ($DP in $allDPs) {

                Write-Verbose "Remove - Application : $($Package.PackageID) : $($Package.LocalizedDisplayName) from DP : $($DP)" -Verbose

                Remove-CMContentDistribution -ApplicationId $Package.CI_ID -DistributionPointName $DP -Force

            }

            # Array of DPs fails if Package already removed
            ForEach ($DPGroup in $allDPGroups){

                Write-Verbose "Remove - Application : $($Package.PackageID) : $($Package.LocalizedDisplayName) from DP Group : $($DPGroup)" -Verbose

                Remove-CMContentDistribution -ApplicationId $Package.CI_ID -DistributionPointGroupName $DPGroup -Force

            }

            # Get Object Path
            $PackageObjectPath = (Get-CimInstance -Namespace root/SMS/site_$($SiteCode) -Query "select * from SMS_ApplicationLatest WHERE CI_ID = '$($Package.CI_ID)'").ObjectPath

            # Get Parent Folder
            $ParentFolder = $PackageObjectPath.Split('/')[1]

            # Move none superseded Applictaions only
            If ($Package.IsSuperseded -eq $false){

                # Is Object Is Outside Of Actioned Folder
                If($ParentFolder -ne $ActionedFolder){

                    # Build Package Folder Root Path
                    $MoveTo = "$($SiteCode):\Application\$($ActionedFolder)"

                    # Create Package Root Folder
                    if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

                    # Assign Date Sub Folder
                    $MoveTo = "$($MoveTo)\$($Date)"

                    # If SubFolder Does Not Exist - Create Sub Folder
                    if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

                    Write-Verbose "Move - Application : $($Package.PackageID) : $($Package.LocalizedDisplayName) to $($MoveTo)" -Verbose

                    # Move Package to Actioned Date Folder
                    $Package | Move-CMObject -FolderPath $MoveTo

                }else{

                    Write-Verbose "Move - Application : $($Package.PackageID) : $($Package.LocalizedDisplayName) in $($PackageObjectPath)" -Verbose
                }
            }
        }

    else{Write-Verbose "Application not found! $($item.PackageID) : $($item.LocalizedDisplayName)" -Verbose}

    # Increment Progress Counter
    $i++
}

}

# Initiate Progress Counter
[int]$i = 0

# Remove Packages
ForEach ($item in $ImportedPackageList) {

    # Percentage Caculator
    $Pecentage = [int][Math]::Round(($($i)/$($ImportedPackageList.Count))*100)

    Write-Progress -Activity "Package Content Removal Progress" -Status "$($Pecentage)% Complete:" -PercentComplete $Pecentage

    # Get Package List
    $Package = Get-CMPackage -PackageType $item.PackageType -Id $item.PackageID -Fast

    # If Packages Found
    if ($null -ne $Package){

        #https://docs.microsoft.com/en-us/powershell/module/configurationmanager/move-cmobject?view=sccm-ps
        Switch($Package.PackageType){

            # RegularPackage
            0 {
                $PackageTypeSearch = "select * from SMS_Package WHERE PackageID = '$($Package.PackageID)'"
                $FriendlyPackageType = "Package"
                }
            # DriverPackage
            3 {
                $PackageTypeSearch = "select * from SMS_DriverPackage WHERE PackageID = '$($Package.PackageID)'"
                $FriendlyPackageType = "DriverPackage"
            }
            # ImageDeployment
            257 {
                $PackageTypeSearch = "select * from SMS_ImagePackage WHERE PackageID = '$($Package.PackageID)'"
                $FriendlyPackageType = "OperatingSystemImage"
            }
            # BootImage
            258 {
                $PackageTypeSearch = "select * from SMS_BootImagePackage WHERE PackageID = '$($Package.PackageID)'"
                $FriendlyPackageType = "BootImage"
            }
            # OSInstallPackage
            259 {
                $PackageTypeSearch = "select * from SMS_OSInstallPackage WHERE PackageID = '$($Package.PackageID)'"
                $FriendlyPackageType = "OperatingSystemInstaller"
            }
            default{$FriendlyPackageType = "Unknown Package Type"}

        }


        # Confirm Content Removal
        if ($SkipConfirmationPrompt -eq $false){Get-Confirmation -Title "Confirm Content Removal" -Message "Remove - $($FriendlyPackageType)`r`n`r`n$($Package.PackageID) : $($Package.Name)`r`n`r`nFrom all Distribution Points?"}

        # Remove Package From All DPs
        if($MessageResult -eq 'Yes' -or $SkipConfirmationPrompt -eq $true){

            # Array of DPs fails if Package already removed
            ForEach ($DP in $allDPs) {

                Write-Verbose "Remove - $($FriendlyPackageType): $($Package.PackageID) : $($Package.Name) from DP : $($DP)" -Verbose

                Remove-CMContentDistribution -PackageId $Package.PackageID -DistributionPointName $DP -Force

            }

            # Array of DPs fails if Package already removed
            ForEach ($DPGroup in $allDPGroups){

                Write-Verbose "Remove - $($FriendlyPackageType) : $($Package.PackageID) : $($Package.Name) from DP Group : $($DPGroup)" -Verbose

                Remove-CMContentDistribution -PackageId $Package.PackageID -DistributionPointGroupName $DPGroup -Force

            }

            # Get Object Path
            $PackageObjectPath = (Get-CimInstance -Namespace root/SMS/site_$($SiteCode) -Query $PackageTypeSearch).ObjectPath

            # Get Parent Folder
            $ParentFolder = $PackageObjectPath.Split('/')[1]

            # Is Object Is Outside Of Actioned Folder
            If($ParentFolder -ne $ActionedFolder){

                # Build Package Folder Root Path
                $MoveTo = "$($SiteCode):\$($FriendlyPackageType)\$($ActionedFolder)"

                # Create Package Root Folder
                if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

                # Assign Date Sub Folder
                $MoveTo = "$($MoveTo)\$($Date)"

                # If SubFolder Does Not Exist - Create Sub Folder
                if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

                Write-Verbose "Move - $($FriendlyPackageType) : $($Package.PackageID) : $($Package.Name) to $($MoveTo)" -Verbose

                # Move Package to Actioned Date Folder
                $Package | Move-CMObject -FolderPath $MoveTo

            }else{

                Write-Verbose "Leave - $($FriendlyPackageType) : $($Package.PackageID) : $($Package.Name) in $($PackageObjectPath)" -Verbose
            }

        }

    }else{Write-Verbose "Package not found! $($item.PackageID) : $($item.name)" -Verbose}

    # Increment Progress Counter
    $i++
}

Write-Verbose "Complete" -Verbose