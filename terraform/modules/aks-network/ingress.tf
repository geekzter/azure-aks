# Azure Internal Load Balancer
resource kubernetes_service internal_load_balancer {
  metadata {
    annotations                = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
    }
    name                       = "azure-all-front"
  }
  spec {
    selector                   = {
      app                      = "azure-all-front"
    }
    session_affinity           = "ClientIP"
    port {
      port                     = 80
    }

    type                       = "LoadBalancer"
  }

  depends_on                   = [
    null_resource.application_gateway_add_on, # HACK; If AGiC can be provisioned, surely this can be provisioned
  ]

  count                        = var.peer_network_id != "" ? 1 : 0
}

locals {
   application_gateway_name    = "${var.resource_group_name}-waf"
}

# https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-new
# TODO: Use Terraform resource once supported: https://github.com/terraform-providers/terraform-provider-azurerm/issues/7384
resource null_resource application_gateway_add_on {
  triggers = {
    aks_id                     = data.azurerm_kubernetes_cluster.aks.id
    always                     = timestamp()
  }

  provisioner local-exec { 
    interpreter                = ["pwsh", "-nop", "-c"]
    command                    = "./configure_app_gw.ps1 -AksName ${data.azurerm_kubernetes_cluster.aks.name} -ApplicationGatewayName ${local.application_gateway_name} -ResourceGroupName ${var.resource_group_name} -ApplicationGatewaySubnetID ${var.application_gateway_subnet_id}"
    environment                = {
      AZURE_EXTENSION_USE_DYNAMIC_INSTALL = "yes_without_prompt"
    }  
    working_dir                = "../scripts"
  }

  depends_on                   = [
    azurerm_firewall_network_rule_collection.iag_net_outbound_rules,
    azurerm_firewall_application_rule_collection.aks_app_rules,
    azurerm_private_dns_zone_virtual_network_link.api_server_domain,
  ]

  count                        = var.deploy_agic ? 1 : 0
}

data azurerm_public_ip application_gateway_public_ip {
  name                         = "${local.application_gateway_name}-appgwpip"
  resource_group_name          = data.azurerm_kubernetes_cluster.aks.node_resource_group

  depends_on                   = [null_resource.application_gateway_add_on]

  count                        = var.deploy_agic ? 1 : 0
}