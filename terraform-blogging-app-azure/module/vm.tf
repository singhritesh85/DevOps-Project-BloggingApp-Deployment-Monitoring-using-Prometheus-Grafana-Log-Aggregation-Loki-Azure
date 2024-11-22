############################################## Creation for NSG for SonarQube #######################################################

resource "azurerm_network_security_group" "azure_nsg_sonarqube" {
#  count               = var.vm_count_rabbitmq
  name                = "NSG-SonarQube-Server"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  security_rule {
    name                       = "azure_ssh_sonarqube"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_sonarqube"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = azurerm_public_ip.public_ip_devopsagent.ip_address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_node_exporter"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefixes      = ["10.224.0.0/12"]
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.env
  }
}

########################################## Create Public IP and Network Interface for SonarQube #############################################

resource "azurerm_public_ip" "public_ip_sonarqube" {
#  count               = var.vm_count_rabbitmq
  name                = "sonarqube-ip"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  allocation_method   = var.static_dynamic[0]

  sku = "Standard"   ### Basic, For Availability Zone to be Enabled the SKU of Public IP must be Standard  
  zones = var.availability_zone

  tags = {
    environment = var.env
  }
}

resource "azurerm_network_interface" "vnet_interface_sonarqube" {
#  count               = var.vm_count_rabbitmq
  name                = "sonarqube-nic"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  ip_configuration {
    name                          = "sonarqube-ip-configuration"
    subnet_id                     = azurerm_subnet.aks_subnet.id
    private_ip_address_allocation = var.static_dynamic[1]
    public_ip_address_id = azurerm_public_ip.public_ip_sonarqube.id
  }
  
  tags = {
    environment = var.env
  }
}

############################################ Attach NSG to Network Interface for SonarQube #####################################################

resource "azurerm_network_interface_security_group_association" "nsg_nic_sonarqube" {
#  count                     = var.vm_count_rabbitmq
  network_interface_id      = azurerm_network_interface.vnet_interface_sonarqube.id
  network_security_group_id = azurerm_network_security_group.azure_nsg_sonarqube.id

}

######################################################## Create Azure VM for SonarQube ##########################################################

resource "azurerm_linux_virtual_machine" "azure_vm_sonarqube" {
#  count                 = var.vm_count_rabbitmq
  name                  = "Sonarqube-Server"
  location              = azurerm_resource_group.aks_rg.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  network_interface_ids = [azurerm_network_interface.vnet_interface_sonarqube.id]
  size                  = var.vm_size
  zone                 = var.availability_zone[0]
  computer_name  = "SonarQube-Server"
  admin_username = var.admin_username
  admin_password = var.admin_password
  custom_data    = filebase64("custom_data_sonarqube.sh")
  disable_password_authentication = false

  #### Boot Diagnostics is Enable with managed storage account ########
  boot_diagnostics {
    storage_account_uri  = ""
  }

  source_image_reference {
    publisher = "almalinux"     ###"OpenLogic"
    offer     = "almalinux-x86_64"     ###"CentOS"
    sku       = "8_7-gen2"        ###"7_9-gen2"
    version   = "latest"        ###"latest"
  }
  os_disk {
    name              = "sonarqube-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb      = var.disk_size_gb
  }

  tags = {
    environment = var.env
  }

  depends_on = [azurerm_managed_disk.disk_sonarqube]
}

resource "null_resource" "azurevm_sonarqube" {
  depends_on = [azurerm_linux_virtual_machine.azure_vm_sonarqube, azurerm_network_interface.vnet_interface_loki]
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${azurerm_network_interface.vnet_interface_loki[0].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[1].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[2].private_ip_address}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = azurerm_public_ip.public_ip_sonarqube.ip_address
    user = "ritesh"
    password = "Password@#795"
  }
}

resource "azurerm_managed_disk" "disk_sonarqube" {
#  count                = var.vm_count_rabbitmq
  name                 = "sonarqube-datadisk"
  location             = azurerm_resource_group.aks_rg.location
  resource_group_name  = azurerm_resource_group.aks_rg.name
  zone                 = var.availability_zone[0]
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.extra_disk_size_gb
}


resource "azurerm_virtual_machine_data_disk_attachment" "sonarqube_diskattachment" {
#  count              = var.vm_count_rabbitmq
  managed_disk_id    = azurerm_managed_disk.disk_sonarqube.id
  virtual_machine_id = azurerm_linux_virtual_machine.azure_vm_sonarqube.id
  lun                ="0"
  caching            = "ReadWrite"
}  

