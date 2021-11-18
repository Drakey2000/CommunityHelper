<#
.SYNOPSIS
    Enables you to export a list of drivers before and then after and automatically compares the two

.DESCRIPTION
    Compare-Drivers is a function that returns all third-party drivers and compare the versions before and after installation

.PARAMETER State
    The Compare-Drivers State you are running, either Pre-Update or Post-Update

.EXAMPLE
     .\Compare-Drivers.ps1 -Action Pre-Update

.EXAMPLE
     .\Compare-Drivers.ps1 -Action Post-Update

.INPUTS
    String

.OUTPUTS
    Compare-Drivers-Difference.csv    (comma-separated)

.NOTES
     Author : Steven Drake
    Website : https://ourcommunityhelper.com
    Version
        1.1 : Hardcoded log file name, so it can be used from .ps1 or embedded PowerShell in a Task Sequence
        1.0 : Initial release

#>


# Set Mandatory Parameters
[CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, Position=0)]
        [ValidateSet('Pre-Update','Post-Update')]
        [string]$Action
    )

# Main Try Catch
Try{

    # Set Filename
    $FileName = "_Compare-Drivers"

    # Set Log Folder
    $LogFolder = "$($env:windir)\CCM\Logs"

    # Create Log Folder
    New-Item -Path $LogFolder -ItemType Directory -Force

    # Set Drivers-Before File Path
    $BeforeFilePath = "$LogFolder\$FileName-Before.xml"

    # Set Drivers-After File Path
    $AfterFilePath = "$LogFolder\$FileName-After.xml"

    # Set Drivers-Difference File Path
    $ComparisonFilePath = "$LogFolder\$FileName-Difference.log"

    # Set Error Log File
    $LogFile = "$LogFolder\$FileName.log"

        # Get Windows Third Party Drivers Only
        $WindowsDrivers = Get-WindowsDriver -Online | Select-Object *

        # Processing Pre-Update Drivers ?
        If($Action  -eq "Pre-Update"){

            # Export Third Party Drivers Only - XML Machine Reading
            $WindowsDrivers | Export-Clixml $BeforeFilePath -Force

            # Export Third Party Drivers Only - Log Human Reading
            $WindowsDrivers | Out-File ($BeforeFilePath).Replace('.xml','.log') -Force

            }else{

            # Export Third Party Drivers Only - XML Machine Reading
            $WindowsDrivers | Export-Clixml $AfterFilePath -Force

            # Export Third Party Drivers Only - Log Human Reading
            $WindowsDrivers | Out-File ($AfterFilePath).Replace('.xml','.log') -Force

            # Delete exisiting Drivers-Difference.csv
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $ComparisonFilePath -Force}

            # Add Headers to .csv File
            Add-Content -Path $ComparisonFilePath -value "Class Name,Class Description,Boot Critical,Provider Name,Original Filename,Pre-Update,Post-Update,Status"

            # Compare the Drivers Pre-Update and Post-Update and Group On Unique ID CatalogFile
            $Differences = Compare-Object -ReferenceObject (Import-Clixml $BeforeFilePath) -DifferenceObject (Import-Clixml $AfterFilePath) -Property ClassName,ClassDescription,BootCritical,ProviderName,OriginalFilename,Version,CatalogFile -IncludeEqual | Sort-Object ClassName | Group-Object CatalogFile

            # For Each Comparison Group - Append to Log
            ForEach($Diff in $Differences){

                # Check Where The Change Has Occurred - Reference or Difference
                Switch ($Diff.Group[0].SideIndicator) {

                    # Property value appeared only in the reference object (<=)  - Before
                    '<=' {

                        # Check record count
                        If($Diff.Count -eq 1) {

                            # Add-content to comparison file - Use record 0 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].ClassDescription.Replace(',',' ')),$($Diff.Group[0].ClassName),$($Diff.Group[0].BootCritical),$($Diff.Group[0].ProviderName.Replace(',',' ')),$(Split-Path -Path ($Diff.Group[0].OriginalFilename) -Leaf),$($Diff.Group[0].Version),$null,Removed"

                            }else{

                            # Add-content to comparison file - Use record 1 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[1].ClassDescription.Replace(',',' ')),$($Diff.Group[1].ClassName),$($Diff.Group[1].BootCritical),$($Diff.Group[1].ProviderName.Replace(',',' ')),$(Split-Path -Path ($Diff.Group[1].OriginalFilename) -Leaf),$($Diff.Group[0].Version),$($Diff.Group[1].Version),Updated"

                            }
                        }

                    # Property value appeared only in the difference object (=>)  - After
                    '=>' {

                            # Check record count
                        If($Diff.Count -eq 1) {

                            # Add-content to comparison file - Use record 0 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].ClassDescription.Replace(',',' ')),$($Diff.Group[0].ClassName),$($Diff.Group[0].BootCritical),$($Diff.Group[0].ProviderName.Replace(',',' ')),$(Split-Path -Path ($Diff.Group[0].OriginalFilename) -Leaf),$null,$($Diff.Group[0].Version),Added"

                            }else{

                            # Add-content to comparison file - Use record 1 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[1].ClassDescription.Replace(',',' ')),$($Diff.Group[1].ClassName),$($Diff.Group[1].BootCritical),$($Diff.Group[1].ProviderName.Replace(',',' ')),$(Split-Path -Path ($Diff.Group[1].OriginalFilename) -Leaf),$($Diff.Group[1].Version),$($Diff.Group[0].Version),Updated"

                            }
                        }

                    # Only active if the option -IncludeEqual is used - Add-content to comparison file - Use record 0 as reference
                    '==' { Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].ClassDescription.Replace(',',' ')),$($Diff.Group[0].ClassName),$($Diff.Group[0].BootCritical),$($Diff.Group[0].ProviderName.Replace(',',' ')),$(Split-Path -Path ($Diff.Group[0].OriginalFilename) -Leaf),$($Diff.Group[0].Version),$($Diff.Group[0].Version),-" }

                }
            }

            # Tidyup Delete exisiting Before .xml
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $BeforeFilePath -Force}

            # Tidyup Delete exisiting After .xml
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $AfterFilePath -Force}

        }

}Catch{ Add-Content $Logfile -Value $_.Exception.Message;Exit 1}