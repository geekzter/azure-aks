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
  aks_name                     = "aks-${terraform.workspace}-${local.suffix}"
  # aks_sp_application_id        = local.create_service_principal ? module.service_principal.0.application_id : var.aks_sp_application_id
  # aks_sp_object_id             = local.create_service_principal ? module.service_principal.0.object_id : var.aks_sp_object_id
  # aks_sp_application_secret    = local.create_service_principal ? module.service_principal.0.secret : var.aks_sp_application_secret
  create_service_principal     = (var.aks_sp_application_id == "" || var.aks_sp_object_id == "" || var.aks_sp_application_secret == "") ? true : false
  kube_config_path             = var.kube_config_path != "" ? var.kube_config_path : "${path.root}/../.kube/${local.workspace_moniker}config"

# Making sure all character classes are represented, as random does not guarantee that  
  password                     = ".Az9${random_string.password.result}"
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  environment                  = var.resource_environment != "" ? lower(var.resource_environment) : terraform.workspace
  workspace_moniker            = terraform.workspace == "default" ? "" : terraform.workspace
  resource_group_name          = "${lower(var.resource_prefix)}-${lower(local.environment)}-${lower(local.suffix)}"
}

# Usage: https://www.terraform.io/docs/providers/azurerm/d/client_config.html
data azurerm_client_config current {}
data azurerm_subscription primary {}

data http localpublicip {
# Get public IP address of the machine running this terraform template
  url                          = "https://ipinfo.io/ip"
}

resource azurerm_resource_group rg {
  name                         = local.resource_group_name
  location                     = var.location

  tags                         = map(
    "application",               "Kubernetes",
    "environment",               local.environment,
    "provisioner",               "terraform",
    "repository",                basename(abspath("${path.root}/..")),
    "runid",                     var.run_id,
    "shutdown",                  "true",
    "suffix",                    local.suffix,
    "workspace",                 terraform.workspace,
  )
}

resource azurerm_container_registry acr {
  name                         = "${lower(var.resource_prefix)}reg${local.suffix}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  sku                          = "Basic"
  admin_enabled                = true
# georeplication_locations     = ["East US", "West Europe"]
 
  tags                         = azurerm_resource_group.rg.tags
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