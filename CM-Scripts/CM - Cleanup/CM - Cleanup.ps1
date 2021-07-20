<#
.SYNOPSIS
    This script will export a .csv file showing all applications and packages that are not in use within Configuration Manager

.DESCRIPTION
   Connect to your Configuration Manger PowerShell Console and execute. A .csv file of all applications and packages that are not in use
   will be written to C:\Windows\Temp\SCCM_Apps.csv and C:\Windows\Temp\SCCM_Pacakes.csv

.NOTES
    The original author was Matt Bobke : https://mattbobke.com/2018/05/06/finding-unused-sccm-applications-and-packages/ and enhancements by Skatterbrainz

    Since its has been updated by
    File Name      : SCCM - Clenup.ps1
    Author         : S.P.Drake
    Version        : 1.0  : Enhnced package filter, exlude predinfied pacakes, Configuration Manager Client Piloting Package and DefaultImages and dependant programs

#>


# Assign report folder
$ReportFolder = "$env:systemdrive\Windows\Temp"

# Suppress Fast check not in use warning message
$CMPSSuppressFastNotUsedCheck = $true

Write-Host "Get - applications" -ForegroundColor Cyan

# Grab all Applications, IsDeployed=False, NumberofDependentTS=0, NumberofDependentDTs=0 applications (can't filter packages like applications)
$FinalApplications = Get-CMApplication -Fast | Where-Object {($_.IsDeployed -eq $False) -and ($_.NumberofDependentTS -eq 0) -and ($_.NumberofDependentDTs -eq 0)}

Write-Host "Get - packages" -ForegroundColor Cyan

# Grab all Regular Packages, IsPredefinedPackage=False and Name -ne 'Configuration Manager Client Piloting Package' packages
$RegularPackage = Get-CMPackage -Fast -PackageType RegularPackage | Where-Object {($_.IsPredefinedPackage -eq $false -and ($_.Name -ne 'Configuration Manager Client Piloting Package'))}

# Grab all Driver Packages
$DriverPackage = Get-CMPackage -Fast -PackageType Driver

# Grab all Operating System Image packages
$ImageDeploymentPackage = Get-CMPackage -Fast -PackageType ImageDeployment

# Grab all Operating System Upgrade packages
$OSInstallPackagePackage = Get-CMPackage -Fast -PackageType OSInstallPackage

# Grab all Boot Image packages, DefaultImage=False
$BootImagePackage = Get-CMPackage -Fast -PackageType BootImage | Where-Object {$_.DefaultImage -eq $false}

# Combine all applictaions and packages into one list
$AllPackages = ($RegularPackage + $DriverPackage + $ImageDeploymentPackage + $OSInstallPackagePackage + $BootImagePackage)

Write-Host "Get - deployments" -ForegroundColor Cyan

# Grab all deployments, filter to just a list of their package IDs
$DeploymentPackageIDs = Get-CMDeployment | Select-Object PackageID | Sort-Object PackageID | Get-Unique -AsString

Write-Host "Get - task sequences" -ForegroundColor Cyan

# Grab all task sequences, References -ne $null, TsEnabled -ne $false (can not use -Fast)
$FilteredTaskSequences = Get-CMTaskSequence | Where-Object { $_.References -ne $null -and $_.TsEnabled -ne $false }

# If filtered task Sequence found
if ($FilteredTaskSequences.Count -ne 0) {

    Write-Host "Filter - task sequence references only" -ForegroundColor Cyan

    # Filter task sequnces to just a list of their references (can not use -Fast)
    $TSReferences = ( $FilteredTaskSequences | Select-Object References).References.Package | Sort-Object | Get-Unique -AsString

    Write-Host "Filter - task sequence dependant programs only " -ForegroundColor Cyan

    # Filter task Sequences dependant programs, filter to just a list of their references (can not use -Fast)
    $TSDependentProgram = $FilteredTaskSequences | Select-Object DependentProgram | Foreach-Object {$_.DependentProgram.Split(';;')[0]} | Sort-Object | Get-Unique -AsString
}


Write-Host "Filter - applications and packages that are not active" -ForegroundColor Cyan

# Initialise FinalPackages
$FinalPackages = New-Object -TypeName 'System.Collections.ArrayList'

# Filter packages to only those that do not have their PackageID in the list of references
foreach ($package in $AllPackages) {
    if (($package.PackageID -notin $TSReferences -and $package.PackageID -notin $DeploymentPackageIDs -and $package.PackageID -notin $TSDependentProgram )) {
        $FinalPackages.Add($package) | Out-Null
    }
}

Write-Host "Export - applications and packages that are not active" -ForegroundColor Cyan

# Export application list to .csv
$FinalApplications `
    | Select-Object -Property LocalizedDisplayName, PackageID, DateCreated, DateLastModified, IsDeployable, IsEnabled, IsExpired, IsHidden, IsSuperseded `
    | Sort-Object -Property LocalizedDisplayName `
    | Export-Csv -Path "$ReportFolder\SCCM_Apps.csv" -NoTypeInformation

# Export package list to .csv
$FinalPackages `
    | Select-Object Name, PackageType, PackageID, SourceDate, LastRefreshTime, PkgSourcePath `
    | Sort-Object -Property PackageType, Name `
    | Export-Csv -Path "$ReportFolder\SCCM_Packages.csv" -NoTypeInformation

Write-Host "Done! CSVs stored in $ReportFolder" -ForegroundColor Green

# Future releases will have the option for Report Only, Prompt On Delete, or Auto Delete