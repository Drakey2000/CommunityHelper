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
    Author:  Steven Drake
    Website: https://ourcommunityhelper.com
    Version:
    Comment: Will revist to make the syntax more efficient and compact

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

# Read Application CSV
$ImportedApplictaionList = import-csv -Path (Get-FileName -initialDirectory “C:\Windows\Temp” -Title "Select Appplication CSV") -Delimiter ','

# Read Packages CSV
$ImportedPackageList = import-csv -Path (Get-FileName -initialDirectory “C:\Windows\Temp” -Title "Select Package CSV") -Delimiter ','

# Set To Be Deleted Date Folder
$Date = Get-Date -Format "dd MMM yyyy"

# Initialise Packages List By Type From CSV
$RegularPackages = @($ImportedPackageList | Where-Object {$_.PackageType -eq 'RegularPackage'} | Select-Object -ExpandProperty PackageID)

$DriverPackages = @($ImportedPackageList | Where-Object {$_.PackageType -eq 'Driver'} | Select-Object -ExpandProperty PackageID)

$ImageDeploymentPackages = @($ImportedPackageList | Where-Object {$_.PackageType -eq 'ImageDeployment'} | Select-Object -ExpandProperty PackageID)

$OSInstallPackagePackages = @($ImportedPackageList | Where-Object {$_.PackageType -eq 'OSInstallPackage'} | Select-Object -ExpandProperty PackageID)

$BootImagePackages = @($ImportedPackageList | Where-Object {$_.PackageType -eq 'BootImage'} | Select-Object -ExpandProperty PackageID)

$ApplicationPackages = @($ImportedApplictaionList | Select-Object -ExpandProperty PackageID)

Write-Verbose "Get - distribution points" -Verbose

# Get All Distribution Point Servers
$allDPs = Get-CMDistributionPointInfo | Select-Object -ExpandProperty ServerName

# Get All Distribution Groups
$allDPGroups = Get-CMDistributionPointGroup | Select-Object -ExpandProperty Name

Write-Verbose "Get - distribution points groups" -Verbose

# Remove RegularPackages
ForEach ($id in $RegularPackages) {

    # Get Pacakge List
    $Package = Get-CMPackage -PackageType RegularPackage -Id $id -Fast

    # Confirm Content Removal
    Get-Confirmation -Title "Confirm Content Removal" -Message "Remove - RegularPackage`r`n`r`n$($id) : $($Package.Name)`r`n`r`nFrom all Distribution Points?"

    # Remove Package From All DPs
    if($MessageResult -eq 'Yes'){

        # Array of DPs fails if Package already removed
        ForEach ($DP in $allDPs) {

            Write-Verbose "Remove - RegularPackage: $($id) : $($Package.Name) from $($DP)" -Verbose

            Remove-CMContentDistribution -PackageId $id -DistributionPointName $DP -Force

        }

        # Array of DPs fails if Package already removed
        ForEach ($DPGroup in $allDPGroups){

            Write-Verbose "Remove - RegularPackage : $($id) : $($Package.Name) from $($DPGroup)" -Verbose

            Remove-CMContentDistribution -PackageId $id -DistributionPointGroupName $DPGroup -Force

        }

        # Move Package To Actioned Folder
        $MoveTo = "$($SiteCode):\Package\To Be Deleted"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        $MoveTo = "$($MoveTo)\$($Date)"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        if ($package.ObjectPath -notlike "*To Be Deleted*" ) {

            Write-Verbose "Move - RegularPackage : $($id) : $($Package.Name) to $($MoveTo)" -Verbose

            $Package | Move-CMObject -FolderPath $MoveTo

        }else{

            Write-Verbose "Move - RegularPackage : $($id) : $($Package.Name) to $($Package.ObjectPath)" -Verbose

        }
    }
}

