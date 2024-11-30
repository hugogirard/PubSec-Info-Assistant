output "name" {
  value = var.useExistingAOAIService ? "" : azurerm_cognitive_account.openaiAccount.name
}

output "endpoint" {
  value = var.useExistingAOAIService ? "" : azurerm_cognitive_account.openaiAccount.endpoint
}

output "id" {
  value = var.useExistingAOAIService ? "" : azurerm_cognitive_account.openaiAccount.id
}
