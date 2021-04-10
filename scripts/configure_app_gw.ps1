#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$true)][string]$AksName,
    [parameter(Mandatory=$false)][string]$ApplicationGatewayName="${ResourceGroupName}-waf",
    [parameter(Mandatory=$true)][string]$ApplicationGatewaySubnetID,
    [parameter(Mandatory=$true)][string]$ResourceGroupName,
    [parameter(Mandatory=$false)][switch]$NoWait,
    [parameter(Mandatory=$false)][switch]$RemoveIfExists
)
. (Join-Path $PSScriptRoot functions.ps1)

function Get-AGICState() {
    return $(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-IngressApplicationGatewayAddon')].properties.state" -o tsv)    
}
function Wait-ApplicationGateway(
    [parameter(Mandatory=$true)][string]$AksName,
    [parameter(Mandatory=$true)][string]$ApplicationGatewayName,
    [parameter(Mandatory=$true)][string]$ResourceGroupName
) {
    $nodeResourceGroupName = $(az aks show -n $AksName -g $ResourceGroupName --query nodeResourceGroup -o tsv)

    do {
        $waf = (az network application-gateway show -n $ApplicationGatewayName -g $nodeResourceGroupName -o table 2>$null)
    } while (!$waf)
    $waf

    $applicationGatewayIpAddressName = "${ApplicationGatewayName}-appgwpip"
    az network public-ip show -n $applicationGatewayIpAddressName -g $nodeResourceGroupName -o table
}
                                                                                                                                                                                                                                                     b
az extension add --name aks-preview 2>&1

if ($ApplicationGatewayName -ieq $(az aks show -n $AksName -g $ResourceGroupName --query "addonProfiles.ingressApplicationGateway.config.applicationGatewayName" -o tsv)) {
    if ($RemoveIfExists) {
        Write-Host "Removing Application Gateway Ingress Controller Add On from '$AksName'..."
        az aks disable-addons -n $AksName -g $ResourceGroupName -a ingress-appgw
    } else {
        if (!$NoWait) {
            Wait-ApplicationGateway -AksName $AksName -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName
        }
        Write-Host "$ApplicationGatewayName is already configured as add on for $AksName"
        exit    
    }
}

$agicState = Get-AGICState
while ($agicState -ine "Registered") {
    az feature register --name AKS-IngressApplicationGatewayAddon --namespace Microsoft.ContainerService
    Write-Host "Registering feature Microsoft.ContainerService/AKS-IngressApplicationGatewayAddon, waiting 10 seconds..."
    Start-Sleep -Seconds 10
    $agicState = Get-AGICState
} 

az provider register --namespace Microsoft.ContainerService
Write-Host "Adding Application Gateway Ingress Controller Add On to '$AksName'..."
az aks enable-addons -n $AksName -g $ResourceGroupName -a ingress-appgw --appgw-name $ApplicationGatewayName --appgw-subnet-id $ApplicationGatewaySubnetID --query addonProfiles $($NoWait ? "--no-wait" : $null)


if (!$NoWait) {
    # BUG: IP address data source not available in Terraform after completion
    Wait-ApplicationGateway -AksName $AksName -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName
}
