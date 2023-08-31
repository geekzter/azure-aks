resource random_string firewall_domain_name_label {
  length                      = 16
  upper                       = false
  lower                       = true
  numeric                     = false
  special                     = false
}

resource azurerm_ip_group admin {
  name                         = "${var.resource_group_name}-ipgroup-admin"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  cidrs                        = local.admin_cidrs

  tags                         = var.tags
}

resource azurerm_ip_group nodes {
  name                         = "${var.resource_group_name}-ipgroup-nodes"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  cidrs                        = azurerm_subnet.nodes_subnet.address_prefixes

  tags                         = var.tags
}

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#restrict-egress-traffic-using-azure-firewall
# We recommend having a minimum of 20 Frontend IPs on the Azure Firewall for production scenarios to avoid incurring in SNAT port exhaustion issues.
resource azurerm_public_ip firewall_pip {
  name                         = "${var.resource_group_name}-iag-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard" # Zone redundant
  domain_name_label            = random_string.firewall_domain_name_label.result

  tags                         = var.tags
}
resource azurerm_monitor_diagnostic_setting firewall_pip {
  name                         = "${azurerm_public_ip.firewall_pip.name}-logs"
  target_resource_id           = azurerm_public_ip.firewall_pip.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  enabled_log {
    category                   = "DDoSProtectionNotifications"
  }
  enabled_log {
    category                   = "DDoSMitigationFlowLogs"
  }
  enabled_log {
    category                   = "DDoSMitigationReports"
  }  

  metric {
    category                   = "AllMetrics"
  }
} 

resource azurerm_firewall gateway {
  name                         = "${var.resource_group_name}-iag"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku_name                     = "AZFW_VNet"
  sku_tier                     = "Standard"
  
  dns_servers                  = var.dns_servers

  ip_configuration {
    name                       = "firewall_ipconfig"
    subnet_id                  = azurerm_subnet.firewall_subnet.id
    public_ip_address_id       = azurerm_public_ip.firewall_pip.id
  }

  tags                         = var.tags
}

resource azurerm_monitor_diagnostic_setting firewall_logs {
  name                         = "${azurerm_firewall.gateway.name}-logs"
  target_resource_id           = azurerm_firewall.gateway.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  enabled_log {
    category                   = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category                   = "AzureFirewallNetworkRule"
  }
  
  metric {
    category                   = "AllMetrics"
  }
}