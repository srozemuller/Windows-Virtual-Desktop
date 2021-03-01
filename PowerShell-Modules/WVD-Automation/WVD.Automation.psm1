function Get-WvdVmResource {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][Object]$SessionHost
    )
    try {
        $Resource = Get-AzResource -ResourceId $SessionHost.ResourceId
        $VirtualMachine = (Get-AzVm -Name $Resource.Name)
    }
    catch {
        Throw "No virtual machine found based on $SessionHost, $_"
    }
    return $VirtualMachine
}
function Get-WvdLatestSessionHost {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$WvdHostpoolName,
        [parameter(mandatory = $true)][string]$WvdHostpoolResourceGroup
    )
    try {
        $SessionHosts = Get-AzWvdSessionHost -HostPoolName $WvdHostpoolName -ResourceGroupName $WvdHostpoolResourceGroup |  Sort-Object ResourceId -Descending
    }
    catch {
        Throw "No session hosts found in WVD Hostpool $WvdHostpoolName, $_"
    }
    # Convert hosts to highest number to get initial value
    $All = @{}
    $Names = $SessionHosts | % { ($_.Name).Split("/")[-1].Split(".")[0] }
    $Names | % { $All.add([int]($_).Split("-")[-1], $_) }
    $LatestHost = $All.GetEnumerator() | select -first 1 -ExpandProperty Value
    $VirtualMachine = Get-AzVM -Name $LatestHost
    return $VirtualMachine
}

function Get-WvdSubnet {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$WvdHostpoolName,
        [parameter(mandatory = $true)][string]$WvdHostpoolResourceGroup
    )
    try {
        $SessionHost = Get-WvdLatestSessionhost -WvdHostpoolName $WvdHostpoolName -WvdHostpoolResourceGroup $WvdHostpoolResourceGroup
    }
    catch {
        Throw "No sessionhost has been found in $WvdHostpoolName, $_"
    }
    $NetworkInterface = ($SessionHost).NetworkProfile
    $Subnet = (Get-AzNetworkInterface -ResourceId $NetworkInterface.NetworkInterfaces.id).IpConfigurations.subnet
    return $Subnet
}
function Get-WvdNsg {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$WvdHostpoolName,
        [parameter(mandatory = $true)][string]$WvdHostpoolResourceGroup
    )
    try {
        $Subnet = Get-WvdSubnet -WvdHostpoolName $WvdHostpoolName -WvdHostpoolResourceGroup $WvdHostpoolResourceGroup
    }
    catch {
        Throw "No subnet has been found in $WvdHostpoolName, $_"
    }
    $WvdNsg = Get-AzNetworkSecurityGroup | Where-Object { $_.Subnets.id -match $Subnet.id }
    if ($null -ne $WvdNsg) {
        return $WvdNsg
    }
    else {
        Throw "No Network Security Group assigned at subnet $Subnet"
    }
}

function Get-WvdImageVersionStatus {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$WvdHostpoolName,
        [parameter(mandatory = $true)][string]$WvdHostpoolResourceGroup
    )
    try {
        $WvdHostpool = Get-AzWvdHostPool -HostPoolName $WvdHostpoolName -ResourceGroupName $WvdHostpoolResourceGroup
    }
    catch {
        Throw "No sessiohost has been found in $WvdHostpoolName, $_"
    }
    $ImageReference = ($WvdHostpool.VMTemplate | ConvertFrom-Json).customImageId
    if ($ImageReference -match 'Microsoft.Compute/galleries/') {
        $GalleryImageDefintion = get-AzGalleryImageDefinition -ResourceId $imageReference
        $GalleryName = $imageReference.Split("/")[-3]
        $Gallery = Get-AzGallery -Name $galleryName
        $ImageVersions = Get-AzGalleryImageVersion -ResourceGroupName $gallery.ResourceGroupName -GalleryName $Gallery.Name -GalleryImageDefinitionName $galleryImageDefintion.Name
        $LastVersion = ($ImageVersions | select -last 1).Name
        $UpToDate = $True
        $Results = @()
        foreach ($SessionHost in (Get-AzWvdSessionHost -HostPoolName $WvdHostpoolName -ResourceGroupName $WvdHostpoolResourceGroup)) {
            $Resource = Get-AzResource -resourceId $SessionHost.ResourceId
            $CurrentVersion = (Get-AzVm -name $Resource.Name).StorageProfile.ImageReference.ExactVersion
            if ($LastVersion -notmatch $CurrentVersion) {
                $UpToDate = $False
            }
            $SessionHost | Add-Member -membertype noteproperty -name LatestVersion -value $LastVersion
            $SessionHost | Add-Member -membertype noteproperty -name CurrentVersion -value $CurrentVersion
            $SessionHost | Add-Member -membertype noteproperty -name UpToDate -value $UpToDate
            $Results += $SessionHost
        }
        return $Results | Select-Object Name, CurrentVersion, LatestVersion, UpToDate
    }
    else {
        "Sessionhosts does not use an image from the image gallery"
    }
}

function New-WvdRegistrationToken {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$WvdHostpoolName,
        [parameter(mandatory = $true)][string]$WvdHostpoolResourceGroup
    )
    try {
        $WvdHostpool = Get-AzWvdHostPool -HostPoolName $WvdHostpoolName -ResourceGroupName $WvdHostpoolResourceGroup
    }
    catch {
        Throw "No WVD Hostpool found for $WvdHostpoolName, $_"
    }

    $now = get-date
    # Create a registration key for adding machines to the WVD Hostpool
    $registered = Get-AzWvdRegistrationInfo -SubscriptionId $hostpoolSubscription -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName
    if (($null -eq $registered.ExpirationTime) -or ($registered.ExpirationTime -le ($now))) {
        $registered = New-AzWvdRegistrationInfo -SubscriptionId $hostpoolSubscription -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName -ExpirationTime $now.AddHours(4)
    }
    if ($registered.Token) {
    }
    return $registered
    
}

New-WvdSessionHostFromSig {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][string]$WvdHostpoolName,
        [parameter(mandatory = $true)][string]$WvdHostpoolResourceGroup,
        [parameter(mandatory = $true)][string]$AdminUsername,
        [parameter(mandatory = $true)][string]$AdminPassword,
        [parameter(mandatory = $false)][string]$Tags
    )
    try {
        $WvdHostpool = Get-AzWvdHostPool -HostPoolName $WvdHostpoolName -ResourceGroupName $WvdHostpoolResourceGroup
    }
    catch {
        Throw "No WVD Hostpool found for $WvdHostpoolName, $_"
    }
}

Set-WvdSessionhostToDrainMode {
    
}
