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
    $SessionHostContent = Get-WvdImageVersionStatus @SessionHostParameters 
    $ConvertParameters = @{
        Property = "Name","AgentVersion","AllowNewSession","OSVersion","HasLatestVersion","CurrentVersion"
        Fragment = $true
        PreContent = "<p>Sessionhosts in $HostpoolName</p>"
    }
    $SessionHostParameters = @{
        HostPoolName      = $HostpoolName 
        ResourceGroupName = $ResourceGroupName 
    }
    $SessionHostContent = Get-WvdImageVersionStatus @SessionHostParameters | ConvertTo-Html @ConvertParameters
    $SessionHostContent = $SessionHostContent -replace '<td>True</td>','<td class="GoodStatus">True</td>'
    $SessionHostContent = $SessionHostContent -replace '<td>False</td>','<td class="WrongStatus">False</td>'
    return $SessionHostContent
}

function Get-SubnetConfigHtmlContent {
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
        Property = "Name","PrivateEndpointNetworkPolicies","PrivateLinkServiceNetworkPolicies","NatGateway"
        Fragment = $true
        PreContent = "<p>SubnetConfig in $HostpoolName</p>"
    }
    $Parameters = @{
        HostPoolName      = $HostpoolName 
        ResourceGroupName = $ResourceGroupName 
    }
    $SubnetConfigContent =  Get-WvdSubnet @Parameters |  ConvertTo-Html @ConvertParameters
    return $SubnetConfigContent
}