# Remove $DriverPackage
ForEach ($id in $DriverPackages) {

    # Get DriverPacakge List
    $Package = Get-CMPackage -PackageType Driver -Id $id -Fast

    # Confirm Content Removal
    Get-Confirmation -Title "Confirm Content Removal" -Message "Remove - Driver`r`n`r`n$($id) : $($Package.Name)`r`n`r`nFrom all Distribution Points?"

    # Remove Package From All DPs
    if($MessageResult -eq 'Yes'){

        # Array of DPs fails if Package already removed
        ForEach ($DP in $allDPs) {

            Write-Verbose "Remove - Driver : $($id) : $($Package.Name) from $($DP)" -Verbose

            Remove-CMContentDistribution -DriverPackageId $id -DistributionPointName $DP -Force

        }

        # Array of DPs fails if Package already removed
        ForEach ($DPGroup in $allDPGroups){

            Write-Verbose "Remove - Driver : $($id) : $($Package.Name) from $($DPGroup)" -Verbose

            Remove-CMContentDistribution -DriverPackageId $id  -DistributionPointGroupName $DPGroup -Force

        }

        # Move Package to actioned folder
        $MoveTo = "$($SiteCode):\DriverPackage\To Be Deleted"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        $MoveTo = "$($MoveTo)\$($Date)"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        if ($package.ObjectPath -notlike "*To Be Deleted*" ) {

            Write-Verbose "Move - Driver : $($id) : $($Package.Name) to $($MoveTo)" -Verbose

            $Package | Move-CMObject -FolderPath $MoveTo

        }else{

            Write-Verbose "Move - Driver : $($id) : $($Package.Name) to $($Package.ObjectPath)" -Verbose

        }
    }
}

# Remove $ImageDeploymentPackages
ForEach ($id in $ImageDeploymentPackages) {

    # Get ImageDeploymentPackages List
    $Package = Get-CMPackage -PackageType ImageDeployment -Id $id -Fast

    Get-Confirmation -Title "Confirm Content Removal" -Message "Remove - ImageDeployment`r`n`r`n$($id) : $($Package.Name)`r`n`r`nFrom all Distribution Points?"

    # Remove Package From All DPs
    if($MessageResult -eq 'Yes'){

        # Array of DPs fails if Package already removed
        ForEach ($DP in $allDPs) {

            Write-Verbose "Remove - ImageDeployment : $($id) : $($Package.Name) from $($DP)" -Verbose

            Remove-CMContentDistribution -OperatingSystemImageId $id -DistributionPointName $DP -Force

        }

        # Array of DPs fails if Package already removed
        ForEach ($DPGroup in $allDPGroups){

            Write-Verbose "Remove - ImageDeployment : $($id) : $($Package.Name) from $($DPGroup)" -Verbose

            Remove-CMContentDistribution -OperatingSystemImageId $id -DistributionPointGroupName $DPGroup -Force

        }


        # Move Package to actioned folder
        $MoveTo = "$($SiteCode):\OperatingSystemImage\To Be Deleted"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        $MoveTo = "$($MoveTo)\$($Date)"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        if ($package.ObjectPath -notlike "*To Be Deleted*" ) {

            Write-Verbose "Move - ImageDeployment : $($id) : $($Package.Name) to $($MoveTo)" -Verbose

            $Package | Move-CMObject -FolderPath $MoveTo

        }else{

            Write-Verbose "Move - ImageDeployment : $($id) : $($Package.Name) to $($Package.ObjectPath)" -Verbose

        }
    }
}

# Remove $OSInstallPackagePackages
ForEach ($id in $OSInstallPackagePackages) {

    # Get OSInstallPackagePackages List
    $Package = Get-CMPackage -PackageType OSInstallPackage -Id $id -Fast

    # Confirm Content Removal
    Get-Confirmation -Title "Confirm Content Removal" -Message "Remove - OSInstallPackage`r`n`r`n$($id) : $($Package.Name)`r`n`r`nFrom all Distribution Points?"

    # Remove Package From All DPs
    if($MessageResult -eq 'Yes'){

        # Array of DPs fails if Package already removed
        ForEach ($DP in $allDPs) {

            Write-Verbose "Remove - OSInstallPackage : $($id) : $($Package.Name) from $($DP)" -Verbose

            Remove-CMContentDistribution -OperatingSystemInstallerId $id -DistributionPointName $DP -Force

        }

        # Array of DPs fails if Package already removed
        ForEach ($DPGroup in $allDPGroups){

            Write-Verbose "Remove - OSInstallPackage : $($id) : $($Package.Name) from $($DPGroup)" -Verbose

            Remove-CMContentDistribution -OperatingSystemInstallerId $id -DistributionPointGroupName $DPGroup -Force

        }

        # Move Package to actioned folder
        $MoveTo = "$($SiteCode):\OperatingSystemInstaller\To Be Deleted"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        $MoveTo = "$($MoveTo)\$($Date)"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        if ($package.ObjectPath -notlike "*To Be Deleted*" ) {

            Write-Verbose "Move - OSInstallPackage : $($id) : $($Package.Name) to $($MoveTo)" -Verbose

            $Package | Move-CMObject -FolderPath $MoveTo

        }else{

            Write-Verbose "Move - OSInstallPackage : $($id) : $($Package.Name) to $($Package.ObjectPath)" -Verbose

        }
    }
}


