# Criação de uma VPC com CIDR 192.168.0.0/16 e habilitação de DNS para as instâncias
resource "aws_vpc" "vpn_vpc" {
  cidr_block           = "192.168.0.0/16"  # Intervalo de IP para a VPC
  enable_dns_hostnames = true               # Habilita DNS para as instâncias dentro da VPC

  tags = {
    Name = "VPC-VPN"                        # Nome da VPC
  }
}

# Subnet 1 na disponibilidade 'us-east-1a' com CIDR 192.168.1.0/24
resource "aws_subnet" "vpn_subnet1" {
  vpc_id                                      = aws_vpc.vpn_vpc.id
  cidr_block                                  = "192.168.1.0/24"  # Intervalo de IP para esta subnet
  availability_zone                           = "us-east-1a"       # Zona de disponibilidade
  enable_resource_name_dns_a_record_on_launch = true  # Cria registro DNS automaticamente para as instâncias
  map_public_ip_on_launch                     = true  # Aloca IP público para as instâncias lançadas

  tags = {
    Name = "SubPubVPN1"                       # Nome da subnet
  }
}

# Subnet 2 em 'us-east-1b' com CIDR 192.168.2.0/24
resource "aws_subnet" "vpn_subnet2" {
  vpc_id                                      = aws_vpc.vpn_vpc.id
  cidr_block                                  = "192.168.2.0/24"
  availability_zone                           = "us-east-1b"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch                     = true

  tags = {
    Name = "SubPubVPN2"
  }
}

# Subnet 3 em 'us-east-1c' com CIDR 192.168.3.0/24
resource "aws_subnet" "vpn_subnet3" {
  vpc_id                                      = aws_vpc.vpn_vpc.id
  cidr_block                                  = "192.168.3.0/24"
  availability_zone                           = "us-east-1c"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch                     = true

  tags = {
    Name = "SubPubVPN3"
  }
}

# Subnet 4 em 'us-east-1d' com CIDR 192.168.4.0/24
resource "aws_subnet" "vpn_subnet4" {
  vpc_id                                      = aws_vpc.vpn_vpc.id
  cidr_block                                  = "192.168.4.0/24"
  availability_zone                           = "us-east-1d"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch                     = true

  tags = {
    Name = "SubPubVPN4"
  }
}

# Criação de um Gateway de Internet (IGW) para permitir tráfego externo na VPC
resource "aws_internet_gateway" "IGW-VPN" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name = "IGW-VPN"
  }
}

# Criação de um Gateway VPN para permitir a conexão com a rede externa
resource "aws_vpn_gateway" "vpn_gateway" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name = "VPGW-VPN"
  }
}

# Criação do Gateway do Cliente (CGW) com ASN BGP 65000 e IP público configurado
resource "aws_customer_gateway" "cg" {
  bgp_asn    = 65000  # ASN BGP para a comunicação
  ip_address = azurerm_public_ip.vpn_gateway_ip.ip_address  # Endereço IP do gateway no Azure (referência a um recurso do Azure)
  type       = "ipsec.1"  # Tipo de VPN IPsec

  tags = {
    Name = "CGW-VPN"
  }
}

# Configuração da conexão VPN entre o VPGW e o CGW, especificando rotas estáticas
resource "aws_vpn_connection" "vpn_connection" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id
  customer_gateway_id = aws_customer_gateway.cg.id
  type                = "ipsec.1"  # Tipo de VPN (IPsec)
  static_routes_only  = true  # Apenas rotas estáticas

  tags = {
    Name = "VPN-AWS-AZURE"
  }
}

# Configura rotas de VPN específicas para sub-redes externas conectadas via VPN (Azure)
resource "aws_vpn_connection_route" "rota_vpnAZ1" {
  depends_on             = [aws_vpn_connection.vpn_connection]
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
  destination_cidr_block = "172.16.1.0/24"  # Rota para a sub-rede na Azure
}

resource "aws_vpn_connection_route" "rota_vpnAZ2" {
  depends_on             = [aws_vpn_connection.vpn_connection]
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
  destination_cidr_block = "172.16.2.0/24"  # Outra rota para sub-rede na Azure
}

# Criação de uma tabela de rotas com rotas para a internet e para a VPN
resource "aws_route_table" "vpn_route_table" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"  # Rota padrão para a Internet via IGW
    gateway_id = aws_internet_gateway.IGW-VPN.id
  }
  route {
    cidr_block = "172.16.1.0/24"  # Rota para a rede na Azure via VPN
    gateway_id = aws_vpn_gateway.vpn_gateway.id
  }
  route {
    cidr_block = "172.16.2.0/24"  # Outra rota para rede na Azure
    gateway_id = aws_vpn_gateway.vpn_gateway.id
  }

  tags = {
    Name = "Rotas-VPN"
  }
}

# Propagação de rotas no Gateway VPN para a tabela de rotas
resource "aws_vpn_gateway_route_propagation" "vpn_propagation" {
  depends_on     = [aws_vpn_gateway.vpn_gateway, aws_route_table.vpn_route_table]
  vpn_gateway_id = aws_vpn_gateway.vpn_gateway.id
  route_table_id = aws_route_table.vpn_route_table.id
}

# Associa as subnets com a tabela de rotas, garantindo que o tráfego seja roteado corretamente
resource "aws_route_table_association" "vpn_route_table_association1" {
  subnet_id      = aws_subnet.vpn_subnet1.id
  route_table_id = aws_route_table.vpn_route_table.id
}

# Instância EC2 configurada para rodar o Zabbix, monitorando a infraestrutura
resource "aws_instance" "lin_zabbix" {
  ami                         = "ami-0e001c9271cf7f3b9"  # ID da imagem AMI
  instance_type               = "t3.medium"  # Tipo da instância
  subnet_id                   = aws_subnet.vpn_subnet1.id  # Subnet onde a instância será criada
  key_name                    = "vockey"  # Chave SSH para acessar a instância
  associate_public_ip_address = true  # Atribui IP público
  vpc_security_group_ids      = [aws_security_group.zab_sg.id]  # Associa o security group

  user_data_base64 = var.bootZab  # Script para configuração inicial do Zabbix

  tags = {
    Name = "SRV-Monitoramento"
  }
}

# Security Group para o EKS, permitindo tráfego para o funcionamento do cluster Kubernetes
resource "aws_security_group" "eks_sg" {
  name        = "EKS-SEC"
  description = "Permitir todos os protocolos necessários para o funcionamento do Cluster EKS"
  vpc_id      = aws_vpc.vpn_vpc.id

  # Regras de entrada e saída (ingress/egress) configuradas para permitir comunicação com o cluster EKS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Saída"
  }

  tags = {
    Name = "EKS-SEC"
  }
}

# Security Group para o Zabbix Server, permitindo acesso ao Zabbix e à VPN do Azure
resource "aws_security_group" "zab_sg" {
  name        = "ZAB-SEC"
  description = "Permitir todos os protocolos necessários para o funcionamento do Zabbix Server"
  vpc_id      = aws_vpc.vpn_vpc.id

  # Regras de entrada configuradas para permitir acesso SSH, HTTP, Zabbix e Kubernetes
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["193.186.4.239/32"]  # IP de origem específico (SSH)
    description = "SSH"
  }

  # Tráfego de saída configurado para permitir qualquer tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Saída"
  }

  tags = {
    Name = "ZAB-SEC"
  }
}
