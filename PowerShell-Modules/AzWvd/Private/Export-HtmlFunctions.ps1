function Get-SessionHostHtmlContent {
    <#
    .SYNOPSIS
    Exports the complete Windows Virtual Desktop environment, based on the hostpool name.
    .DESCRIPTION
    The function will help you exporting the complete WVD environment to common output types as HTML and CSV.
    .PARAMETER HostpoolName
    Enter the WVD hostpoolname name.
    .PARAMETER ResourceGroupName
    Enter the WVD hostpool resource group name.
    .PARAMETER 
    .EXAMPLE
    Export-WvdConfig -Hostpoolname $hostpoolName -resourceGroup $ResourceGroup -Scope Hostpool,SessionHosts -Verbose -FilePath .\wvdexport.html
    Add a comment to existing incidnet
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$HostpoolName,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName
    )
    $ConvertParameters = @{
        Property = "Name"
        Fragment = $true
    }
    $SessionHostParameters = @{
        HostPoolName      = $HostpoolName 
        ResourceGroupName = $ResourceGroup 
    }
    $SessionHostContent = Get-AzWvdSessionHost @SessionHostParameters | ConvertTo-Html @ConvertParameters
    return $SessionHostContent
}