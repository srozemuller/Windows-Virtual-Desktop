param(
    [parameter(mandatory = $false)][string]$EventsTemplate,
    [parameter(mandatory = $false)][string]$CountersTemplate,
    [parameter(mandatory = $true)][string]$ResourceGroup,
    [parameter(mandatory = $true)][string]$Location,
    [parameter(mandatory = $true)][string]$WorkspaceName

)
Import-Module Az.OperationalInsights

if ($null -eq $WorkspaceName) {
    Write-Host "No Log Analytics Workspace name provided, creating new Workspace"
    $WorkspaceName = "log-analytics-wvd-" + (Get-Random -Maximum 99999) # workspace names need to be unique across all Azure subscriptions - Get-Random helps with this for the example code

    # Create the workspace
    New-AzOperationalInsightsWorkspace -Location $Location -Name $WorkspaceName -Sku Standard -ResourceGroupName $ResourceGroup
}
Write-Host "Created workspace $WorkspaceName"

$WindowsEvents = Get-Content $EventsTemplate | ConvertFrom-Json
$PerformanceCounters = Get-Content $CountersTemplate | ConvertFrom-Json

function Get-CorrectEventLevels($EventLevels) {
    $CollectInformation, $collectWarnings, $collectErrors = $false
    if (($WindowsEventLog.EventTypes).Contains("Information")) { $CollectInformation = $true }
    if (($WindowsEventLog.EventTypes).Contains("Warning")) { $collectWarnings = $true }
    if (($WindowsEventLog.EventTypes).Contains("Error")) { $collectErrors = $true }
    $eventLevels = @{
        collectInformation = $CollectInformation
        collectWarnings    = $collectWarnings
        collectErrors      = $collectErrors
    }
    $eventLevels
}
# A slash (/) is not allowed in an object name, converting it if needed.
function Make-NameAzureFriendly($Name) {
    if (($Counter.name).Contains("/") ) { $name = $Counter.name.Replace("/", "-") }
    else { $name = $Counter.name }
    return $name
}

If ($EventsTemplate) {
    foreach ($WindowsEventLog in $WindowsEvents.WindowsEvent.EventLogNames) {
        $Level = Get-CorrectEventLevels -EventLevels $WindowsEventLog.EventTypes
        $Name = Make-NameAzureFriendly -Name $WindowsEventLog.Value
        # Windows Event
        New-AzOperationalInsightsWindowsEventDataSource -ResourceGroupName $ResourceGroup -WorkspaceName $WorkspaceName -EventLogName $WindowsEventLog.Value -Name $Name @Level
    }
}

If ($CountersTemplate) {
    foreach ($CounterObject in $PerformanceCounters.WindowsPerformanceCounter) {
        $CounterObject
        foreach ($Counter in $CounterObject.Counters) {
            $Name = Make-NameAzureFriendly -Name $Counter.name
            $Parameters = @{
                ObjectName      = $CounterObject.Object
                InstanceName    = $Counter.InstanceName
                CounterName     = $Counter.CounterName
                IntervalSeconds = $Counter.IntervalSeconds
                Name            = $Name
            }
            $Parameters
            New-AzOperationalInsightsWindowsPerformanceCounterDataSource -ResourceGroupName $ResourceGroup -WorkspaceName $WorkspaceName @parameters
        }
    }
}
