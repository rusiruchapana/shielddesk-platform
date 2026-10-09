terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
  # Learning-only local state. For team use: provision secure Azure Storage backend FIRST.
  # backend "azurerm" {}
}
provider "azurerm" { features {} subscription_id = var.subscription_id }
