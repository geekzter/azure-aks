data http local_public_ip {
# Get public IP address of the machine running this terraform template
  url                          = "https://ipinfo.io/ip"
}

data http local_public_prefix {
# Get public IP prefix of the machine running this terraform template
  url                          = "https://stat.ripe.net/data/network-info/data.json?resource=${chomp(data.http.local_public_ip.response_body)}"
}

locals {
  admin_cidrs                  = [
                                  cidrsubnet("${chomp(data.http.local_public_ip.response_body)}/30",0,0), # /32 not allowed in network_rules
                                  jsondecode(chomp(data.http.local_public_prefix.response_body)).data.prefix
  ] 
  bastion_cidr                 = cidrsubnet(azurerm_virtual_network.network.address_space[0],3,2) # /26, assuming network is /23
  firewall_cidr                = cidrsubnet(azurerm_virtual_network.network.address_space[0],3,0)
  nodes_cidr                   = cidrsubnet(azurerm_virtual_network.network.address_space[0],1,1) # /24, assuming network is /23
  paas_cidr                    = cidrsubnet(azurerm_virtual_network.network.address_space[0],3,3) # /24, assuming network is /23
  waf_cidr                     = cidrsubnet(azurerm_virtual_network.network.address_space[0],3,1) # /26, assuming network is /23
}

resource azurerm_virtual_network network {
  name                         = "${var.resource_group_name}-network"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  address_space                = [var.address_space]
  dns_servers                  = var.dns_servers
  
  tags                         = var.tags
}
resource azurerm_monitor_diagnostic_setting network {
  name                         = "${azurerm_virtual_network.network.name}-logs"
  target_resource_id           = azurerm_virtual_network.network.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  enabled_log {
    category                   = "VMProtectionAlerts"

    retention_policy {
      enabled                  = false
    }
  }

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
}
resource azurerm_subnet firewall_subnet {
  name                         = "AzureFirewallSubnet"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [local.firewall_cidr]
}

resource azurerm_subnet waf_subnet {
  name                         = "ApplicationGatewaySubnet"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [local.waf_cidr]

  # Reduce the likelihood of race conditions
  depends_on = [
    azurerm_network_security_rule.allow_application_gateway_management,
    azurerm_network_security_rule.allow_azure_loadbalancer,
    azurerm_network_security_rule.allow_http
  ]
}
resource azurerm_network_security_group waf_nsg {
  name                         = "${azurerm_virtual_network.network.name}-waf-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.network.resource_group_name

  tags                         = var.tags
}
# https://docs.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#network-security-groups
resource azurerm_network_security_rule allow_application_gateway_management {
  name                         = "AllowAppGWManagementInbound"
  priority                     = 201
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "65200-65535" # Unblocks ApplicationGatewaySubnetInboundTrafficBlockedByNetworkSecurityGroup
  source_address_prefix        = "GatewayManager"
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.waf_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.waf_nsg.name
}
resource azurerm_network_security_rule allow_azure_loadbalancer {
  name                         = "AllowAzureLoadBalancerInbound"
  priority                     = 202
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefix        = "AzureLoadBalancer"
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.waf_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.waf_nsg.name
}
resource azurerm_network_security_rule allow_http {
  name                         = "AllowHttpInbound"
  priority                     = 203
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_ranges      = ["80","443"]
  source_address_prefix        = "Internet"
  destination_address_prefixes = [local.waf_cidr]
  resource_group_name          = azurerm_network_security_group.waf_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.waf_nsg.name
}
resource azurerm_subnet_network_security_group_association waf_subnet {
  subnet_id                    = azurerm_subnet.waf_subnet.id
  network_security_group_id    = azurerm_network_security_group.waf_nsg.id
}
resource time_sleep waf_nsg_wait_time {
  create_duration              = "${var.nsg_reassign_wait_minutes}m"
  depends_on                   = [azurerm_subnet_network_security_group_association.waf_subnet]

  count                        = var.nsg_reassign_wait_minutes == 0 ? 0 : 1
}
data azurerm_subnet waf_subnet {
  name                         = azurerm_subnet.waf_subnet.name
  resource_group_name          = azurerm_subnet.waf_subnet.resource_group_name
  virtual_network_name         = azurerm_subnet.waf_subnet.virtual_network_name

  depends_on                   = [
    time_sleep.waf_nsg_wait_time
  ]

  count                        = var.nsg_reassign_wait_minutes == 0 ? 0 : 1
}
# Address race condition where policy assigned NSG before we can assign our own
# Let's wait for any updates to happen, then overwrite with our own
resource null_resource waf_nsg_association {
  triggers                     = {
    nsg                        = coalesce(data.azurerm_subnet.waf_subnet.0.network_security_group_id,azurerm_network_security_group.waf_nsg.id)
  }

  provisioner local-exec {
    command                    = "${path.root}/../scripts/create_nsg_assignment.ps1 -SubnetId ${azurerm_subnet.waf_subnet.id} -NsgId ${azurerm_network_security_group.waf_nsg.id}"
    interpreter                = ["pwsh","-nop","-command"]
  }  

  count                        = var.nsg_reassign_wait_minutes == 0 ? 0 : 1
}

