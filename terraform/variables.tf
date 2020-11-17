variable "resource_prefix" {
  description = "The prefix to put in front of resource names created"
  default     = "K8S"
}

variable "resource_suffix" {
  description = "The suffix to put at the of resource names created"
  default     = "" # Empty string triggers a random suffix
}

variable "resource_environment" {
  description = "The logical environment (tier) resource will be deployed in"
  default     = "" # Empty string defaults to workspace name
}

variable ssh_public_key_file {
  type         = string
  default      = "~/.ssh/id_rsa.pub"
}

variable "location" {
  description = "The location/region where the resources will be created."
  default     = "westeurope"
}

variable "workspace_location" {
  description = "The location/region where the monitoring workspaces will be created."
  default     = "westeurope"
}

variable "failover_location" {
  description = "The location/region where some (database) resources will fail over to"
  default     = "northeurope"
}

variable "docker_image" {
  description = "The name of the docker image to (initially) deploy"
# default     = "ttreg.azurecr.io/website:latest"
# default     = "msfttailwindtraders/tailwindtraderswebsite:latest"
  default     = "appsvcsample/static-site:latest"
}
variable "admin_ips" {
  default = [
    "82.217.160.55/32",   # Home
    "194.69.100.0/22", # Microsoft NL
    "80.255.240.0/20", # HTC WLAN PUB
    "145.103.0.0/16", # Notenkraker
    "13.93.9.74/32", # Dev VM
    "13.93.114.99/32", # Linux VM
    "104.211.211.109/32" # India Demo VM
  ]
}

variable "aks_sp_application_id" {
  description = "Application ID of AKS Service Principal"
  default     = ""
}
variable "aks_sp_object_id" {
  description = "Object ID of AKS Service Principal"
  default     = ""
}
variable "aks_sp_application_secret" {
  description = "Password of AKS Service Principal"
  default     = ""
}

variable "kube_config_path" {
  description = "Path to the kube config file (e.g. .kube/config)"
  default = ""
}
