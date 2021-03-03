#requires -module @{ModuleName = 'Az.Resources'; ModuleVersion = '3.2.1'}
#requires -version 6.2
function Get-WvdVmResource {
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
        [parameter(mandatory = $true, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Object]$SessionHost
    )
    
    $Resource = Get-AzResource -ResourceId $SessionHost.ResourceId
    $VirtualMachine = (Get-AzVm -Name $Resource.Name)
    Write-Verbose "Found virtual machine: $($Resource.Name)"
    return $VirtualMachine
}
