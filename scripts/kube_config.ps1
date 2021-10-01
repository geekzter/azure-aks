#!/usr/bin/env pwsh
. (Join-Path $PSScriptRoot functions.ps1)

try {
    ChangeTo-TerraformDirectory
    if (Prepare-KubeConfig -Workspace $(terraform workspace show)) {
        kubectl config use-context (Get-TerraformOutput aks_name)
        kubectl config view
        kubectl cluster-info
        kubectl get nodes
    } else {
        Write-Warning "Terraform did not provision K8s yet" >2&1
    }
} finally {
    Pop-Location
}
