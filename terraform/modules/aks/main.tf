data azurerm_resource_group rg {
  name                         = var.resource_group_name
}

data azurerm_log_analytics_workspace log_analytics {
  name                         = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-1)
  resource_group_name          = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-5)
}

resource azurerm_log_analytics_solution log_analytics_solution {
  solution_name                = "ContainerInsights" 
  location                     = var.location
  resource_group_name          = data.azurerm_log_analytics_workspace.log_analytics.resource_group_name
  workspace_resource_id        = data.azurerm_log_analytics_workspace.log_analytics.id
  workspace_name               = data.azurerm_log_analytics_workspace.log_analytics.name

  plan {
    publisher                  = "Microsoft"
    product                    = "OMSGallery/ContainerInsights"
  }
} 

# resource azurerm_role_definition aksrd {
#   name                         = "MinimalAKSPermissions-${data.azurerm_resource_group.rg.tags["suffix"]}"
#   scope                        = data.azurerm_resource_group.rg.id

#   permissions {
#     actions                    = [
#       # https://docs.microsoft.com/en-us/azure/aks/kubernetes-service-principal#storage
#         "Microsoft.Compute/disks/read",
#         "Microsoft.Compute/disks/write",
#       # https://docs.microsoft.com/en-us/azure/aks/kubernetes-service-principal#networking
#         "Microsoft.Network/virtualNetworks/subnets/join/action",
#         "Microsoft.Network/virtualNetworks/subnets/read",
#         "Microsoft.Network/virtualNetworks/subnets/write",
#         "Microsoft.Network/publicIPAddresses/join/action",
#         "Microsoft.Network/publicIPAddresses/read",
#         "Microsoft.Network/publicIPAddresses/write",
#         "Microsoft.Network/routeTables/read",
#         "Microsoft.Network/routeTables/write",
#     ]
#     not_actions                = []
#   }

#   assignable_scopes            = [
#     data.azurerm_resource_group.rg.id
#   ]
# }

data azurerm_subnet nodes_subnet {
  name                         = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-1)
  virtual_network_name         = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-3)
  resource_group_name          = element(split("/",var.node_subnet_id),length(split("/",var.node_subnet_id))-7)
}

# TODO: resource replaced on every apply, as the data source value is not known at plan time
# AKS needs permission to make changes for kubelet networking mode
resource azurerm_role_assignment spn_network_permission {
  scope                        = data.azurerm_subnet.nodes_subnet.route_table_id
  role_definition_name         = "Network Contributor"
  # principal_id                 = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  principal_id                 = var.sp_object_id
}

# TODO: resource replaced on every apply, as the data source value is not known at plan time
# Requires Terraform owner access to resource group, in order to be able to perform access management
resource azurerm_role_assignment spn_permission {
  scope                        = data.azurerm_resource_group.rg.id
  # role_definition_id           = azurerm_role_definition.aksrd.role_definition_resource_id
  role_definition_name         = "Virtual Machine Contributor"
  # principal_id                 = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  principal_id                 = var.sp_object_id
}

data azurerm_kubernetes_service_versions current {
  location                     = var.location
  include_preview              = false
}

resource azurerm_kubernetes_cluster aks {
  name                         = var.name
  location                     = var.location
  resource_group_name          = data.azurerm_resource_group.rg.name
  dns_prefix                   = var.dns_prefix

  # Triggers resource to be recreated
  # kubernetes_version           = data.azurerm_kubernetes_service_versions.current.latest_version

  addon_profile {
    azure_policy {
      enabled                  = true
    }
    http_application_routing {
      enabled                  = true
    }
    kube_dashboard {
      enabled                  = true
    }
    
    oms_agent {
      enabled                  = true
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  default_node_pool {
    availability_zones         = [1,2,3]
    enable_node_public_ip      = false
    name                       = terraform.workspace
    node_count                 = 3
    tags                       = data.azurerm_resource_group.rg.tags
    vm_size                    = "Standard_D2_v2"
    vnet_subnet_id             = var.node_subnet_id
  }

  # Clusters using managed identity do not support bringing your own route table. 
  # Please see https://aka.ms/aks/customrt for more information
  # Using service_principal instead
  # identity {
  #   type                       = "SystemAssigned"
  # }

  dynamic linux_profile {
    for_each                   = range(fileexists(var.ssh_public_key_file) ? 1 : 0)
    content {
      admin_username           = var.admin_username
      ssh_key {
        key_data               = file(var.ssh_public_key_file)
      }
    }
  }

  network_profile {
    network_plugin             = "kubenet"
  }

  private_cluster_enabled      = true

  role_based_access_control {
    azure_active_directory {
      # admin_group_object_ids   = 
      managed                  = true
    }
    enabled                    = true
  }

  service_principal {
    client_id                  = var.sp_application_id
    client_secret              = var.sp_application_secret
  }

  tags                         = data.azurerm_resource_group.rg.tags

  depends_on                   = [
    azurerm_role_assignment.spn_permission,
    azurerm_role_assignment.spn_network_permission,
  ]
}

resource local_file kube_config {
  filename                     = var.kube_config_path
  content                      = azurerm_kubernetes_cluster.aks.kube_config_raw
}