<#
.SYNOPSIS
The script will create a new resource group with a new virtual machine and all of its needs.

.DESCRIPTION
The script will create a new virtual machine based on an existing WVD hostpool and sessionhosts. 
The VM and all other needed components are placed in a single new resource group. The VM can be used to create a new WVD image. 

After completing all the tasks the whole resource group can be deleted.

.PARAMETER HostpoolName
The WVD hostpool you like to update

.PARAMETER SnapshotName
Which snapshot will be used for creating a new virtual machine

.PARAMETER TempResourceGroup
Name of the temporary resource group

.PARAMETER ResourceGroupLocation
The resource group its location

.PARAMETER localPublicIp
Your local public IP to add to the NSG
.EXAMPLE
.\WVD-Create-UpdateVM.ps1 -HostpoolName 'wvd-hostpool' -SnapshotName 'before-sysprep-snapshot' -TempResourceGroup 'rg-temp-deploy' -ResourceGroupLocation 'westeurope' -localPublicIp 127.0.0.1
#>
param(
    [parameter(mandatory = $true)]
    [string]$HostpoolName,
    
    [parameter(mandatory = $true)]
    [string]$SnapshotName,
  
    [parameter(mandatory = $true)]
    [string]$TempResourceGroup,

    [parameter(mandatory = $true)]
    [string]$ResourceGroupLocation,

    [parameter(mandatory = $true)]
    [string]$localPublicIp
)

import-module az.desktopvirtualization
import-module az.network
import-module az.compute


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
function create-randomString($type) {
    function Get-RandomCharacters($length, $characters) {
        $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
        $private:ofs = ""
        return [String]$characters[$random]
    }
    if ($type -eq 'username') {
        $username = Get-RandomCharacters -length 8 -characters 'abcdefghiklmnoprstuvwxyz'
        return $username
    }
    if ($type -eq 'password') {
        $password = Get-RandomCharacters -length 9 -characters 'abcdefghiklmnoprstuvwxyz'
        $password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
        $password += Get-RandomCharacters -length 1 -characters '1234567890'
        $password += Get-RandomCharacters -length 1 -characters '!$%&/()=?}][{@#*+'
        return $password
    }
}

# Get WVD hostpool information
$hostpool = Get-AzWvdHostPool | Where-Object { $_.Name -eq $hostpoolname }
$hostpoolResourceGroup = ($hostpool).id.split("/")[4]
# Get current WVD Configurgation
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $hostpoolResourceGroup -HostPoolName $hostpool.name
$sessionHostName = ($sessionHosts.Name.Split("/")[-1]).Split(".")[0]
$currentVmInfo = Get-AzVM -name $sessionHostName
$virtualMachineSize = $currentVmInfo.hardwareprofile.vmsize
$virtualNetworkSubnet = (Get-AzNetworkInterface -ResourceId $currentVmInfo.NetworkProfile.NetworkInterfaces.id).IpConfigurations.subnet.id


# Snapshot values for creating a disk
try {
    $snapshot = get-azsnapshot -SnapshotName $snapshotname
    $resourceGroupName = $snapshot.ResourceGroupName
}
catch {
    Throw "No snapshot found, $_"
}

# Creating a new temporary resource group first
$ResourceGroup = New-AzResourceGroup -Name $TempResourceGroup -Location $ResourceGroupLocation

$VirtualMachineName = ('vm_' + $snapshot.name)
# Creating a disk
$diskConfig = New-AzDiskConfig -SkuName "Premium_LRS" -Location $ResourceGroup.location -CreateOption Copy -SourceResourceId $snapshot.Id
$diskname = ($VirtualMachineName.ToLower() + '-OS')
$disk = Get-azdisk -diskname $diskname
try {
    $disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $ResourceGroup.resourceGroupName -DiskName $diskName
}
catch {
    Throw "$diskname allready exits, $_"
}

$NicParameters = @{
    Name              = ($VirtualMachineName.ToLower() + '_nic')
    ResourceGroupName = $ResourceGroup.resourceGroupName
    Location          = $ResourceGroup.Location
    SubnetId          = $virtualNetworkSubnet
    PublicIpAddressId = $publicIp.Id
    Force             = $true
}
$nic = New-AzNetworkInterface @NicParameters

$PublicIpParameters = @{
    Name              = ($VirtualMachineName.ToLower() + '_ip')
    ResourceGroupName = $ResourceGroup.ResourceGroupName
    Location          = $ResourceGroup.Location
    AllocationMethod  = 'Dynamic'
    Force             = $true
}
$publicIp = New-AzPublicIpAddress @PublicIpParameters

# Creating a temporary network security group
$NsgParameters = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName
    Location          = $ResourceGroup.Location
    Name              = ($VirtualMachineName.ToLower() + '_nsg')
}
$nsg = New-AzNetworkSecurityGroup @NsgParameters

# Adding a security rule to only the network interface card
add-firewallRule -NSG $NSG -localPublicIp $localPublicIp -port 3389
$nic.NetworkSecurityGroup = $nsg
$nic | Set-AzNetworkInterface

# Creating virtual machine configuration
$VirtualMachine = New-AzVMConfig -VMName $VirtualMachineName -VMSize $virtualMachineSize
# Use the Managed Disk Resource Id to attach it to the virtual machine. Please change the OS type to linux if OS disk has linux OS
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $disk.Id -CreateOption Attach -Windows
# Create a public IP for the VM
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id
#Create the virtual machine with Managed Disk
$newVm = New-AzVM -VM $VirtualMachine -ResourceGroupName $ResourceGroup.resourceGroupName -Location $ResourceGroup.Location

$userName = create-randomString -type 'username'
$password = ConvertTo-SecureString (create-randomString -type 'password') -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($userName, $password);

$CredentialParameters = @{
    ResourceGroupName  = $ResourceGroup.ResourceGroupName
    Location           = $ResourceGroup.Location
    VMName             = $VirtualMachineName
    Credential         = $Credential
    typeHandlerVersion = "2.0"
    Name               = "VMAccessAgent"
}
Set-AzVMAccessExtension @CredentialParameters

if ($newVm) {
    #Adding the role
    $publicIp = (Get-AzPublicIpAddress | where { $_.name -match $VirtualMachineName }).IpAddress
    $bodyValues = [Ordered]@{
        Status                 = $newVm.StatusCode
        hostPool               = $hostpoolName
        virtualMachineName     = $VirtualMachineName
        resourceGroupName      = $ResourceGroup.ResourceGroupName
        virtualMachinePublicIp = $publicIp
        username               = $userName
        password               = $password | ConvertFrom-SecureString -AsPlainText
        virtualMachineDisk     = $diskname
        engineersIp            = $localpublicIp
    }
}
Write-Output $bodyValues
