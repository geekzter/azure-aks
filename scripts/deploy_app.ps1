#!/usr/bin/env pwsh

. (Join-Path $PSScriptRoot functions.ps1)

Set-Environment

try {
    ChangeTo-TerraformDirectory

    kubectl config use-context $(terraform output aks_name)
    kubectl apply -f internal-vote.yaml
} finally {
    Pop-Location
}

