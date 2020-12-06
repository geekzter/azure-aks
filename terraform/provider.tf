terraform {
  required_providers {
    azuread                    = "~> 1.1.1"
    azurerm                    = "~> 2.36"
    external                   = "~> 2.0.0"
    helm                       = "~> 1.3.2"
    http                       = "~> 2.0.0"
    kubernetes                 = "~> 1.13.3"
    local                      = "~> 2.0.0"
    null                       = "~> 2.1"
    random                     = "~> 2.3"
    time                       = "~> 0.6"
  }
  required_version             = "~> 0.13.0"
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
    host                       = var.deploy_aks ? module.aks.0.kubernetes_host : ""
    client_certificate         = var.deploy_aks ? base64decode(module.aks.0.kubernetes_client_certificate) : ""
    client_key                 = var.deploy_aks ? base64decode(module.aks.0.kubernetes_client_key) : ""
    cluster_ca_certificate     = var.deploy_aks ? base64decode(module.aks.0.kubernetes_cluster_ca_certificate) : ""
  }
}

# Use AKS to prepare Kubernetes provider
provider kubernetes {
  host                         = var.deploy_aks ? module.aks.0.kubernetes_host : ""
  client_certificate           = var.deploy_aks ? base64decode(module.aks.0.kubernetes_client_certificate) : ""
  client_key                   = var.deploy_aks ? base64decode(module.aks.0.kubernetes_client_key) : ""
  cluster_ca_certificate       = var.deploy_aks ? base64decode(module.aks.0.kubernetes_cluster_ca_certificate) : ""
}