#!/usr/bin/env pwsh

param(
    [parameter(Mandatory=$false)][string]$workspace
)

New-Item -ItemType Directory -Force -Path ~/.kube > $null

Push-Location (Join-Path (Get-Item (Split-Path -parent -Path $MyInvocation.MyCommand.Path)).Parent.FullName "Terraform")

$currentWorkspace = $(terraform workspace list | Select-String -Pattern \* | %{$_ -Replace ".* ",""} 2> $null)

try 
{
    if ($workspace)
    {
        terraform workspace select $workspace
    }
    terraform output kube_config > ~/.kube/config

    #az aks get-credentials -n $(terraform output aks_name) -g $(terraform output resource_group) #--subscription $env:ARM_SUBSCRIPTION_ID

    kubectl config use-context $(terraform output aks_name)

    kubectl cluster-info
    kubectl get nodes
    Write-Output "Tiller pod(s):"
    kubectl get pods --all-namespaces | Select-String -Pattern tiller
}
finally
{
    # Ensure this always runs
    if ($currentWorkspace)
    {
        terraform workspace select $currentWorkspace
    }
}

Pop-Location