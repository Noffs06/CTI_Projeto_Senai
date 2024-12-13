# Exibe o endereço IP público da instância Zabbix
output "ipzabbix" {
  value = aws_instance.lin_zabbix.public_ip  # IP público da instância do Zabbix
}

# Exibe o endereço IP privado da instância Zabbix
output "ipprivzab" {
  value = aws_instance.lin_zabbix.private_ip  # IP privado da instância do Zabbix
}

# Exibe a URL de acesso ao Zabbix utilizando o IP público
output "urlzabbix" {
  value = "http://${aws_instance.lin_zabbix.public_ip}/zabbix"  # URL do Zabbix com o IP público
}

# Exibe a URL de acesso ao Grafana utilizando o IP público e a porta 3000
output "urlgrafana" {
  value = "http://${aws_instance.lin_zabbix.public_ip}:3000"  # URL do Grafana com o IP público e porta 3000
}
