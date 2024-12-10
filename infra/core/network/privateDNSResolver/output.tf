output "dns_private_resolver_ip" {
  value = azurerm_private_dns_resolver_inbound_endpoint.private_dns_resolver.ip_configurations[0].private_ip_address
}