resource azurerm_role_definition aksrd {
  # role_definition_id           = uuid() # Optional
  name                         = "MinimalAKSPermissions-${data.azurerm_resource_group.rg.tags["suffix"]}"
  scope                        = data.azurerm_resource_group.rg.id

  permissions {
    actions                    = [
      # https://docs.microsoft.com/en-us/azure/aks/kubernetes-service-principal#storage
        "Microsoft.Compute/disks/read",
        "Microsoft.Compute/disks/write",
      # https://docs.microsoft.com/en-us/azure/aks/kubernetes-service-principal#networking
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/read",
        "Microsoft.Network/virtualNetworks/subnets/write",
        "Microsoft.Network/publicIPAddresses/join/action",
        "Microsoft.Network/publicIPAddresses/read",
        "Microsoft.Network/publicIPAddresses/write",
        "Microsoft.Network/routeTables/read",
        "Microsoft.Network/routeTables/write",
    ]
    not_actions                = []
  }

  assignable_scopes            = [
    data.azurerm_resource_group.rg.id
  ]
}


# Requires Terraform owner access to resource group, in order to be able to perform access management
resource azurerm_role_assignment aksspnassignment {
# name                         = uuid() # Optional
  scope                        = data.azurerm_resource_group.rg.id
  role_definition_id           = azurerm_role_definition.aksrd.role_definition_resource_id
  # role_definition_name         = "Contributor"
  principal_id                 = var.sp_object_id
}

data azurerm_kubernetes_service_versions current {
  location                     = data.azurerm_resource_group.rg.location
  include_preview              = false
}

resource azurerm_kubernetes_cluster aks {
  name                         = var.name
  location                     = data.azurerm_resource_group.rg.location
  resource_group_name          = data.azurerm_resource_group.rg.name
  dns_prefix                   = var.dns_prefix

  kubernetes_version           = data.azurerm_kubernetes_service_versions.current.latest_version

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

  identity {
    type                       = "SystemAssigned"
  }


  linux_profile {
    admin_username             = var.admin_username
    dynamic ssh_key {
      for_each                 = range(fileexists(var.ssh_public_key_file) ? 1 : 0)
      content {
        key_data               = file(var.ssh_public_key_file)
      }
    }
  }

  network_profile {
    network_plugin             = "kubenet"
  }

  role_based_access_control {
    azure_active_directory {
      # admin_group_object_ids   = 
      managed                  = true
    }
    enabled                    = true
  }

  # service_principal {
  #   client_id                  = var.sp_application_id
  #   client_secret              = var.sp_application_secret
  # }

  tags                         = data.azurerm_resource_group.rg.tags

  depends_on                   = [azurerm_role_assignment.aksspnassignment] # RBAC
}

