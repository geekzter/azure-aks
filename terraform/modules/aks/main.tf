locals {
  kubernetes_version           = var.kubernetes_version != null && var.kubernetes_version != "" ? var.kubernetes_version : data.azurerm_kubernetes_service_versions.current.latest_version
  resource_group_name          = element(split("/",var.resource_group_id),length(split("/",var.resource_group_id))-1)
}

data azurerm_subscription primary {}

data azurerm_subnet nodes_subnet {
  name                         = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-1)
  virtual_network_name         = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-3)
  resource_group_name          = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-7)
}

resource azurerm_user_assigned_identity aks_identity {
  name                         = "${var.name}-identity"
  location                     = var.location
  resource_group_name          = local.resource_group_name
}

# AKS needs permission to make changes for kubelet networking mode
resource azurerm_role_assignment spn_network_permission {
  scope                        = var.resource_group_id
  role_definition_name         = "Network Contributor"
  principal_id                 = azurerm_user_assigned_identity.aks_identity.principal_id
}

# AKS needs permission for BYO DNS
resource azurerm_role_assignment spn_dns_permission {
  scope                        = var.resource_group_id
  role_definition_name         = "Private DNS Zone Contributor"
  principal_id                 = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Requires Terraform owner access to resource group, in order to be able to perform access management
resource azurerm_role_assignment spn_permission {
  scope                        = var.resource_group_id
  role_definition_name         = "Virtual Machine Contributor"
  principal_id                 = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Grant Terraform user Cluster Admin role
resource azurerm_role_assignment terraform_cluster_permission {
  scope                        = var.resource_group_id
  role_definition_name         = "Azure Kubernetes Service Cluster Admin Role"
  principal_id                 = var.client_object_id
}

data azurerm_kubernetes_service_versions current {
  location                     = var.location
  include_preview              = false
}

resource azurerm_kubernetes_cluster aks {
  name                         = var.name
  location                     = var.location
  resource_group_name          = local.resource_group_name
  dns_prefix                   = var.dns_prefix

  # Triggers resource to be recreated
  kubernetes_version           = local.kubernetes_version

  addon_profile {
    azure_policy {
      enabled                  = true
    }
    http_application_routing {
      enabled                  = false # Use AGIC instead
    }
    ingress_application_gateway {
      enabled                  = true
      subnet_id                = var.application_gateway_subnet_id
    }
    kube_dashboard {
      # Deprecated for Kubernetes version >= 1.19.0.
      enabled                  = false
    }
    oms_agent {
      enabled                  = true
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  automatic_channel_upgrade    = "stable"

  default_node_pool {
    availability_zones         = [1,2,3]
    enable_auto_scaling        = true
    enable_host_encryption     = false # Requires 'Microsoft.Compute/EncryptionAtHost' feature
    enable_node_public_ip      = false
    min_count                  = 3
    max_count                  = 10
    name                       = "default"
    node_count                 = 3
    tags                       = var.tags
    # https://docs.microsoft.com/en-us/azure/virtual-machines/disk-encryption#supported-vm-sizes
    vm_size                    = var.node_size
    vnet_subnet_id             = var.node_subnet_id
  }

  identity {
    type                       = "UserAssigned"
    user_assigned_identity_id  = azurerm_user_assigned_identity.aks_identity.id
  }

  # local_account_disabled       = true # Will become default in 1.24

  network_profile {
    network_plugin             = "azure"
    network_policy             = "azure"
    outbound_type              = "userDefinedRouting"
  }

  private_cluster_enabled      = true

  role_based_access_control {
    azure_active_directory {
      admin_group_object_ids   = [var.client_object_id]
      azure_rbac_enabled       = true
      managed                  = true
    }
    enabled                    = true
  }

  lifecycle {
    ignore_changes             = [
      default_node_pool.0.node_count # Ignore changes made by autoscaling
    ]
  }

  tags                         = var.tags

  depends_on                   = [
    azurerm_role_assignment.spn_permission,
    azurerm_role_assignment.spn_dns_permission,
    azurerm_role_assignment.spn_network_permission,
  ]
}

data azurerm_private_endpoint_connection api_server_endpoint {
  name                         = "kube-apiserver"
  resource_group_name          = azurerm_kubernetes_cluster.aks.node_resource_group
}

data azurerm_application_gateway app_gw {
  name                         = split("/",azurerm_kubernetes_cluster.aks.addon_profile[0].ingress_application_gateway[0].effective_gateway_id)[8]
  resource_group_name          = azurerm_kubernetes_cluster.aks.node_resource_group
}
resource random_string application_gateway_domain_label {
  length                      = min(16,63-length(var.dns_host_suffix))
  upper                       = false
  lower                       = true
  number                      = false
  special                     = false
}

locals {
  application_gateway_domain_label = "${random_string.application_gateway_domain_label.result}${var.dns_host_suffix}"
}

resource null_resource application_gateway_domain_label {
  provisioner local-exec {
    command                    = "az network public-ip update --dns-name ${local.application_gateway_domain_label} -n ${data.azurerm_application_gateway.app_gw.name}-appgwpip -g ${azurerm_kubernetes_cluster.aks.node_resource_group} --subscription ${data.azurerm_subscription.primary.subscription_id} --query 'dnsSettings'"
  }

  depends_on                   = [random_string.application_gateway_domain_label]
}

data azurerm_public_ip application_gateway_public_ip {
  name                         = "${data.azurerm_application_gateway.app_gw.name}-appgwpip"
  resource_group_name          = azurerm_kubernetes_cluster.aks.node_resource_group

  depends_on                   = [null_resource.application_gateway_domain_label]
}

data azurerm_resources scale_sets {
  resource_group_name          = azurerm_kubernetes_cluster.aks.node_resource_group
  type                         = "Microsoft.Compute/virtualMachineScaleSets"

  required_tags                = azurerm_kubernetes_cluster.aks.tags
}

# Export kube_config for kubectl
resource local_file kube_config {
  filename                     = var.kube_config_path
  content                      = azurerm_kubernetes_cluster.aks.kube_admin_config_raw
}
