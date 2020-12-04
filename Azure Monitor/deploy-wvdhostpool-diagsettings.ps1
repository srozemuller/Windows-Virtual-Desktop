param(
    [parameter(mandatory = $true)][string]$HostPoolName,
    [parameter(mandatory = $true)][string]$WorkspaceName

)
Import-Module Az.OperationalInsights
Import-Module Az.DesktopVirtualization

#region configure Log Analytics Workspace
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
#endregion

# region install Log Analytics Agent on Virutal Machine 
$ResourceGroup = ($hostpool).id.split("/")[4]
$sessionhosts = Get-AzWvdSessionHost -HostpoolName  $HostpoolName -ResourceGroupName $ResourceGroup
$virtualMachines = @($sessionhosts.ResourceId.Split("/")[-1])
$workspaceKey = ($Workspace | Get-AzOperationalInsightsWorkspaceSharedKey).PrimarySharedKey
$TemplateParameters = @{
    workspaceId = $Workspace.CustomerId
    workspaceKey = $workspaceKey
    virtualMachines = $virtualMachines
    extensionNames = @("OMSExtenstion")
}
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -TemplateUri "https://raw.githubusercontent.com/srozemuller/Windows-Virtual-Desktop/master/Azure%20Monitor/deploy-lawsagent.json" -TemplateParameterObject $TemplateParameters
#endregion
