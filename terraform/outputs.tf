# Студент: Яровий Михайло, група КН-42

output "instance_ip" {
  description = "Публічна IP-адреса EC2 — значення для секрету EC2_HOST у GitHub Actions"
  value       = aws_instance.app_server.public_ip
}

output "instance_id" {
  description = "ID створеного інстансу EC2"
  value       = aws_instance.app_server.id
}

output "ami_id" {
  description = "Фактично використаний AMI"
  value       = aws_instance.app_server.ami
}

output "security_group_id" {
  description = "ID Security Group з відкритими портами 22 і app_port"
  value       = aws_security_group.app_sg.id
}

output "ssh_command" {
  description = "Команда для підключення до інстансу по SSH"
  value       = "ssh -i ${var.private_key_path} ${var.ssh_user}@${aws_instance.app_server.public_ip}"
}

output "app_url" {
  description = "Адреса застосунку після деплою"
  value       = "http://${aws_instance.app_server.public_ip}:${var.app_port}"
}
