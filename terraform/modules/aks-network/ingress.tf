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

locals {
    # Use the last ip address in the subnet as the load balancer address
    # data.azurerm_subnet.nodes_subnet.address_prefixes[0]
    # pow(2,32-split("/",data.azurerm_subnet.nodes_subnet.address_prefixes[0]))
    load_balancer_ip_address   = cidrhost(data.azurerm_subnet.nodes_subnet.address_prefixes[0], pow(2,32-split("/",data.azurerm_subnet.nodes_subnet.address_prefixes[0])[1])-1)
    # cidrhost("10.32.16.0/20", pow(2,32-split("/","10.32.16.0/20")[1])-1)
}

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
}