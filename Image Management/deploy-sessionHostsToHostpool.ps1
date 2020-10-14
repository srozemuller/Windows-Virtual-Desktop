param(
    [parameter(mandatory = $true)][string]$hostpoolName,
    [parameter(mandatory = $false)][int]$sessionHostsNumber,
    [parameter(mandatory = $true)][string]$administratorAccountUsername,
    [parameter(mandatory = $true)][securestring]$administratorAccountPassword,
    [parameter(mandatory = $true)][boolean]$setDrainModeToOn
)

import-module az.desktopvirtualization
import-module az.network
import-module az.compute

function create-wvdHostpoolToken($hostpoolName, $resourceGroup, $hostpoolSubscription) {
    $now = get-date
    # Create a registration key for adding machines to the WVD Hostpool
    $registered = Get-AzWvdRegistrationInfo -SubscriptionId $hostpoolSubscription -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName
    if (($null -eq $registered.ExpirationTime) -or ($registered.ExpirationTime -le ($now))) {
        $registered = New-AzWvdRegistrationInfo -SubscriptionId $hostpoolSubscription -ResourceGroupName $resourceGroup -HostPoolName $hostpool.Name -ExpirationTime $now.AddHours(4)
    }
    if ($registered.Token) {
    }
    return $registered
}

# Get the hostpool information
$hostpool = Get-AzWvdHostPool | ? { $_.Name -eq $hostpoolName }
$resourceGroup = ($hostpool).id.split("/")[4].ToUpper()
$hostpoolSubscription = ($hostpool).id.split("/")[2]
# Get current sessionhost information
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpool.name

if ($null -eq $sessionHosts) {
    Write-Host "No sessionhosts found in hostpool $hostpoolname, exiting script"
    exit;
}

if (create-wvdHostpoolToken -hostpoolName $hostpoolName -resourceGroup $resourceGroup -hostpoolSubscription $hostpoolSubscription) {
    $hostPoolToken = (ConvertTo-SecureString -AsPlainText -Force ($hostPoolToken).Token)
}

if ($null -eq $sessionHostsNumber) {
    $sessionHostsNumber = $sessionHosts.count
    Write-Host "No sessionHostsNumber provided, creating $sessionHostsNumber hosts"
}

# Get current sessionhost configuration, used in the next steps
$existingHostName = $sessionHosts[-1].ResourceId.Split("/")[-1]
$prefix = $existingHostName.Split("-")[0]
$currentVmInfo = Get-AzVM -name $existingHostName
$vmInitialNumber = ([int]$existingHostName.Split("-")[-1]) + 1
$vmNetworkInformation = (Get-AzNetworkInterface -ResourceId $currentVmInfo.NetworkProfile.NetworkInterfaces.id)
$virtualNetworkName = $vmNetworkInformation.IpConfigurations.subnet.id.split("/")[-3]
$virutalNetworkResoureGroup = $vmNetworkInformation.IpConfigurations.subnet.id.split("/")[4]
$virtualNetworkSubnet = $vmNetworkInformation.IpConfigurations.subnet.id.split("/")[-1]


# Get the image gallery information for getting latest image
$imageReference = ($currentVmInfo.storageprofile.ImageReference).id
$galleryImageDefintion = get-AzGalleryImageDefinition -ResourceId $imageReference
$galleryName = $imageReference.Split("/")[-3]
$gallery = Get-AzGallery -Name $galleryName
$latestImageVersion = (Get-AzGalleryImageVersion -ResourceGroupName $gallery.ResourceGroupName -GalleryName $gallery.Name -GalleryImageDefinitionName $galleryImageDefintion.Name)[-1]

$tags = @{
    ImageVersion = $latestImageVersion.Name
    HostPool     = $hostpoolName
}

$templateParameters = @{
    resourceGroupName               = $resourceGroup
    hostpoolName                    = $hostpoolName
    administratorAccountUsername    = $administratorAccountUsername
    administratorAccountPassword    = (ConvertTo-SecureString $administratorAccountPassword -AsPlainText -Force)
    createAvailabilitySet           = $false
    hostpooltoken                   = $hostPoolToken
    vmInitialNumber                 = $vmInitialNumber
    vmResourceGroup                 = ($resourceGroup).ToUpper()
    vmLocation                      = $currentVmInfo.Location
    vmSize                          = $currentVmInfo.HardwareProfile.vmsize
    vmNumberOfInstances             = $sessionHostsNumber
    vmNamePrefix                    = $prefix
    vmImageType                     = "CustomImage"
    vmDiskType                      = $currentVmInfo.StorageProfile.osdisk.ManagedDisk.StorageAccountType
    vmUseManagedDisks               = $true
    existingVnetName                = $virtualNetworkName
    existingSubnetName              = $virtualNetworkSubnet
    virtualNetworkResourceGroupName = $virutalNetworkResoureGroup
    usePublicIP                     = $false
    createNetworkSecurityGroup      = $false
    vmCustomImageSourceId           = $imageReference
    availabilitySetTags             = $tags
    networkInterfaceTags            = $tags
    networkSecurityGroupTags        = $tags
    publicIPAddressTags             = $tags
    virtualMachineTags              = $tags
    imageTags                       = $tags
}


$deploy = new-AzresourcegroupDeployment -TemplateUri "https://raw.githubusercontent.com/srozemuller/Windows-Virtual-Desktop/master/Image%20Management/deploy-sessionhost-template.json" @templateParameters -Name "deploy-version-$($latestImageVersion.Name)"
if (($deploy.ProvisioningState -eq "Succeeded") -and ($setDrainModeToOn)) {
    foreach ($sessionHost in $sessionHosts) {
        $sessionHostName = $sessionHost.name.Split("/")[-1]
        $sessionHostName
        Update-AzWvdSessionHost -HostPoolName $Hostpoolname -ResourceGroupName $ResourceGroup -Name $sessionHostName -AllowNewSession:$false
    }
}