resource azurerm_subnet bastion_subnet {
  name                         = "AzureBastionSubnet"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [local.bastion_cidr]

  # # Reduce the likelihood of race conditions
  # depends_on                   = [
  #   azurerm_network_security_rule.https_inbound,
  #   azurerm_network_security_rule.gateway_manager_inbound,
  #   azurerm_network_security_rule.load_balancer_inbound,
  #   azurerm_network_security_rule.bastion_host_communication_inbound,
  #   azurerm_network_security_rule.ras_outbound,
  #   azurerm_network_security_rule.azure_outbound,
  #   azurerm_network_security_rule.bastion_host_communication_oubound,
  #   azurerm_network_security_rule.get_session_oubound,
  # ]  
}
# # https://docs.microsoft.com/en-us/azure/bastion/bastion-nsg
# resource azurerm_network_security_group bastion_nsg {
#   name                         = "${azurerm_virtual_network.network.name}-bastion-nsg"
#   location                     = var.location
#   resource_group_name          = azurerm_virtual_network.network.resource_group_name

#   tags                         = var.tags
# }
# resource azurerm_network_security_rule https_inbound {
#   name                         = "AllowHttpsInbound"
#   priority                     = 220
#   direction                    = "Inbound"
#   access                       = "Allow"
#   protocol                     = "Tcp"
#   source_port_range            = "*"
#   destination_port_range       = "443"
#   source_address_prefix        = "Internet"
#   destination_address_prefix   = "*"
#   resource_group_name          = azurerm_network_security_group.bastion_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
# }
# resource azurerm_network_security_rule gateway_manager_inbound {
#   name                         = "AllowGatewayManagerInbound"
#   priority                     = 230
#   direction                    = "Inbound"
#   access                       = "Allow"
#   protocol                     = "Tcp"
#   source_port_range            = "*"
#   destination_port_range       = "443"
#   source_address_prefix        = "GatewayManager"
#   destination_address_prefix   = "*"
#   resource_group_name          = azurerm_network_security_group.bastion_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
# }
# resource azurerm_network_security_rule load_balancer_inbound {
#   name                         = "AllowLoadBalancerInbound"
#   priority                     = 240
#   direction                    = "Inbound"
#   access                       = "Allow"
#   protocol                     = "Tcp"
#   source_port_range            = "*"
#   destination_port_range       = "443"
#   source_address_prefix        = "AzureLoadBalancer"
#   destination_address_prefix   = "*"
#   resource_group_name          = azurerm_network_security_group.bastion_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
# }
# resource azurerm_network_security_rule bastion_host_communication_inbound {
#   name                         = "AllowBastionHostCommunication"
#   priority                     = 250
#   direction                    = "Inbound"
#   access                       = "Allow"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_ranges      = ["5701","8080"]
#   source_address_prefix        = "VirtualNetwork"
#   destination_address_prefix   = "VirtualNetwork"
#   resource_group_name          = azurerm_network_security_group.bastion_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
# }
# resource azurerm_network_security_rule ras_outbound {
#   name                         = "AllowSshRdpOutbound"
#   priority                     = 200
#   direction                    = "Outbound"
#   access                       = "Allow"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_ranges      = ["22","3389"]
#   source_address_prefix        = "*"
#   destination_address_prefix   = "VirtualNetwork"
#   resource_group_name          = azurerm_network_security_group.bastion_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
# }
# resource azurerm_network_security_rule azure_outbound {
#   name                         = "AllowAzureCloudOutbound"
#   priority                     = 210
#   direction                    = "Outbound"
#   access                       = "Allow"
#   protocol                     = "Tcp"
#   source_port_range            = "*"
#   destination_port_range       = "443"
#   source_address_prefix        = "*"
#   destination_address_prefix   = "AzureCloud"
#   resource_group_name          = azurerm_network_security_group.bastion_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
# }
# resource azurerm_network_security_rule bastion_host_communication_oubound {
#   name                         = "AllowBastionCommunication"
#   priority                     = 220
#   direction                    = "Outbound"
#   access                       = "Allow"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_ranges      = ["5701","8080"]
#   source_address_prefix        = "VirtualNetwork"
#   destination_address_prefix   = "VirtualNetwork"
#   resource_group_name          = azurerm_network_security_group.bastion_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
# }
# resource azurerm_network_security_rule get_session_oubound {
#   name                         = "AllowGetSessionInformation"
#   priority                     = 230
#   direction                    = "Outbound"
#   access                       = "Allow"
#   protocol                     = "*"
#   source_port_range            = "*"
#   destination_port_range       = "80"
#   source_address_prefix        = "*"
#   destination_address_prefix   = "Internet"
#   resource_group_name          = azurerm_network_security_group.bastion_nsg.resource_group_name
#   network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
# }
# resource azurerm_subnet_network_security_group_association bastion_nsg {
#   subnet_id                    = azurerm_subnet.bastion_subnet.id
#   network_security_group_id    = azurerm_network_security_group.bastion_nsg.id

#   depends_on                   = [
#     azurerm_network_security_rule.https_inbound,
#     azurerm_network_security_rule.gateway_manager_inbound,
#     azurerm_network_security_rule.load_balancer_inbound,
#     azurerm_network_security_rule.bastion_host_communication_inbound,
#     azurerm_network_security_rule.ras_outbound,
#     azurerm_network_security_rule.azure_outbound,
#     azurerm_network_security_rule.bastion_host_communication_oubound,
#     azurerm_network_security_rule.get_session_oubound,
#   ]
# }

resource azurerm_subnet paas_subnet {
  name                         = "PrivateEndpoints"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [local.paas_cidr]
  private_endpoint_network_policies_enabled = true
}
resource azurerm_subnet nodes_subnet {
  name                         = "KubernetesClusterNodes"
  virtual_network_name         = azurerm_virtual_network.network.name
  resource_group_name          = var.resource_group_name
  address_prefixes             = [local.nodes_cidr]
  private_endpoint_network_policies_enabled = true
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