
function ChangeTo-TerraformDirectory() {
    Push-Location (Get-TerraformDirectory)
}

function Get-Tools() {
    if (!(Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Warning "Azure CLI not found"
        exit
    }
    az extension add --name aks-preview 2>&1
    if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Information "kubectl not found, using Azure CLI to get it..."
        az aks install-cli
    }
}

function Get-LoadBalancerIPAddress(
    [parameter(Mandatory=$true)][string]$KubernetesService,
    [parameter(Mandatory=$false)][int]$MaxTests=600    
) {
    $ilb = (kubectl get service azure-vote-front -o=jsonpath='{.status.loadBalancer}' | ConvertFrom-Json)
    if (!$ilb) {
        Write-Warning "Could not find ILB for service $KubernetesService"
        exit
    }
    $tests = 0
    while ((!$ilb.ingress.ip) -and ($tests -le $MaxTests)) {
        $tests++
        Start-Sleep 1
        $ilb = (kubectl get service azure-vote-front -o=jsonpath='{.status.loadBalancer}' | ConvertFrom-Json)
    }
    if (!$ilb.ingress.ip) {
        Write-Warning "Could not obtain ILB external IP address for service $KubernetesService"
        exit
    }

    Write-Verbose "Get-LoadBalancerIPAddress: $($ilb.ingress.ip)"
    return $ilb.ingress.ip
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

function Test-App (
    [parameter(Mandatory=$true)][string]$AppUrl,
    [parameter(Mandatory=$false)][int]$MaxTests=600    
) {
    $test = 0
    Write-Host "Testing $AppUrl (max $MaxTests times)" -NoNewLine
    while (!$responseOK -and ($test -lt $MaxTests)) {
        try {
            $test++
            Write-Host "." -NoNewLine
            $homePageResponse = Invoke-WebRequest -UseBasicParsing -Uri $AppUrl
            if ($homePageResponse.StatusCode -lt 400) {
                $responseOK = $true
            } else {
                $responseOK = $false
            }
        }
        catch {
            $responseOK = $false
            if ($test -ge $MaxTests) {
                throw
            } else {
                Start-Sleep -Milliseconds 500
            }
        }
    }
    Write-Host "✓" # Force NewLine
    Write-Information "Request to $AppUrl completed with HTTP Status Code $($homePageResponse.StatusCode)"
}