#!/usr/bin/env pwsh
. (Join-Path $PSScriptRoot functions.ps1)

Set-Environment

try {
    ChangeTo-TerraformDirectory

    kubectl config use-context (Get-TerraformOutput aks_name)
    kubectl config view
    kubectl cluster-info
    kubectl get nodes
    kubectl get ingress
} finally {
    Pop-Location
}
