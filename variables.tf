# AWS - Arquivo de configuração da AWS
variable "configfile" {
  sensitive = true  # Marca a variável como sensível (não será exibida nos logs)
}

# AWS - Arquivo de credenciais da AWS
variable "credentialsfile" {
  sensitive = true  # Marca a variável como sensível (não será exibida nos logs)
}

# AWS - Dados de inicialização do Zabbix (em base64)
variable "bootZab" {
  sensitive = true  # Marca a variável como sensível (não será exibida nos logs)
}

# Azure - ID da assinatura do Azure
variable "subId" {
  sensitive = true  # Marca a variável como sensível (não será exibida nos logs)
}
