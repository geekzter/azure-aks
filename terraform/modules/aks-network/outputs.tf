output internal_load_balancer_ip_address {
  value = var.peer_network_id != "" ? kubernetes_service.internal_load_balancer.0.load_balancer_ingress[0].ip : null
}

output kubernetes_ip_address {
  value = local.kubernetes_api_ip_address
}