<#
.SYNOPSIS
    Compliments the script CM-Cleanup.ps1 and parses exported .csv and Deletes Applications and Packages from Configuration Manager

.DESCRIPTION
    The script will parse the Application and Package .csv exported from CM-Cleanup.ps1 and delete the object from Configuration Manager,

.INPUTS
    File Paths to exported Application and Packages .csv

.OUTPUTS
    Applications and Packages deleted from Configuration Manager

.NOTES
    Author:  Steven Drake
    Website: https://ourcommunityhelper.com
    Version:
        1.2: Handling of superseded applications, skip deletion.
        1.1: Added Package Filter and removed $ErrorActionPreference = 'Inquire'
        1.0: Initial release

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

# Set Suppress Confirmaton Prompt
[Bool]$SkipConfirmationPrompt = $false

# Set PackageType Filter
$PackageTypeFilter = "RegularPackage|Driver|ImageDeployment|BootImage|OSInstallPackage"

# Read Application CSV
$ImportedApplictaionList = import-csv -Path (Get-FileName -initialDirectory “C:\Windows\Temp” -Title "Select Appplication .CSV") -Delimiter ','

# Read Packages CSV
$ImportedPackageList = import-csv -Path (Get-FileName -initialDirectory “C:\Windows\Temp” -Title "Select Package .CSV") -Delimiter ',' | Where-Object {$_.PackageType -match $PackageTypeFilter}


# Confirm Auto Removal of Content
Get-Confirmation -Title "Auto-Approval Confirmation" -Message "Do you wish to with suppress confirmation messages?"

    if($MessageResult -eq 'Yes'){

    $SkipConfirmationPrompt = $true

    }

# Initiate Progress Counter
[int]$i = 0

# Remove $ApplicationPackages
ForEach ($item in $ImportedApplictaionList) {

    If($i -ne 0){

        # Percentage Caculator
        $Pecentage = [int][Math]::Round(($($i)/$($ImportedApplictaionList.Count))*100)

        Write-Progress -Activity "Application Delete Progress" -Status "$($Pecentage)% Complete:" -PercentComplete $Pecentage
    }

    # Get ApplicationPackages List
    $Package = Get-CMApplication | Where-Object {$_.PackageID -eq $item.PackageID}

    # If Packages Found
    if ($null -ne $Package){

       # Only delete non superseded applications
       If ($Package.IsSuperseded -eq $false){

            # Confirm Content Removal
            if ($SkipConfirmationPrompt-eq $false){Get-Confirmation -Title "Confirm Permanently Delete" -Message "Permanently Delete - Application`r`n`r`n$($Package.PackageID) : $($Package.LocalizedDisplayName)`r`n`r`nFrom Configuration Manager?"}

            # Remove Package From All DPs
            if($MessageResult -eq 'Yes' -or $SkipConfirmationPrompt -eq $true){

                Write-Verbose "Deleted - Application : $($Package.PackageID) : $($Package.LocalizedDisplayName)" -Verbose

                Remove-CMApplication -ModelName $Package.ModelName -Force

            }

        }else{Write-Verbose "Application found to be superseded! $($item.PackageID) : $($item.LocalizedDisplayName) - skipping deletion" -Verbose}

    }else{Write-Verbose "Application not found! $($item.PackageID) : $($item.LocalizedDisplayName)" -Verbose}

    # Increment Progress Counter
    $i++
}

# Initiate Progress Counter
[int]$i = 0

# Remove Packages
ForEach ($item in $ImportedPackageList) {

    # Percentage Caculator
    $Pecentage = [int][Math]::Round(($($i)/$($ImportedPackageList.Count))*100)

    Write-Progress -Activity "Package Delete Progress" -Status "$($Pecentage)% Complete:" -PercentComplete $Pecentage

    $FriendlyPackageType = $item.PackageType

    # Get Package
    $Package = Get-CMPackage -PackageType $FriendlyPackageType -Id $item.PackageID -Fast

    # If Packages Found
    if ($null -ne $Package){

        # Confirm Package Deletion
        if ($SkipConfirmationPrompt -eq $false){Get-Confirmation -Title "Confirm Permanently Delete" -Message "Permanently Delete - $($FriendlyPackageType)`r`n`r`n$($Package.PackageID) : $($Package.Name)`r`n`r`nFrom Configuration Manager?"}

        # Remove Package From All DPs
        if($MessageResult -eq 'Yes' -or $SkipConfirmationPrompt -eq $true){

            Write-Verbose "Deleted - $($item.PackageType) : $($Package.PackageID) : $($Package.Name)" -Verbose

            Switch($Package.PackageType){

            # RegularPackage
            0 {Remove-CMPackage -Id $Package.PackageID -Force}

            # DriverPackage
            3 {Remove-CMDriverPackage -Id $Package.PackageID -Force}

            # ImageDeployment
            257 {Remove-CMOperatingSystemImage -Id $Package.PackageID -Force}

            # BootImage
            258 {Remove-CMBootImage -Id $Package.PackageID -Force}

            # OSInstallPackage
            259 {Remove-CMOperatingSystemInstalle -Id $Package.PackageID -Force}

            default{Write-Verbose "Unknown Package Type" -Verbose}

            }

        }

    }else{Write-Verbose "Package not found! $($item.PackageID) : $($item.name)" -Verbose}

    # Increment Progress Counter
    $i++
}


Write-Verbose "Complete" -Verbose