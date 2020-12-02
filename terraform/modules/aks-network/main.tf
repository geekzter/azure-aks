data azurerm_resource_group rg {
  name                         = var.resource_group_name
}

data azurerm_kubernetes_cluster aks {
  name                         = element(split("/",var.aks_id),length(split("/",var.aks_id))-1)
  resource_group_name          = element(split("/",var.aks_id),length(split("/",var.aks_id))-5)
}

data azurerm_firewall iag {
  name                         = element(split("/",var.firewall_id),length(split("/",var.firewall_id))-1)
  resource_group_name          = element(split("/",var.firewall_id),length(split("/",var.firewall_id))-5)
}

data azurerm_public_ip iag_pip {
  name                         = element(split("/",data.azurerm_firewall.iag.ip_configuration.0.public_ip_address_id),length(split("/",data.azurerm_firewall.iag.ip_configuration.0.public_ip_address_id))-1)
  resource_group_name          = element(split("/",data.azurerm_firewall.iag.ip_configuration.0.public_ip_address_id),length(split("/",data.azurerm_firewall.iag.ip_configuration.0.public_ip_address_id))-5)
}

data azurerm_subnet nodes_subnet {
  name                         = element(split("/",var.nodes_subnet_id),length(split("/",var.nodes_subnet_id))-1)
  virtual_network_name         = element(split("/",var.nodes_subnet_id),length(split("/",var.nodes_subnet_id))-3)
  resource_group_name          = element(split("/",var.nodes_subnet_id),length(split("/",var.nodes_subnet_id))-7)
}

# "az network private-dns record-set list -z 80e0f086-6949-4e86-ae85-185fc246d53d.privatelink.westeurope.azmk8s.io -g mc_k8s-default-qcmv_aks-default-qcmv_westeurope --query "[].aRecords[] | [0]" "
data external image_info {
  program                      = [
                                 "az",
                                 "network",
                                 "private-dns",
                                 "record-set",
                                 "list",
                                 "-g",
                                 data.azurerm_kubernetes_cluster.aks.node_resource_group,
                                 "-z",
                                 local.api_server_domain,
                                 "--query",
                                 "[].aRecords[] | [0]",
                                 "-o",
                                 "json",
                                 ]
}

locals {
  api_server_domain            = join(".",slice(split(".",local.api_server_host),1,length(split(".",local.api_server_host))))
  api_server_host              = regex("^(?:(?P<scheme>[^:/?#]+):)?(?://(?P<host>[^:/?#]*))?", data.azurerm_kubernetes_cluster.aks.kube_admin_config.0.host).host
  kubernetes_api_ip_address    = data.external.image_info.result.ipv4Address
  peer_network_name            = element(split("/",var.peer_network_id),length(split("/",var.peer_network_id))-1)
}

resource azurerm_ip_group api_server {
  name                         = "${data.azurerm_resource_group.rg.name}-ipgroup-apiserver"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  cidrs                        = data.azurerm_kubernetes_cluster.aks.api_server_authorized_ip_ranges

  tags                         = var.tags
}

resource azurerm_ip_group nodes {
  name                         = "${data.azurerm_resource_group.rg.name}-ipgroup-nodes"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  cidrs                        = data.azurerm_subnet.nodes_subnet.address_prefixes

  tags                         = var.tags
}

# Set up name resolution for peered network
data azurerm_private_dns_zone api_server_domain {
  name                         = local.api_server_domain
  resource_group_name          = data.azurerm_kubernetes_cluster.aks.node_resource_group
}
resource azurerm_private_dns_zone_virtual_network_link api_server_domain {
  name                         = "${local.peer_network_name}-zone-link"
  resource_group_name          = data.azurerm_private_dns_zone.api_server_domain.resource_group_name
  private_dns_zone_name        = data.azurerm_private_dns_zone.api_server_domain.name
  virtual_network_id           = var.peer_network_id

  count                        = var.peer_network_id != "" ? 1 : 0
}