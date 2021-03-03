function Get-WvdLatestSessionHost {
    <#
    .SYNOPSIS
    Gets the latest session host from the WVD Hostpool
    .DESCRIPTION
    The function will help you getting the latests session host from a WVD Hostpool. 
    By running this function you will able to define the initial number for deploying new session hosts
    .PARAMETER HostpoolName
    Enter the WVD Hostpool name
    .PARAMETER ResourceGroupName
    Enter the WVD Hostpool resourcegroup name
    .EXAMPLE
    Get-WvdLatestSessionHost -WvdHostpoolName wvd-hostpool -ResourceGroupName wvd-resourcegroup
    Add a comment to existing incidnet
    #>
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HostpoolName,
        [parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName
    )
    try {
        $SessionHosts = Get-AzWvdSessionHost -HostPoolName $HostpoolName -ResourceGroupName $ResourceGroupName |  Sort-Object ResourceId -Descending
    }
    catch {
        Throw "No session hosts found in WVD Hostpool $WvdHostpoolName, $_"
    }
    # Convert hosts to highest number to get initial value
    $All = @{}
    $Names = $SessionHosts | % { ($_.Name).Split("/")[-1].Split(".")[0] }
    $Names | % { $All.add([int]($_).Split("-")[-1], $_) }
    $LatestHost = $All.GetEnumerator() | select -first 1 -ExpandProperty Value
    $VirtualMachine = Get-AzVM -Name $LatestHost
    return $VirtualMachine
}
