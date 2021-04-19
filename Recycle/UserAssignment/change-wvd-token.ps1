<#
    .SYNOPSIS
    Changed the hostpool token to a new one. 
    .DESCRIPTION
    This script can be used with the Invoke-AzRunCommand to change the RDInfraAgent registry values.
    .PARAMETER HostpoolToken
    Enter the new WVD hostpool registration token.
    .EXAMPLE
    Invoke-AzVMRunCommand -ResourceGroupName rg-wvd-001 -VMName wvd-0 -CommandId 'RunPowerShellScript' -ScriptPath .\change-wvd-token.ps1 -Parameter @{HostpoolToken = 'token'}
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostpoolToken
)

Set-ItemProperty -Path "HKLM:\Software\Microsoft\RDInfraAgent" -Name "RegistrationToken" -Value $HostpoolToken
Set-ItemProperty -Path "HKLM:\Software\Microsoft\RDInfraAgent" -Name "IsRegistered" -Value 0
