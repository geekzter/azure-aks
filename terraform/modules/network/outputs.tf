output admin_ip_group_id {
  value                        = azurerm_ip_group.admin.id
}

output application_gateway_subnet_id {
  value                        = azurerm_subnet.waf_subnet.id
}

output bastion_subnet_id {
  value                        = azurerm_subnet.bastion_subnet.id
}

output firewall_fqdn {
  value                        = azurerm_public_ip.firewall_pip.fqdn
}
output firewall_id {
  value                        = azurerm_firewall.gateway.id
}
output firewall_subnet_id {
  value                        = azurerm_subnet.firewall_subnet.id
}

output nodes_ip_group_id {
  value                        = azurerm_ip_group.nodes.id
}
output nodes_subnet_id {
  value                        = azurerm_subnet.nodes_subnet.id
}

output paas_subnet_id {
  value                        = azurerm_subnet.paas_subnet.id
}

output virtual_network_id {
  value                        = azurerm_virtual_network.network.id
}