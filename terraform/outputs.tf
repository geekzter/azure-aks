output client_certificate {
  sensitive   = true
  value       = module.aks.client_certificate
}

output kube_config {
  sensitive   = true
  value       = module.aks.kube_config
}

output node_resource_group {
  value       = module.aks.node_resource_group
}