# Remove $BootImagePackages
ForEach ($id in $BootImagePackages) {

    # Get BootImagePackages List
    $Package = Get-CMPackage -PackageType BootImage -Id $id -Fast

    # Confirm Content Removal
    Get-Confirmation -Title "Confirm Content Removal" -Message "Remove - BootImage`r`n`r`n$($id) : $($Package.Name)`r`n`r`nFrom all Distribution Points?"

    # Remove Package From All DPs
    if($MessageResult -eq 'Yes'){

        # Array of DPs fails if Package already removed
        ForEach ($DP in $allDPs) {

            Write-Verbose "Remove - BootImage : $($id) : $($Package.Name) from $($DP)" -Verbose

            Remove-CMContentDistribution  -BootImageId $id -DistributionPointName $DP -Force

        }

        # Array of DPs fails if Package already removed
        ForEach ($DPGroup in $allDPGroups){

            Write-Verbose "Remove - BootImage : $($id) : $($Package.Name) from $($DPGroup)" -Verbose

            Remove-CMContentDistribution -BootImageId $id -DistributionPointGroupName $DPGroup -Force

        }

        # Move Package to actioned folder
        $MoveTo = "$($SiteCode):\BootImage\To Be Deleted"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        $MoveTo = "$($MoveTo)\$($Date)"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        if ($package.ObjectPath -notlike "*To Be Deleted*" ) {

            Write-Verbose "Move - BootImage : $($id) : $($Package.Name) to $($MoveTo)" -Verbose

            $Package | Move-CMObject -FolderPath $MoveTo

        }else{

            Write-Verbose "Move - BootImage : $($id) : $($Package.Name) to $($Package.ObjectPath)" -Verbose

        }
    }
}

# Remove $ApplicationPackages
ForEach ($id in $ApplicationPackages) {

    # Get ApplicationPackages List
    $Package = Get-CMApplication | Where-Object {$_.PackageID -eq $id}

    # Confirm Content Removal
    Get-Confirmation -Title "Confirm Content Removal" -Message "Remove - Application`r`n`r`n$($id) : $($Package.LocalizedDisplayName)`r`n`r`nFrom all Distribution Points?"

    # Remove Package From All DPs
    if($MessageResult -eq 'Yes'){

        # Array of DPs fails if Package already removed
        ForEach ($DP in $allDPs) {

            Write-Verbose "Remove - Application : $($id) : $($Package.LocalizedDisplayName) from $($DP)" -Verbose

            Remove-CMContentDistribution -ApplicationId $Package.CI_ID -DistributionPointName $DP -Force

        }

        # Array of DPs fails if Package already removed
        ForEach ($DPGroup in $allDPGroups){

            Write-Verbose "Remove - Application : $($id) : $($Package.LocalizedDisplayName) from $($DPGroup)" -Verbose

            Remove-CMContentDistribution -ApplicationId $Package.CI_ID -DistributionPointGroupName $DPGroup -Force

        }

        # Move Package to actioned folder
        $MoveTo = "$($SiteCode):\Application\To Be Deleted"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        $MoveTo = "$($MoveTo)\$($Date)"

        if (!(Test-Path -Path $MoveTo)){New-Item -Path $MoveTo}

        if ($package.ObjectPath -notlike "*To Be Deleted*" ) {

            Write-Verbose "Move - Application : $($id) : $($Package.Name) to $($MoveTo)" -Verbose

            $Package | Move-CMObject -FolderPath $MoveTo

        }else{

            Write-Verbose "Move - Application : $($id) : $($Package.Name) to $($Package.ObjectPath)" -Verbose

        }
    }
}