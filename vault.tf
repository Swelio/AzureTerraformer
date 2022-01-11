resource "azurerm_key_vault" "terraform" {
  name                       = var.key_vault_name
  location                   = azurerm_resource_group.terraform_group.location
  resource_group_name        = azurerm_resource_group.terraform_group.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  enabled_for_deployment     = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "create",
      "delete",
      "deleteissuers",
      "get",
      "getissuers",
      "import",
      "list",
      "listissuers",
      "managecontacts",
      "manageissuers",
      "purge",
      "setissuers",
      "update",
    ]

    key_permissions = [
      "backup",
      "create",
      "decrypt",
      "delete",
      "encrypt",
      "get",
      "import",
      "list",
      "purge",
      "recover",
      "restore",
      "sign",
      "unwrapKey",
      "update",
      "verify",
      "wrapKey",
    ]

    secret_permissions = [
      "backup",
      "delete",
      "get",
      "list",
      "purge",
      "recover",
      "restore",
      "set",
    ]
  }
}

resource "azurerm_key_vault_certificate" "ad_cert" {
  name         = "${var.dc_domain_name}-cert"
  key_vault_id = azurerm_key_vault.terraform.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 4096
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = [data.azurerm_public_ip.domain_controller.fqdn]
      }

      subject            = "CN=${data.azurerm_public_ip.domain_controller.fqdn}"
      validity_in_months = 12
    }
  }
}

resource "azurerm_key_vault_secret" "dc_username" {
  key_vault_id = azurerm_key_vault.terraform.id
  name         = "dc-username"
  value        = var.domain_controller_admin_username
}

resource "azurerm_key_vault_secret" "dc_password" {
  key_vault_id = azurerm_key_vault.terraform.id
  name         = "dc-password"
  value        = random_password.admin_password.result
}

resource "azurerm_key_vault_secret" "dc_safe_mode_password" {
  key_vault_id = azurerm_key_vault.terraform.id
  name         = "dc-safe-mode-password"
  value        = random_password.safe_mode_admin_password.result
}

data "azurerm_key_vault" "terraform" {
  name                = azurerm_key_vault.terraform.name
  resource_group_name = azurerm_resource_group.terraform_group.name
}

data "azurerm_key_vault_certificate" "ad_cert" {
  key_vault_id = data.azurerm_key_vault.terraform.id
  name         = azurerm_key_vault_certificate.ad_cert.name
}