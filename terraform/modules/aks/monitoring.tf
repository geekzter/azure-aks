
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

  log {
    category                   = "kube-apiserver"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "kube-audit"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "kube-audit-admin"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "kube-controller-manager"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "kube-scheduler"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "cluster-autoscaler"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "guard"
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

resource azurerm_monitor_diagnostic_setting application_gateway_logs {
  name                         = "${split("/",azurerm_kubernetes_cluster.aks.addon_profile[0].ingress_application_gateway[0].effective_gateway_id)[8]}-logs"
  target_resource_id           = azurerm_kubernetes_cluster.aks.addon_profile[0].ingress_application_gateway[0].effective_gateway_id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  log {
    category                   = "ApplicationGatewayAccessLog"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "ApplicationGatewayPerformanceLog"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "ApplicationGatewayFirewallLog"
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