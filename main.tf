# Specify the provider - AZURE in our case

provider "azurerm" {
    version = "1.20.0"
}

# Define variables to be used
### Caution: it is extremly poor programming practice to write explicit variables like these, but they serve as an example now
#variable "admin_username" {
#    default = "sebinego"
#}

#variable "admin_password" {
#    default = "3SebiDev*****"
#}

# Create the Resource Group first
resource "azurerm_resource_group" "resourceGroup" {
    name = "${var.prefix}ResourceGroup"
    location = "westeurope"
    tags = "${var.tags}"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
    name = "${var.prefix}Vnet"
    location = "${var.location}"
    address_space = ["10.0.0.0/16"]
    resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
    tags = "${var.tags}"
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
    name = "${var.prefix}Subnet"
    resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    address_prefix = "10.0.1.0/24"
}

# Create a Public IP
resource "azurerm_public_ip" "publicip" {
    name = "${var.prefix}PublicIP"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
    public_ip_address_allocation = "dynamic"
    tags = "${var.tags}"
}

# Create Network Security Group and rules associated with it
resource "azurerm_network_security_group" "nsg" {
    name = "${var.prefix}NSG"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
    tags = "${var.tags}"

    security_rule {
        name = "SSH"
        priority = 1001
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
}

# Create Network Interface
resource "azurerm_network_interface" "nic" {
    name = "${var.prefix}NIC"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
    network_security_group_id = "${azurerm_network_security_group.nsg.id}"
    tags = "${var.tags}"

    ip_configuration {
        name = "${var.prefix}NICConfig"
        subnet_id = "${azurerm_subnet.subnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = "${azurerm_public_ip.publicip.id}"
    }
}

# Create Virtual Machine
resource "azurerm_virtual_machine" "vm" {
    name = "${var.prefix}VM"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
    network_interface_ids = ["${azurerm_network_interface.nic.id}"]
    vm_size = "Standard_DS1_v2"
    tags = "${var.tags}"

    storage_os_disk {
        name = "${var.prefix}OsDisk"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "16.04.0-LTS"
        version = "latest"
    }

    os_profile {
        computer_name = "${var.prefix}UbuntuVM"
        admin_username = "${var.admin_username}"
        admin_password = "${var.admin_password}"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    provisioner "file" {
        connection {
            type = "ssh"
            user = "${var.admin_username}"
            password = "${var.admin_password}"
        }

        source = "newfile.txt"
        destination = "newfile.txt"
    }

    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = "${var.admin_username}"
            password = "${var.admin_password}"
        }
        inline = [
            "ls -la",
            "cat newfile.txt"
        ]
    }
}

output "ip" {
    value = "${azurerm_public_ip.publicip.ip_address}"
}

output "os_sku" {
    value = "${lookup(var.sku, var.location)}"
}
