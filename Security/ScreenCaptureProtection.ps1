<#
This script enables the Windows Virtual Desktop Screen Capture Protection. Run this script on the session host. 
#>

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fEnableScreenCaptureProtection /t REG_DWORD /d 1
