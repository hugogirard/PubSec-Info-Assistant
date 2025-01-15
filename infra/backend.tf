terraform {
  backend "azurerm" {
    resource_group_name  = "assist-runner-rg"
    storage_account_name = "assisttfstatest"
    container_name       = "tfstate"
    key                  = "assist.tfstate"
    use_azuread_auth     = true
  }
}
