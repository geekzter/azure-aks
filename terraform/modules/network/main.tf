data http local_public_ip {
# Get public IP address of the machine running this terraform template
  url                          = "http://ipinfo.io/ip"
}

data http local_public_prefix {
# Get public IP prefix of the machine running this terraform template
  url                          = "https://stat.ripe.net/data/network-info/data.json?resource=${chomp(data.http.local_public_ip.body)}"
}

locals {
  admin_cidrs                  = [
                                  cidrsubnet("${chomp(data.http.local_public_ip.body)}/30",0,0), # /32 not allowed in network_rules
                                  jsondecode(chomp(data.http.local_public_prefix.body)).data.prefix
  ] 
}

resource azurerm_virtual_network network {
  name                         = "${var.resource_group_name}-network"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  address_space                = [var.address_space]
  dns_servers                  = var.dns_servers
  
  tags                         = var.tags
}

resource azurerm_subnet firewall_subnet {
  name                         = "AzureFirewallSubnet"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.network.address_space[0],3,0)] # /26, assuming network is /23
}
resource azurerm_subnet waf_subnet {
  name                         = "ApplicationGatewaySubnet"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.network.address_space[0],3,1)] # /26, assuming network is /23
}
resource azurerm_subnet bastion_subnet {
  name                         = "AzureBastionSubnet"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.network.address_space[0],3,2)] # /26, assuming network is /23
}
resource azurerm_subnet paas_subnet {
  name                         = "PrivateEndpoints"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.network.address_space[0],3,3)] # /24, assuming network is /23
  enforce_private_link_endpoint_network_policies = true
}
resource azurerm_subnet nodes_subnet {
  name                         = "KubernetesClusterNodes"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.network.address_space[0],1,1)] # /24, assuming network is /23
  enforce_private_link_endpoint_network_policies = true
}

resource azurerm_route_table user_defined_routes {
  name                        = "${var.resource_group_name}-routes"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  
  route {
    name                       = "VnetLocal"
    address_prefix             = "10.0.0.0/8"
    next_hop_type              = "VnetLocal"
  }
  route {
    name                       = "InternetViaFW"
    address_prefix             = "0.0.0.0/0"
    next_hop_type              = "VirtualAppliance"
    next_hop_in_ip_address     = azurerm_firewall.gateway.ip_configuration.0.private_ip_address
  }

  # AKS (in kubelet network mode) may add routes Terraform is not aware off
  lifecycle {
    ignore_changes             = [
                                 route
    ]
  }  

  tags                         = var.tags
}

resource azurerm_subnet_route_table_association user_defined_routes {
  subnet_id                    = azurerm_subnet.nodes_subnet.id
  route_table_id               = azurerm_route_table.user_defined_routes.id
}

data azurerm_virtual_network peered_network {
  name                         = element(split("/",var.peer_network_id),length(split("/",var.peer_network_id))-1)
  resource_group_name          = element(split("/",var.peer_network_id),length(split("/",var.peer_network_id))-5)

  count                        = var.peer_network_id == "" ? 0 : 1
}

resource azurerm_virtual_network_peering network_to_peer {
  name                         = "${azurerm_virtual_network.network.name}-to-peer"
  resource_group_name          = azurerm_virtual_network.network.resource_group_name
  virtual_network_name         = azurerm_virtual_network.network.name
  remote_virtual_network_id    = data.azurerm_virtual_network.peered_network.0.id

  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
  use_remote_gateways          = var.peer_network_has_gateway

  count                        = var.peer_network_id == "" ? 0 : 1

  depends_on                   = [azurerm_virtual_network_peering.peer_to_network]
}

resource azurerm_virtual_network_peering peer_to_network {
  name                         = "${azurerm_virtual_network.network.name}-from-peer"
  resource_group_name          = data.azurerm_virtual_network.peered_network.0.resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.peered_network.0.name
  remote_virtual_network_id    = azurerm_virtual_network.network.id

  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.peer_network_has_gateway
  allow_virtual_network_access = true
  use_remote_gateways          = false

  count                        = var.peer_network_id == "" ? 0 : 1
}