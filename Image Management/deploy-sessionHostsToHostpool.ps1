param(
    [parameter(mandatory = $true)][string]$hostpoolName,
    [parameter(mandatory = $false)][int]$sessionHostsNumber,
    [parameter(mandatory = $true)][string]$administratorAccountUsername,
    [parameter(mandatory = $true)][string]$administratorAccountPassword
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

$hostpoolName = "WVD-Experts-Hostpool-Norm"
# Get the hostpool information
$hostpool = Get-AzWvdHostPool | ? { $_.Name -eq $hostpoolName }
Write-Host "Found hostpool $($hostpool).name"
$resourceGroup = ($hostpool).id.split("/")[4].ToUpper()
Write-Host "Found resourcegroup $resourceGroup"
$hostpoolSubscription = ($hostpool).id.split("/")[2]
Write-Host "Found subscription $hostpoolSubscription"
# Get current sessionhost information
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpool.name
Write-Host "Sessionhosts $sessionHosts"
$sessionHost = $sessionHosts[-1]
Write-Host "Last sessionhost is $sessionhost" 


if ($null -eq $sessionHosts) {
    Write-Host "No sessionhosts found in hostpool $hostpoolname, exiting script"
    exit;
}

$hostPoolRegistration = create-wvdHostpoolToken -hostpoolName $hostpoolName -resourceGroup $resourceGroup -hostpoolSubscription $hostpoolSubscription
if ($hostPoolRegistration) {
    $hostPoolToken = (ConvertTo-SecureString -AsPlainText -Force ($hostPoolRegistration).Token)
}

if ($null -eq $sessionHostsNumber) {
    $sessionHostsNumber = $sessionHosts.count
    Write-Host "No sessionHostsNumber provided, creating $sessionHostsNumber hosts"
}

# Get current sessionhost configuration, used in the next steps
$existingHostName = $sessionHosts[-1].Id.Split("/")[-1]
$prefix = $existingHostName.Split("-")[0]
$currentVmInfo = Get-AzVM -Name $existingHostName.Split(".")[0]
$vmInitialNumber = [int]$existingHostName.Split("-")[-1].Split(".")[0] + 1
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
    administratorAccountPassword    = $administratorAccountPassword #(ConvertTo-SecureString $administratorAccountPassword -AsPlainText -Force)
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
$templateParameters

$deploy = new-AzresourcegroupDeployment -TemplateUri "https://raw.githubusercontent.com/srozemuller/Windows-Virtual-Desktop/master/Image%20Management/deploy-sessionhost-template.json" @templateParameters -Name "deploy-version-$($latestImageVersion.Name)"
if (($deploy.ProvisioningState -eq "Succeeded")) {
    foreach ($sessionHost in $sessionHosts) {
        $sessionHostName = $sessionHost.name.Split("/")[-1]
        $sessionHostName
        Update-AzWvdSessionHost -HostPoolName $Hostpoolname -ResourceGroupName $ResourceGroup -Name $sessionHostName -AllowNewSession:$false
    }
}
