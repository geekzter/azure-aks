output admin_ip_group_id {
  value                        = azurerm_ip_group.admin.id
}
# output application_gateway_id {
#   value                        = azurerm_application_gateway.waf.id
# }
output application_gateway_subnet_id {
  value                        = azurerm_subnet.waf_subnet.id
}
output firewall_fqdn {
  value                        = azurerm_public_ip.iag_pip.fqdn
}
output firewall_id {
  value                        = azurerm_firewall.iag.id
}

output nodes_ip_group_id {
  value                        = azurerm_ip_group.nodes.id
}

output subnet_ids {
  value                        = zipmap(azurerm_subnet.subnet.*.name, azurerm_subnet.subnet.*.id)
}