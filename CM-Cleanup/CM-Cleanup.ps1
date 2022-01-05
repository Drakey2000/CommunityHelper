<#
.SYNOPSIS
    This script will export a .csv file showing all applications and packages that are not in use within Configuration Manage

.DESCRIPTION
   Connect to your Configuration Manger PowerShell Console and execute. A .csv file of all applications and packages that are not in use
   will be written to C:\Windows\Temp\CM_Apps.csv and C:\Windows\Temp\CM_Packages.csv

.NOTES
    The original author was Matt Bobke : https://mattbobke.com/2018/05/06/finding-unused-sccm-applications-and-packages/ and enhancements by Skatterbrainz
    and has since been updated by S.P.Drake

    Full functionality requires Configuration Manager Release 2010 or later 

    File Name      : CM - Cleanup.ps1
    Author         : S.P.Drake
    Version        : 1.2  : Added superseded -eq False to applictaion filter (as if used in a task sequence, all superseded content need to be avaliable on DPs) 
    Version        : 1.1  : Added content distribution count, package type translation and ConfigurationManager compatibility
    Version        : 1.0  : Enhanced package filter, exclude predefined packages, Configuration Manager Client Piloting Package and DefaultImages and dependant programs

#>

# Assign report folder
$ReportFolder = "$env:systemdrive\Windows\Temp"

# Suppress Fast check not in use warning message
$CMPSSuppressFastNotUsedCheck = $true

Write-Verbose "Get - distribution points and package content" -Verbose

# Initialise $packageContentCount array
$packageContentCount = @()

# Get all distribution points servers
$allDPs = Get-CMDistributionPointInfo | Select-Object -ExpandProperty ServerName

# Get the content on each distribution pint
foreach ($dp in $allDPs){

    $packageContentCount += Get-CMDeploymentPackage -DistributionPointName $dp | Select-Object -ExpandProperty PackageID }

# Group the content found on each distribution point to get a package distributed total count
$groupedPackageContentCount  = $packageContentCount | Sort-Object $_.Name | Group-Object $_.Name

Write-Verbose "Get - applications" -Verbose

# Get all Applications that are not deployed, have no dependant task sequences, no deployment types that depend on this application and not superseded - (can't filter packages like applications)
$AllApplications = Get-CMApplication | Where-Object {($_.IsDeployed -eq $False) -and ($_.NumberofDependentTS -eq 0) -and ($_.NumberofDependentDTs -eq 0) -and ($_.IsSuperseded -eq $False)}

Write-Verbose "Get - packages" -Verbose

# If running ConfigurationManager version 2010 or later
If ((Get-Module -Name ConfigurationManager).Version.Major -ge 5 -and (Get-Module -Name ConfigurationManager).Version.Minor -ge 2010){

    # Get all Regular Packages that are not predefined packages and package name not 'Configuration Manager Client Piloting Package'
    $RegularPackage = Get-CMPackage -Fast -PackageType RegularPackage | Where-Object {($_.IsPredefinedPackage -eq $false) -and ($_.Name -ne 'Configuration Manager Client Piloting Package')}

    # Get all Driver Packages
    $DriverPackage = Get-CMPackage -Fast -PackageType Driver

    # Get all Operating System Image packages
    $ImageDeploymentPackage = Get-CMPackage -Fast -PackageType ImageDeployment

    # Get all Operating System Upgrade packages
    $OSInstallPackagePackage = Get-CMPackage -Fast -PackageType OSInstallPackage

    # Get all Boot Image packages, DefaultImage=False
    $BootImagePackage = Get-CMPackage -Fast -PackageType BootImage | Where-Object {$_.DefaultImage -eq $false}

    # Combine all packages lists together
    $AllPackages = ($RegularPackage + $DriverPackage + $ImageDeploymentPackage + $OSInstallPackagePackage + $BootImagePackage)}

    else{

    # Get all Regular Packages that are not predefined packages and package name not 'Configuration Manager Client Piloting Package'
    $AllPackages = Get-CMPackage -Fast | Where-Object {($_.IsPredefinedPackage -eq $false) -or ($_.Name -ne 'Configuration Manager Client Piloting Package')}

    }

