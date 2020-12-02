
function ChangeTo-TerraformDirectory() {
    Push-Location (Get-TerraformDirectory)
}

function Get-TerraformDirectory() {
    return (Join-Path (Split-Path -parent -Path $MyInvocation.PSScriptRoot) "Terraform")
}

function Set-Environment() {
    $kubeConfig = (Join-Path (Split-Path -parent -Path $MyInvocation.PSScriptRoot) ".kube" "config")

    if (Test-Path $kubeConfig) {
        $env:KUBECONFIG=$kubeConfig
    } else {
        Write-Warning "$kubeConfig not found"
    }
}

function Start-Agents () {
    ChangeTo-TerraformDirectory

    $nodeResourceGroup = $(terraform output node_resource_group)
    if ($nodeResourceGroup) {
        $location = $(az group show -g $nodeResourceGroup --query location -o tsv)
        $vmssNames = $(az resource list -l $location -g $nodeResourceGroup --resource-type "Microsoft.Compute/virtualMachineScaleSets" --query "[].name" -o tsv)
        foreach ($vmssName in $vmssNames) {
            Write-Host "Starting nodes in scale set ${vmssName}..."
            az vmss start -n $vmssName -g $nodeResourceGroup
        }
    } else {
        Write-Host "No terraform output for node_resource_group"
    }

    Pop-Location
}