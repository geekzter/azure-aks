resource azurerm_public_ip bastion_pip {
  name                         = "${var.resource_group_name}-bastion-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard" # Zone redundant

  tags                         = var.tags
}
resource azurerm_monitor_diagnostic_setting bastion_pip {
  name                         = "${azurerm_public_ip.bastion_pip.name}-logs"
  target_resource_id           = azurerm_public_ip.bastion_pip.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  log {
    category                   = "DDoSProtectionNotifications"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "DDoSMitigationFlowLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "DDoSMitigationReports"
    enabled                    = true

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

# https://docs.microsoft.com/en-us/azure/bastion/bastion-nsg
resource azurerm_network_security_group bastion_nsg {
  name                         = "${var.resource_group_name}-bastion-nsg"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
}
resource azurerm_network_security_rule https_inbound {
  name                         = "AllowHttpsInbound"
  priority                     = 220
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "Internet"
  destination_address_prefix   = "*"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
}
resource azurerm_network_security_rule gateway_manager_inbound {
  name                         = "AllowGatewayManagerInbound"
  priority                     = 230
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "GatewayManager"
  destination_address_prefix   = "*"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
}
resource azurerm_network_security_rule load_balancer_inbound {
  name                         = "AllowLoadBalancerInbound"
  priority                     = 240
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "AzureLoadBalancer"
  destination_address_prefix   = "*"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
}
resource azurerm_network_security_rule bastion_host_communication_inbound {
  name                         = "AllowBastionHostCommunication"
  priority                     = 250
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_ranges      = ["5701","8080"]
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefix   = "VirtualNetwork"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
}
resource azurerm_network_security_rule ras_outbound {
  name                         = "AllowSshRdpOutbound"
  priority                     = 200
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_ranges      = ["22","3389"]
  source_address_prefix        = "*"
  destination_address_prefix   = "VirtualNetwork"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
}
resource azurerm_network_security_rule azure_outbound {
  name                         = "AllowAzureCloudOutbound"
  priority                     = 210
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "*"
  destination_address_prefix   = "AzureCloud"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
}
resource azurerm_network_security_rule bastion_host_communication_oubound {
  name                         = "AllowBastionCommunication"
  priority                     = 220
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_ranges      = ["5701","8080"]
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefix   = "VirtualNetwork"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
}
resource azurerm_network_security_rule get_session_oubound {
  name                         = "AllowGetSessionInformation"
  priority                     = 230
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "80"
  source_address_prefix        = "*"
  destination_address_prefix   = "Internet"
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.name
}
resource azurerm_subnet_network_security_group_association bastion_nsg {
  subnet_id                    = var.subnet_id
  network_security_group_id    = azurerm_network_security_group.bastion_nsg.id

  depends_on                   = [
    azurerm_network_security_rule.https_inbound,
    azurerm_network_security_rule.gateway_manager_inbound,
    azurerm_network_security_rule.load_balancer_inbound,
    azurerm_network_security_rule.bastion_host_communication_inbound,
    azurerm_network_security_rule.ras_outbound,
    azurerm_network_security_rule.azure_outbound,
    azurerm_network_security_rule.bastion_host_communication_oubound,
    azurerm_network_security_rule.get_session_oubound,
  ]
}

resource azurerm_bastion_host managed_bastion {
  name                         = "${var.resource_group_name}-bastion"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  ip_configuration {
    name                       = "bastion-ipconfig"
    subnet_id                  = var.subnet_id
    public_ip_address_id       = azurerm_public_ip.bastion_pip.id
  }

  tags                         = var.tags

  depends_on                   = [azurerm_subnet_network_security_group_association.bastion_nsg]
}

resource azurerm_monitor_diagnostic_setting bastion_logs {
  name                         = "${azurerm_bastion_host.managed_bastion.name}-logs"
  target_resource_id           = azurerm_bastion_host.managed_bastion.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  log {
    category                   = "BastionAuditLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
} 