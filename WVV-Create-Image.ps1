param(
    [parameter(mandatory = $true)][string]$hostpoolName,
    [parameter(mandatory = $true)][string]$snapshotName,
    [parameter(mandatory = $true)][string]$localPublicIp
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
        $password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
        $password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
        $password += Get-RandomCharacters -length 1 -characters '1234567890'
        $password += Get-RandomCharacters -length 1 -characters '!$%&/()=?}][{@#*+'
        return $password
    }
}


$hostpool = Get-AzWvdHostPool | ? { $_.Name -eq $hostpoolname }
# Snapshot values 
$snapshot = get-azsnapshot -SnapshotName $snapshotname
$resourceGroupName = $snapshot.ResourceGroupName
$location = $snapshot.Location

$hostpoolResourceGroup = ($hostpool).id.split("/")[4]
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $hostpoolResourceGroup -HostPoolName $hostpool.name
$sessionHostName = ($sessionHosts.Name.Split("/")[-1]).Split(".")[0]
$currentVmInfo = Get-AzVM -name $sessionHostName
$virtualMachineSize = $currentVmInfo.hardwareprofile.vmsize
$virtualNetworkSubnet = (Get-AzNetworkInterface -ResourceId $currentVmInfo.NetworkProfile.NetworkInterfaces.id).IpConfigurations.subnet.id
$NSG = Get-AzNetworkSecurityGroup | ? { $_.subnets.id -eq $virtualNetworkSubnet }
$virtualMachineResourceGroup = $currentVmInfo.ResourceGroupName
$diskConfig = New-AzDiskConfig -SkuName "Premium_LRS" -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id
$diskname = ('disk_' + $snapshot.name)
$disk = Get-azdisk -diskname $diskname
if ($disk) {
    Write-Output "Disk $diskname exists in resourcegroup $resourceGroupname"
}
else {
    New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $diskName
    #Test if disk is created
    $disk = Get-azdisk -diskname $diskname
    if ($disk) {
        Write-Output "Disk $diskname created succesful in resourcegroup $resourceGroupname"
    }
}
$VirtualMachineName = ('vm' + $snapshot.name)
$VirtualMachine = New-AzVMConfig -VMName $VirtualMachineName -VMSize $virtualMachineSize
# Use the Managed Disk Resource Id to attach it to the virtual machine. Please change the OS type to linux if OS disk has linux OS
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $disk.Id -CreateOption Attach -Windows
# Create a public IP for the VM
$publicIp = New-AzPublicIpAddress -Name ($VirtualMachineName.ToLower() + '_ip') -ResourceGroupName $virtualMachineResourceGroup  -Location $snapshot.Location -AllocationMethod Dynamic -Force
# Create NIC in the first subnet of the virtual network
$nic = New-AzNetworkInterface -Name ($VirtualMachineName.ToLower() + '_nic') -ResourceGroupName $resourceGroupName -Location $snapshot.Location -SubnetId $virtualNetworkName -PublicIpAddressId $publicIp.Id -Force
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id

#Create the virtual machine with Managed Disk
$newVm = New-AzVM -VM $VirtualMachine -ResourceGroupName $resourceGroupName -Location $snapshot.Location

if ($newVm) {
    #Adding the role
    add-firewallRule -NSG $NSG -localPublicIp $localPublicIp -port 3389
    $userName = create-randomString -type 'username'
    $password = create-randomString -type 'password'
    # Convert to SecureString
    [securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
    [pscredential]$creds = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
    # For reset username/password
    Set-AzVMAccessExtension -ResourceGroupName $resourceGroupName -Location $snapshot.Location -VMName $VirtualMachineName -Credential $creds -typeHandlerVersion "2.0" -Name VMAccessAgent
    $publicIp = (Get-AzPublicIpAddress | where { $_.name -match $VirtualMachineName }).IpAddress
    $details = "VM $virtualmachinename created succesful"
    $bodyValues = [Ordered]@{
        details                = $details
        hostPool               = $hostpoolName
        virtualMachineName     = $VirtualMachineName
        resourceGroupName      = $resourceGroupName
        virtualMachinePublicIp = $publicIp
        username               = $userName
        password               = $password
        virtualMachineDisk     = $diskname
        engineersIp            = $localpublicIp
    }
}
Write-Host $bodyValues
