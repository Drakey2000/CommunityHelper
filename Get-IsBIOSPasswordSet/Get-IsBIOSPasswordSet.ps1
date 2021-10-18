<#
.SYNOPSIS
    This script can be used within a task sequence to identify if a BIOS Admin Password is set for Dell, HP and Lenovo

.DESCRIPTION
   This script will identify if a BIOS Admin Password is set for Dell, HP and Lenovo hardware layers and create the SMS Variable
   [Boolean] - 'IsBIOSPasswordSet' which can then be used in the task sequence logic to configure the arguments passed to the BIOS Update.exe

.NOTES
    References for the wmi classes were obtained from Dell, HP, Lenovo and https://www.configjon.com/

    File Name      : Get-IsBIOSPasswordSet.ps1
    Author         : S.P.Drake
    Website        : https://ourcommunityhelper.com
    Version        : 1.0  : Initial version
#>

$VerbosePreference = "SilentlyContinue"

function Get-DellBIOSSetting {

# Dell Hardware Layer

    # Connect to the Dell PasswordObject WMI class
    $PasswordState = (Get-CimInstance -Namespace root\dcim\sysman\wmisecurity -ClassName PasswordObject | Where-Object {$_.NameId -eq 'Admin'}).IsPasswordSet

    # Check the current password configuration state
    switch ($PasswordState){

        0 { $isPasswordSet = $false  }   # No BIOS Admin Password
        1 { $isPasswordSet = $true   }   # Bios Admin Password

        Default{$isPasswordSet = $false} # No BIOS Admin Password
    }

    # write-Verbose message
    Write-Verbose "BIOS Password State = $PasswordState" -Verbose
    Write-Verbose "BIOS Password IsPasswordSet = $IsPasswordSet" -Verbose

    # Set SMS IsBIOSPasswordSet variable
    $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    $TSEnv.Value('IsBIOSPasswordSet') = $isPasswordSet
}


function Get-HPBIOSSetting {

# HP Hardware Layer

    # Connect to the HP_BIOSPassword WMI class
    $PasswordState = (Get-CimInstance -Namespace root/hp/InstrumentedBIOS -Class HP_BIOSPassword | Where-Object {$_.Name -eq 'Setup Password'}).IsSet

    # Check the current password configuration state
    switch ($PasswordState){

        0 { $isPasswordSet = $false  }   # No BIOS Setup Password
        1 { $isPasswordSet = $true   }   # Bios Setup Password

        Default{$isPasswordSet = $false} # No BIOS Setup Password
    }

    # write-Verbose message
    Write-Verbose "BIOS Password State = $PasswordState" -Verbose
    Write-Verbose "BIOS Password IsPasswordSet = $IsPasswordSet" -Verbose

    # Set SMS IsBIOSPasswordSet variable
    $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    $TSEnv.Value('IsBIOSPasswordSet') = $isPasswordSet
}


function Get-LenovoBIOSSetting {

# Lenovo Hardware Layer

    # Connect to the Lenovo_BiosPasswordSettings WMI class
    $PasswordState = (Get-CimInstance -Namespace root\wmi -Class Lenovo_BiosPasswordSettings).PasswordState

    # Check the current password configuration state
    switch ($PasswordState){

        0	{$isPasswordSet = $false}    # No BIOS Passwords Set
        1	{$isPasswordSet = $false}    # Only Power On Password
        2	{$isPasswordSet = $true}     # Only Supervisor Password
        3	{$isPasswordSet = $true}     # Supervisor + Power On Password
        4	{$isPasswordSet = $false}    # User HDD and/or User HDD and Master Password
        5	{$isPasswordSet = $false}    # Power On + User HDD and/or User HDD and Master Password
        6	{$isPasswordSet = $true}     # Supervisor + User HDD and/or User HDD and Master Password
        7	{$isPasswordSet = $true}     # Supervisor + Power On + User HDD and/or User HDD and Master Password
        64	{$isPasswordSet = $false}    # Only System Management Password
        65	{$isPasswordSet = $false}    # System Management + Power On Password
        66	{$isPasswordSet = $true}     # Supervisor + System Management Password
        67	{$isPasswordSet = $true}     # Supervisor + System Management + Power On Password
        68	{$isPasswordSet = $false}    # System Management + User HDD and/or User HDD Master Password
        69	{$isPasswordSet = $false}    # System Management + Power On + User HDD and/or User HDD Master Password
        70	{$isPasswordSet = $true}     # Supervisor + System Management + User HDD and/or User HDD Master Password
        71	{$isPasswordSet = $true}     # Supervisor + System Management + Power On + User HDD and/or User HDD Master Password

        Default{$isPasswordSet = $false} # No BIOS Setup Password

    }

    # write-Verbose message
    Write-Verbose "BIOS Password State = $PasswordState" -Verbose
    Write-Verbose "BIOS Password IsPasswordSet = $IsPasswordSet" -Verbose

    # Set SMS IsBIOSPasswordSet variable
    $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    $TSEnv.Value('IsBIOSPasswordSet') = $isPasswordSet
}

# Get hardware manufacturer
$Manufacturer = (Get-CimInstance -ClassName Win32_BIOS).Manufacturer

# Run BIOSSettings function
switch ($Manufacturer){

    'Dell Inc.'           {Get-DellBIOSSetting}
    'HP'                  {Get-HPBIOSSetting}
    'Hewlett-Packard'     {Get-HPBIOSSetting}
    'Lenovo'              {Get-LenovoBIOSSetting}

}
