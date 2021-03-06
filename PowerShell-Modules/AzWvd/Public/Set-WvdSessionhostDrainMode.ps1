function Set-WvdSessionhostDrainMode {
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
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [pscustomobject]$InputObject,

        [parameter(ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("All","NotLatest")]
        [string]$Sessionhosts,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$HostpoolName,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$SessionHostName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [switch]$AllowNewSession
             
    )

    switch ($PsCmdlet.ParameterSetName) {
        InputObject {
            $HostpoolName = $InputObject.Name.Split("/")[0]
            $ResourceGroupName = $InputObject.id.split("/")[4]
            $Name = $InputObject.Name.Split("/")[1]
          }
        Default {

        }
    }
    if ($AllowNewSession) {
        $AllowNewSession = $true
    }
    else { 
        $AllowNewSession = $false 
    }
    if ($PSBoundParameters.ContainsKey('InputObject') -and $Sessionhosts -eq 'All') {
        foreach ($object in $InputObject) {
            $HostpoolName = $object.Name.Split("/")[0]
            $ResourceGroupName = $object.id.split("/")[4]
            $Name = $object.Name.Split("/")[1]
            Update-AzWvdSessionHost -HostPoolName $HostpoolName -ResourceGroupName -Name $Name -AllowNewSession:$AllowNewSession
        }
    }
    else {
        foreach ($object in $InputObject) {
            $HostpoolName = $object.Name.Split("/")[0]
            $ResourceGroupName = $object.id.split("/")[4]
            $Name = $object.Name.Split("/")[1]
            if (Get-WvdImageVersionStatus -HostPoolName $HostpoolName -ResourceGroupName -Sessionhost $Name){
                Update-AzWvdSessionHost -HostPoolName $HostpoolName -ResourceGroupName -Name $SessionHostName -AllowNewSession:$AllowNewSession    
            }
        }
    }
}