#!/usr/bin/env pwsh

. (Join-Path $PSScriptRoot functions.ps1)
$manifestsDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) manifests)

Set-Environment

try {
    ChangeTo-TerraformDirectory

    kubectl config use-context $(terraform output aks_name)

    # AGIC Demo: https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#deploy-a-sample-application-using-agic
    kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml
    kubectl get ingress

    # ILB Demo: https://docs.microsoft.com/en-us/azure/aks/internal-lb
    kubectl apply -f (Join-Path $manifestsDirectory internal-vote.yaml)
    kubectl get service azure-vote-front --watch

} finally {
    Pop-Location
}

