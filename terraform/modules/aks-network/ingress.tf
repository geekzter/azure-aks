# Azure Internal Load Balancer
resource kubernetes_service internal_load_balancer {
  metadata {
    annotations                = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
    }
    name                       = "azure-all-front"
  }
  spec {
    selector                   = {
      app                      = "azure-all-front"
    }
    session_affinity           = "ClientIP"
    port {
      port                     = 80
    }

    type                       = "LoadBalancer"
  }

  count                        = var.peer_network_id != "" ? 1 : 0
}

# Application Ingress controller is created as AKS add on