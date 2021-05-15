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