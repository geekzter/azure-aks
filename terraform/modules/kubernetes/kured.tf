# https://gist.github.com/ToruMakabe/46ac0b31f7f8a07fa9a1254f862bc15c
resource kubernetes_cluster_role kured {
  metadata {
    name                       = "kured"
  }

  rule {
    api_groups                 = [""]
    resources                  = ["nodes"]
    verbs                      = ["get", "patch"]
  }

  rule {
    api_groups                 = [""]
    resources                  = ["pods"]
    verbs                      = ["list", "delete", "get"]
  }

  rule {
    api_groups                 = ["extensions"]
    resources                  = ["daemonsets"]
    verbs                      = ["get"]
  }

  rule {
    api_groups                 = [""]
    resources                  = ["pods/eviction"]
    verbs                      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "kured" {
  metadata {
    name                       = "kured"
  }

  role_ref {
    api_group                  = "rbac.authorization.k8s.io"
    kind                       = "ClusterRole"
    name                       = "kured"
  }

  subject {
    kind                       = "ServiceAccount"
    name                       = "kured"
    namespace                  = "kube-system"
  }
}

resource kubernetes_role kured {
  metadata {
    name                       = "kured"
    namespace                  = "kube-system"
  }

  rule {
    api_groups                 = ["extensions"]
    resources                  = ["daemonsets"]
    resource_names             = ["kured"]
    verbs                      = ["update"]
  }
}

resource kubernetes_role_binding kured {
  metadata {
    name                       = "kured"
    namespace                  = "kube-system"
  }

  role_ref {
    api_group                  = "rbac.authorization.k8s.io"
    kind                       = "Role"
    name                       = "kured"
  }

  subject {
    kind                       = "ServiceAccount"
    name                       = "kured"
    namespace                  = "kube-system"
  }
}

resource kubernetes_service_account kured {
  metadata {
    name                       = "kured"
    namespace                  = "kube-system"
  }
}

resource kubernetes_daemonset kured {
  metadata {
    name                       = "kured"
    namespace                  = "kube-system"
  }

  spec {
    selector {
      match_labels             = {
        name                   = "kured"
      }
    }

    strategy {
      type                     = "RollingUpdate"
    }

    template {
      metadata {
        labels                 = {
          name                 = "kured"
        }
      }

      spec {
        service_account_name   = "kured"
        host_pid               = true
        restart_policy         = "Always"

        container {
          image                = var.kured_image
          image_pull_policy    = "IfNotPresent"
          name                 = "kured"

          security_context {
            privileged         = true
          }

          env {
            name = "KURED_NODE_ID"

            value_from {
              field_ref {
                field_path     = "spec.nodeName"
              }
            }
          }

          volume_mount {
            mount_path         = "/var/run/secrets/kubernetes.io/serviceaccount"
            name               = kubernetes_service_account.kured.default_secret_name
            read_only          = true
          }

          command              = ["/usr/bin/kured"]

          resources {
            limits {
              cpu              = "50m"
              memory           = "50Mi"
            }

            requests {
              cpu              = "50m"
              memory           = "50Mi"
            }
          }
        }

        volume {
          name                 = kubernetes_service_account.kured.default_secret_name

          secret {
            secret_name        = kubernetes_service_account.kured.default_secret_name
          }
        }
      }
    }
  }
}