Write-Verbose "Get - deployments" -Verbose

# Get all deployments, filter to just a list of their package IDs
$DeploymentPackageIDs = Get-CMDeployment | Select-Object PackageID | Sort-Object | Get-Unique -AsString

Write-Verbose "Get - task sequences" -Verbose

# Get all task sequences that have references and not disabled (cannot use -Fast)
$FilteredTaskSequences = Get-CMTaskSequence | Where-Object { ($_.References -ne $null) -and ($_.TsEnabled -ne $false) }

# If filtered task Sequence found
if ($FilteredTaskSequences.Count -ne 0) {

    Write-Verbose "Filter - task sequence references only" -Verbose

    # Filter task sequences to just a list of their references (cannot use -Fast)
    $TSReferences = ( $FilteredTaskSequences | Select-Object References).References.Package | Sort-Object | Get-Unique -AsString

    Write-Verbose "Filter - task sequence dependant programs only " -Verbose

    # Filter task Sequence’s dependant programs, filter to just a list of their references (cannot use -Fast)
    $TSDependentProgram = $FilteredTaskSequences | Select-Object DependentProgram | Foreach-Object {$_.DependentProgram.Split(';;')[0]} | Sort-Object | Get-Unique -AsString
}

Write-Verbose "Filter - applications and packages that are not active" -Verbose

# Initialise FinalApplications
$FinalApplications = New-Object -TypeName 'System.Collections.ArrayList'

# Initialise FinalPackage
$FinalPackages = New-Object -TypeName 'System.Collections.ArrayList'

# Append content distribution count to the application list
foreach ($App in $AllApplications) {
        $App | Add-Member -MemberType NoteProperty DPCount -Value ($groupedPackageContentCount | Where-Object {$_.Name -eq $App.PackageID} | Select-Object -ExpandProperty count)
        $FinalApplications.Add($App) | Out-Null
}

# Filter packages to only those that do not have their PackageID in the list of references and append content distribution count to the package list
foreach ($Package in $AllPackages) {
    if (($Package.PackageID -notin $TSReferences) -and ($Package.PackageID -notin $DeploymentPackageIDs.PackageID) -and ($Package.PackageID -notin $TSDependentProgram)) {
        $Package | Add-Member -MemberType NoteProperty DPCount -Value ($groupedPackageContentCount | Where-Object {$_.Name -eq $Package.PackageID} | Select-Object -ExpandProperty count)
        $FinalPackages.Add($Package) | Out-Null
    }
}

Write-Verbose "Export - applications and packages that are not active" -Verbose

# Export application list to .csv
$FinalApplications `
    | Select-Object -Property LocalizedDisplayName, PackageID, DateCreated, DateLastModified, IsDeployable, IsEnabled, IsExpired, IsHidden, IsSuperseded, DPCount  `
    | Sort-Object -Property LocalizedDisplayName `
    | Export-Csv -Path "$ReportFolder\CM_Applications.csv" -NoTypeInformation

# Export package list to .csv
$FinalPackages `
    | Select-Object Name, @{Name = "PackageType";Expression = {$_.PackageType -replace '258','BootImage' -replace '3','Driver' -replace '257','ImageDeployment' -replace '259','OSInstallPackage' -replace '0','RegularPackage'}},PackageID, SourceDate, LastRefreshTime, PkgSourcePath, DPCount `
    | Sort-Object -Property PackageType, Name `
    | Export-Csv -Path "$ReportFolder\CM_Packages.csv" -NoTypeInformation

Write-Verbose "Done - CSVs stored in $ReportFolder" -Verbose

# Future releases will have the option for Report Only, Prompt on Delete, or Auto Delete
