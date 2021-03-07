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
    Begin {
        Write-Verbose "Start searching"
        precheck
    }
    Process {
        switch ($PsCmdlet.ParameterSetName) {
            InputObject { 
                if ($InputObject.Type -eq 'Microsoft.DesktopVirtualization/hostpools') {
                    $HostpoolParameters = @{
                        HostpoolName      = $InputObject.Name
                        ResourceGroupName = $InputObject.id.split("/")[4]
                    }
                }
                elseif ($InputObject.Type -eq 'Microsoft.DesktopVirtualization/hostpools/sessionhosts'){
                    Write-Verbose "Sessionhost(s) provided, $($InputObject.Name)"
                    $Sessionhosts = $InputObject
                }
                else {
                    Write-Error "No correct resources provided, must be hostpool or sessionhost"
                    Break
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
                    Name              = $SessionHostName
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

        foreach ($SessionHost in $SessionHosts) {
            Write-Verbose "Searching for $($SessionHost.Name)"
            $HasLatestVersion, $IsVirtualMachine = $False
            try {
                $Resource = Get-AzResource -resourceId $SessionHost.ResourceId
                $IsVirtualMachine = $True
            }
            catch {
                Throw "$SessionHost has no vm Resource"
            }
            $imageReference = (Get-AzVm -name $Resource.Name).StorageProfile.ImageReference
            if ($ImageReference.Id) {
                $GalleryImageDefintion = get-AzGalleryImageDefinition -ResourceId $imageReference.Id
                $GalleryName = $imageReference.Id.Split("/")[-3]
                $Gallery = Get-AzGallery -Name $galleryName
                $ImageVersions = Get-AzGalleryImageVersion -ResourceGroupName $gallery.ResourceGroupName -GalleryName $Gallery.Name -GalleryImageDefinitionName $galleryImageDefintion.Name
                $LastVersion = ($ImageVersions | Select-Object -last 1).Name
            }
            if ($null -eq $imageReference.ExactVersion) {
                $HasLatestVersion = 'NoVersionFound'
            }
            if ($LastVersion -eq $imageReference.ExactVersion) {
                $HasLatestVersion = $True
            }
            $SessionHost | Add-Member -membertype noteproperty -name LatestVersion -value $LastVersion -Force
            $SessionHost | Add-Member -membertype noteproperty -name CurrentVersion -value $imageReference.ExactVersion -Force
            $SessionHost | Add-Member -membertype noteproperty -name HasLatestVersion -value $HasLatestVersion -Force
            $SessionHost | Add-Member -membertype noteproperty -name IsVirtualMachine -value $IsVirtualMachine -Force
        }
        if ($NotLatest) {
            return $Sessionhosts | Where-Object { (!($_.HasLatestVersion)) }
        }
        else { 
            return $Sessionhosts 
        }
    }
    End { 
        Write-Verbose "All host objects updated" 
    }
}
