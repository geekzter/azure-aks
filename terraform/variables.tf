variable aks_sp_application_id {
  description = "Application ID of AKS Service Principal"
  default     = ""
}
variable aks_sp_object_id {
  description = "Object ID of AKS Service Principal"
  default     = ""
}
variable aks_sp_application_secret {
  description = "Password of AKS Service Principal"
  default     = ""
}

variable configure_kubernetes {
  type        = bool
  default     = true
  description = "Whether to configure Kubernetes using the Terraform Kubernetes provider"
}

variable deploy_agic {
  type        = bool
  default     = false
  description = "Whether to deploy AKS Application Gateway Ingress Controller Add On"
}

variable deploy_aks {
  type        = bool
  default     = true
  description = "Whether to deploy AKS & Kubernetes. False will deploy network infrastructure only."
}

variable kube_config_path {
  description = "Path to the kube config file (e.g. .kube/config)"
  default     = ""
}

variable location {
  description = "The location/region where the resources will be created."
  default     = "westeurope"
}

variable peer_network_id {
  description = "Virtal network to be peered with. This is usefull to run Terraform from and be able to access a private API server."
  default     = ""
}

variable resource_prefix {
  description = "The prefix to put in front of resource names created"
  default     = "K8S"
}
variable resource_suffix {
  description = "The suffix to put at the of resource names created"
  default     = "" # Empty string triggers a random suffix
}

variable resource_environment {
  description = "The logical environment (tier) resource will be deployed in"
  default     = "" # Empty string defaults to workspace name
}

variable ssh_public_key_file {
  type         = string
  default      = "~/.ssh/id_rsa.pub"
}

variable workspace_location {
  description = "The location/region where the monitoring workspaces will be created."
  default     = "westeurope"
}
