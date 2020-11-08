# Disable Store auto update
if(Test-Path HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore){
    set-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore -Name AutoDownload -Value 0 -Force
}

# Disable Content Delivery auto download apps that they want to promote to users
if(!(Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager)){
    New-Item HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager
}
set-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name PreInstalledAppsEnabled -Value 0 -Force

if(!(Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug)){
    New-Item HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug
}
set-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug -Name ContentDeliveryAllowedOverride -Value 0x2 -Force


$tasks = @("Automatic app update", "Scheduled Start")
foreach ($task in $tasks) {
    if (Get-ScheduledTask $task) {
        Get-ScheduledTask $task |  Disable-ScheduledTask 
    }
}
# Disable Windows Update:
Get-Service wuauserv | Set-Service -StartupType Disabled
# Enable Hyper-V because you'll be using the Mount-VHD command to stage and and Dismount-VHD to destage
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
Restart-Computer $env:computername