############################################## Creation for NSG for Azure DevOps Agent #######################################################

resource "azurerm_network_security_group" "azure_nsg_devopsagent" {
#  count               = var.vm_count_rabbitmq
  name                = "devopsagent-nsg"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  security_rule {
    name                       = "devopsagent_ssh_azure"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_node_exporter"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefixes      = ["10.224.0.0/12"]
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.env
  }
}

########################################## Create Public IP and Network Interface for Azure DevOps Agent #############################################

resource "azurerm_public_ip" "public_ip_devopsagent" {
#  count               = var.vm_count_rabbitmq
  name                = "devopsagent-ip"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  allocation_method   = var.static_dynamic[0]

  sku = "Standard"   ### Basic, For Availability Zone to be Enabled the SKU of Public IP must be Standard
  zones = var.availability_zone

  tags = {
    environment = var.env
  }
}

resource "azurerm_network_interface" "vnet_interface_devopsagent" {
#  count               = var.vm_count_rabbitmq
  name                = "devopsagent-nic"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  ip_configuration {
    name                          = "devopsagent-ip-configuration"
    subnet_id                     = azurerm_subnet.aks_subnet.id
    private_ip_address_allocation = var.static_dynamic[1]
    public_ip_address_id = azurerm_public_ip.public_ip_devopsagent.id
  }

  tags = {
    environment = var.env
  }
}

############################################ Attach NSG to Network Interface for Azure DevOps Agent #####################################################

resource "azurerm_network_interface_security_group_association" "nsg_nic" {
#  count                     = var.vm_count_rabbitmq
  network_interface_id      = azurerm_network_interface.vnet_interface_devopsagent.id
  network_security_group_id = azurerm_network_security_group.azure_nsg_devopsagent.id

}

######################################################## Create Azure VM for Azure DevOps Agent ##########################################################

resource "azurerm_linux_virtual_machine" "azure_vm_devopsagent" {
#  count                 = var.vm_count_rabbitmq
  name                  = "devopsagent-vm"
  location              = azurerm_resource_group.aks_rg.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  network_interface_ids = [azurerm_network_interface.vnet_interface_devopsagent.id]
  size                  = var.vm_size
  zone                 = var.availability_zone[0]
  computer_name  = "devopsagent-vm"
  admin_username = var.admin_username
  admin_password = var.admin_password
  custom_data    = filebase64("custom_data_devopsagent.sh")
  disable_password_authentication = false

  #### Boot Diagnostics is Enable with managed storage account ########
  boot_diagnostics {
    storage_account_uri  = ""
  }

  source_image_reference {
    publisher = "almalinux"      ###"OpenLogic"
    offer     = "almalinux-x86_64"      ###"CentOS"
    sku       = "8_7-gen2"         ###"7_9-gen2"
    version   = "latest"         ###"latest"
  }
  os_disk {
    name              = "devopsagent-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb      = var.disk_size_gb
  }

  tags = {
    environment = var.env
  }

  depends_on = [azurerm_managed_disk.disk_devopsagent]

}

resource "null_resource" "azurevm_devopsagent" {
  depends_on = [azurerm_linux_virtual_machine.azure_vm_devopsagent, azurerm_network_interface.vnet_interface_loki]
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${azurerm_network_interface.vnet_interface_loki[0].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[1].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[2].private_ip_address}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = azurerm_public_ip.public_ip_devopsagent.ip_address
    user = "ritesh"
    password = "Password@#795"
  }
}

resource "azurerm_managed_disk" "disk_devopsagent" {
#  count                = var.vm_count_rabbitmq
  name                 = "devopsagent-datadisk"
  location             = azurerm_resource_group.aks_rg.location
  resource_group_name  = azurerm_resource_group.aks_rg.name
  zone                 = var.availability_zone[0]
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.extra_disk_size_gb
}


resource "azurerm_virtual_machine_data_disk_attachment" "disk_attachment_devopsagent" {
#  count              = var.vm_count_rabbitmq
  managed_disk_id    = azurerm_managed_disk.disk_devopsagent.id
  virtual_machine_id = azurerm_linux_virtual_machine.azure_vm_devopsagent.id
  lun                ="0"
  caching            = "ReadWrite"
}

############################################## Creation for NSG for Prometheus Server #######################################################

resource "azurerm_network_security_group" "azure_nsg_prometheus" {
#  count               = var.vm_count_rabbitmq
  name                = "prometheus-nsg"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  security_rule {
    name                       = "prometheus_ssh_azure"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_node_exporter"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefixes      = ["10.224.0.0/12"]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_prometheus"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.env
  }
}

