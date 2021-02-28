function Get-WvdLatestSessionhost {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$WvdHostpoolName,
        [parameter(mandatory = $true)][string]$WvdHostpoolResourceGroup
    )
    try {
        $sessionHosts = Get-AzWvdSessionHost -HostPoolName $WvdHostpoolName -ResourceGroupName $WvdHostpoolResourceGroup |  Sort-Object ResourceId -Descending
    }
    catch {
        Throw "No sessionhosts found in WVD Hostpool $WvdHostpoolName, $_"
    }
    # Convert hosts to highest number to get initial value
    $all = @{}
    $names = $sessionHosts | % { ($_.Name).Split("/")[-1].Split(".")[0] }
    $names | % { $all.add([int]($_).Split("-")[-1], $_) }
    $latestHost = $all.GetEnumerator() | select -first 1 -ExpandProperty Value
    return $latestHost
}
