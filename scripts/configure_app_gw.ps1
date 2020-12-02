#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$true)][string]$AksName,
    [parameter(Mandatory=$false)][string]$ApplicationGatewayName="${ResourceGroupName}-waf",
    [parameter(Mandatory=$true)][string]$ApplicationGatewaySubnetID,
    [parameter(Mandatory=$true)][string]$ResourceGroupName
)
. (Join-Path $PSScriptRoot functions.ps1)

function Get-AGICState() {
    return $(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-IngressApplicationGatewayAddon')].properties.state" -o tsv)    
}

Set-Environment

if ($ApplicationGatewayName -ieq $(az aks show -n $AksName -g $ResourceGroupName --query "addonProfiles.ingressApplicationGateway.config.applicationGatewayName" -o tsv)) {
    Write-Host "$ApplicationGatewayName is already configured as add on for $AksName"
    exit    
}

az extension add --name aks-preview 2>&1

$agicState = Get-AGICState
while ($agicState -ine "Registered") {
    az feature register --name AKS-IngressApplicationGatewayAddon --namespace Microsoft.ContainerService
    Write-Host "Registering feature Microsoft.ContainerService/AKS-IngressApplicationGatewayAddon, waiting 10 seconds..."
    Start-Sleep -Seconds 10
    $agicState = Get-AGICState
} 

az provider register --namespace Microsoft.ContainerService
az aks enable-addons -n $AksName -g $ResourceGroupName -a ingress-appgw --appgw-name $ApplicationGatewayName --appgw-subnet-id $ApplicationGatewaySubnetID
