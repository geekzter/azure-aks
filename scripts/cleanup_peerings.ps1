#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Clean up VNet peerings
#> 
#Requires -Version 7.2
param ( 
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $AgentNetworkId=$env:PIPELINE_DEMO_AGENT_VIRTUAL_NETWORK_ID,
    
    [parameter(Mandatory=$false)]
    [string[]]
    $Workspace=$env:TF_WORKSPACE ?? "default"
)

# az network vnet peering list doesn't support '--ids', peal of elements manually
$agentNetworkName       = ($AgentNetworkId -split "/")[-1]
if (!$agentNetworkName) {
    Write-Error "AgentNetworkId is not a valid virtual network resource id: '${AgentNetworkId}'"
    exit
}
$agentResourceGroupName = ($AgentNetworkId -split "/")[4]
$agentSubscriptionId    = ($AgentNetworkId -split "/")[2]

$jmesPathQuery = "ends_with(name,'from-peer') "
if ($Workspace) {
    $jmesPathQuery += " && ("
    $firstWorkspace = $true
    foreach ($individualWorkspace in $Workspace) {
        if (!$firstWorkspace) {
            $jmesPathQuery += " || "
        }
        $jmesPathQuery += " contains(name, 'aks-${individualWorkspace}-') "
        $firstWorkspace = $false
    }    
    $jmesPathQuery += ") "
}
Write-Debug "jmesPathQuery: $jmesPathQuery"

az network vnet peering list -g $agentResourceGroupName `
                             --vnet-name $agentNetworkName `
                             --subscription $agentSubscriptionId `
                             --query "[?${jmesPathQuery}].name" `
                             -o tsv `
                             | Set-Variable peeringNames
Write-Debug "peerings: $peeringNames"

if ($peeringNames) {
    foreach ($peeringName in $peeringNames) {
        Write-Verbose "az network vnet peering delete -g $agentResourceGroupName --vnet-name $agentNetworkName -n $peeringName --subscription $agentSubscriptionId"
        az network vnet peering delete -g $agentResourceGroupName `
                                       --vnet-name $agentNetworkName `
                                       -n $peeringName `
                                       --subscription $agentSubscriptionId
    }
} else {
    Write-Host "No virtual network peerings to remove for workspace '${Workspace}' in network '${AgentNetworkId}'"
}
