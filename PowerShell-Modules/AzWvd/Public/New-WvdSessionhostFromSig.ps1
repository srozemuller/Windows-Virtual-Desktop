function New-WvdSessionHostFromSig {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$WvdHostpoolName,
        [parameter(mandatory = $true)][string]$WvdHostpoolResourceGroup,
        [parameter(mandatory = $true)][string]$AdminUsername,
        [parameter(mandatory = $true)][string]$AdminPassword,
        [parameter(mandatory = $false)][string]$Tags
    )
    try {
        $WvdHostpool = Get-AzWvdHostPool -HostPoolName $WvdHostpoolName -ResourceGroupName $WvdHostpoolResourceGroup
    }
    catch {
        Throw "No WVD Hostpool found for $WvdHostpoolName, $_"
    }
}