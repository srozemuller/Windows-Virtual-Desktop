param(
    [parameter(mandatory = $true, ValueFromPipelineByPropertyName)]$vhdlocation
)
#$vhdlocation = "\\wvdfslogixwvdexperts2.file.core.windows.net\fslogix"
$FsLogixDownloadLocation = 'https://aka.ms/fslogix_download'
$FsLogixRegLocation =  'HKLM:\Software\FSLogix'
$FsLogixRegLocationProfiles = 'HKLM:\Software\FSLogix\Profiles'
$DownloadedFileLocation = '.\fslogix.zip'

try {
    
    Invoke-WebRequest $FsLogixDownloadLocation -OutFile $DownloadedFileLocation
    Expand-Archive $DownloadedFileLocation
    $FsLogixFileLocation = Get-ChildItem -Path .\fslogix -Recurse -Include 'FSLogixAppsSetup.exe' | where {$_.FullName -match 'x64'}
}
catch {
    Throw "File is not downloaded to $DownloadedFileLocation or 64BIT file is not found $_"
}

try {
    Start-Process -FilePath $FsLogixFileLocation -ArgumentList "/quiet /norestart" -Wait
    # Wait till FSLogix has been installed, after installation create the Profiles key into the registry.
    New-item -Path $FsLogixRegLocation -name "Profiles"
}
catch 
{
    Throw "FSLogix not installed $_"
}
if(Test-Path $FsLogixRegLocation){
    # If registry location exists, create the needed registry values
    New-ItemProperty -Path $FsLogixRegLocationProfiles -Name 'VHDLocations' -ErrorAction:SilentlyContinue -PropertyType:String -Value $vhdlocation -Force
    New-ItemProperty -Path $FsLogixRegLocationProfiles -Name 'Enabled' -ErrorAction:SilentlyContinue -PropertyType:dword -Value 1 -Force
    New-ItemProperty -Path $FsLogixRegLocationProfiles -Name 'DeleteLocalProfileWhenVHDShouldApply' -ErrorAction:SilentlyContinue -PropertyType:dword -Value 1 -Force
    New-ItemProperty -Path $FsLogixRegLocationProfiles -Name 'FlipFlopProfileDirectoryName' -ErrorAction:SilentlyContinue -PropertyType:dword -Value 1 -Force
}
else {
    Write-Warning "No profiles folder found!"
}
Restart-Computer -ComputerName $env:COMPUTERNAME -Force
