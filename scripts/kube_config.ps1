#!/usr/bin/env pwsh
. (Join-Path $PSScriptRoot functions.ps1)

try {
    ChangeTo-TerraformDirectory
    if (Prepare-KubeConfig -Workspace $(terraform workspace show)) {
        kubectl config use-context (Get-TerraformOutput aks_name)
        kubectl config view
        kubectl cluster-info
        kubectl get nodes
        kubectl get ingress
    } else {
        Write-Warning "Terraform did not provision K8s yet"
    }
} finally {
    Pop-Location
}
