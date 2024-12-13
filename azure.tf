# Criação do Grupo de Recursos
resource "azurerm_resource_group" "grupo" {
  name     = "RG-VPN"
  location = "East US"
}

# Criação da Rede Virtual (VNET)
resource "azurerm_virtual_network" "VNET-VPN" {
  name                = "VNET-VPN"
  address_space       = ["10.0.0.0/16", "172.16.0.0/16"]
  location            = "East US"
  resource_group_name = azurerm_resource_group.grupo.name
}

# Definição da Subrede Pública 1
resource "azurerm_subnet" "public1" {
  name                 = "SubredePub1-AZVPN"
  resource_group_name  = azurerm_resource_group.grupo.name
  virtual_network_name = azurerm_virtual_network.VNET-VPN.name
  address_prefixes     = ["172.16.1.0/24"]
}

# Definição da Subrede Pública 2
resource "azurerm_subnet" "public2" {
  name                 = "SubredePub1-AZVPN"
  resource_group_name  = azurerm_resource_group.grupo.name
  virtual_network_name = azurerm_virtual_network.VNET-VPN.name
  address_prefixes     = ["172.16.2.0/24"]
}

# Criação da Subrede do Gateway
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.grupo.name
  virtual_network_name = azurerm_virtual_network.VNET-VPN.name
  address_prefixes     = ["172.16.0.0/27"]
}

# Criação do IP Público Estático para o Gateway VPN
resource "azurerm_public_ip" "vpn_gateway_ip" {
  name                = "vpn-gateway-ip"
  location            = azurerm_resource_group.grupo.location # Região do grupo de recursos
  resource_group_name = azurerm_resource_group.grupo.name     # Nome do grupo de recursos
  allocation_method   = "Static"
  sku                 = "Standard" # Necessário para o Gateway VPN
}

# Configuração do Gateway de Rede Virtual (VPN Gateway)
resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = "VPGW-VPN-AZ"
  location            = "East US"                         # Região do gateway
  resource_group_name = azurerm_resource_group.grupo.name # Nome do grupo de recursos
  type                = "Vpn"                             # Tipo de Gateway: VPN
  sku                 = "VpnGw1"                          # SKU do Gateway: VpnGw1
  active_active       = false
  enable_bgp          = false
  ip_configuration {
    name                          = "VPN-Gateway-IP-Config"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }
}

# Tabela de Rotas para a conexão com AWS
resource "azurerm_route_table" "Rota_AWS" {
  name                = "TabelaRotas_VPN"
  location            = azurerm_resource_group.grupo.location
  resource_group_name = azurerm_resource_group.grupo.name

  route {
    name           = "RotaAWS"
    address_prefix = "192.168.0.0/21"
    next_hop_type  = "VirtualNetworkGateway"
  }
}

# Definição do Gateway Local 1 para a conexão VPN com AWS
resource "azurerm_local_network_gateway" "GTW-LOCAL01" {
  name                = "GTW-LOCAL01"
  location            = azurerm_resource_group.grupo.location
  resource_group_name = azurerm_resource_group.grupo.name

  gateway_address = aws_vpn_connection.vpn_connection.tunnel1_address
  address_space = [
    aws_subnet.vpn_subnet1.cidr_block,
    aws_subnet.vpn_subnet2.cidr_block,
    aws_subnet.vpn_subnet3.cidr_block,
    aws_subnet.vpn_subnet4.cidr_block
  ]
}

# Definição do Gateway Local 2 para a conexão VPN com AWS
resource "azurerm_local_network_gateway" "GTW-LOCAL02" {
  name                = "GTW-LOCAL02"
  location            = azurerm_resource_group.grupo.location
  resource_group_name = azurerm_resource_group.grupo.name

  gateway_address = aws_vpn_connection.vpn_connection.tunnel2_address
  address_space = [
    aws_subnet.vpn_subnet1.cidr_block,
    aws_subnet.vpn_subnet2.cidr_block,
    aws_subnet.vpn_subnet3.cidr_block,
    aws_subnet.vpn_subnet4.cidr_block
  ]
}

# Configuração da Primeira Conexão VPN com AWS
resource "azurerm_virtual_network_gateway_connection" "CONEXAO-01" {
  name                       = "CONEXAO-AWS01"
  location                   = azurerm_resource_group.grupo.location
  resource_group_name        = azurerm_resource_group.grupo.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.GTW-LOCAL01.id
  # Chave compartilhada da conexão VPN com AWS
  shared_key = aws_vpn_connection.vpn_connection.tunnel1_preshared_key
}

# Configuração da Segunda Conexão VPN com AWS
resource "azurerm_virtual_network_gateway_connection" "CONEXAO-02" {
  name                       = "CONEXAO-AWS02"
  location                   = azurerm_resource_group.grupo.location
  resource_group_name        = azurerm_resource_group.grupo.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.GTW-LOCAL02.id
  # Chave compartilhada da conexão VPN com AWS
  shared_key = aws_vpn_connection.vpn_connection.tunnel2_preshared_key
}

# Geração de um Prefixo Aleatório para o DNS do AKS
resource "random_pet" "azurerm_kubernetes_cluster_dns_prefix" {
  prefix = "dns"
}

# Criação do Cluster Kubernetes no Azure (AKS)
resource "azurerm_kubernetes_cluster" "default" {
  depends_on          = [azurerm_virtual_network.VNET-VPN]
  name                = "Cluster-AKS"
  location            = azurerm_resource_group.grupo.location
  resource_group_name = azurerm_resource_group.grupo.name
  dns_prefix          = "${random_pet.azurerm_kubernetes_cluster_dns_prefix.prefix}-k8s"
  kubernetes_version  = "1.29.10"
  node_resource_group = "AKS-NodesRG"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                 = "agentpool"
    vm_size              = "Standard_B2S"
    min_count            = 1
    max_count            = 2
    node_count           = 2
    auto_scaling_enabled = true
    max_pods             = 30
    vnet_subnet_id       = azurerm_subnet.public1.id
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
} 
