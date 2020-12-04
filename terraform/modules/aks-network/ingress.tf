# # Inbound port forwarding rules
# resource azurerm_firewall_nat_rule_collection iag_nat_rules {
#   name                         = "${data.azurerm_firewall.iag.name}-aks-fwd-rules"
#   azure_firewall_name          = data.azurerm_firewall.iag.name
#   resource_group_name          = data.azurerm_firewall.iag.resource_group_name
#   priority                     = 1002
#   action                       = "Dnat"

#   # API Server
#   rule {
#     name                       = "AllowInboundAPIServer"
#     source_ip_groups           = [var.admin_ip_group_id]
#     destination_ports          = [split(":",data.azurerm_kubernetes_cluster.aks.kube_admin_config.0.host)[2]]
#     destination_addresses      = [data.azurerm_public_ip.iag_pip.ip_address]
#     translated_port            = split(":",data.azurerm_kubernetes_cluster.aks.kube_admin_config.0.host)[2]
#     translated_address         = local.kubernetes_api_ip_address
#     protocols                  = ["TCP"]
#   }
# }

# Azure Internal Load Balancer
resource kubernetes_service internal_load_balancer {
  metadata {
    annotations                = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
    }
    name                       = "azure-all-front"
  }
  spec {
    #load_balancer_ip           = local.load_balancer_ip_address
    selector                   = {
      app                      = "azure-all-front"
    }
    session_affinity           = "ClientIP"
    port {
      port                     = 80
      #target_port              = 80
    }

    type                       = "LoadBalancer"
  }

  depends_on                   = [
    azurerm_private_dns_zone_virtual_network_link.api_server_domain
  ]

  count                        = var.peer_network_id != "" ? 1 : 0
}

locals {
   application_gateway_name    = "${var.resource_group_name}-waf"
}

# https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-new
resource null_resource application_gateway_add_on {
  triggers = {
    aks_id                     = data.azurerm_kubernetes_cluster.aks.id
    always                     = timestamp()
  }

  provisioner local-exec { 
    interpreter                = ["pwsh", "-nop", "-c"]
    command                    = "./configure_app_gw.ps1 -AksName ${data.azurerm_kubernetes_cluster.aks.name} -ApplicationGatewayName ${local.application_gateway_name} -ResourceGroupName ${var.resource_group_name} -ApplicationGatewaySubnetID ${var.application_gateway_subnet_id}"
    working_dir                = "../scripts"
    # environment                = {
    #   KUBECONFIG               = var.kube_config_path
    # }
  }

  count                        = var.deploy_agic ? 1 : 0
}

data azurerm_public_ip application_gateway_public_ip {
  name                         = "${local.application_gateway_name}-appgwpip"
  resource_group_name          = data.azurerm_kubernetes_cluster.aks.node_resource_group

  depends_on                   = [null_resource.application_gateway_add_on]

  count                        = var.deploy_agic ? 1 : 0
}