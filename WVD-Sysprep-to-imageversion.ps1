param(
    [parameter(mandatory = $true, ValueFromPipelineByPropertyName)]$virtualMachineName,
    [parameter(mandatory = $true, ValueFromPipelineByPropertyName)]$resourceGroupName,
    [parameter(mandatory = $true, ValueFromPipelineByPropertyName)]$hostpoolName
)
import-module az.compute
$date = get-date -format "yyyy-MM-dd"
$version = $date.Replace("-", ".")

function test-VMstatus($virtualMachineName) {
    $vmStatus = Get-AzVM -name $virtualMachineName -resourcegroup $resourceGroupName -Status
    return "$virtualMachineName status " + (($vmstatus.Statuses | ? { $_.code -match 'Powerstate' }).DisplayStatus)
}

function add-firewallRule($NSG, $localPublicIp, $port) {
    # Pick random number for setting priority. It will exclude current priorities.
    $InputRange = 100..200
    $Exclude = ($NSG | Get-AzNetworkSecurityRuleConfig | select Priority).priority
    $RandomRange = $InputRange | Where-Object { $Exclude -notcontains $_ }
    $priority = Get-Random -InputObject $RandomRange
    $nsgParameters = @{
        Name                     = "Allow-$port-Inbound-$localPublicIp"
        Description              = "Allow port $port from local ip address $localPublicIp"
        Access                   = 'Allow'
        Protocol                 = "Tcp" 
        Direction                = "Inbound" 
        Priority                 = $priority 
        SourceAddressPrefix      = $localPublicIp 
        SourcePortRange          = "*"
        DestinationAddressPrefix = "*" 
        DestinationPortRange     = $port
    }
    $NSG | Add-AzNetworkSecurityRuleConfig @NSGParameters  | Set-AzNetworkSecurityGroup 
}
# Stopping VM for creating clean snapshot
Stop-AzVM -name $virtualMachineName -resourcegroup $resourceGroupName -Force -StayProvisioned

do {
    $status = test-vmStatus -virtualMachineName $virtualMachineName
    $status
} until ( $status -match "stopped")

# If VM is stopped, create snapshot Before Sysprep
$vm = Get-AzVM -name $virtualMachineName -ResourceGroupName $resourceGroupName
$snapshot = New-AzSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $vm.location -CreateOption copy
$snapshotName = ($vm.StorageProfile.OsDisk.name).Split("-")
$snapshotName = $snapshotName[0] + "-" + $snapshotName[1] + "-" + $date + "-BS"
Write-Output "Creating snapshot $snapshotName for $virtualMachineName"
$createSnapshot = New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName 

#Source: https://docs.microsoft.com/nl-nl/azure/virtual-machines/windows/capture-image-resource
# If snapshot is created start VM again and run a sysprep
if ($null -eq $createSnapshot) {
    Write-Error "No snapshot created"
    break; 
}
Start-AzVM -name $virtualMachineName -resourcegroup $resourceGroupName 
Write-Output "Snapshot created, starting machine."
do {
    $status = test-vmStatus -virtualMachineName $virtualMachineName
    $status
} until ($status -match "running")
$virtualMachinePublicIp = (Get-AzPublicIpAddress | where { $_.name -match $VirtualMachineName }).IpAddress
$virtualNetworkSubnet = (Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces.id).IpConfigurations.subnet.id
$NSG = Get-AzNetworkSecurityGroup | ? { $_.subnets.id -eq $virtualNetworkSubnet }
Write-Output "Enabling Powershell Remote Extention"
Invoke-AzVMRunCommand -CommandId "EnableRemotePS" -VM $vm
#Adding the role
add-firewallRule -NSG $NSG -localPublicIp $localPublicIp -port 5986
$connectionUri = "https://" + $virtualMachinePublicIp + ":5986" 
$session = $null
while (!($session)) {
    $session = New-PSSession -ConnectionUri $connectionUri -Credential $creds -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)
    Write-Output "Creating Remote Powershell session"
    $session
}
#$setRegCommand = "Set-Itemproperty -path 'HKLM:\SYSTEM\Setup\Status\SysprepStatus' -Name 'GeneralizationState' -value 3"
$sysprep = 'C:\Windows\System32\Sysprep\Sysprep.exe'
$arg = '/generalize /oobe /shutdown /quiet'
Invoke-Command -Session $session -ScriptBlock { param($sysprep, $arg) Start-Process -FilePath $sysprep -ArgumentList $arg } -ArgumentList $sysprep, $arg
Write-Output "Sysprep command started on $virtualMachineName, now waiting till the vm is stopped."


# After sysprep check if vm is stopped and deallocated
do {
    $status = test-vmStatus -virtualMachineName $virtualMachineName
    $status
} until ($status -like "stopped")
#>
# When the VM is stopped it is time to generalize the VM 
# Source https://docs.microsoft.com/nl-nl/azure/virtual-machines/windows/capture-image-resource
Write-Output "$virtualMachineName is going to be generalized"
Set-AzVm -ResourceGroupName $resourceGroupName -Name $virtualMachineName -Generalized

# Testing if there is allready a WVD VM with an update status
$hostpool = Get-AzWvdHostPool | ? { $_.Name -eq $hostpoolname } 
# Creating VM configuration based on existing VM's in specific hostpool, selecting first one
$hostpoolResourceGroup = ($hostpool).id.split("/")[4]
Write-Output "Hostpool resourcegroup is $hostpoolResourceGroup"

# Get one of the current production VM's for getting the share image gallery info
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $hostpoolResourceGroup -HostPoolName $hostpool.name
$existingSessionHost = ($sessionHosts.Name.Split("/")[-1]).Split(".")[0]
$productionVm = Get-AzVM -Name $existingSessionHost

# Get the update VM for creating new image based on connected disk
$diskName = $vm.StorageProfile.OsDisk.name
# Replace the Before Sysprep to After Sysprep
$imageName = $diskname.Replace("BS", "AS")
$image = New-AzImageConfig -Location $vm.location -SourceVirtualMachineId $vm.Id 
# Create the image based on the connected disk on the update VM
Write-Output "Creating image $imageName based on $($vm.name)"
New-AzImage -Image $image -ImageName $imageName -resourcegroupname $productionVm.ResourceGroupName
$managedImage = Get-AzImage -ImageName $imageName -resourcegroupname $productionVm.ResourceGroupName

# Source: https://docs.microsoft.com/en-us/azure/virtual-machines/image-version-managed-image-powershell
# Creating image version based on the image created few steps ago
$imageReference = ((get-azvm -Name $productionVm[-1].name -ResourceGroupName $productionVm[-1].ResourceGroupName).storageprofile.ImageReference).id
$galleryImageDefintion = get-AzGalleryImageDefinition -ResourceId $imageReference
$galleryName = $imageReference.Split("/")[-3]
$gallery = Get-AzGallery -Name $galleryName

# Configuring paramaters
$imageVersionParameters = @{
    GalleryImageDefinitionName = $galleryImageDefintion.Name
    GalleryImageVersionName    = $version
    GalleryName                = $gallery.Name
    ResourceGroupName          = $gallery.ResourceGroupName
    Location                   = $gallery.Location
    Source                     = $managedImage.id.ToString()
}
# Doing the job
New-AzGalleryImageVersion @imageVersionParameters

$bodyValues = [Ordered]@{
    hostPool               = $hostpoolName
    virtualMachineName     = $VirtualMachineName
    resourceGroupName      = $resourceGroupName
    virtualMachinePublicIp = $virtualMachinePublicIp
    username               = $username
    password               = $password
}
$bodyValues
