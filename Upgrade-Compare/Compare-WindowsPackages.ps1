<#
.SYNOPSIS
    Enables you to export a list of Windows Packages before and then after and automatically compares the two

.DESCRIPTION
    Compare-WindowsPackages is a function that returns all Windows Packages and compare the versions before and after installation

.PARAMETER Action
    The Compare-WindowsPackages Action you are running, either Pre-Update or Post-Update

.EXAMPLE
     .\Compare-WindowsPackages.ps1 -Action Pre-Update

.EXAMPLE
     .\Compare-WindowsPackages.ps1 -Action Post-Update

.INPUTS
    String

.OUTPUTS
    WindowsPackages-Difference.log   (comma-separated)

.NOTES
     Author : Steven Drake
    Website : https://ourcommunityhelper.com/
    Version
        1.1 : Expanded compare object grouping
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

    # Get Script Name - Without Extention
    $FileName = "_Compare-WindowsPackages"

    # Set Log File
    $LogFolder = "$($env:windir)\CCM\Logs"

    # Create Log Folder
    New-Item -Path $LogFolder -ItemType Directory -Force

    # Set Driver-Before File Path
    $BeforeFilePath = "$LogFolder\$FileName-Before.xml"

    # Set Driver-After File Path
    $AfterFilePath = "$LogFolder\$FileName-After.xml"

    # Set Driver-Difference File Path
    $ComparisonFilePath = "$LogFolder\$FileName-Difference.log"

    # Set Log File
    $LogFile = "$LogFolder\$FileName.log"

    # Get Windows Packages
    $Packages = Get-WindowsPackage -Online | Where-Object {$_.PackageState -eq 'Installed'}

        # Processing Pre-Update Drivers ?
        If($Action  -eq "Pre-Update"){

            # Export Packages - XML Machine Reading
            $Packages | Export-Clixml $BeforeFilePath -Force

            # Export Packages - Log Human Reading
            $Packages | Out-File ($BeforeFilePath).Replace('.xml','.log') -Force

            }else{

            # Export Packages - XML Machine Reading
            $Packages | Export-Clixml $AfterFilePath -Force

            # Export Packages - Log Human Reading
            $Packages | Out-File  ($AfterFilePath).Replace('.xml','.log') -Force

            # Delete exisiting Drivers-Difference.csv
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $ComparisonFilePath -Force}

            # Add Headers to .csv File
            Add-Content -Path $ComparisonFilePath -value "Friendly Name,Package Name,Release Type,Install Time,Pre-Update,Post-Update,Status"

            # Compare the Drivers Pre-Update and Post-Update and Group On Unique ID PackageName
            $Differences = Compare-Object -ReferenceObject (Import-Clixml $BeforeFilePath) -DifferenceObject (Import-Clixml $AfterFilePath) -Property PackageName,PackageState,ReleaseType,InstallTime -IncludeEqual | Sort-Object PackageName | Group-Object @{expression={$_.PackageName.Substring(0,$_.PackageName.LastIndexOf($_.PackageName.Split('~')[4])-1)}}

            # For Each Comparison Group - Append to Log
            ForEach($Diff in $Differences){

                # Check Where The Change Has Occurred - Reference or Difference
                Switch ($Diff.Group[0].SideIndicator) {

                    # Property value appeared only in the reference object (<=)  - Before
                    '<=' {

                        # Check record count
                        If($Diff.Count -eq 1) {

                            # Add-content to comparison file - Use record 0 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].PackageName.Substring(0,$($Diff.Group[0].PackageName).IndexOf('~')).Replace(',',' ')),$($Diff.Group[0].PackageName.Replace(',',' ')),$($Diff.Group[0].ReleaseType.Value),$($Diff.Group[0].InstallTime),$($Diff.Group[0].PackageName.Substring($($Diff.Group[0].PackageName).LastIndexOf('~')+1)),$null,Removed"

                            }else{

                            # Add-content to comparison file - Use record 1 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[1].PackageName.Substring(0,$($Diff.Group[1].PackageName).IndexOf('~')).Replace(',',' ')),$($Diff.Group[1].PackageName.Replace(',',' ')),$($Diff.Group[1].ReleaseType.Value),$($Diff.Group[1].InstallTime),$($Diff.Group[0].PackageName.Substring($($Diff.Group[0].PackageName).LastIndexOf('~')+1)),$($Diff.Group[1].PackageName.Substring($($Diff.Group[1].PackageName).LastIndexOf('~')+1)),Updated"

                            }

                        }

                    # Property value appeared only in the difference object (=>)  - After
                    '=>' {

                        # Check record count
                        If($Diff.Count -eq 1) {

                            # Add-content to comparison file - Use record 0 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].PackageName.Substring(0,$($Diff.Group[0].PackageName).IndexOf('~')).Replace(',',' ')),$($Diff.Group[0].PackageName.Replace(',',' ')),$($Diff.Group[0].ReleaseType.Value),$($Diff.Group[0].InstallTime),$null,$($Diff.Group[0].PackageName.Substring($($Diff.Group[0].PackageName).LastIndexOf('~')+1)),Added"

                            }else{

                            # Add-content to comparison file - Use record 1 as reference
                            Add-Content -Path $ComparisonFilePath "$($Diff.Group[1].PackageName.Substring(0,$($Diff.Group[1].PackageName).IndexOf('~')).Replace(',',' ')),$($Diff.Group[1].PackageName.Replace(',',' ')),$($Diff.Group[1].ReleaseType.Value),$($Diff.Group[1].InstallTime),$($Diff.Group[1].PackageName.Substring($($Diff.Group[1].PackageName).LastIndexOf('~')+1)),$($Diff.Group[0].PackageName.Substring($($Diff.Group[0].PackageName).LastIndexOf('~')+1)),Updated"

                            }

                         }

                    # Only active if the option -IncludeEqual is used - Add-content to comparison file - Use record 0 as reference
                    '==' { Add-Content -Path $ComparisonFilePath "$($Diff.Group[0].PackageName.Substring(0,$($Diff.Group[0].PackageName).IndexOf('~')).Replace(',',' ')),$($Diff.Group[0].PackageName.Replace(',',' ')),$($Diff.Group[0].ReleaseType.Value),$($Diff.Group[0].InstallTime),$($Diff.Group[0].PackageName.Substring($($Diff.Group[0].PackageName).LastIndexOf('~')+1)),$($Diff.Group[0].PackageName.Substring($($Diff.Group[0].PackageName).LastIndexOf('~')+1)),-" }

                }
            }

            # Tidyup Delete exisiting Before .xml
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $BeforeFilePath -Force}

            # Tidyup Delete exisiting After .xml
            If(Test-Path -Path $ComparisonFilePath){Remove-Item $AfterFilePath -Force}
        }

}Catch{ Add-Content $Logfile -Value $_.Exception.Message; Exit 1}
