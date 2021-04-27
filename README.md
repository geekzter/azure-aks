# Network Isolated AKS

[![Build Status](https://dev.azure.com/ericvan/VDC/_apis/build/status/azure-aks-ci?branchName=main)](https://dev.azure.com/ericvan/VDC/_build/latest?definitionId=85&branchName=main)

This repo lets you provision a network isolated Azure Kubernetes Service, customizing egress, ingress with both Internal Load Balancer and Application Gateway, and the Kubernetes API Server (AKS management nodes) connected via Private Link. It uses Terraform as that can create all the Azure AD, Azure and Kubernetes resources required.
 
## Description
![alt text](visuals/diagram.png "Network view")

When you create an Azure Kubernetes Service (AKS) in the Azure Portal, or with the Azure CLI, by default it will be open in the sense of traffic (both application & management) using public IP addresses. This is a challenge in Enterprise, especially in regulated industries. Effort is needed to embed services in Virtual Networks, and in the case of AKS there are quite a few moving parts to consider.

To constrain connectivity to/from an AKS cluster, the following available measures are implemented in this repo:

1. The Kubernetes API server is the entry point for Kubernetes management operations, and is hosted as a multi-tenant PaaS service by Microsoft. The API server can be projected in the Virtual Network using Private Link ([article](https://docs.microsoft.com/en-us/azure/aks/private-clusters))
1. Instead of an external Load Balancer (with a public IP address), use an internal Load Balancer ([article](https://docs.microsoft.com/en-us/azure/aks/internal-lb))
1. Use user defined routes and an Azure Firewall to manage egress, instead of breaking out to the Internet directly ([article](https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#restrict-egress-traffic-using-azure-firewall))
1. Application Gateway can be used to manage ingress traffic. There are multiple ways to set this up, by far the simplest is to use the AKS add on. This lets AKS create the Application Gateway and maintain it's configuration ([article](https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing))   

Note 2. and 4. are overlapping, you only need one of both.

### AKS Networking modes
AKS supports two networking 'modes'. These modes control the IP address allocation of the agent nodes in the cluster. In short: 
- [kubenet](https://docs.microsoft.com/en-us/azure/aks/configure-kubenet) creates IP addresses in a different address space, and uses NAT (network address translation) to expose the agents. This is where the Kubernetes term 'external IP' comes from, this is a private IP address known to the rest of the network. 
- [Azure CNI](https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni) uses the same address space for agents as the rest of the virtual network.
See [comparison](https://docs.microsoft.com/en-us/azure/aks/concepts-network#compare-network-models)

I won't go into detail of these modes, as the network mode is __irrelevant__ for the isolation meassures you need to take. Choosing one over the other does not make a major difference for network isolation. This deployment has been [tested](https://dev.azure.com/ericvan/VDC/_build/latest?definitionId=85&branchName=main) with Azure CNI.

## Pre-requisites
### Tools
- To get started you need [Git](https://git-scm.com/), [Terraform](https://www.terraform.io/downloads.html) (to get that you can use [tfenv](https://github.com/tfutils/tfenv) on Linux & macOS, [Homebrew](https://github.com/hashicorp/homebrew-tap) on macOS or [chocolatey](https://chocolatey.org/packages/terraform) on Windows)
- The AKS add on is configured through [PowerShell](https://github.com/PowerShell/PowerShell#get-powershell), as there is no native Terraform support yet.
- Application deployment requires [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

If you're on macOS, you can run `brew bundle` in the repo root to get the required tools, as there is a `Brewfile`. 

### Connectivity
As this provisions an isolated AKS, how will you be able to access the AKS cluster once deployed? If you set the `peer_network_id` Terraform variable to a network where you're running Terraform from (or you are connected to e.g. using VPN), this project will set up the peering and Private DNS link required to look up the Kubernetes API Server and access cluster nodes. Without this you can only perform partial deployment, you won't be able to deploy applications.   
Example connectivity scenarios:
- The [pipeline](pipelines/azure-aks-ci.yml) in this repository uses a [Scale Set Agent pool](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops) deployed into a virtual network by [geekzter/azure-pipeline-agents](https://github.com/geekzter/azure-pipeline-agents)
- You can use [geekzter/azure-devenv](https://github.com/geekzter/azure-devenv) to create a fully prepped development VM in a VNet, and deploy from there

## Provisioning
1. Clone repository:  
`git clone https://github.com/geekzter/azure-aks.git`  

1. Change to the [`terraform`](./terraform) directrory  
`cd azure-aks/terraform`

1. Login to Azure with Azure CLI:  
`az login`   

1. This also authenticates the Terraform [azuread](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/guides/azure_cli) and [azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) providers. Optionally, you can select the subscription to target:  
`az account set --subscription 00000000-0000-0000-0000-000000000000`   
`ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)` (bash, zsh)   
`$env:ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)` (pwsh)   

1. You can then provision resources by first initializing Terraform:   
`terraform init`  

1. And then running:  
`terraform apply`

1. Demo applications are deployed with the following script:  
`scripts/deploy_app.ps1`
This script will output the url's used by the demo applications. One application is exposed via Application Gateway and is publically accessible, the other over the internal Load Balancer.

Once deployed the applications will look like this:

Internal Load Balancer: Voting App  |Application Gateway: ASP.NET App
:----------------:|:-----------------:
![](visuals/votingapp.png)|![](visuals/aspnetapp.png)


### Clean Up
When you want to destroy resources, run:   
`terraform destroy`


## Resources
- [Azure Kubernetes Service checklist](https://www.the-aks-checklist.com/)
- [Baseline architecture for an Azure Kubernetes Service (AKS) cluster](https://aka.ms/architecture/aks-baseline)
- [Enterprise-Scale Construction Set for Azure Kubernetes Services using Terraform](https://github.com/Azure/caf-terraform-landingzones-starter/tree/starter/enterprise_scale/construction_sets/aks/online/aks_secure_baseline)