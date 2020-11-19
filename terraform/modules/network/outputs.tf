output admin_ip_group_id {
  value                        = azurerm_ip_group.admin.id
}
output firewall_fqdn {
  value                        = azurerm_public_ip.iag_pip.fqdn
}
output firewall_id {
  value                        = azurerm_firewall.iag.id
}
output subnet_ids {
  value                        = zipmap(azurerm_subnet.subnet.*.name, azurerm_subnet.subnet.*.id)
}