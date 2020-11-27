output internal_load_balancer_ip_address {
  value = kubernetes_service.internal_load_balancer.load_balancer_ingress[0].ip
}

output kubernetes_ip_address {
  value = local.kubernetes_api_ip_address
}