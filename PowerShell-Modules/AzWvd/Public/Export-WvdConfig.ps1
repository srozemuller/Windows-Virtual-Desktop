function Export-WvdConfig {
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
        [string]$FilePath,

        [parameter()]
        [ValidateSet("Hostpool", "Sessionhosts")]
        [array]$Scope
    )

    if ($null -eq $FilePath) {
        $FilePath = ".\WvdExport.Html"
    }
    switch -wildcard ($Scope) {
        Hostpool* { 
            $ConvertParameters = @{
                Property = "Description", "HostpoolType", "Type"
                Fragment = $true
            }
            $HostpoolContent = Get-AzWvdHostPool -Name $HostpoolName -ResourceGroupName $ResourceGroup | ConvertTo-Html @ConvertParameters
        }
        Default {
            
        }
    }
    $AllContent = @()
    $HtmlParameters = @{
        Title  = "WVD Information Report"
        body   = "$HostpoolContent"
        CssUri = ".\Private\exportconfig.css"
    }
    $AllContent | ConvertTo-HTML @HtmlParameters | Out-File ".\WvdExport.Html"

}