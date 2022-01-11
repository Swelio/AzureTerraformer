data "http" "exec-ip" {
  url = "http://ipv4.icanhazip.com"
}

variable "dc_domain_name" {
  type      = string
  sensitive = true
}

variable "active_directory_domain" {
  type      = string
  sensitive = true
}

variable "active_directory_netbios" {
  type      = string
  sensitive = true
}

variable "key_vault_name" {
  type = string
  sensitive = true
}

variable "domain_controller_admin_username" {
  type    = string
  default = "Gilgamesh"
}

resource "random_password" "admin_password" {
  length           = 20
  special          = true
  min_special      = 1
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  override_special = "!@#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "safe_mode_admin_password" {
  length           = 20
  special          = true
  min_special      = 1
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  override_special = "!@#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_resource_group" "terraform_group" {
  name     = "terraform-resources"
  location = "France Central"
}

resource "azurerm_virtual_network" "terraform" {
  name                = "active-directory-network"
  address_space       = ["10.30.0.0/16"]
  location            = azurerm_resource_group.terraform_group.location
  resource_group_name = azurerm_resource_group.terraform_group.name
}

resource "azurerm_subnet" "active_directory" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.terraform_group.name
  virtual_network_name = azurerm_virtual_network.terraform.name
  address_prefixes     = ["10.30.10.0/24"]
}

resource "azurerm_network_security_group" "active_directory" {
  location            = azurerm_resource_group.terraform_group.location
  name                = "ActiveDirectorySecurity"
  resource_group_name = azurerm_resource_group.terraform_group.name

  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "rdp_access"
    priority                   = 500
    protocol                   = "Tcp"
    source_address_prefix      = "${chomp(data.http.exec-ip.body)}/32"
    source_port_range          = "*"
    destination_port_range     = "3389"
    destination_address_prefix = "${azurerm_network_interface.domain_controller.private_ip_address}/32"
  }
}

resource "azurerm_subnet_network_security_group_association" "active_directory" {
  network_security_group_id = azurerm_network_security_group.active_directory.id
  subnet_id                 = azurerm_subnet.active_directory.id
}

resource "azurerm_public_ip" "domain_controller" {
  allocation_method   = "Dynamic"
  location            = azurerm_resource_group.terraform_group.location
  name                = "master-public-ip"
  resource_group_name = azurerm_resource_group.terraform_group.name
  domain_name_label   = var.dc_domain_name
}

resource "azurerm_network_interface" "domain_controller" {
  name                = "domain-controller-nic"
  location            = azurerm_resource_group.terraform_group.location
  resource_group_name = azurerm_resource_group.terraform_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.active_directory.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.active_directory.address_prefixes[0], 10)
    public_ip_address_id          = azurerm_public_ip.domain_controller.id
  }
}

data "azurerm_public_ip" "domain_controller" {
  name                = azurerm_public_ip.domain_controller.name
  resource_group_name = azurerm_resource_group.terraform_group.name
}

data "template_file" "adds_deployment" {
  template = file("./scripts/adds_deployment.tpl")
  vars     = {
    domain_name              = var.active_directory_domain
    netbios                  = var.active_directory_netbios
    safe_mode_admin_password = random_password.safe_mode_admin_password.result
  }
}

resource "azurerm_windows_virtual_machine" "domain_controller" {
  name                     = "domain-controller"
  computer_name            = "Master"
  enable_automatic_updates = true
  provision_vm_agent       = true
  resource_group_name      = azurerm_resource_group.terraform_group.name
  location                 = azurerm_resource_group.terraform_group.location
  size                     = "Standard_B2s"
  admin_username           = var.domain_controller_admin_username
  admin_password           = random_password.admin_password.result
  network_interface_ids    = [
    azurerm_network_interface.domain_controller.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  secret {
    key_vault_id = data.azurerm_key_vault_certificate.ad_cert.key_vault_id
    certificate {
      store = "My"
      url   = data.azurerm_key_vault_certificate.ad_cert.secret_id
    }
  }
}

resource "azurerm_virtual_machine_extension" "dc_installer" {
  depends_on = [azurerm_windows_virtual_machine.domain_controller]

  name                       = "adds-installer"
  virtual_machine_id         = azurerm_windows_virtual_machine.domain_controller.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = <<PROTECTED_SETTINGS
    {
        "commandToExecute": "powershell.exe -ExecutionPolicy Bypass -NonInteractive -NoProfile -EncodedCommand ${textencodebase64(data.template_file.adds_deployment.rendered, "UTF-16LE")}"
    }
PROTECTED_SETTINGS
}

output "administrator_name" {
  value     = var.domain_controller_admin_username
  sensitive = true
}

output "administrator_password" {
  value     = random_password.admin_password.result
  sensitive = true
}

output "domain_controller_ip" {
  value = data.azurerm_public_ip.domain_controller.ip_address
}

output "domain_controller_fqdn" {
  value     = data.azurerm_public_ip.domain_controller.fqdn
  sensitive = true
}