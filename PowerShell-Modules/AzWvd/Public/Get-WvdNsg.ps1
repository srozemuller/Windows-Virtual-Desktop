function Get-WvdNsg {
    <#
    .SYNOPSIS
    Gets the connected Network Security Group based on the WVD subnet
    .DESCRIPTION
    The function will help you getting the connected Network Security Group, based on the latest sessionhost.
    The function will return the NSG object from where you are able to add rules.
    .PARAMETER HostpoolName
    Enter the WVD Hostpool name
    .PARAMETER ResourceGroupName
    Enter the WVD Hostpool resourcegroup name
    .EXAMPLE
    Get-WvdSubnet -WvdHostpoolName wvd-hostpool -ResourceGroupName wvd-resourcegroup
    Add a comment to existing incidnet
    #>
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$HostpoolName,
        [parameter(mandatory = $true)][string]$ResourceGroupName
    )
    try {
        $Subnet = Get-WvdSubnet -WvdHostpoolName $HostpoolName -ResourceGroupName $ResourceGroupName
    }
    catch {
        Throw "No subnet has been found in $WvdHostpoolName, $_"
    }
    $WvdNsg = Get-AzNetworkSecurityGroup | Where-Object { $_.Subnets.id -match $Subnet.id }
    if ($null -ne $WvdNsg) {
        return $WvdNsg
    }
    else {
        Throw "No Network Security Group assigned to subnet $Subnet"
    }
}