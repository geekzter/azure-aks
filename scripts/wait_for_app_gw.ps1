#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$true)][string]$AksName,
    [parameter(Mandatory=$false)][string]$ApplicationGatewayName="applicationgateway",
    [parameter(Mandatory=$true)][string]$ResourceGroupName
    )
. (Join-Path $PSScriptRoot functions.ps1)

function Wait-ApplicationGateway(
    [parameter(Mandatory=$true)][string]$AksName,
    [parameter(Mandatory=$true)][string]$ApplicationGatewayName,
    [parameter(Mandatory=$true)][string]$ResourceGroupName
) {
    $nodeResourceGroupName = $(az aks show -n $AksName -g $ResourceGroupName --query nodeResourceGroup -o tsv)

    Write-Host "Waiting for Application Gateway ${ApplicationGatewayName} to finish updating..."
    do {
        Start-Sleep -Milliseconds 500
        $appGWState = (az network application-gateway show -n $ApplicationGatewayName -g $nodeResourceGroupName --query "provisioningState" -o tsv 2>$null)
        Write-Verbose "Application Gateway ${ApplicationGatewayName} provisioning status is ${appGWState}"
    } while ((-not $appGWState) -or ($appGWState -ieq "updating"))
    Write-Host "Application Gateway ${ApplicationGatewayName} provisioning status is ${appGWState}"

    $applicationGatewayIpAddressName = "${ApplicationGatewayName}-appgwpip"
    az network public-ip show -n $applicationGatewayIpAddressName -g $nodeResourceGroupName -o json
}

az extension add --name aks-preview 2>$null

if ($ApplicationGatewayName -ieq $(az aks show -n $AksName -g $ResourceGroupName --query "addonProfiles.ingressApplicationGateway.config.applicationGatewayName" -o tsv)) {
    Wait-ApplicationGateway -AksName $AksName -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName
    Write-Host "$ApplicationGatewayName is already configured as add on for $AksName"
    exit    
}

Wait-ApplicationGateway -AksName $AksName -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName
