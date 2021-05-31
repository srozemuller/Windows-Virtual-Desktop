<#
This script will execute the sysprep command on the machine. 
#>
$sysprep = 'C:\Windows\System32\Sysprep\Sysprep.exe'
$arg = '/generalize /oobe /shutdown /quiet /mode:vm'
Start-Process -FilePath $sysprep -ArgumentList $arg
