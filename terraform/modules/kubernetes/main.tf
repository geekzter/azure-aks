data azurerm_client_config current {}

# Cluster role binding to AAD group
resource kubernetes_cluster_role_binding terraform_admin {
  metadata {
    name                        = "terraform"
  }
  role_ref {
    api_group                   = "rbac.authorization.k8s.io"
    kind                        = "ClusterRole"
    name                        = "cluster-admin"
  }
  subject {
    kind                        = "User"
    name                        = data.azurerm_client_config.current.client_id
  }
}

# Make sure proxy access to dashboard works
resource kubernetes_cluster_role_binding dashboard {
  metadata {
    name                       = "kubernetes-dashboard"
  }

  role_ref {
    api_group                  = "rbac.authorization.k8s.io"
    kind                       = "ClusterRole"
    name                       = "cluster-admin"
  }

  subject {
    api_group                  = ""
    kind                       = "ServiceAccount"
    name                       = "kubernetes-dashboard"
    namespace                  = "kube-system"
  }
}

