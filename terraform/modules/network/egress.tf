
# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-network-rules
# Only rules that have no dependency on AKS being created first
resource azurerm_firewall_network_rule_collection iag_net_outbound_rules {
  name                         = "${azurerm_firewall.iag.name}-network-rules"
  azure_firewall_name          = azurerm_firewall.iag.name
  resource_group_name          = azurerm_firewall.iag.resource_group_name
  priority                     = 1001
  action                       = "Allow"

  # rule {
  #   name                       = "AllowOutboundAKSAPIServer1"
  #   source_ip_groups           = [data.azurerm_ip_group.nodes.id]
  #   destination_ports          = ["1194"]
  #   destination_addresses      = [
  #     "AzureCloud.${data.azurerm_resource_group.rg.location}",
  #   ]
  #   protocols                  = ["UDP"]
  # }
  # rule {
  #   name                       = "AllowOutboundAKSAPIServer2"
  #   source_ip_groups           = [data.azurerm_ip_group.nodes.id]
  #   destination_ports          = ["9000"]
  #   destination_addresses      = [
  #     "AzureCloud.${data.azurerm_resource_group.rg.location}",
  #   ]
  #   protocols                  = ["TCP"]
  # }
  # rule {
  #   name                       = "AllowOutboundAKSAPIServerHTTPS"
  #   source_ip_groups           = [data.azurerm_ip_group.nodes.id]
  #   destination_ports          = ["443"]
  #   destination_addresses      = [
  #     "AzureCloud.${data.azurerm_resource_group.rg.location}",
  #   ]
  #   protocols                  = ["TCP"]
  # }
  
  rule {
    name                       = "AllowUbuntuNTP"
    source_ip_groups           = [azurerm_ip_group.nodes.id]
    destination_ports          = ["123"]
    destination_fqdns          = [
      "ntp.ubuntu.com",
    ]
    protocols                  = ["UDP"]
  }
  rule {
    name                       = "AllowNTP"
    source_ip_groups           = [azurerm_ip_group.nodes.id]
    destination_ports          = ["123"]
    destination_fqdns          = [
      "pool.ntp.org",
    ]
    protocols                  = ["UDP"]
  }
}

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
resource azurerm_firewall_application_rule_collection aks_app_rules {
  name                         = "${azurerm_firewall.iag.name}-app-rules"
  azure_firewall_name          = azurerm_firewall.iag.name
  resource_group_name          = azurerm_firewall.iag.resource_group_name
  priority                     = 2001
  action                       = "Allow"

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
  rule {
    name                       = "Allow outbound traffic"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "*.hcp.${data.azurerm_resource_group.rg.location}.azmk8s.io",
      "mcr.microsoft.com",
      "*.data.mcr.microsoft.com",
      "management.azure.com",
      "login.microsoftonline.com",
      "packages.microsoft.com",
      "acs-mirror.azureedge.net",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#optional-recommended-fqdn--application-rules-for-aks-clusters
  rule {
    name                       = "Allow outbound AKS optional traffic (recommended)"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "security.ubuntu.com",
      "azure.archive.ubuntu.com",
      "changelogs.ubuntu.com",
    ]

    protocol {
      port                     = "80"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#gpu-enabled-aks-clusters
  rule {
    name                       = "Allow outbound AKS optional traffic (GPU enabled nodes)"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "nvidia.github.io",
      "*.download.nvidia.com",
      "apt.dockerproject.org",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#gpu-enabled-aks-clusters
  rule {
    name                       = "Allow outbound AKS optional traffic (Windows enabled nodes)"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "onegetcdn.azureedge.net",
      "go.microsoft.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#gpu-enabled-aks-clusters
  rule {
    name                       = "Allow outbound AKS optional traffic (Windows enabled nodes, port 80)"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "*.mp.microsoft.com",
      "www.msftconnecttest.com",
      "ctldl.windowsupdate.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-monitor-for-containers
  rule {
    name                       = "Allow outbound AKS Azure Monitor traffic"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "dc.services.visualstudio.com",
      "*.ods.opinsights.azure.com",
      "*.oms.opinsights.azure.com",
      "*.monitoring.azure.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-dev-spaces
  rule {
    name                       = "Allow outbound AKS Dev Spaces"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "cloudflare.docker.com",
      "gcr.io",
      "storage.googleapis.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-policy
  rule {
    name                       = "Allow outbound AKS Azure Policy"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "data.policy.core.windows.net",
      "store.policy.core.windows.net",
      "gov-prod-policy-data.trafficmanager.net",
      "raw.githubusercontent.com",
      "dc.services.visualstudio.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#restrict-egress-traffic-using-azure-firewall
  # rule {
  #   name                       = "Allow outbound AKS"

  #   source_ip_groups           = [azurerm_ip_group.nodes.id]
  #   fqdn_tags                  = ["AzureKubernetesService"]
  # }

  # Traffic required, but not documented
  rule {
    name                       = "Allow misc container management traffic"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "api.snapcraft.io",
      "auth.docker.io",
      "motd.ubuntu.com",
      "production.cloudflare.docker.com",
      "registry-1.docker.io",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }
  
} 