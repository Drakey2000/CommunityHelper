<#
.SYNOPSIS
    Enables you to export a list of Packages before and then after and automatically compares the two

.DESCRIPTION
    Compare-Drivers is a function that returns all Windows Packages and compare the versions before and after installation

.PARAMETER Action
    The Compare-WindowsPackages Action you are running, either Pre-Update or Post-Update

.EXAMPLE
     .\Compare-Packages.ps1 -Action Pre-Update

.EXAMPLE
     .\Compare-Packages.ps1 -Action Post-Update

.INPUTS
    String

.OUTPUTS
    WindowsPackages-Difference.csv

.NOTES
     Author : Steven Drake
    Website : https://ourcommunityhelper.com/
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
    $FileName = "_Compare-Packages"

    # Set Log Folder
    $LogFolder = "$($env:windir)\CCM\Logs"

    # Create Log Folder
    New-Item -Path $LogFolder -ItemType Directory -Force

    # Set Packages-Before File Path
    $BeforeFilePath = "$LogFolder\$FileName-Before.xml"

    # Set Packages-After File Path
    $AfterFilePath = "$LogFolder\$FileName-After.xml"

    # Set Packages-Difference File Path
    $ComparisonFilePath = "$LogFolder\$FileName-Difference.log"

    # Set Error Log File
    $LogFile = "$LogFolder\$FileName.log"

    # Get Packages
    $Packages = Get-Package | Select-Object Name,Version,Status

        # Processing Pre-Update Packages ?
        If($Action  -eq "Pre-Update"){

            # Export Packages - XML Machine Reading
            $Packages | Export-Clixml $BeforeFilePath -Force

            # Export Packages - Log Human Reading
            $Packages | Format-List | Out-File ($BeforeFilePath).Replace('.xml','.log') -Force

            }else{

            # Export Packages - XML Machine Reading
            $Packages | Export-Clixml $AfterFilePath -Force

            # Export Packages - Log Human Reading
            $Packages | Format-List | Out-File ($AfterFilePath).Replace('.xml','.log') -Force

            # Delete exisiting Packages-Difference.csv
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $ComparisonFilePath -Force}

            # Add Headers to .csv File
            Add-Content -Path $ComparisonFilePath -value "Package Name,Pre-Update,Post-Update,Status"

            # Compare the Packages Pre-Update and Post-Update and Group On Unique ID Name
            $Differences = Compare-Object -ReferenceObject (Import-Clixml $BeforeFilePath) -DifferenceObject (Import-Clixml $AfterFilePath) -Property Name,Version -IncludeEqual | Sort-Object Name | Group-Object Name

            # For Each Comparison Group - Append to Log
            ForEach($Diff in $Differences){

                # Check Where The Change Has Occurred - Reference or Difference
                Switch ($Diff.Group[0].SideIndicator) {

                    # Property value appeared only in the reference object (<=)  - Before
                    '<=' {

                        # Check record count
                        If($Diff.Count -eq 1) {

                            # Add-content to comparison file - Use record 0 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].Name.Replace(',',' ')),$($Diff.Group[0].Version),$null,Removed"

                            }else{

                            # Add-content to comparison file - Use record 1 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[1].Name.Replace(',',' ')),$($Diff.Group[0].Version),$($Diff.Group[1].Version),Updated"

                            }

                        }

                    # Property value appeared only in the difference object (=>)  - After
                    '=>' {

                        # Check record count
                        If($Diff.Count -eq 1) {

                            # Add-content to comparison file - Use record 0 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].Name.Replace(',',' ')),$null,$($Diff.Group[0].Version),Added"

                            }else{

                            # Add-content to comparison file - Use record 1 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[1].Name.Replace(',',' ')),$($Diff.Group[1].Version),$($Diff.Group[0].Version),Updated"

                            }
                        }

                    # Only active if the option -IncludeEqual is used - Add-content to comparison file - Use record 0 as reference
                    '==' { Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].Name.Replace(',',' ')),$($Diff.Group[0].Version),$($Diff.Group[0].Version),-" }

                }
            }

            # Tidyup Delete exisiting Before .xml
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $BeforeFilePath -Force}

            # Tidyup Delete exisiting After .xml
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $AfterFilePath -Force}

        }

}Catch{ Add-Content $Logfile -Value $_.Exception.Message ; Exit 1}
