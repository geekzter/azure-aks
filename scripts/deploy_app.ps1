#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$false)][bool]$Deploy=$true,
    [parameter(Mandatory=$false)][bool]$Test=$true
)

. (Join-Path $PSScriptRoot functions.ps1)
$manifestsDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) manifests)

Get-Tools

try {
    ChangeTo-TerraformDirectory
    $aksName = (Get-TerraformOutput aks_name)
    #$resourceGroup = (Get-TerraformOutput resource_group)

    #az aks get-credentials --name $aksName --resource-group $resourceGroup -a --overwrite-existing

    $null = Prepare-KubeConfig -Workspace $(terraform workspace show)
    kubectl config use-context $aksName 2>&1

    # ILB Demo: https://docs.microsoft.com/en-us/azure/aks/internal-lb
    if ($Deploy) {
        Write-Host "`nDeploying Voting App..."
        kubectl apply -f (Join-Path $manifestsDirectory internal-vote.yaml) 2>&1
        if ($DebugPreference -ine "SilentlyContinue") {
            kubectl get service azure-vote-front 2>&1
        }
    }
    $ilbIPAddress = Get-LoadBalancerIPAddress -KubernetesService azure-vote-front

    # AGIC Demo: https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing#deploy-a-sample-application-using-agic
    $agicFQDN = (Get-TerraformOutput application_gateway_fqdn)
    if ($Deploy) {
        if ($agicFQDN) {
            Write-Host "`nDeploying ASP.NET App..."
            kubectl apply -f (Join-Path $manifestsDirectory aspnetapp.yaml) 2>&1
            if ($DebugPreference -ine "SilentlyContinue") {
                kubectl describe ingress aspnetapp 2>&1
                kubectl get ingress 2>&1
            }
        } else {
            Write-Warning "`nNo Application Gateway found. ASP.NET App will not be deployed."
        }
    }

    # Test after deployment, this should be faster
    if ($Test) {
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
    }
} finally {
    Pop-Location
}