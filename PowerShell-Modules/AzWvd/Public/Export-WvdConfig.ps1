function Export-WvdConfig {
    <#
    .SYNOPSIS
    Gets the Virtual Machines Azure resource from a WVD Session Host
    .DESCRIPTION
    The function will help you getting the virtual machine resource information which is behind the WVD Session Host
    .PARAMETER SessionHost
    Enter the WVD Session Host name
    .EXAMPLE
    Get-WvdSessionHostResources -SessionHost SessionHostObject
    Add a comment to existing incidnet
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ParameterSetName = 'Hostpool')]
        [ValidateNotNullOrEmpty()]
        [string]$HostpoolName,

        [parameter(Mandatory, ParameterSetName = 'Hostpool')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$InputObject,

        [parameter()]
        [ValidateSet("HTML", "CSV")]
        [string]$ExportType,
        
        [parameter()]
        [switch]$Html,

        [parameter()]
        [switch]$CSV,

        [parameter()]
        [string]$FilePath
    )

    if ($null -eq $FilePath){
        $FilePath = ".\WvdExport.Html"
    }
    $Content = Get-AzWvdHostPool -Name $HostpoolName -ResourceGroupName $ResourceGroup
    
    $Content | ConvertTo-Html @htmlParams | Out-File ".\WvdExport.Html"

}