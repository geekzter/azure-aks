#!/usr/bin/env pwsh
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) functions.ps1)

Set-Environment

try {
    ChangeTo-TerraformDirectory

    kubectl config use-context $(terraform output aks_name)
    kubectl config view
    kubectl cluster-info
    kubectl get nodes
} finally {
    Pop-Location
}
