param(
    [parameter(mandatory = $false)][string]$HostPoolName,
    [parameter(mandatory = $false)][string]$WorkspaceName

)
Import-Module Az.OperationalInsights
Import-Module Az.DesktopVirtualization

try {
    $Hostpool = Get-AzWvdHostPool | where {$_.Name -eq $HostPoolName}
    $Workspace = Get-AzOperationalInsightsWorkspace | where{$_.Name -eq $WorkspaceName}
}
catch{
    Write-Host "Hostpool or Workspace not found"
    exit;
}

# Check if the insightsprovide is registered otherwise register
If (!(Register-AzResourceProvider -ProviderNamespace microsoft.insights).RegistrationState.Contains("Registered")){
    Register-AzResourceProvider -ProviderNamespace microsoft.insights
}
while (!(Register-AzResourceProvider -ProviderNamespace microsoft.insights).RegistrationState.Contains("Registered")){
    Write-Host "Resource provider microsoft.insights is not registered yet"
    Start-Sleep 1
}

$Parameters = @{
    ResourceId = $Hostpool.id
    WorkspaceId = $Workspace.ResourceId
    Enabled = $true
    Category = "Checkpoint,Error,Management,Connection,HostRegistration"
}

Set-AzDiagnosticSetting -Name WVD-Diagnostics @parameters
