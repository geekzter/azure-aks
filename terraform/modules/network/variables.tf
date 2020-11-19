variable address_space {
  default = "10.16.0.0/12"
}
variable dns_servers {
  type    = list
  default = ["168.63.129.16"]
}
variable log_analytics_workspace_id {}
variable resource_group_name {}
variable subnet_bits {
  type    = number
  default = 8
}
variable subnets {
  type = list
}