########################################## Create Public IP and Network Interface for Prometheus #############################################

resource "azurerm_public_ip" "public_ip_prometheus" {
#  count               = var.vm_count_rabbitmq
  name                = "prometheus-ip"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  allocation_method   = var.static_dynamic[0]

  sku = "Standard"   ### Basic, For Availability Zone to be Enabled the SKU of Public IP must be Standard
  zones = var.availability_zone

  tags = {
    environment = var.env
  }
}

resource "azurerm_network_interface" "vnet_interface_prometheus" {
#  count               = var.vm_count_rabbitmq
  name                = "prometheus-nic"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  ip_configuration {
    name                          = "prometheus-ip-configuration"
    subnet_id                     = azurerm_subnet.aks_subnet.id
    private_ip_address_allocation = var.static_dynamic[1]
    public_ip_address_id = azurerm_public_ip.public_ip_prometheus.id
  }

  tags = {
    environment = var.env
  }
}

############################################ Attach NSG to Network Interface for Prometheus #####################################################

resource "azurerm_network_interface_security_group_association" "nsg_nic_prometheus" {
#  count                     = var.vm_count_rabbitmq
  network_interface_id      = azurerm_network_interface.vnet_interface_prometheus.id
  network_security_group_id = azurerm_network_security_group.azure_nsg_prometheus.id

}

######################################################## Create Azure VM for Prometheus ##########################################################

resource "azurerm_linux_virtual_machine" "azure_vm_prometheus" {
#  count                 = var.vm_count_rabbitmq
  name                  = "prometheus-vm"
  location              = azurerm_resource_group.aks_rg.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  network_interface_ids = [azurerm_network_interface.vnet_interface_prometheus.id]
  size                  = var.vm_size
  zone                 = var.availability_zone[0]
  computer_name  = "prometheus-vm"
  admin_username = var.admin_username
  admin_password = var.admin_password
  custom_data    = filebase64("custom_data_prometheus.sh")
  disable_password_authentication = false

  #### Boot Diagnostics is Enable with managed storage account ########
  boot_diagnostics {
    storage_account_uri  = ""
  }

  source_image_reference {
    publisher = "almalinux"      ###"OpenLogic"
    offer     = "almalinux-x86_64"      ###"CentOS"
    sku       = "8_7-gen2"         ###"7_9-gen2"
    version   = "latest"         ###"latest"
  }
  os_disk {
    name              = "prometheus-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb      = var.disk_size_gb
  }

  tags = {
    environment = var.env
  }

  depends_on = [azurerm_managed_disk.disk_prometheus]

}

resource "null_resource" "azurevm_prometheus" {
  depends_on = [azurerm_linux_virtual_machine.azure_vm_prometheus, azurerm_network_interface.vnet_interface_loki]
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${azurerm_network_interface.vnet_interface_loki[0].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[1].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[2].private_ip_address}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = azurerm_public_ip.public_ip_prometheus.ip_address
    user = "ritesh"
    password = "Password@#795"
  }

}

resource "azurerm_managed_disk" "disk_prometheus" {
#  count                = var.vm_count_rabbitmq
  name                 = "prometheus-datadisk"
  location             = azurerm_resource_group.aks_rg.location
  resource_group_name  = azurerm_resource_group.aks_rg.name
  zone                 = var.availability_zone[0]
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.extra_disk_size_gb
}


resource "azurerm_virtual_machine_data_disk_attachment" "disk_attachment_prometheus" {
#  count              = var.vm_count_rabbitmq
  managed_disk_id    = azurerm_managed_disk.disk_prometheus.id
  virtual_machine_id = azurerm_linux_virtual_machine.azure_vm_prometheus.id
  lun                ="0"
  caching            = "ReadWrite"
}

############################################## Creation for NSG for Grafana Server #######################################################

resource "azurerm_network_security_group" "azure_nsg_grafana" {
#  count               = var.vm_count_rabbitmq
  name                = "grafana-nsg"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  security_rule {
    name                       = "grafana_ssh_azure"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_node_exporter"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefixes      = ["10.224.0.0/12"]
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.env
  }
}

########################################## Create Public IP and Network Interface for Grafana #############################################

resource "azurerm_public_ip" "public_ip_grafana" {
#  count               = var.vm_count_rabbitmq
  name                = "grafana-ip"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  allocation_method   = var.static_dynamic[0]

  sku = "Standard"   ### Basic, For Availability Zone to be Enabled the SKU of Public IP must be Standard
  zones = var.availability_zone

  tags = {
    environment = var.env
  }
}

resource "azurerm_network_interface" "vnet_interface_grafana" {
#  count               = var.vm_count_rabbitmq
  name                = "grafana-nic"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  ip_configuration {
    name                          = "grafana-ip-configuration"
    subnet_id                     = azurerm_subnet.aks_subnet.id
    private_ip_address_allocation = var.static_dynamic[1]
    public_ip_address_id = azurerm_public_ip.public_ip_grafana.id
  }

  tags = {
    environment = var.env
  }
}

############################################ Attach NSG to Network Interface for Grafana #####################################################

resource "azurerm_network_interface_security_group_association" "nsg_nic_grafana" {
#  count                     = var.vm_count_rabbitmq
  network_interface_id      = azurerm_network_interface.vnet_interface_grafana.id
  network_security_group_id = azurerm_network_security_group.azure_nsg_grafana.id

}

######################################################## Create Azure VM for Grafana ##########################################################

resource "azurerm_linux_virtual_machine" "azure_vm_grafana" {
#  count                 = var.vm_count_rabbitmq
  name                  = "grafana-vm"
  location              = azurerm_resource_group.aks_rg.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  network_interface_ids = [azurerm_network_interface.vnet_interface_grafana.id]
  size                  = var.vm_size
  zone                 = var.availability_zone[0]
  computer_name  = "grafana-vm"
  admin_username = var.admin_username
  admin_password = var.admin_password
  custom_data    = filebase64("custom_data_grafana.sh")
  disable_password_authentication = false

  #### Boot Diagnostics is Enable with managed storage account ########
  boot_diagnostics {
    storage_account_uri  = ""
  }

  source_image_reference {
    publisher = "almalinux"      ###"OpenLogic"
    offer     = "almalinux-x86_64"      ###"CentOS"
    sku       = "8_7-gen2"         ###"7_9-gen2"
    version   = "latest"         ###"latest"
  }
  os_disk {
    name              = "grafana-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb      = var.disk_size_gb
  }

  tags = {
    environment = var.env
  }

  depends_on = [azurerm_managed_disk.disk_grafana]

}

resource "null_resource" "azurevm_grafana" {
  depends_on = [azurerm_linux_virtual_machine.azure_vm_grafana, azurerm_network_interface.vnet_interface_loki]

  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${azurerm_network_interface.vnet_interface_loki[0].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[1].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[2].private_ip_address}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = azurerm_public_ip.public_ip_grafana.ip_address
    user = "ritesh"
    password = "Password@#795"
  }

}

resource "azurerm_managed_disk" "disk_grafana" {
#  count                = var.vm_count_rabbitmq
  name                 = "grafana-datadisk"
  location             = azurerm_resource_group.aks_rg.location
  resource_group_name  = azurerm_resource_group.aks_rg.name
  zone                 = var.availability_zone[0]
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.extra_disk_size_gb
}


resource "azurerm_virtual_machine_data_disk_attachment" "disk_attachment_grafana" {
#  count              = var.vm_count_rabbitmq
  managed_disk_id    = azurerm_managed_disk.disk_grafana.id
  virtual_machine_id = azurerm_linux_virtual_machine.azure_vm_grafana.id
  lun                ="0"
  caching            = "ReadWrite"
}

############################################## Creation for NSG for Blackbox Exporter Server #######################################################

resource "azurerm_network_security_group" "azure_nsg_blackbox" {
#  count               = var.vm_count_rabbitmq
  name                = "blackbox-nsg"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  security_rule {
    name                       = "blackbox_ssh_azure"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_node_exporter"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefixes      = ["10.224.0.0/12"]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_blackbox_exporter"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9115"
    source_address_prefixes      = ["10.224.0.0/12"]
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.env
  }
}

########################################## Create Public IP and Network Interface for Blackbox Exporter #############################################

resource "azurerm_public_ip" "public_ip_blackbox" {
#  count               = var.vm_count_rabbitmq
  name                = "blackbox-ip"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  allocation_method   = var.static_dynamic[0]

  sku = "Standard"   ### Basic, For Availability Zone to be Enabled the SKU of Public IP must be Standard
  zones = var.availability_zone

  tags = {
    environment = var.env
  }
}

