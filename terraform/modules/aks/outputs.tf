output aks_id {
  value       = azurerm_kubernetes_cluster.aks.id
}

output application_gateway_id {
  value       = var.deploy_application_gateway ? azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].effective_gateway_id : null
}

output application_gateway_fqdn {
  value       = var.deploy_application_gateway ? data.azurerm_public_ip.application_gateway_public_ip.0.fqdn : null
}

output application_gateway_public_ip {
  value       = var.deploy_application_gateway ? data.azurerm_public_ip.application_gateway_public_ip.0.ip_address : null
}

output kube_config {
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config_raw
}

output kubernetes_api_server_ip_address {
  value       = var.private_cluster_enabled ? data.azurerm_private_endpoint_connection.api_server_endpoint[0].private_service_connection.0.private_ip_address : null
}
output kubernetes_client_certificate {
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate
}
output kubernetes_client_key {
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key
}
output kubernetes_cluster_ca_certificate {
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate
}
output kubernetes_host {
  sensitive   = true
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
}

output kubernetes_version {
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output node_pool_scale_set_id {
  value       = data.azurerm_resources.scale_sets.resources[0].id
}

output node_resource_group {
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}