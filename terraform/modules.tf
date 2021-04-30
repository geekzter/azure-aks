# Provision base network infrastructure
module network {
  source                       = "./modules/network"
  resource_group_name          = azurerm_resource_group.rg.name
  address_space                = var.address_space
  location                     = var.location
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.log_analytics.id
  peer_network_has_gateway     = var.peer_network_has_gateway
  peer_network_id              = var.peer_network_id
  subnets                      = [
    "nodes"
  ]
  tags                         = azurerm_resource_group.rg.tags
}

# Provision base Kubernetes infrastructure provided by Azure
module aks {
  source                       = "./modules/aks"
  name                         = local.aks_name

  admin_username               = "aksadmin"
  application_gateway_subnet_id= module.network.application_gateway_subnet_id
  client_object_id             = data.azurerm_client_config.current.object_id
  dns_prefix                   = "ew-aks"
  location                     = var.location
  kube_config_path             = local.kube_config_absolute_path
  kubernetes_version           = var.kubernetes_version
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.log_analytics.id
  node_size                    = var.node_size
  node_subnet_id               = module.network.subnet_ids["nodes"]
  resource_group_id            = azurerm_resource_group.rg.id
  ssh_public_key_file          = var.ssh_public_key_file
  tags                         = azurerm_resource_group.rg.tags

  count                        = var.deploy_aks ? 1 : 0
  depends_on                   = [module.network]
}

# Provision AKS network infrastructure (allowing dependencies on AKS)
module aks_network {
  source                       = "./modules/aks-network"
  resource_group_name          = azurerm_resource_group.rg.name

  admin_ip_group_id            = module.network.admin_ip_group_id
  aks_id                       = module.aks.0.aks_id
  #application_gateway_id       = module.network.application_gateway_id
  # application_gateway_subnet_id= module.network.application_gateway_subnet_id
  deploy_agic                  = var.deploy_agic
  firewall_id                  = module.network.firewall_id
  location                     = var.location
  nodes_ip_group_id            = module.network.nodes_ip_group_id
  nodes_subnet_id              = module.network.subnet_ids["nodes"]
  peer_network_id              = var.peer_network_id
  resource_group_id            = azurerm_resource_group.rg.id
  tags                         = azurerm_resource_group.rg.tags
  wait_for_agic                = var.wait_for_agic

  count                        = var.deploy_aks ? 1 : 0
  depends_on                   = [
    # module.aks,
    #module.network
  ]
}

# Confugure Kubernetes
module k8s {
  source                       = "./modules/kubernetes"

  count                        = var.deploy_aks && var.configure_kubernetes && var.peer_network_id != "" ? 1 : 0
  depends_on                   = [module.aks,module.aks_network]
}