resource "azurerm_network_interface" "vnet_interface_blackbox" {
#  count               = var.vm_count_rabbitmq
  name                = "blackbox-nic"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  ip_configuration {
    name                          = "blackbox-ip-configuration"
    subnet_id                     = azurerm_subnet.aks_subnet.id
    private_ip_address_allocation = var.static_dynamic[1]
    public_ip_address_id = azurerm_public_ip.public_ip_blackbox.id
  }

  tags = {
    environment = var.env
  }
}

############################################ Attach NSG to Network Interface for Blackbox Exporter #####################################################

resource "azurerm_network_interface_security_group_association" "nsg_nic_blackbox" {
#  count                     = var.vm_count_rabbitmq
  network_interface_id      = azurerm_network_interface.vnet_interface_blackbox.id
  network_security_group_id = azurerm_network_security_group.azure_nsg_blackbox.id

}

######################################################## Create Azure VM for Blackbox Exporter ##########################################################

resource "azurerm_linux_virtual_machine" "azure_vm_blackbox" {
#  count                 = var.vm_count_rabbitmq
  name                  = "blackboxexporter-vm"
  location              = azurerm_resource_group.aks_rg.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  network_interface_ids = [azurerm_network_interface.vnet_interface_blackbox.id]
  size                  = var.vm_size
  zone                 = var.availability_zone[0]
  computer_name  = "blackboxexporter-vm"
  admin_username = var.admin_username
  admin_password = var.admin_password
  custom_data    = filebase64("custom_data_blackboxexporter.sh")
  disable_password_authentication = false

  #### Boot Diagnostics is Enable with managed storage account ########
  boot_diagnostics {
    storage_account_uri  = ""
  }

  source_image_reference {
    publisher = "almalinux"      ###"OpenLogic"
    offer     = "almalinux-x86_64"      ###"CentOS"
    sku       = "8_7-gen2"         ###"7_9-gen2"
    version   = "latest"         ###"latest"
  }
  os_disk {
    name              = "blackbox-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb      = var.disk_size_gb
  }

  tags = {
    environment = var.env
  }

  depends_on = [azurerm_managed_disk.disk_blackbox]

}

resource "null_resource" "azurevm_blackbox" {
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${azurerm_network_interface.vnet_interface_loki[0].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[1].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[2].private_ip_address}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = azurerm_public_ip.public_ip_blackbox.ip_address
    user = "ritesh"
    password = "Password@#795"
  }
  depends_on = [azurerm_linux_virtual_machine.azure_vm_blackbox, azurerm_network_interface.vnet_interface_loki]
}

resource "azurerm_managed_disk" "disk_blackbox" {
#  count                = var.vm_count_rabbitmq
  name                 = "blackbox-datadisk"
  location             = azurerm_resource_group.aks_rg.location
  resource_group_name  = azurerm_resource_group.aks_rg.name
  zone                 = var.availability_zone[0]
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.extra_disk_size_gb
}


resource "azurerm_virtual_machine_data_disk_attachment" "disk_attachment_blackbox" {
#  count              = var.vm_count_rabbitmq
  managed_disk_id    = azurerm_managed_disk.disk_blackbox.id
  virtual_machine_id = azurerm_linux_virtual_machine.azure_vm_blackbox.id
  lun                ="0"
  caching            = "ReadWrite"
}

############################################## Creation for NSG for Loki Server #######################################################

resource "azurerm_network_security_group" "azure_nsg_loki" {
#  count               = var.vm_count_rabbitmq
  name                = "loki-nsg"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  security_rule {
    name                       = "loki_ssh_azure"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_node_exporter"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefixes    = ["10.224.0.0/12"]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "azure_nsg_loki"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["9096", "9093", "7946", "9080"]  #Default port for Loki is 3100 but here I am using it through the Application Gateways.
    source_address_prefixes    = ["10.224.0.0/12"]
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.env
  }
}

########################################## Create Public IP and Network Interface for Loki #############################################

resource "azurerm_public_ip" "public_ip_loki" {
  count               = 3           ###var.vm_count_rabbitmq
  name                = "loki-ip-${count.index + 1}"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  allocation_method   = var.static_dynamic[0]

  sku = "Standard"   ### Basic, For Availability Zone to be Enabled the SKU of Public IP must be Standard
  zones = var.availability_zone

  tags = {
    environment = var.env
  }
}

resource "azurerm_network_interface" "vnet_interface_loki" {
  count               = 3           ###var.vm_count_rabbitmq
  name                = "loki-nic-${count.index + 1}"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name

  ip_configuration {
    name                          = "loki-ip-configuration-${count.index + 1}"
    subnet_id                     = azurerm_subnet.aks_subnet.id
    private_ip_address_allocation = var.static_dynamic[1]
    public_ip_address_id = azurerm_public_ip.public_ip_loki[count.index].id
  }

  tags = {
    environment = var.env
  }
}

