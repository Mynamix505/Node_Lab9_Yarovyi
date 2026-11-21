# Практичне заняття №12. Terraform + GitHub Actions
# Студент: Яровий Михайло, група КН-42

variable "aws_region" {
  description = "Регіон AWS, у якому створюється інфраструктура"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "ID образу ОС (AMI). Порожній рядок — автоматично взяти найновіший Ubuntu 24.04 LTS від Canonical у вибраному регіоні"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Тип інстансу EC2 (t3.micro / t2.micro входять у Free Tier)"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Назва Key Pair в AWS EC2 для SSH-доступу до інстансу"
  type        = string
}

variable "public_key_path" {
  description = "Шлях до ПУБЛІЧНОГО ключа (.pub). Якщо задано — Terraform сам створить Key Pair з назвою key_name; якщо null — використовується вже існуючий Key Pair key_name"
  type        = string
  default     = null
}

variable "private_key_path" {
  description = "Шлях до приватного ключа на локальному комп'ютері (використовується в підказці ssh_command)"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "app_port" {
  description = "Порт Node.js-застосунку"
  type        = number
  default     = 3000

  validation {
    condition     = var.app_port > 0 && var.app_port < 65536
    error_message = "app_port має бути в діапазоні 1–65535."
  }
}

variable "ssh_user" {
  description = "Користувач SSH для образу Ubuntu"
  type        = string
  default     = "ubuntu"
}
