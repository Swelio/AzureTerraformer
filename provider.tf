# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.80.0"
    }
  }
}

variable "selected_subscription_id" {
  type        = string
  description = "Subscription id selected to perform terraform actions."
  sensitive   = true
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.selected_subscription_id
}

data "azurerm_client_config" "current" {}