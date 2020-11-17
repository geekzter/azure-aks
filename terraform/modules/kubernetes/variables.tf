variable kubernetes_client_certificate {}
variable kubernetes_client_key {}
variable kubernetes_cluster_ca_certificate {}
variable kubernetes_host {}
variable kured_image {
  default = "docker.io/weaveworks/kured:1.1.0"
}