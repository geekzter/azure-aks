resource random_string password {
  length                       = 12
  upper                        = true
  lower                        = true
  number                       = true
  special                      = true
# override_special             = "!@#$%&*()-_=+[]{}<>:?" # default
# Avoid characters that may cause shell scripts to break
  override_special             = "." 
}

resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  number                       = false
  special                      = false
}

locals {
  aks_name                     = "${var.resource_prefix}-${terraform.workspace}-${local.suffix}"
  owner                        = var.application_owner != "" ? var.application_owner : data.azuread_client_config.current.object_id
  kube_config_relative_path    = var.kube_config_path != "" ? var.kube_config_path : "../.kube/${local.workspace_moniker}config"
  kube_config_absolute_path    = var.kube_config_path != "" ? var.kube_config_path : "${path.root}/../.kube/${local.workspace_moniker}config"

# Making sure all character classes are represented, as random does not guarantee that  
  password                     = ".Az9${random_string.password.result}"
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  environment                  = var.resource_environment != "" ? lower(var.resource_environment) : terraform.workspace
  workspace_moniker            = terraform.workspace == "default" ? "" : terraform.workspace
}

data azuread_client_config current {}
data azurerm_client_config current {}
data azurerm_subscription primary {}

data http localpublicip {
# Get public IP address of the machine running this terraform template
  url                          = "https://ipinfo.io/ip"
}

resource azurerm_resource_group rg {
  name                         = "${lower(var.resource_prefix)}-${lower(local.environment)}-${lower(local.suffix)}"
  location                     = var.location

  tags                         = {
    application                = var.application_name
    environment                = local.environment
    github-repo                = "https://github.com/geekzter/azure-aks"
    owner                      = local.owner
    provisioner                = "terraform"
    provisioner-client-id      = data.azurerm_client_config.current.client_id
    provisioner-object-id      = data.azuread_client_config.current.object_id
    repository                 = "azure-aks"
    runid                      = var.run_id
    shutdown                   = "true"
    suffix                     = local.suffix
    workspace                  = terraform.workspace
  }
}

resource azurerm_container_registry acr {
  name                         = "${lower(replace(var.resource_prefix,"/\\W/",""))}${terraform.workspace}reg${local.suffix}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  sku                          = "Premium"
  admin_enabled                = true
 
  tags                         = azurerm_resource_group.rg.tags
}
resource azurerm_monitor_diagnostic_setting acr {
  name                         = "${azurerm_container_registry.acr.name}-logs"
  target_resource_id           = azurerm_container_registry.acr.id
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.log_analytics.id

  log {
    category                   = "ContainerRegistryRepositoryEvents"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "ContainerRegistryLoginEvents"
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

resource azurerm_log_analytics_workspace log_analytics {
  name                         = "${azurerm_resource_group.rg.name}-logs"
  # Doesn't deploy in all regions e.g. South India
  location                     = var.workspace_location
  resource_group_name          = azurerm_resource_group.rg.name
  sku                          = "Standalone"
  retention_in_days            = 90 
  
  tags                         = azurerm_resource_group.rg.tags
}
resource azurerm_log_analytics_saved_search query {
  name                         = each.value
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.log_analytics.id

  category                     = "Favorites"
  display_name                 = replace(replace(each.value,"-"," "),".kql","")
  query                        = file("${path.root}/../kusto/${each.value}")

  for_each                     = toset([
    "denied-outbound-http-traffic.kql",
    "denied-outbound-traffic.kql",
  ])
}