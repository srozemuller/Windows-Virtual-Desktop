function Remove-WvdSessionHostResources {
    <#
    .SYNOPSIS
    Gets the Virtual Machines Azure resource from a WVD Session Host
    .DESCRIPTION
    The function will help you getting the virtual machine resource information which is behind the WVD Session Host
    .PARAMETER SessionHost
    Enter the WVD Session Host name
    .EXAMPLE
    Get-WvdVmResource -SessionHost SessionHostObject
    Add a comment to existing incidnet
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ParameterSetName = 'Single')]
        [ValidateNotNullOrEmpty()]
        [String]$SessionHostName,

        [parameter(Mandatory, ParameterSetName = 'Single')]
        [ValidateNotNullOrEmpty()]
        [String]$HostpoolName,

        [parameter(Mandatory, ParameterSetName = 'Single')]
        [ValidateNotNullOrEmpty()]
        [String]$ResourceGroupName,

        [parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$InputObject,

        [parameter()]
        [ValidateNotNullOrEmpty()]
        [Switch]$Force
    )

    if ($Force) {
        $ForceStatus = $force
    }
    else {
        $ForceStatus = $false
    }

    switch ($PsCmdlet.ParameterSetName) {
        InputObject { 
            $Resources = $InputObject
        }
        Default {
            $parameters = @{
                HostpoolName      = $HostpoolName
                ResourceGroupName = $ResourceGroupName
                Name              = $SessionHostName
            }
            $Resources = Get-AzWvdSessionHost @Parameters
        }
    }
    foreach ($Object in $Resources) {
        Write-Host $Object.ResourceId
        $SessionHostParameters = @{
            HostpoolName  = $object.Name.Split("/")[0]
            ResourceGroup = $Object.ResourceId.Split("/")[4]
            Name          = $object.name.Split("/")[1]
        }

        $Resource = Get-AzResource -ResourceId $Object.ResourceId
        $VirtualMachine = Get-AzVM -Name $Resource.Name
        $VirtualMachine | Stop-AzVM  -NoWait -Force:$ForceStatus
        $Disk = Get-AzDisk | Where-Object { $_.ManagedBy -eq $VirtualMachine.Id } 
        $Nic = Get-AzNetworkInterface -ResourceId $VirtualMachine.NetworkProfile.NetworkInterfaces.Id
        $VirtualMachine | Remove-AzVM -Force:$ForceStatus
        
        Remove-AzWvdUserSession @SessionHostParameters
        Write-Verbose "Deleting sessionhost $($SessionHostParameters.Name) from $($SessionHostParameters.HostpoolName)"
        Remove-AzWvdSessionHost @SessionHostParameters

        Write-Verbose "Deleting VirtualMachine $($VirtualMachine.Name)"
        $Disk | Remove-AzDisk -Force:$ForceStatus
        Write-Verbose "Deleting VirtualMachine $($Disk.Name)"
        $Nic | Remove-AzNetworkInterface -Force:$ForceStatus
        Write-Verbose "Deleting VirtualMachine $($Nic.Name)"
    }
}
