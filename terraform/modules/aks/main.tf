data azurerm_resource_group rg {
  name                         = var.resource_group_name
}

data azurerm_log_analytics_workspace log_analytics {
  name                         = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-1)
  resource_group_name          = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-5)
}

resource azurerm_log_analytics_solution log_analytics_solution {
  solution_name                = "ContainerInsights" 
  location                     = data.azurerm_log_analytics_workspace.log_analytics.location
  resource_group_name          = data.azurerm_log_analytics_workspace.log_analytics.resource_group_name
  workspace_resource_id        = data.azurerm_log_analytics_workspace.log_analytics.id
  workspace_name               = data.azurerm_log_analytics_workspace.log_analytics.name

  plan {
    publisher                  = "Microsoft"
    product                    = "OMSGallery/ContainerInsights"
  }
} 