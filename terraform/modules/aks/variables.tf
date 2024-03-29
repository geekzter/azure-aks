variable admin_username {}
variable application_gateway_subnet_id {}
variable client_object_id {}
variable configure_access_control {
  type                         = bool
}
variable deploy_application_gateway {
  type                         = bool
}
variable dns_prefix {}
variable dns_host_suffix {}
variable kube_config_path {}
variable kubernetes_version {}
variable location {}
variable log_analytics_workspace_id {}
variable name {}
variable node_size {}
variable node_subnet_id {}
variable private_cluster_enabled {
  type        = bool
}
variable resource_group_id {}
variable ssh_public_key_file {}
variable tags {
  type        = map
}