############################################ Attach NSG to Network Interface for Loki #####################################################

resource "azurerm_network_interface_security_group_association" "nsg_nic_loki" {
  count                     = 3             ###var.vm_count_rabbitmq
  network_interface_id      = azurerm_network_interface.vnet_interface_loki[count.index].id
  network_security_group_id = azurerm_network_security_group.azure_nsg_loki.id

}

######################################################## Create Azure VM for Loki ##########################################################

resource "azurerm_linux_virtual_machine" "azure_vm_loki" {
  count                 = 3       ###var.vm_count_rabbitmq
  name                  = "loki-vm-${count.index + 1}"
  location              = azurerm_resource_group.aks_rg.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  network_interface_ids = [azurerm_network_interface.vnet_interface_loki[count.index].id]
  size                  = var.vm_size
  zone                 = var.availability_zone[0]
  computer_name  = "loki-vm-${count.index + 1}"
  admin_username = var.admin_username
  admin_password = var.admin_password
  custom_data    = filebase64("custom_data_loki.sh")
  disable_password_authentication = false

  #### Boot Diagnostics is Enable with managed storage account ########
  boot_diagnostics {
    storage_account_uri  = ""
  }

  source_image_reference {
    publisher = "almalinux"      ###"OpenLogic"
    offer     = "almalinux-x86_64"      ###"CentOS"
    sku       = "8_7-gen2"         ###"7_9-gen2"
    version   = "latest"         ###"latest"
  }
  os_disk {
    name              = "loki-osdisk-${count.index + 1}"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb      = var.disk_size_gb
  }

  tags = {
    environment = var.env
  }

  depends_on = [azurerm_managed_disk.disk_loki]
}

resource "null_resource" "azurevm_loki" {
  count = 3
  depends_on = [azurerm_linux_virtual_machine.azure_vm_loki, azurerm_network_interface.vnet_interface_loki]
  provisioner "remote-exec" {
    inline = [
         "sleep 60",
         "echo 'memberlist:' | sudo tee -a /opt/loki-local-config.yaml > /dev/null",
         "echo -e '  join_members:' | sudo tee -a /opt/loki-local-config.yaml > /dev/null",
         "echo -e \"  - url: http://${azurerm_network_interface.vnet_interface_loki[0].private_ip_address}:7946\" | sudo tee -a /opt/loki-local-config.yaml > /dev/null",                                                                                                                                                      
         "echo -e \"  - url: http://${azurerm_network_interface.vnet_interface_loki[1].private_ip_address}:7946\" | sudo tee -a /opt/loki-local-config.yaml > /dev/null",
         "echo -e \"  - url: http://${azurerm_network_interface.vnet_interface_loki[2].private_ip_address}:7946\" | sudo tee -a /opt/loki-local-config.yaml > /dev/null",
         "sudo systemctl restart loki",
         "sudo sed -i '/- url:/d' /opt/promtail-local-config.yaml",
         "sudo sed -i -e '/clients:/a \"- url: http://${azurerm_network_interface.vnet_interface_loki[0].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[1].private_ip_address}:3100/loki/api/v1/push\" \\n\"- url: http://${azurerm_network_interface.vnet_interface_loki[2].private_ip_address}:3100/loki/api/v1/push\"' /opt/promtail-local-config.yaml",
         "sudo sed -i 's/\"//g' /opt/promtail-local-config.yaml",
         "sudo systemctl restart promtail",
    ]
  }
  connection {
    type = "ssh"
    host = azurerm_public_ip.public_ip_loki[count.index].ip_address
    user = "ritesh"
    password = "Password@#795"
  }
}

resource "azurerm_managed_disk" "disk_loki" {
  count                = 3          ###var.vm_count_rabbitmq
  name                 = "loki-datadisk-${count.index + 1}"
  location             = azurerm_resource_group.aks_rg.location
  resource_group_name  = azurerm_resource_group.aks_rg.name
  zone                 = var.availability_zone[0]
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.extra_disk_size_gb
}


resource "azurerm_virtual_machine_data_disk_attachment" "disk_attachment_loki" {
  count              = 3            ###var.vm_count_rabbitmq
  managed_disk_id    = azurerm_managed_disk.disk_loki[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.azure_vm_loki[count.index].id
  lun                ="0"
  caching            = "ReadWrite"
}

