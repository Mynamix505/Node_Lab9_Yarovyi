# Практичне заняття №12. Автоматичне створення інфраструктури через Terraform
# Студент: Яровий Михайло, група КН-42
#
# Створює: Security Group (SSH 22, застосунок 3000) + EC2 Ubuntu з Docker і Docker Compose,
# на який GitHub Actions (.github/workflows/deploy.yml, джоб deploy-ec2) деплоїть контейнери.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Найновіший офіційний Ubuntu 24.04 LTS (власник 099720109477 — Canonical),
# використовується лише якщо ami_id не задано явно
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id

  # Скрипт першого запуску: Docker + Compose plugin, видалення pm2, директорія для docker-compose.yml
  user_data = <<-EOT
    #!/bin/bash
    set -eux
    export DEBIAN_FRONTEND=noninteractive

    # Видалення pm2 (якщо присутній), щоб старі процеси Node.js не займали порт ${var.app_port}
    if command -v pm2 >/dev/null 2>&1; then
      sudo -u ${var.ssh_user} pm2 delete all || true
      sudo -u ${var.ssh_user} pm2 kill || true
      npm uninstall -g pm2 || true
    fi

    # Docker Engine + Docker Compose plugin з репозиторію Ubuntu
    apt-get update
    apt-get install -y docker.io docker-compose-v2 curl
    systemctl enable --now docker
    usermod -aG docker ${var.ssh_user}

    # Сюди GitHub Actions копіює docker-compose.yml
    install -d -o ${var.ssh_user} -g ${var.ssh_user} /home/${var.ssh_user}/nodeapp
    echo "nodeapp-lab12: bootstrap done" > /var/log/nodeapp-bootstrap.log
  EOT
}

# Key Pair створюється лише якщо передано public_key_path; інакше використовується існуючий key_name
resource "aws_key_pair" "deployer" {
  count      = var.public_key_path == null ? 0 : 1
  key_name   = var.key_name
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_security_group" "app_sg" {
  name        = "nodeapp-lab12-yarovyi-sg"
  description = "SSH and Node.js app access for Lab 12"

  ingress {
    description = "SSH (GitHub Actions deploy)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node.js app"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nodeapp-lab12-yarovyi-sg"
  }
}

resource "aws_instance" "app_server" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  key_name                    = var.public_key_path == null ? var.key_name : aws_key_pair.deployer[0].key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true
  user_data                   = local.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "required" # лише IMDSv2
  }

  tags = {
    Name    = "nodeapp-lab12-yarovyi"
    Student = "Yarovyi Mykhailo, KN-42"
  }
}
