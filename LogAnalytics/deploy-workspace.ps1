param(
    [parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,
    
    [parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName

)
Import-Module Az.OperationalInsights

if ($null -eq $WorkspaceName) {
    Write-Host "No Log Analytics Workspace name provided, creating new Workspace"
    $WorkspaceName = "log-analytics-wvd-" + (Get-Random -Maximum 99999) # workspace names need to be unique across all Azure subscriptions - Get-Random helps with this for the example code
    # Create the workspace
    New-AzOperationalInsightsWorkspace -Location $Location -Name $WorkspaceName -Sku Standard -ResourceGroupName $ResourceGroup
    Write-Host "Created workspace $WorkspaceName"
}
else {
    $WorkspaceName = Get-AzOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $ResourceGroup
}
