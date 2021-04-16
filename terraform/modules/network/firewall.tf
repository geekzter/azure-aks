resource random_string iag_domain_name_label {
  length                      = 16
  upper                       = false
  lower                       = true
  number                      = false
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
  cidrs                        = [
    for subnet in azurerm_subnet.subnet : subnet.address_prefixes[0]
  ]

  tags                         = var.tags
}

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#restrict-egress-traffic-using-azure-firewall
# We recommend having a minimum of 20 Frontend IPs on the Azure Firewall for production scenarios to avoid incurring in SNAT port exhaustion issues.
resource azurerm_public_ip iag_pip {
  name                         = "${var.resource_group_name}-iag-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard" # Zone redundant
  domain_name_label            = random_string.iag_domain_name_label.result

  tags                         = var.tags
}

resource azurerm_firewall iag {
  name                         = "${var.resource_group_name}-iag"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  dns_servers                  = var.dns_servers

  # Make zone redundant
  zones                        = [1,2,3]

  ip_configuration {
    name                       = "iag_ipconfig"
    subnet_id                  = azurerm_subnet.iag_subnet.id
    public_ip_address_id       = azurerm_public_ip.iag_pip.id
  }

  tags                         = var.tags
}

resource azurerm_monitor_diagnostic_setting iag_logs {
  name                         = "${azurerm_firewall.iag.name}-logs"
  target_resource_id           = azurerm_firewall.iag.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  log {
    category                   = "AzureFirewallApplicationRule"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "AzureFirewallNetworkRule"
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