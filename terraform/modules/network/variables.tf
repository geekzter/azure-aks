variable address_space {}
variable dns_servers {
  type        = list
  default     = ["168.63.129.16"]
}
variable location {}
variable log_analytics_workspace_id {}
variable nsg_reassign_wait_minutes {
  type        = number
}
variable peer_network_id {}
variable peer_network_has_gateway {
  type        = bool
}
variable resource_group_name {}
variable tags {
  type        = map
}