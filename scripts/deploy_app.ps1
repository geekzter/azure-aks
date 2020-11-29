#!/usr/bin/env pwsh

. (Join-Path $PSScriptRoot functions.ps1)

Set-Environment

try {
    ChangeTo-TerraformDirectory

    kubectl config use-context $(terraform output aks_name)

    # ILB Demo: https://docs.microsoft.com/en-us/azure/aks/internal-lb
    # kubectl apply -f ../manifests/internal-vote.yaml
    # kubectl get service azure-vote-front --watch

    # AGIC Demo: https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#deploy-a-sample-application-using-agic
    # kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml
    # kubectl get ingress
} finally {
    Pop-Location
}

