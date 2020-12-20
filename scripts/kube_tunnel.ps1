#!/usr/bin/env pwsh
. (Join-Path $PSScriptRoot functions.ps1)

Set-Environment

try {
    ChangeTo-TerraformDirectory

    kubectl config use-context (Get-TerraformOutput aks_name)

    # Open SSH tunnel for local portal on 127.0.0.1:8001
    Get-Job | Where-Object {$_.Command.Contains("kubectl proxy")} | Stop-Job
    kubectl proxy &
    #az aks browse --resource-group (Get-TerraformOutput resource_group) --name (Get-TerraformOutput aks_name)

    # Wait for agent nodes to have started
    Start-Agents

    Write-Host "Open Kubernetes Dashboard at http://127.0.0.1:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy"
} finally {
    Pop-Location
}


