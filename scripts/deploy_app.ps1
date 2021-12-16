#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$true)][bool]$Deploy=$true,
    [parameter(Mandatory=$true)][bool]$Test=$true
)

. (Join-Path $PSScriptRoot functions.ps1)
$manifestsDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) manifests)

Get-Tools

try {
    ChangeTo-TerraformDirectory
    $aksName = (Get-TerraformOutput aks_name)
    #$resourceGroup = (Get-TerraformOutput resource_group)

    #az aks get-credentials --name $aksName --resource-group $resourceGroup -a --overwrite-existing

    Prepare-KubeConfig -Workspace $(terraform workspace show)
    kubectl config use-context $aksName

    # ILB Demo: https://docs.microsoft.com/en-us/azure/aks/internal-lb
    if ($Deploy) {
        Write-Host "`nDeploying Voting App..."
        kubectl apply -f (Join-Path $manifestsDirectory internal-vote.yaml)
        kubectl get service azure-vote-front #--watch
    }
    $ilbIPAddress = Get-LoadBalancerIPAddress -KubernetesService azure-vote-front

    # AGIC Demo: https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#deploy-a-sample-application-using-agic
    $agicFQDN = (Get-TerraformOutput application_gateway_fqdn)
    if ($agicFQDN -and $Deploy) {
        Write-Host "`nDeploying ASP.NET App..."
        kubectl apply -f (Join-Path $manifestsDirectory aspnetapp.yaml)
        kubectl describe ingress aspnetapp
        kubectl get ingress
    }

    # Test after deployment, this should be faster
    if ($ilbIPAddress) {
        $ilbUrl = "http://${ilbIPAddress}/"
        Test-App $ilbUrl
    } else {
        Write-Warning "Internal Load Balancer not found"
    }
    if ($agicFQDN) {
        $agicUrl = "http://${agicFQDN}/"
        Test-App $agicUrl
    } else {
        Write-Warning "Application Gateway Ingress Controller not found"
    }
} finally {
    Pop-Location
}