
# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-network-rules
# Rules that have a dependency on AKS being created first
resource azurerm_firewall_network_rule_collection iag_net_outbound_rules {
  name                         = "${data.azurerm_firewall.gateway.name}-aks-network-rules"
  azure_firewall_name          = data.azurerm_firewall.gateway.name
  resource_group_name          = data.azurerm_firewall.gateway.resource_group_name
  priority                     = 1002
  action                       = "Allow"

  rule {
    name                       = "AllowOutboundAKSAPIServer1"
    source_ip_groups           = [var.nodes_ip_group_id]
    destination_ports          = ["1194"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    # destination_addresses      = [
    #   "AzureCloud.${data.azurerm_firewall.gateway.location}",
    # ]
    protocols                  = ["UDP"]
  }
  
  rule {
    name                       = "AllowOutboundAKSAPIServer2"
    source_ip_groups           = [var.nodes_ip_group_id]
    destination_ports          = ["9000"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    # destination_addresses      = [
    #   "AzureCloud.${data.azurerm_firewall.gateway.location}",
    # ]
    protocols                  = ["TCP"]
  }
  
  rule {
    name                       = "AllowOutboundAKSAPIServerHTTPS"
    source_ip_groups           = [var.nodes_ip_group_id]
    destination_ports          = ["443"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    # destination_addresses      = [
    #   "AzureCloud.${data.azurerm_firewall.gateway.location}",
    # ]
    protocols                  = ["TCP"]
  }
  
  rule {
    name                       = "AllowOutboundAKSAzureMonitor"
    source_ip_groups           = [var.nodes_ip_group_id]
    destination_ports          = ["443"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    destination_addresses      = [
      "AzureMonitor",
    ]
    protocols                  = ["TCP"]
  }

  rule {
    name                       = "AllowOutboundAKSAzureDevSpaces"
    source_ip_groups           = [var.nodes_ip_group_id]
    destination_ports          = ["443"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    destination_addresses      = [
      "AzureDevSpaces",
    ]
    protocols                  = ["TCP"]
  }
}

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
resource azurerm_firewall_application_rule_collection aks_app_rules {
  name                         = "${data.azurerm_firewall.gateway.name}-aks-app-rules"
  azure_firewall_name          = data.azurerm_firewall.gateway.name
  resource_group_name          = data.azurerm_firewall.gateway.resource_group_name
  priority                     = 2002
  action                       = "Allow"

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
  rule {
    name                       = "Allow outbound traffic"

    source_ip_groups           = [var.nodes_ip_group_id]
    target_fqdns               = [
      "*.hcp.${data.azurerm_kubernetes_cluster.aks.location}.azmk8s.io",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }
} 