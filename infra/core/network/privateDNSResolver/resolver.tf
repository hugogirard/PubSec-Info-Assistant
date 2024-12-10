resource "azurerm_private_dns_resolver" "private_dns_resolver" {
  name                = var.privateDNSResolverName
  location            = var.location
  resource_group_name = var.resourceGroupName
  virtual_network_id  = var.vnetId
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "private_dns_resolver" {
  name                    = "dns-resolver-inbound-endpoint"
  location                = var.location
  private_dns_resolver_id = azurerm_private_dns_resolver.private_dns_resolver.id

  ip_configurations {
    subnet_id = var.subnetId
  }
}