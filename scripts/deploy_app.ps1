#!/usr/bin/env pwsh

. (Join-Path $PSScriptRoot functions.ps1)
$manifestsDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) manifests)

Set-Environment

try {
    ChangeTo-TerraformDirectory

    kubectl config use-context $(terraform output aks_name)

    # ILB Demo: https://docs.microsoft.com/en-us/azure/aks/internal-lb
    $ilbIPAddress = $(terraform output internal_load_balancer_ip_address)
    if ($ilbIPAddress) {
        Write-Host "`nDeploying Voting App..."
        kubectl apply -f (Join-Path $manifestsDirectory internal-vote.yaml)
        kubectl get service azure-vote-front #--watch
        $ilbIPAddress = Get-LoadBalancerIPAddress -KubernetesService azure-vote-front

        if ($ilbIPAddress) {
            $ilbUrl = "http://${ilbIPAddress}/"
            Test-App $ilbUrl
        } else {
            Write-Warning "Internal Load Balancer not found for service azure-vote-front"
        }
    } else {
        Write-Warning "Internal Load Balancer not found"
    }

    # AGIC Demo: https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#deploy-a-sample-application-using-agic
    $agicIPAddress = $(terraform output application_gateway_public_ip)
    if ($agicIPAddress) {
        Write-Host "`nDeploying ASP.NET App..."
        kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml
        kubectl describe ingress aspnetapp
        kubectl get ingress

        $agicUrl = "http://${agicIPAddress}/"
        Test-App $agicUrl
    } else {
        Write-Warning "Application Gateway Ingress Controller not found"
    }

} finally {
    Pop-Location
}

