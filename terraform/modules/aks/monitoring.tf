
data azurerm_log_analytics_workspace log_analytics {
  name                         = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-1)
  resource_group_name          = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-5)
}

resource azurerm_log_analytics_solution log_analytics_solution {
  solution_name                = "ContainerInsights" 
  location                     = var.location
  resource_group_name          = data.azurerm_log_analytics_workspace.log_analytics.resource_group_name
  workspace_resource_id        = var.log_analytics_workspace_id
  workspace_name               = data.azurerm_log_analytics_workspace.log_analytics.name

  plan {
    publisher                  = "Microsoft"
    product                    = "OMSGallery/ContainerInsights"
  }
} 

resource azurerm_monitor_diagnostic_setting aks {
  name                         = "${azurerm_kubernetes_cluster.aks.name}-logs"
  target_resource_id           = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  enabled_log {
    category                   = "kube-apiserver"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category                   = "kube-audit"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category                   = "kube-audit-admin"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category                   = "kube-controller-manager"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category                   = "kube-scheduler"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category                   = "cluster-autoscaler"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category                   = "guard"

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

resource azurerm_monitor_diagnostic_setting application_gateway_logs {
  name                         = "${split("/",azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].effective_gateway_id)[8]}-logs"
  target_resource_id           = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].effective_gateway_id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  enabled_log {
    category                   = "ApplicationGatewayAccessLog"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category                   = "ApplicationGatewayPerformanceLog"

    retention_policy {
      enabled                  = false
    }
  }
  enabled_log {
    category                   = "ApplicationGatewayFirewallLog"

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

  count                        = var.deploy_application_gateway ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting scale_set {
  name                         = "${split("/",data.azurerm_resources.scale_sets.resources[0].id)[8]}-logs"
  target_resource_id           = data.azurerm_resources.scale_sets.resources[0].id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }

  lifecycle {
    ignore_changes             = [
      # New values are not known after plan stage, but won't change
      name,
      target_resource_id 
    ]
  }
} 