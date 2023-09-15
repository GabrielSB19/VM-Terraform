# Se define el provider que se va a usar, en este caso Azure
provider "azurerm" {
    features{}
}

# Se crea el grupo de recursos donde montaremos nuestros recursos
resource "azurerm_resource_group" "GSBvm"{
    name = var.name_function
    location = var.location
} 

# Ahora se crea la red virtual
resource "azurerm_virtual_network" "virtualNetworkGSB"{
    name = "virtualNet${var.name_function}"
    location = azurerm_resource_group.GSBvm.location
    resource_group_name = azurerm_resource_group.GSBvm.name
    address_space = ["10.0.0.0/16"]
    dns_servers = ["10.0.0.4", "10.0.0.5"]

    tags = {
        environment = "Production"
    }
}

# Ahora se crea la subred
resource "azurerm_subnet" "subnetGSB" {
    name = "subnet${var.name_function}"
    resource_group_name = azurerm_resource_group.GSBvm.name
    virtual_network_name = azurerm_virtual_network.virtualNetworkGSB.name
    address_prefixes = ["10.0.2.0/24"]
}

# Creamos la IP publica
resource "azurerm_public_ip" "IPpublicGSB" {
    name = "IPpublic${var.name_function}"
    location = azurerm_resource_group.GSBvm.location
    resource_group_name = azurerm_resource_group.GSBvm.name
    allocation_method = "Static"

    tags = {
        environment = "Production"
    }
}

# Creamos la interfaz de red
resource "azurerm_network_interface" "networkInterfaceGSB" {
    name = "networkInteface${var.name_function}"
    location = azurerm_resource_group.GSBvm.location
    resource_group_name = azurerm_resource_group.GSBvm.name

    ip_configuration{
        name = "internal"
        subnet_id = azurerm_subnet.subnetGSB.id
        public_ip_address_id = azurerm_public_ip.IPpublicGSB.id
        private_ip_address_allocation = "Dynamic"
    }
}

# Ahora creamos el grupo de seguridad con sus reglas asociadas
resource "azurerm_network_security_group" "groupSecurityGSB"{
    name = "acceptanceTestSecurityGroup1${var.name_function}"
    location = azurerm_resource_group.GSBvm.location
    resource_group_name = azurerm_resource_group.GSBvm.name

    security_rule {
        name = "test123SSH"
        priority = "100"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix  = "*"
        destination_address_prefix = "*"
    }

    security_rule{
        name = "PING"
        priority = "1000"
        direction = "Inbound"
        access = "Allow"
        protocol = "Icmp"
        source_port_range = "*"
        destination_port_range = "*"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Production"
    }
}

# Ahora se crea la asociacion entre la interfaz de red y el grupo de seguridad
resource "azurerm_network_interface_security_group_association" "IR-GS" {
  network_interface_id = azurerm_network_interface.networkInterfaceGSB.id
  network_security_group_id = azurerm_network_security_group.groupSecurityGSB.id
}

# Creamos la maquina virtual de Linux

resource "azurerm_linux_virtual_machine" "vmLinuxGSB" {
    name = "vmLinux${var.name_function}"
    resource_group_name = azurerm_resource_group.GSBvm.name
    location = azurerm_resource_group.GSBvm.location
    size = "Standard_F2"
    admin_username = var.name_function
    network_interface_ids = [azurerm_network_interface.networkInterfaceGSB.id]
    
    admin_ssh_key {
        username = var.name_function
        public_key = file("C:/Users/semillero/id_rsa.pub")
    }

    os_disk {
        caching = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer = "0001-com-ubuntu-server-focal"
        sku = "20_04-lts"
        version = "latest"
    }
}

