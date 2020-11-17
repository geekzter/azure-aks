output subnet_ids {
  value                        = zipmap(azurerm_subnet.subnet.*.name, azurerm_subnet.subnet.*.id)
}