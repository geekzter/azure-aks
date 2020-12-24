#!/usr/bin/env pwsh

. (Join-Path $PSScriptRoot functions.ps1)
$manifestsDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) manifests)

Get-Tools

try {
    ChangeTo-TerraformDirectory
    Prepare-KubeConfig

    kubectl config use-context (Get-TerraformOutput aks_name)

    # ILB Demo: https://docs.microsoft.com/en-us/azure/aks/internal-lb
    $ilbIPAddress = (Get-TerraformOutput internal_load_balancer_ip_address)
    if ($ilbIPAddress) {
        Write-Host "`nDeploying Voting App..."
        kubectl apply -f (Join-Path $manifestsDirectory internal-vote.yaml)
        kubectl get service azure-vote-front #--watch
        $ilbIPAddress = Get-LoadBalancerIPAddress -KubernetesService azure-vote-front
    }

    # AGIC Demo: https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#deploy-a-sample-application-using-agic
    $agicIPAddress = (Get-TerraformOutput application_gateway_public_ip)
    if ($agicIPAddress) {
        Write-Host "`nDeploying ASP.NET App..."
        kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml
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
    if ($agicIPAddress) {
        $agicUrl = "http://${agicIPAddress}/"
        Test-App $agicUrl
    } else {
        Write-Warning "Application Gateway Ingress Controller not found"
    }
} finally {
    Pop-Location
}

