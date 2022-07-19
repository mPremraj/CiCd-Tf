terraform {
 
}

provider "azurerm" {
  features {}
}

variable "vm-size" {
  type        = string
  description = "Preferred VM Size"
  default     = "Standard_F2s_v2"
}

variable "number_of_vms" {
  type        = number
  description = "Number of VMs to create"
  default = 1
}

variable "nics_per_vm" {
  type        = number
  description = "Number of NICs to attach to each created VM"
  default = 1
}

data "azurerm_resource_group" "rg" {
  name     = "RG"
}

data "azurerm_shared_image" "existing" {
  name                = "def1"
  gallery_name        = "Gallary"
  resource_group_name = "RG"
}

resource "azurerm_virtual_network" "vm_network" {
  name                = "my_networks"
  address_space       = ["10.0.0.0/16"]
  location            = "East US"
  resource_group_name = "RG"
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "internal0"
  resource_group_name  = "RG"
  virtual_network_name = azurerm_virtual_network.vm_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip" {
  count               = (var.number_of_vms * var.nics_per_vm)
  name                = "pips-${count.index}"
  resource_group_name = "RG"
  location            = "East US"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "sender_ni" {
  count               = (var.number_of_vms * var.nics_per_vm)
  name                = "my-nic-${count.index}"
  location            = "East US"
  resource_group_name = "RG"

  enable_accelerated_networking = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }
}

resource "azurerm_ssh_public_key" "example" {
  name                = "prem-sshkey"
  resource_group_name = data.azurerm_resource_group.example.name
  location            = data.azurerm_resource_group.example.location
  public_key          = file("C:\\Delete\\SSH\\SSH_Cert.pub")
}


resource "azurerm_windows_virtual_machine" "vm" {
  count               = var.number_of_vms

  name                = "myvms.${count.index}"
  computer_name       = "myvms.${count.index}"
  resource_group_name = "RG"
  location            = "East US"
  size                = var.vm-size
  admin_username      = "prem"
  admin_password      = "P@$$w0rd1234!"
  disable_password_authentication = "false"
  source_image_id     = data.azurerm_shared_image.existing.id

  network_interface_ids = slice(azurerm_network_interface.sender_ni[*].id,
     var.nics_per_vm * count.index, (var.nics_per_vm * count.index) + var.nics_per_vm)
  
  admin_ssh_key {
    username   = "prem"
    public_key = azurerm_ssh_public_key.example.public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
 
