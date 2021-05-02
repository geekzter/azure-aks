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
    $appGWState = (az network application-gateway show -n $ApplicationGatewayName -g $nodeResourceGroupName --query "provisioningState" -o tsv 2>$null)
    while ((-not $appGWState) -or ($appGWState -ieq "updating")) {
        Write-Host "Application Gateway ${ApplicationGatewayName} provisioning status is '${appGWState}'..."
        Start-Sleep -Seconds 10
        $appGWState = (az network application-gateway show -n $ApplicationGatewayName -g $nodeResourceGroupName --query "provisioningState" -o tsv 2>$null)
    } 
    Write-Host "Application Gateway ${ApplicationGatewayName} provisioning status is '${appGWState}'"
}

Wait-ApplicationGateway -AksName $AksName -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName
