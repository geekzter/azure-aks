data azurerm_kubernetes_cluster aks {
  name                         = element(split("/",var.aks_id),length(split("/",var.aks_id))-1)
  resource_group_name          = element(split("/",var.aks_id),length(split("/",var.aks_id))-5)
}

data azurerm_firewall gateway {
  name                         = element(split("/",var.firewall_id),length(split("/",var.firewall_id))-1)
  resource_group_name          = element(split("/",var.firewall_id),length(split("/",var.firewall_id))-5)
}

data azurerm_public_ip firewall_pip {
  name                         = element(split("/",data.azurerm_firewall.gateway.ip_configuration.0.public_ip_address_id),length(split("/",data.azurerm_firewall.gateway.ip_configuration.0.public_ip_address_id))-1)
  resource_group_name          = element(split("/",data.azurerm_firewall.gateway.ip_configuration.0.public_ip_address_id),length(split("/",data.azurerm_firewall.gateway.ip_configuration.0.public_ip_address_id))-5)
}

data azurerm_subnet nodes_subnet {
  name                         = element(split("/",var.nodes_subnet_id),length(split("/",var.nodes_subnet_id))-1)
  virtual_network_name         = element(split("/",var.nodes_subnet_id),length(split("/",var.nodes_subnet_id))-3)
  resource_group_name          = element(split("/",var.nodes_subnet_id),length(split("/",var.nodes_subnet_id))-7)
}

locals {
  api_server_domain            = join(".",slice(split(".",local.api_server_host),1,length(split(".",local.api_server_host))))
  api_server_host              = regex("^(?:(?P<scheme>[^:/?#]+):)?(?://(?P<host>[^:/?#]*))?", data.azurerm_kubernetes_cluster.aks.kube_admin_config.0.host).host
  peer_network_name            = element(split("/",var.peer_network_id),length(split("/",var.peer_network_id))-1)
}

resource azurerm_ip_group api_server {
  name                         = "${var.resource_group_name}-ipgroup-apiserver"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  cidrs                        = data.azurerm_kubernetes_cluster.aks.api_server_authorized_ip_ranges

  tags                         = var.tags
}

resource azurerm_private_dns_zone acr {
  name                         = "privatelink.azurecr.io"
  resource_group_name          = var.resource_group_name
}
resource azurerm_private_dns_zone_virtual_network_link acr {
  name                         = "${var.resource_group_name}-registry-dns-link"
  resource_group_name          = var.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.acr.name
  virtual_network_id           = var.virtual_network_id
}
resource azurerm_private_endpoint acr_endpoint {
  name                         = "${var.resource_group_name}-registry-endpoint"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  
  subnet_id                    = var.paas_subnet_id

  private_dns_zone_group {
    name                      = azurerm_private_dns_zone.acr.name
    private_dns_zone_ids      = [azurerm_private_dns_zone.acr.id]
  }  

  private_service_connection {
    is_manual_connection       = false
    name                       = "${var.resource_group_name}-registry-endpoint-connection"
    private_connection_resource_id = var.container_registry_id
    subresource_names          = ["registry"]
  }

  tags                         = var.tags
}

# Set up name resolution for peered network
data azurerm_private_dns_zone api_server_domain {
  name                         = local.api_server_domain
  resource_group_name          = data.azurerm_kubernetes_cluster.aks.node_resource_group
}
resource azurerm_private_dns_zone_virtual_network_link api_server_domain {
  name                         = "${local.peer_network_name}-zone-link"
  resource_group_name          = data.azurerm_kubernetes_cluster.aks.node_resource_group
  private_dns_zone_name        = data.azurerm_private_dns_zone.api_server_domain.name
  virtual_network_id           = var.peer_network_id

  tags                         = var.tags

  count                        = var.peer_network_id != "" ? 1 : 0
}
