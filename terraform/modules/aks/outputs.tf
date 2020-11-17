output client_certificate {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
}

output kube_config {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
}

output kubernetes_client_certificate {
  value = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate
}
output kubernetes_client_key {
  value = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key
}
output kubernetes_cluster_ca_certificate {
  value = azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate
}
output kubernetes_host {
  value = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
}

output kubernetes_version {
  value = data.azurerm_kubernetes_service_versions.current.latest_version
}

output node_resource_group {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}