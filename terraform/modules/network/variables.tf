variable address_space {
  default = "10.16.0.0/12"
}
variable resource_group_name {}
variable subnet_size {
  type    = number
  default = 8
}
variable subnets {
  type = list
}