terraform {
  required_providers {
    azuread                    = "~> 1.0.0"
    azurerm                    = "~> 2.35"
    # external                   = "~> 1.2"
    helm                       = "~> 1.3.2"
    http                       = "~> 2.0.0"
    kubernetes                 = "~> 1.13.3"
    local                      = "~> 2.0.0"
    null                       = "~> 2.1"
    random                     = "~> 2.3"
  }
  required_version             = "~> 0.13.0"
}

# Microsoft Azure Resource Manager Provider
# This provider block uses the following environment variables: 
# ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET and ARM_TENANT_ID
provider azurerm {
    # Pin Terraform version
    # Pipelines vdc-terraform-apply-ci/cd have a parameter unpinTerraformProviders ('=' -> '~>') to test forward compatibility
    features {
        virtual_machine {
            # Don't do this in production
            delete_os_disk_on_deletion = true
        }
    }
}

# Use AKS to prepare Helm provider
provider helm {
  # debug                        = true

  kubernetes {
    host                       = module.aks.kubernetes_host
    client_certificate         = base64decode(module.aks.kubernetes_client_certificate)
    client_key                 = base64decode(module.aks.kubernetes_client_key)
    cluster_ca_certificate     = base64decode(module.aks.kubernetes_cluster_ca_certificate)
  }

  # override                     = ["spec.template.spec.automountserviceaccounttoken=true"]
}

# Use AKS to prepare Kubernetes provider
provider kubernetes {
  host                         = module.aks.kubernetes_host
  client_certificate           = base64decode(module.aks.kubernetes_client_certificate)
  client_key                   = base64decode(module.aks.kubernetes_client_key)
  cluster_ca_certificate       = base64decode(module.aks.kubernetes_cluster_ca_certificate)
}