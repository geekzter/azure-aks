function AzLogin (
    [parameter(Mandatory=$false)][switch]$DisplayMessages=$false
) {
    # Are we logged into the wrong tenant?
    Invoke-Command -ScriptBlock {
        $Private:ErrorActionPreference = "Continue"
        if ($env:ARM_TENANT_ID) {
            $script:loggedInTenantId = $(az account show --query tenantId -o tsv 2>$null)
        }
    }
    if ($loggedInTenantId -and ($loggedInTenantId -ine $env:ARM_TENANT_ID)) {
        Write-Warning "Logged into tenant $loggedInTenantId instead of $env:ARM_TENANT_ID (`$env:ARM_TENANT_ID), logging off az session"
        az logout -o none
    }

    # Are we logged in?
    Invoke-Command -ScriptBlock {
        $Private:ErrorActionPreference = "Continue"
        # Test whether we are logged in
        $script:loginError = $(az account show -o none 2>&1)
        if (!$loginError) {
            $Script:userType = $(az account show --query "user.type" -o tsv)
            if ($userType -ieq "user") {
                # Test whether credentials have expired
                $Script:userError = $(az ad signed-in-user show -o none 2>&1)
            } 
        }
    }
    $login = ($loginError -or $userError)
    # Set Azure CLI context
    if ($login) {
        if ($env:ARM_TENANT_ID) {
            az login -t $env:ARM_TENANT_ID -o none
        } else {
            az login -o none
        }
    }

    if ($DisplayMessages) {
        if ($env:ARM_SUBSCRIPTION_ID -or ($(az account list --query "length([])" -o tsv) -eq 1)) {
            Write-Host "Using subscription '$(az account show --query "name" -o tsv)'"
        } else {
            if ($env:TF_IN_AUTOMATION -ine "true") {
                # Active subscription may not be the desired one, prompt the user to select one
                $subscriptions = (az account list --query "sort_by([].{id:id, name:name},&name)" -o json | ConvertFrom-Json) 
                $index = 0
                $subscriptions | Format-Table -Property @{name="index";expression={$script:index;$script:index+=1}}, id, name
                Write-Host "Set `$env:ARM_SUBSCRIPTION_ID to the id of the subscription you want to use to prevent this prompt" -NoNewline

                do {
                    Write-Host "`nEnter the index # of the subscription you want Terraform to use: " -ForegroundColor Cyan -NoNewline
                    $occurrence = Read-Host
                } while (($occurrence -notmatch "^\d+$") -or ($occurrence -lt 1) -or ($occurrence -gt $subscriptions.Length))
                $env:ARM_SUBSCRIPTION_ID = $subscriptions[$occurrence-1].id
            
                Write-Host "Using subscription '$($subscriptions[$occurrence-1].name)'" -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            } else {
                Write-Host "Using subscription '$(az account show --query "name" -o tsv)', set `$env:ARM_SUBSCRIPTION_ID if you want to use another one"
            }
        }
    }

    if ($env:ARM_SUBSCRIPTION_ID) {
        az account set -s $env:ARM_SUBSCRIPTION_ID -o none
    }

    # Populate Terraform azurerm variables where possible
    if ($userType -ine "user") {
        # Pass on pipeline service principal credentials to Terraform
        $env:ARM_CLIENT_ID       ??= $env:servicePrincipalId
        $env:ARM_CLIENT_SECRET   ??= $env:servicePrincipalKey
        $env:ARM_TENANT_ID       ??= $env:tenantId
        # Get from Azure CLI context
        $env:ARM_TENANT_ID       ??= $(az account show --query tenantId -o tsv)
        $env:ARM_SUBSCRIPTION_ID ??= $(az account show --query id -o tsv)
    }
    # Variables for Terraform azurerm Storage backend
    if (!$env:ARM_ACCESS_KEY -and !$env:ARM_SAS_TOKEN) {
        if ($env:TF_VAR_backend_storage_account -and $env:TF_VAR_backend_storage_container) {
            $env:ARM_SAS_TOKEN=$(az storage container generate-sas -n $env:TF_VAR_backend_storage_container --as-user --auth-mode login --account-name $env:TF_VAR_backend_storage_account --permissions acdlrw --expiry (Get-Date).AddDays(7).ToString("yyyy-MM-dd") -o tsv)
        }
    }
}

function ChangeTo-TerraformDirectory() {
    Push-Location (Get-TerraformDirectory)
}

function Get-Tools() {
    if (!(Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Warning "Azure CLI not found"
        exit
    }
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
    return (Join-Path (Split-Path -parent -Path $MyInvocation.PSScriptRoot) "terraform")
}

function Get-TerraformOutput (
    [parameter(Mandatory=$true)][string]$OutputVariable
) {
    Invoke-Command -ScriptBlock {
        $Private:ErrorActionPreference    = "SilentlyContinue"
        Write-Verbose "terraform output ${OutputVariable}: evaluating..."
        $result = $(terraform output -raw $OutputVariable 2>$null)
        if ($result -match "\[\d+m") {
            # Terraform warning, return null for missing output
            Write-Verbose "terraform output ${OutputVariable}: `$null (${result})"
            return $null
        } else {
            Write-Verbose "terraform output ${OutputVariable}: ${result}"
            return $result
        }
    }
}

function Get-TerraformWorkspace () {
    Push-Location (Get-TerraformDirectory)
    try {
        return $(terraform workspace show)
    } finally {
        Pop-Location
    }
}

function Invoke (
    [string]$cmd
) {
    Write-Host "`n$cmd" -ForegroundColor Green 
    Invoke-Expression $cmd
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Warning "'$cmd' exited with status $exitCode"
        exit $exitCode
    }
}

function Prepare-KubeConfig(
    [parameter(Mandatory=$true)][string]$Workspace    
) {
    $kubeConfig = (Get-TerraformOutput kube_config)

    if ($kubeConfig) {
        # Make sure the local file exists, terraform apply may have run on another host
        $kubeConfigMoniker = ($Workspace -eq "default") ? "" : $Workspace 
        $kubeConfigDirectory = (Join-Path $PSScriptRoot ".." .kube)
        $null = New-Item -ItemType Directory -Force -Path $kubeConfigDirectory 
        $kubeConfigFile = (Join-Path $kubeConfigDirectory "${kubeConfigMoniker}config")
        Set-Content -Path $kubeConfigFile -Value $kubeConfig 
        $env:KUBECONFIG = $kubeConfigFile
        Write-Host "Prepared ${kubeConfigFile}"
        return $kubeConfigFile
    }
}

function Set-PipelineVariablesFromTerraform () {
    $json = terraform output -json | ConvertFrom-Json -AsHashtable
    foreach ($outputVariable in $json.keys) {
        $value = $json[$outputVariable].value
        if ($value) {
            # Write variable output in the format a Pipeline can understand
            # https://github.com/Microsoft/azure-pipelines-agent/blob/master/docs/preview/outputvariable.md
            Write-Host "##vso[task.setvariable variable=${outputVariable};isOutput=true]${value}"
        }
    }
}

function Start-Agents () {
    ChangeTo-TerraformDirectory

    $nodeResourceGroup = (Get-TerraformOutput node_resource_group)
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
                Start-Sleep -Milliseconds 1000
            }
        }
    }
    Write-Host "✓" # Force NewLine
    Write-Information "Request to $AppUrl completed with HTTP Status Code $($homePageResponse.StatusCode)"
}