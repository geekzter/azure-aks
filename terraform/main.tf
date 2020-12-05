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
  aks_sp_application_id        = var.aks_sp_application_id
  aks_sp_object_id             = var.aks_sp_object_id
  aks_sp_application_secret    = var.aks_sp_application_secret
  create_service_principal     = (var.aks_sp_application_id == "" || var.aks_sp_object_id == "" || var.aks_sp_application_secret == "") ? true : false
  kube_config_path             = var.kube_config_path != "" ? var.kube_config_path : format("../%s/.kube/config",path.module)

# Making sure all character classes are represented, as random does not guarantee that  
  password                     = ".Az9${random_string.password.result}"
# suffix                       = random_string.suffix.result
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  environment                  = var.resource_environment != "" ? lower(var.resource_environment) : terraform.workspace
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
    "provisioner",               "terraform",
    "environment",               local.environment,
    "shutdown",                  "true",
    "suffix",                    local.suffix,
    "workspace",                 terraform.workspace,
  )
}

# resource "azurerm_key_vault" "ttconfig" {
#   name                         = "${lower(var.resource_prefix)}config${local.suffix}"
#   location                     = "${var.location}"
#   resource_group_name          = "${azurerm_resource_group.rg.name}"
#   enabled_for_disk_encryption  = true
#   tenant_id                    = "${data.azurerm_client_config.current.tenant_id}"

#   sku {
#     name                       = "standard"
#   }

#   access_policy {
#     tenant_id                  = "${data.azurerm_client_config.current.tenant_id}"
#     object_id                  = "${data.azuread_service_principal.tfidentity.object_id}"

#     certificate_permissions    = [
#       "create",
#       "delete",
#       "get",
#       "import",
#     ]

#     key_permissions            = [
#       "delete",
#       "get",
#     ]

#     secret_permissions         = [
#       "delete",
#       "get",
#     ]
#   }

#   access_policy {
#     tenant_id                  = "${data.azurerm_client_config.current.tenant_id}"
# # Microsoft.Azure.WebSites RP SPN (appId: abfa0a7c-a6b6-4736-8310-5855508787cd, objectId: f8daea97-62e7-4026-becf-13c2ea98e8b4) requires access to Key Vault
#     object_id                  = "f8daea97-62e7-4026-becf-13c2ea98e8b4"

#     certificate_permissions    = [
#       "get",
#     ]

#     key_permissions            = [
#       "get",
#     ]

#     secret_permissions         = [
#       "get",
#     ]
#   }

#   network_acls {
#     default_action             = "Deny"
#     bypass                     = "AzureServices"
#     ip_rules                   = [
#       "${var.admin_ips}",
#       "${chomp(data.http.localpublicip.body)}/32"
#     ]
#   }
  
#   tags                         = "${local.tags}"
# }

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
  name                         = "${lower(var.resource_prefix)}alaworkspace${local.suffix}"
  # Doesn't deploy in all regions e.g. South India
  location                     = var.workspace_location
  resource_group_name          = azurerm_resource_group.rg.name
  sku                          = "Standalone"
  retention_in_days            = 90 
  
  tags                         = azurerm_resource_group.rg.tags
}

# Provision base network infrastructure
module network {
  source                       = "./modules/network"
  resource_group_name          = azurerm_resource_group.rg.name
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.log_analytics.id
  peer_network_id              = var.peer_network_id
  subnets                      = [
    "nodes"
  ]
}

# Provision base Kubernetes infrastructure provided by Azure
module aks {
  source                       = "./modules/aks"
  name                         = local.aks_name

  admin_username               = "aksadmin"
  client_object_id             = data.azurerm_client_config.current.object_id
  dns_prefix                   = "ew-aks"
  location                     = var.location
  kube_config_path             = local.kube_config_path
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.log_analytics.id
  node_subnet_id               = module.network.subnet_ids["nodes"]
  resource_group_id            = azurerm_resource_group.rg.id
  sp_application_id            = local.aks_sp_application_id
  sp_application_secret        = local.aks_sp_application_secret
  sp_object_id                 = local.aks_sp_object_id
  ssh_public_key_file          = var.ssh_public_key_file
  tags                         = azurerm_resource_group.rg.tags

  count                        = var.deploy_aks ? 1 : 0
  depends_on                   = [module.network]
}

# Provision AKS network infrastructure (allowing dependencies on AKS)
module aks_network {
  source                       = "./modules/aks-network"
  resource_group_name          = local.resource_group_name

  admin_ip_group_id            = module.network.admin_ip_group_id
  aks_id                       = module.aks.0.aks_id
  #application_gateway_id       = module.network.application_gateway_id
  application_gateway_subnet_id= module.network.application_gateway_subnet_id
  deploy_agic                  = var.deploy_agic
  firewall_id                  = module.network.firewall_id
  location                     = var.location
  nodes_subnet_id              = module.network.subnet_ids["nodes"]
  peer_network_id              = var.peer_network_id
  tags                         = azurerm_resource_group.rg.tags

  count                        = var.deploy_aks ? 1 : 0
  depends_on                   = [module.aks,module.network]
}

# Confugure Kubernetes
module k8s {
  source                       = "./modules/kubernetes"

  count                        = var.deploy_aks && var.configure_kubernetes ? 1 : 0
  depends_on                   = [module.aks,module.aks_network]
}