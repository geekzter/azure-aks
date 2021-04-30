output address_space {
  value       = var.address_space
}

output application_gateway_id {
  value       = var.deploy_aks ? module.aks.0.application_gateway_id : null
}
output application_gateway_public_ip {
  value       = var.deploy_aks ? module.aks.0.application_gateway_public_ip : null
}

output aks_name {
  value       = var.deploy_aks ? local.aks_name : null
}

output connectivity_message {
  value       = var.peer_network_id == "" ? "No peering configured. You will NOT be able to deploy applications from this host." : null  
}

output firewall_fqdn {
  value       = module.network.firewall_fqdn
}

output kube_config {
  # sensitive   = true
  value       = var.deploy_aks ? module.aks.0.kube_config : null
}

output kube_config_base64 {
  sensitive   = true
  value       = var.deploy_aks ? base64encode(module.aks.0.kube_config) : null
}
output kube_config_path {
  # Return machine independent relative path
  value       = local.kube_config_relative_path
}

output kubernetes_api_server_ip_address {
  value       = var.deploy_aks ? module.aks.0.kubernetes_api_server_ip_address : null
}

output kubernetes_client_certificate {
  sensitive   = true
  value       = var.deploy_aks ? chomp(module.aks.0.kubernetes_client_certificate) : null
}

output kubernetes_host {
  value       = var.deploy_aks ? module.aks.0.kubernetes_host : null
}

output kubernetes_version {
  value       = var.deploy_aks ? module.aks.0.kubernetes_version : null
}

output node_resource_group {
  value       = var.deploy_aks ? module.aks.0.node_resource_group : null
}

output peered_network {
  value       = var.peer_network_id != "" ? true : false
}

output resource_group {
  value       = azurerm_resource_group.rg.name
}
output resource_suffix {
  value       = local.suffix
}