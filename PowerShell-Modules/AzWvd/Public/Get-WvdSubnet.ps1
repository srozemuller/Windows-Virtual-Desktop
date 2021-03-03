function Get-WvdSubnet {
    <#
    .SYNOPSIS
    Gets the connected subnet to the given WVD Hostpool name
    .DESCRIPTION
    The function will help you getting the connected subnet which are the session hosts are using. Based on the latest sessionhost.
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
        $SessionHost = Get-WvdLatestSessionhost -HostpoolName $HostpoolName -ResourceGroupName $ResourceGroupName
    }
    catch {
        Throw "No sessionhost has been found in $WvdHostpoolName, $_"
    }
    $NetworkInterface = ($SessionHost).NetworkProfile
    $Subnet = (Get-AzNetworkInterface -ResourceId $NetworkInterface.NetworkInterfaces.id).IpConfigurations.subnet
    return $Subnet
}