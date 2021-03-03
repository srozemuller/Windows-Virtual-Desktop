function Get-WvdLatestSessionHost {
    <#
    .SYNOPSIS
    Gets the latest session host from the WVD Hostpool
    .DESCRIPTION
    The function will help you getting the latests session host from a WVD Hostpool. 
    By running this function you will able to define the next number for deploying new session hosts.
    .PARAMETER HostpoolName
    Enter the WVD Hostpool name
    .PARAMETER ResourceGroupName
    Enter the WVD Hostpool resourcegroup name
    .PARAMETER InputObject
    You can put the hostpool object in here. 
    .EXAMPLE
    Get-AzWvdHostpool -WvdHostpoolName wvd-hostpool -ResourceGroupName wvd-resourcegroup | Get-WvdLatestSessionHost
    Get-WvdLatestSessionHost -WvdHostpoolName wvd-hostpool -ResourceGroupName wvd-resourcegroup
    Add a comment to existing incidnet
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$HostpoolName,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$InputObject
    )
    switch ($PsCmdlet.ParameterSetName) {
        InputObject { 
            $Parameters = @{
                HostpoolName      = $InputObject.Name
                ResourceGroupName = $InputObject.id.split("/")[4]
            }
        }
        Default {
            $Parameters = @{
                HostPoolName      = $HostpoolName
                ResourceGroupName = $ResourceGroupName
            }
        }
    }
    try {
        $SessionHosts = Get-AzWvdSessionHost @Parameters |  Sort-Object ResourceId -Descending
    }
    catch {
        Throw "No session hosts found in WVD Hostpool $WvdHostpoolName, $_"
    }
    # Convert hosts to highest number to get initial value
    $All = @{}
    $Names = $SessionHosts | % { ($_.Name).Split("/")[-1].Split(".")[0] }
    $Names | % { $All.add([int]($_).Split("-")[-1], $_) }
    $VirtualMachineName = $All.GetEnumerator() | select -first 1 -ExpandProperty Value
    $LatestSessionHost = $SessionHosts | Where-Object {$_.Name -match $LatestHost } |FL
    $VirtualMachine = Get-AzVM -Name $VirtualMachineName
    $VirtualMachine | Add-Member -membertype noteproperty -name SessionHostInfo -value $LatestSessionHost
    return $VirtualMachine
}


