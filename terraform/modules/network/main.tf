data azurerm_resource_group rg {
  name                         = var.resource_group_name
}

resource azurerm_virtual_network development_network {
  name                         = "${data.azurerm_resource_group.rg.name}-network"
  location                     = data.azurerm_resource_group.rg.location
  resource_group_name          = data.azurerm_resource_group.rg.name
  address_space                = [var.address_space]

  tags                         = data.azurerm_resource_group.rg.tags
}

resource azurerm_subnet subnet {
  name                         = var.subnets[count.index]
  virtual_network_name         = azurerm_virtual_network.development_network.name
  resource_group_name          = data.azurerm_resource_group.rg.name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.development_network.address_space[0],var.subnet_size,count.index)]

  count                        = length(var.subnets)
}
