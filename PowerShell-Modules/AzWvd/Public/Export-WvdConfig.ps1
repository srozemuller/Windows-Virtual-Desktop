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
        [switch]$Html,

        [parameter()]
        [switch]$CSV,

        [parameter(Mandatory)]
        [string]$FilePath,

        [parameter()]
        [ValidateSet("Hostpool", "Sessionhosts","SubnetConfig")]
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
                PreContent = "<p>Windows Virtual Desktop information for $HostpoolName</p>"
            }
            $HostpoolParameters = @{
                Name              = $HostpoolName 
                ResourceGroupName = $ResourceGroupName 
            }
            $HostpoolContent = Get-AzWvdHostPool @HostpoolParameters | ConvertTo-Html @ConvertParameters
            $HtmlBody += $HostpoolContent
        }
        SessionHosts* { 
            $HtmlBody += Get-SessionHostHtmlContent -HostpoolName $HostpoolName -ResourceGroupName $ResourceGroupName
        }
        SubnetConfig* { 
            $HtmlBody += Get-SubnetConfigHtmlContent -HostpoolName $HostpoolName -ResourceGroupName $ResourceGroupName
        }        
        Default {
            $HtmlBody += Get-SessionHostHtmlContent -HostpoolName $HostpoolName -ResourceGroupName $ResourceGroupName
        }
    }
    $Css = Get-Content -Path '.\Private\exportconfig.css' -Raw
    $style= ("<style>`n") + $Css + ("`n</style>")
    $HtmlParameters = @{
        Title  = "WVD Information Report"
        body   = $HtmlBody
        Head   = $style
        PostContent = "<H5><i>$(get-date)</i></H5>"
    }
    Write-Verbose "Exporting config to $FilePath"
    ConvertTo-HTML @HtmlParameters | Out-File $FilePath

}