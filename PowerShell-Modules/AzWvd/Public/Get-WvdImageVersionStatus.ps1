function Get-WvdImageVersionStatus {
    <#
    .SYNOPSIS
    Gets the image version from where the session host is starte.
    .DESCRIPTION
    The function will help you getting insights if there are session hosts started from an old version in the Shared Image Gallery
    .PARAMETER HostpoolName
    Enter the WVD Hostpool name
    .PARAMETER ResourceGroupName
    Enter the WVD Hostpool resourcegroup name
    .EXAMPLE
    Get-WvdImageVersionStatus -WvdHostpoolName wvd-hostpool -ResourceGroupName wvd-resourcegroup
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [string]$HostpoolName,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Single')]
        [pscustomobject]$SingleHost,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'AllHosts')]
        [pscustomobject]$AllSessionHosts
    )

    switch ($PsCmdlet.ParameterSetName) {
        Single { 
            $Parameters = @{
                HostpoolName      = $InputObject.Name.Split("/")[0]
                ResourceGroupName = $InputObject.id.split("/")[4]
                Name             = $InputObject.Name.Split("/")[1]
            }
            $Sessionhosts = Get-AzWvdSessionHost @Parameters
        }
        AllHosts { 
            $Parameters = @{
                HostpoolName      = $InputObject.Name.Split("/")[0]
                ResourceGroupName = $InputObject.id.split("/")[4]
                Name             = $InputObject.Name.Split("/")[1]
            }
            $Sessionhosts = Get-AzWvdSessionHost @Parameters
        }
        Default {
            $Parameters = @{
                HostPoolName      = $HostpoolName
                ResourceGroupName = $ResourceGroupName
            }
            $Sessionhosts = Get-AzWvdSessionHost @Parameters
        }
    }

    $ImageReference = ($WvdHostpool.VMTemplate | ConvertFrom-Json).customImageId
    if ($ImageReference -match 'Microsoft.Compute/galleries/') {
        $GalleryImageDefintion = get-AzGalleryImageDefinition -ResourceId $imageReference
        $GalleryName = $imageReference.Split("/")[-3]
        $Gallery = Get-AzGallery -Name $galleryName
        $ImageVersions = Get-AzGalleryImageVersion -ResourceGroupName $gallery.ResourceGroupName -GalleryName $Gallery.Name -GalleryImageDefinitionName $galleryImageDefintion.Name
        $LastVersion = ($ImageVersions | select -last 1).Name
        $Results = @()
        foreach ($SessionHost in $Sessionhosts) {
            $HasLatestVersion = $true
            $IsVirtualMachine = $true
            $Resource = Get-AzResource -resourceId $SessionHost.ResourceId
            $CurrentVersion = (Get-AzVm -name $Resource.Name).StorageProfile.ImageReference.ExactVersion
            if ($null -eq $CurrentVersion){
                $IsVirtualMachine = $false
                $HasLatestVersion = $null
            }
            if ($LastVersion -notmatch $CurrentVersion) {
                $HasLatestVersion = $False
            }
            $SessionHost | Add-Member -membertype noteproperty -name LatestVersion -value $LastVersion
            $SessionHost | Add-Member -membertype noteproperty -name CurrentVersion -value $CurrentVersion
            $SessionHost | Add-Member -membertype noteproperty -name HasLatestVersion -value $HasLatestVersion
            $SessionHost | Add-Member -membertype noteproperty -name IsVirtualMachine -value $IsVirtualMachine
            $Results += $SessionHost
        }
        return $Results | Select-Object Name, CurrentVersion, HasLatestVersion, IsVirtualMachine
    }
    else {
        "Sessionhosts does not use an image from the image gallery"
    }
}