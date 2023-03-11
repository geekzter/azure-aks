variable address_space {
  default                      = "10.32.100.0/23"
}

variable application_name {
  description                  = "Value of 'application' resource tag"
  default                      = "Kubernetes"
}

variable application_owner {
  description                  = "Value of 'owner' resource tag"
  default                      = "" # Empty string takes objectId of current user
}

variable configure_access_control {
  description                  = "Assumes the Terraform user is an owner of the subscription. Turning this off reduces functionality somewhat"
  default                      = true
  type                         = bool
}

variable configure_kubernetes {
  type                         = bool
  default                      = false
  description                  = "Whether to configure Kubernetes using the Terraform Kubernetes provider"
}

variable deploy_aks {
  type                         = bool
  default                      = true
  description                  = "Whether to deploy AKS & Kubernetes. False will deploy network infrastructure only."
}

variable deploy_bastion {
  type                         = bool
  default                      = false
  description                  = "Whether to deploy managed bastion"
}

# Turn this off if you can't open required ports (65200-65535, ApplicationGatewaySubnetInboundTrafficBlockedByNetworkSecurityGroup)
# https://docs.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#network-security-groups
variable deploy_application_gateway {
  type                         = bool
  default                      = true
  description                  = "Whether to deploy Application Gateway"
}

variable deploy_network {
  description                  = "Deploys Virtual Network"
  default                      = true
  type                         = bool
}

variable dns_host_suffix {
  default                      = "mycicd"
}

variable gateway_type {
  type                         = string
  default                      = "Firewall"
  nullable                     = false
  validation {
    condition                  = var.gateway_type == "Firewall" || var.gateway_type == "NATGateway" || var.gateway_type == "NoGateway"
    error_message              = "The gateway_type must be 'Firewall', 'NATGateway' or 'NoGateway'"
  }
}

variable kube_config_path {
  description                  = "Path to the kube config file (e.g. .kube/config)"
  default                      = ""
}

variable kubernetes_version {
  default                      = null
}

variable location {
  description                  = "The location/region where the resources will be created."
  default                      = "westeurope"
}

variable node_size {
  default                      = "Standard_D2s_v3"
}

variable nsg_reassign_wait_minutes {
  type                         = number
  default                      = 0
}

variable peer_network_has_gateway {
  type                         = bool
  default                      = false
}

variable peer_network_id {
  description                  = "Virtual network to be peered with. This is usefull to run Terraform from and be able to access a private API server."
  default                      = ""
}

variable private_cluster_enabled {
  type                         = bool
  default                      = true
}

variable resource_prefix {
  description                  = "The prefix to put in front of resource names created"
  default                      = "k8s"
}
variable resource_suffix {
  description                  = "The suffix to put at the of resource names created"
  default                      = "" # Empty string triggers a random suffix
}

variable resource_environment {
  description                  = "The logical environment (tier) resource will be deployed in"
  default                      = "" # Empty string defaults to workspace name
}

variable run_id {
  description                  = "The ID that identifies the pipeline / workflow that invoked Terraform"
  default                      = ""
}

variable ssh_public_key_file {
  type                         = string
  default                      = "~/.ssh/id_rsa.pub"
}

variable subscription_id {
  description                  = "Configure subscription_id independent from ARM_SUBSCRIPTION_ID"
  default                      = null
}
variable tenant_id {
  description                  = "Configure tenant_id independent from ARM_TENANT_ID"
  default                      = null
}

variable workspace_location {
  description                  = "The location/region where the monitoring workspaces will be created."
  default                      = "westeurope"
}
