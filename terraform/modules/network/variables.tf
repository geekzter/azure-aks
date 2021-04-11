variable address_space {}
variable dns_servers {
  type    = list
  default = ["168.63.129.16"]
}
variable log_analytics_workspace_id {}
variable peer_network_id {}
variable peer_network_has_gateway {
  type        = bool
}
variable resource_group_name {}
variable subnet_bits {
  type    = number
  default = 8
}
variable subnets {
  type = list
}