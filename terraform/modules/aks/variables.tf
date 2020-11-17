variable dns_prefix {}
variable admin_username {}
variable log_analytics_workspace_id {}
variable name {}
variable node_subnet_id {}
variable resource_group_name {}
variable ssh_public_key_file {}
variable sp_application_id {
  description = "Application ID of AKS Service Principal"
}
variable sp_application_secret {
  description = "Password of AKS Service Principal"
}
variable sp_object_id {
  description = "Object ID of AKS Service Principal"
}
