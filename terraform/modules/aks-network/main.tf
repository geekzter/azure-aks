data azurerm_resource_group rg {
  name                         = var.resource_group_name
}

data azurerm_kubernetes_cluster aks {
  name                         = element(split("/",var.aks_id),length(split("/",var.aks_id))-1)
  resource_group_name          = element(split("/",var.aks_id),length(split("/",var.aks_id))-5)
}

data azurerm_firewall iag {
  name                         = element(split("/",var.firewall_id),length(split("/",var.firewall_id))-1)
  resource_group_name          = element(split("/",var.firewall_id),length(split("/",var.firewall_id))-5)
}

data azurerm_public_ip iag_pip {
  name                         = element(split("/",data.azurerm_firewall.iag.ip_configuration.0.public_ip_address_id),length(split("/",data.azurerm_firewall.iag.ip_configuration.0.public_ip_address_id))-1)
  resource_group_name          = element(split("/",data.azurerm_firewall.iag.ip_configuration.0.public_ip_address_id),length(split("/",data.azurerm_firewall.iag.ip_configuration.0.public_ip_address_id))-5)
}

data azurerm_subnet nodes_subnet {
  name                         = element(split("/",var.subnet_id),length(split("/",var.subnet_id))-1)
  virtual_network_name         = element(split("/",var.subnet_id),length(split("/",var.subnet_id))-3)
  resource_group_name          = element(split("/",var.subnet_id),length(split("/",var.subnet_id))-7)
}

# "az network private-dns record-set list -z 80e0f086-6949-4e86-ae85-185fc246d53d.privatelink.westeurope.azmk8s.io -g mc_k8s-default-qcmv_aks-default-qcmv_westeurope --query "[].aRecords[] | [0]" "
data external image_info {
  program                      = [
                                 "az",
                                 "network",
                                 "private-dns",
                                 "record-set",
                                 "list",
                                 "-g",
                                 data.azurerm_kubernetes_cluster.aks.node_resource_group,
                                 "-z",
                                 local.api_server_domain,
                                 "--query",
                                 "[].aRecords[] | [0]",
                                 "-o",
                                 "json",
                                 ]
}

locals {
  api_server_domain            = join(".",slice(split(".",local.api_server_host),1,length(split(".",local.api_server_host))))
  api_server_host              = regex("^(?:(?P<scheme>[^:/?#]+):)?(?://(?P<host>[^:/?#]*))?", data.azurerm_kubernetes_cluster.aks.kube_admin_config.0.host).host
  kubernetes_api_ip_address    = data.external.image_info.result.ipv4Address
}

resource azurerm_ip_group api_server {
  name                         = "${data.azurerm_resource_group.rg.name}-ipgroup-apiserver"
  location                     = data.azurerm_resource_group.rg.location
  resource_group_name          = data.azurerm_resource_group.rg.name
  cidrs                        = data.azurerm_kubernetes_cluster.aks.api_server_authorized_ip_ranges

  tags                         = data.azurerm_resource_group.rg.tags
}

resource azurerm_ip_group nodes {
  name                         = "${data.azurerm_resource_group.rg.name}-ipgroup-nodes"
  location                     = data.azurerm_resource_group.rg.location
  resource_group_name          = data.azurerm_resource_group.rg.name
  cidrs                        = data.azurerm_subnet.nodes_subnet.address_prefixes

  tags                         = data.azurerm_resource_group.rg.tags
}

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-network-rules
resource azurerm_firewall_network_rule_collection iag_net_outbound_rules {
  name                         = "${data.azurerm_firewall.iag.name}-aks-network-rules"
  azure_firewall_name          = data.azurerm_firewall.iag.name
  resource_group_name          = data.azurerm_firewall.iag.resource_group_name
  priority                     = 1001
  action                       = "Allow"

  rule {
    name                       = "AllowOutboundAKSAPIServer1"
    source_ip_groups           = [azurerm_ip_group.nodes.id]
    destination_ports          = ["1194"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    # destination_addresses      = [
    #   "AzureCloud.${data.azurerm_firewall.iag.location}",
    # ]
    protocols                  = ["UDP"]
  }
  
  rule {
    name                       = "AllowOutboundAKSAPIServer2"
    source_ip_groups           = [azurerm_ip_group.nodes.id]
    destination_ports          = ["9000"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    # destination_addresses      = [
    #   "AzureCloud.${data.azurerm_firewall.iag.location}",
    # ]
    protocols                  = ["TCP"]
  }
  
  rule {
    name                       = "AllowOutboundAKSAPIServerHTTPS"
    source_ip_groups           = [azurerm_ip_group.nodes.id]
    destination_ports          = ["443"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    # destination_addresses      = [
    #   "AzureCloud.${data.azurerm_firewall.iag.location}",
    # ]
    protocols                  = ["TCP"]
  }
  
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
    name                       = "AllowOutboundAKSAzureMonitor"
    source_ip_groups           = [azurerm_ip_group.nodes.id]
    destination_ports          = ["443"]
    destination_ip_groups      = [azurerm_ip_group.api_server.id]
    destination_addresses      = [
      "AzureMonitor",
    ]
    protocols                  = ["TCP"]
  }

  rule {
    name                       = "AllowOutboundAKSAzureDevSpaces"
    source_ip_groups           = [azurerm_ip_group.nodes.id]
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
  name                         = "${data.azurerm_firewall.iag.name}-aks-app-rules"
  azure_firewall_name          = data.azurerm_firewall.iag.name
  resource_group_name          = data.azurerm_firewall.iag.resource_group_name
  priority                     = 2001
  action                       = "Allow"

# https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
  rule {
    name                       = "Allow outbound traffic"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    target_fqdns               = [
      "*.hcp.${data.azurerm_kubernetes_cluster.aks.location}.azmk8s.io",
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
  rule {
    name                       = "Allow outbound AKS"

    source_ip_groups           = [azurerm_ip_group.nodes.id]
    fqdn_tags                  = ["AzureKubernetesService"]
  }
} 

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