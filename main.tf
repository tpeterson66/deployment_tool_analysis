provider "azurerm" {
  features {}
}

variable "server_count" {
  default = 1
}
variable "name" {}
# variable "tags" {}

# resource "azurerm_resource_group" "apprg" {
#   name     = "${var.name}-rg"
#   location = "Central US"
# }
resource "azurerm_virtual_network" "network" {
  name                = "${var.name}-vnet"
  address_space       = ["10.255.240.0/23"]
  location            = azurerm_resource_group.apprg.location
  resource_group_name = azurerm_resource_group.apprg.name
}
resource "azurerm_subnet" "appsubnet" {
  name                 = "${var.name}-app-subnet"
  resource_group_name  = azurerm_resource_group.apprg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.255.240.0/24"]
}
resource "azurerm_network_security_group" "appsubnetnsg" {
  name                = "${var.name}-app-nsg"
  location            = azurerm_resource_group.apprg.location
  resource_group_name = azurerm_resource_group.apprg.name
}
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.appsubnet.id
  network_security_group_id = azurerm_network_security_group.appsubnetnsg.id
}
resource "azurerm_network_security_rule" "http-in" {
  name                        = "http-in"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.apprg.name
  network_security_group_name = azurerm_network_security_group.appsubnetnsg.name
}
resource "azurerm_network_security_rule" "ssh-in" {
  name                        = "ssh-in"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.apprg.name
  network_security_group_name = azurerm_network_security_group.appsubnetnsg.name
}

resource "azurerm_public_ip" "apppip" {
  count               = var.server_count
  name                = "${var.name}${(count.index + 1)}-pip"
  resource_group_name = azurerm_resource_group.apprg.name
  location            = azurerm_resource_group.apprg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  count               = var.server_count
  name                = "${var.name}${(count.index + 1)}-nic"
  location            = azurerm_resource_group.apprg.location
  resource_group_name = azurerm_resource_group.apprg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.appsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.apppip[count.index].id
  }
}
resource "azurerm_linux_virtual_machine" "webvm" {
  count               = var.server_count
  name                = "${var.name}${(count.index + 1)}"
  resource_group_name = azurerm_resource_group.apprg.name
  location            = azurerm_resource_group.apprg.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  availability_set_id = azurerm_availability_set.aset.id
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("./id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "file" {
    source      = "./startup.sh"
    destination = "./startup.sh"
    connection {
      type        = "ssh"
      user        = "adminuser"
      private_key = file("/mnt/workspace/spacelift")
      host        = azurerm_public_ip.apppip[count.index].ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ./startup.sh",
      "./startup.sh",
    ]
    connection {
      type        = "ssh"
      user        = "adminuser"
      private_key = file("/mnt/workspace/spacelift")
      host        = azurerm_public_ip.apppip[count.index].ip_address
    }
  }
}
resource "azurerm_availability_set" "aset" {
  name                = "tf-aset"
  location            = azurerm_resource_group.apprg.location
  resource_group_name = azurerm_resource_group.apprg.name

}
output "VirtualMachine_IP_Address" {
  value = ["${azurerm_public_ip.apppip.*.ip_address}"]
}

resource "azurerm_public_ip" "lb_pip" {
  name                = "tf-lb-pip"
  location            = azurerm_resource_group.apprg.location
  resource_group_name = azurerm_resource_group.apprg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "tf_lab_lb" {
  name                = "tf-lb"
  location            = azurerm_resource_group.apprg.location
  resource_group_name = azurerm_resource_group.apprg.name

  frontend_ip_configuration {
    name                 = "lb-pip"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  # resource_group_name = azurerm_resource_group.apprg.name
  loadbalancer_id = azurerm_lb.tf_lab_lb.id
  name            = "backend_pool"
}

resource "azurerm_lb_rule" "lb-rule" {
  # resource_group_name            = azurerm_resource_group.apprg.name
  loadbalancer_id                = azurerm_lb.tf_lab_lb.id
  name                           = "rule-01"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lb-pip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id                       = azurerm_lb_probe.health_probe.id
}

resource "azurerm_network_interface_backend_address_pool_association" "backend_pool" {
  count                   = var.server_count
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = "ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}
resource "azurerm_lb_probe" "health_probe" {
  # resource_group_name = azurerm_resource_group.apprg.name
  loadbalancer_id = azurerm_lb.tf_lab_lb.id
  name            = "http-running-probe"
  port            = 80
}
output "Load_Balencer_IP_Address" {
  value = azurerm_public_ip.lb_pip.ip_address
}
