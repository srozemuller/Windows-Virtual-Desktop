function Set-WvdSessionhostDrainMode {
    <#
    .SYNOPSIS
    Updates sessionhosts for accepting or denying connections.
    .DESCRIPTION
    The function will update sessionhosts drainmode to true or false. This can be one sessionhost or all of them.
    .PARAMETER HostpoolName
    Enter the WVD Hostpool name
    .PARAMETER ResourceGroupName
    Enter the WVD Hostpool resourcegroup name
    .PARAMETER SessionHostName
    Enter the sessionhosts name
    .PARAMETER AllowNewSession
    Enter $true or $false. Default is $true
    .PARAMETER Scope
    Enter All or NotLatest. NotLatest will only sets drainmode on sessionhosts which has an old SIG version.
    Default is All
    .EXAMPLE
    Set-WvdSessionhostDrainMode -HostpoolName wvd-hostpool-personal -ResourceGroupName rg-wvd-01 -SessionHostName wvd-host-1.wvd.domain -AllowNewSession $true 
    .EXAMPLE
    $sessionhosts | Set-WvdSessionhostDrainMode -AllowNewSession $false -Scope All
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [pscustomobject]$InputObject,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$HostpoolName,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [parameter(Mandatory, ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string]$SessionHostName,

        [parameter()]
        [ValidateNotNullOrEmpty()]
        [boolean]$AllowNewSession = $true,

        [parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("All", "NotLatest")]
        [String]$Scope = "All"
             
    )
    Begin {
        Write-Verbose "Start searching"
        precheck
    }
    Process {
        switch ($PsCmdlet.ParameterSetName) {
            InputObject {
                $HostpoolName = $InputObject.Name.Split("/")[0]
                $ResourceGroupName = $InputObject.id.split("/")[4]
                $Name = $InputObject.Name.Split("/")[1]
            }
            Default {
                Update-AzWvdSessionHost -HostPoolName $HostpoolName -ResourceGroupName $ResourceGroupName -Name $SessionHostName -AllowNewSession:$AllowNewSession
            }
        }
        if ($PSBoundParameters.ContainsKey('InputObject') -and $Scope -eq 'All') {
            foreach ($object in $InputObject) {
                $HostpoolName = $object.Name.Split("/")[0]
                $ResourceGroupName = $object.id.split("/")[4]
                $Name = $object.Name.Split("/")[1]
                Update-AzWvdSessionHost -HostPoolName $HostpoolName -ResourceGroupName $ResourceGroupName -Name $Name -AllowNewSession:$AllowNewSession
            }
        }
        else {
            $NotLatest = $InputObject | Get-WvdImageVersionStatus | Where-Object {$_.NotLatest -eq $true}
            foreach ($object in $NotLatest) {
                $HostpoolName = $object.Name.Split("/")[0]
                $ResourceGroupName = $object.id.split("/")[4]
                $Name = $object.Name.Split("/")[1]
                Update-AzWvdSessionHost -HostPoolName $HostpoolName -ResourceGroupName $ResourceGroupName -Name $Name -AllowNewSession:$AllowNewSession
            }
    }
    End { 
        Write-Verbose "All host objects updated" 
    }
}