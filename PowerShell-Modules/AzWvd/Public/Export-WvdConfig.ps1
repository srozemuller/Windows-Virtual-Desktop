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
    $HtmlBody = @()
    switch -wildcard ($Scope) {
        Hostpool* { 
            $ConvertParameters = @{
                Property = "Description", "HostpoolType", "Type"
                Fragment = $true
            }
            $HostpoolParameters = @{
                Name              = $HostpoolName 
                ResourceGroupName = $ResourceGroup 
            }
            $HostpoolContent = Get-AzWvdHostPool @HostpoolParameters | ConvertTo-Html @ConvertParameters
            $HtmlBody += $HostpoolContent
        }
        SessionHosts* { 
            $HtmlBody += Get-SessionHostHtmlContent -HostpoolName $HostpoolName -ResourceGroupName $ResourceGroupName
        }
        Default {
            $HtmlBody += Get-SessionHostHtmlContent -HostpoolName $HostpoolName -ResourceGroupName $ResourceGroupName
        }
    }
    $HtmlParameters = @{
        Title  = "WVD Information Report"
        body   = $HtmlBody
        CssUri = ".\Private\exportconfig.css"
    }
    Write-Verbose "Exporting config to $FilePath"
    ConvertTo-HTML @HtmlParameters | Out-File $FilePath

}