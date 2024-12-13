# Definição da versão do Terraform e dos providers necessários
terraform {
  required_version = ">=1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.42.0"  # Versão do provider AWS
    }
    azurerm = {
      source = "hashicorp/azurerm"  # Provider do Azure
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"  # Versão do provider para recursos aleatórios
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"  # Versão do provider para manipulação de tempo
    }
  }
}

# Configuração do provider Azure
provider "azurerm" {
  features {}  # Habilita as funcionalidades do provider Azure
  subscription_id = var.subId  # ID da assinatura do Azure
}

# Configuração do provider AWS
provider "aws" {
  region                   = "us-east-1"  # Região da AWS
  shared_config_files      = var.configfile  # Arquivo de configuração compartilhada
  shared_credentials_files = var.credentialsfile  # Arquivo de credenciais compartilhadas
}
