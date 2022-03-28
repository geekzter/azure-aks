terraform {
  required_providers {
    azuread                    = "~> 2.12"
    azurerm                    = "~> 2.99"
    external                   = "~> 2.1"
    helm                       = "~> 2.0"
    http                       = "~> 2.1"
    kubernetes                 = "~> 2.0"
    local                      = "~> 2.1"
    null                       = "~> 3.1"
    random                     = "~> 3.1"
    time                       = "~> 0.7"
  }
  required_version             = "~> 1.0"
}

# Microsoft Azure Resource Manager Provider
# This provider block uses the following environment variables: 
# ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET and ARM_TENANT_ID
provider azurerm {
  features {
    virtual_machine {
      # Don't do this in production
      delete_os_disk_on_deletion = true
    }
  }
}

# Use AKS to prepare Helm provider
provider helm {
  kubernetes {
    config_path                = var.deploy_aks ? local.kube_config_absolute_path : ""
    host                       = var.deploy_aks ? module.aks.0.kubernetes_host : ""
    client_certificate         = var.deploy_aks ? base64decode(module.aks.0.kubernetes_client_certificate) : ""
    client_key                 = var.deploy_aks ? base64decode(module.aks.0.kubernetes_client_key) : ""
    cluster_ca_certificate     = var.deploy_aks ? base64decode(module.aks.0.kubernetes_cluster_ca_certificate) : ""
  }
}

# Use AKS to prepare Kubernetes provider
provider kubernetes {
  config_path                  = var.deploy_aks ? local.kube_config_absolute_path : ""
  host                         = var.deploy_aks ? module.aks.0.kubernetes_host : ""
  client_certificate           = var.deploy_aks ? base64decode(module.aks.0.kubernetes_client_certificate) : ""
  client_key                   = var.deploy_aks ? base64decode(module.aks.0.kubernetes_client_key) : ""
  cluster_ca_certificate       = var.deploy_aks ? base64decode(module.aks.0.kubernetes_cluster_ca_certificate) : ""
}