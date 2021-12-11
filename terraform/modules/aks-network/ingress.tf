# Azure Internal Load Balancer provisioned by application (manifest)
# resource kubernetes_service internal_load_balancer {
#   metadata {
#     annotations                = {
#       "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
#     }
#     name                       = "azure-all-front"
#   }
#   spec {
#     selector                   = {
#       app                      = "azure-all-front"
#     }
#     session_affinity           = "ClientIP"
#     port {
#       port                     = 80
#     }

#     type                       = "LoadBalancer"
#   }

#   depends_on                   = [
#     azurerm_firewall_network_rule_collection.iag_net_outbound_rules,
#     azurerm_firewall_application_rule_collection.aks_app_rules,
#     azurerm_private_dns_zone_virtual_network_link.api_server_domain,
#   ]

#   count                        = var.peer_network_id != "" ? 1 : 0
# }

# Application Ingress controller is created as AKS add on