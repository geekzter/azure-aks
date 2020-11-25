output aks_name {
  value       = var.deploy_aks ? local.aks_name : null
}

output firewall_fqdn {
  value       = module.network.firewall_fqdn
}

output kube_config {
  sensitive   = true
  value       = var.deploy_aks ? module.aks.0.kube_config : null
}

output kubernetes_client_certificate {
  sensitive   = true
  value       = var.deploy_aks ? module.aks.0.kubernetes_client_certificate : null
}

output kubernetes_host {
  value       = var.deploy_aks ? module.aks.0.kubernetes_host : null
}

output node_resource_group {
  value       = var.deploy_aks ? module.aks.0.node_resource_group : null
}

output resource_group {
  value       = azurerm_resource_group.rg.name
}
