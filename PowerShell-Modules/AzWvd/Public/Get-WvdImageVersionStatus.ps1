Function Get-WvdImageVersionStatus {
    <#
    .SYNOPSIS
    Gets the image version from where the session host is started.
    .DESCRIPTION
    The function will help you getting insights if there are session hosts started from an old version in the Shared Image Gallery
    .PARAMETER HostpoolName
    Enter the WVD Hostpool name
    .PARAMETER ResourceGroupName
    Enter the WVD Hostpool resourcegroup name
    .PARAMETER InputObject
    You can put the hostpool object in here. 
    .PARAMETER NotLatest
    This is a switch parameter which let you control the output to show only the sessionhosts which are not started from the latest version.
    .EXAMPLE
    Get-WvdImageVersionStatus -WvdHostpoolName wvd-hostpool -ResourceGroupName wvd-resourcegroup
    Get-AzWvdHostpool -WvdHostpoolName wvd-hostpool -ResourceGroupName wvd-resourcegroup | Get-WvdImageVersionStatus
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ParameterSetName = 'Hostpool')]
        [parameter(Mandatory, ParameterSetName = 'Sessionhost')]
        [ValidateNotNullOrEmpty()]
        [string]$HostpoolName,

        [parameter(Mandatory, ParameterSetName = 'Hostpool')]
        [parameter(Mandatory, ParameterSetName = 'Sessionhost')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [parameter(Mandatory, ParameterSetName = 'Sessionhost')]
        [ValidateNotNullOrEmpty()]
        [string]$SessionHostName,

        [parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$InputObject,

        [parameter()]
        [switch]$NotLatest
    )

    switch ($PsCmdlet.ParameterSetName) {
        InputObject { 
            if ($InputObject.Type -eq 'Microsoft.DesktopVirtualization/hostpools') {
                $HostpoolParameters = @{
                    HostpoolName      = $InputObject.Name
                    ResourceGroupName = $InputObject.id.split("/")[4]
                }
            }
            else {
                Write-Verbose "Sessionhost(s) provided"
                $Sessionhosts = $InputObject     
            }
        }
        Hostpool {
            $HostpoolParameters = @{
                HostPoolName      = $HostpoolName
                ResourceGroupName = $ResourceGroupName
            }
        }
        Default {
            $SessionHostParameters = @{
                HostPoolName      = $HostpoolName
                ResourceGroupName = $ResourceGroupName
                Name = $SessionHostName
            }
        }
    }
    if ($HostpoolParameters) {
        Write-Verbose "Hostpool parameters provided"
        try {
            $WvdHostpool = Get-AzWvdHostPool @HostpoolParameters
            $ImageReference = ($WvdHostpool.VMTemplate | ConvertFrom-Json).customImageId
        }
        catch {
            Throw "No WVD Hostpool found with name $Hostpoolname in resourcegroup $ResourceGroupName or no sessionhosts"
        }
    }
    if ($SessionHostParameters) {
        Write-Verbose "Sessionhost parameters provided"
        try {
            $SessionHosts = Get-AzWvdsessionhost @SessionHostParameters
        }
        catch {
            Throw "No WVD Hostpool found with name $Hostpoolname in resourcegroup $ResourceGroupName or no sessionhosts"
        }
    }
    $Results = @()
    foreach ($SessionHost in $Sessionhosts) {
        Write-Verbose "Searching for $($SessionHost.Name)"
        $HasLatestVersion, $IsVirtualMachine = $true
        $Resource = Get-AzResource -resourceId $SessionHost.ResourceId
        $imageReference = (Get-AzVm -name $Resource.Name).StorageProfile.ImageReference
        if ($ImageReference){
            $GalleryImageDefintion = get-AzGalleryImageDefinition -ResourceId $imageReference
            $GalleryName = $imageReference.Split("/")[-3]
            $Gallery = Get-AzGallery -Name $galleryName
            $ImageVersions = Get-AzGalleryImageVersion -ResourceGroupName $gallery.ResourceGroupName -GalleryName $Gallery.Name -GalleryImageDefinitionName $galleryImageDefintion.Name
            $LastVersion = ($ImageVersions | Select-Object -last 1).Name
        }
        if ($null -eq $imageReference.ExactVersion) {
            $IsVirtualMachine = $false
            $HasLatestVersion = $null
        }
        if ($LastVersion -notmatch $imageReference.ExactVersion) {
            $HasLatestVersion = $False
        }
        $SessionHost | Add-Member -membertype noteproperty -name LatestVersion -value $LastVersion
        $SessionHost | Add-Member -membertype noteproperty -name CurrentVersion -value $imageReference.ExactVersion
        $SessionHost | Add-Member -membertype noteproperty -name HasLatestVersion -value $HasLatestVersion
        $SessionHost | Add-Member -membertype noteproperty -name IsVirtualMachine -value $IsVirtualMachine
        $Results += $SessionHost
    }
    if ($NotLatest) {
        return $Results | Where { (!($_.HasLatestVersion)) }
    }
    else { 
        return $Results 
    }
}
