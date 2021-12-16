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
    $intervalSeconds = 10
    $timeoutSeconds = 300

    Write-Host "Waiting for AKS to finish provisioning..."
    az aks wait -g $ResourceGroupName -n $AksName --created --updated --interval $intervalSeconds --timeout $timeoutSeconds

    $nodeResourceGroupName = $(az aks show -n $AksName -g $ResourceGroupName --query nodeResourceGroup -o tsv)

    Write-Host "Waiting for Application Gateway ${ApplicationGatewayName} to finish updating..."
    az network application-gateway wait -g $nodeResourceGroupName -n $ApplicationGatewayName --created --updated --interval $intervalSeconds --timeout $timeoutSeconds
}

Wait-ApplicationGateway -AksName $AksName -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName
