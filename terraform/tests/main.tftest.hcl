# Офлайн-тести конфігурації (без акаунта AWS): провайдер aws замінено моком.
# Запуск із папки terraform/:  terraform test
# Студент: Яровий Михайло, група КН-42

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0mockubuntu2404"
    }
  }
  mock_resource "aws_instance" {
    defaults = {
      public_ip = "203.0.113.10"
    }
  }
}

variables {
  key_name         = "nodeapp-lab12-key"
  public_key_path  = "tests/fixtures/test_key.pub"
  private_key_path = "~/.ssh/nodeapp_lab9"
}

run "security_group_opens_22_and_app_port" {
  command = plan

  assert {
    condition     = length(aws_security_group.app_sg.ingress) == 2
    error_message = "Очікується 2 вхідні правила"
  }
  assert {
    condition     = toset([for r in aws_security_group.app_sg.ingress : r.from_port]) == toset([22, 3000])
    error_message = "Мають бути відкриті порти 22 і 3000"
  }
  assert {
    condition     = one(aws_security_group.app_sg.egress).protocol == "-1"
    error_message = "Вихідний трафік має бути дозволений повністю"
  }
}

run "instance_uses_variables_and_bootstrap" {
  command = plan

  assert {
    condition     = aws_instance.app_server.instance_type == "t3.micro"
    error_message = "Тип інстансу за замовчуванням — t3.micro"
  }
  assert {
    condition     = aws_instance.app_server.ami == "ami-0mockubuntu2404"
    error_message = "Порожній ami_id має брати AMI Ubuntu з data source"
  }
  assert {
    condition     = aws_instance.app_server.tags["Name"] == "nodeapp-lab12-yarovyi"
    error_message = "Неправильний тег Name"
  }
  assert {
    condition     = strcontains(local.user_data, "docker-compose-v2") && strcontains(local.user_data, "pm2")
    error_message = "user_data має встановлювати Docker Compose і прибирати pm2"
  }
  assert {
    condition     = length(aws_key_pair.deployer) == 1
    error_message = "Key Pair має створюватися з public_key_path"
  }
}

run "explicit_ami_and_existing_key_pair" {
  command = plan

  variables {
    ami_id          = "ami-0123456789abcdef0"
    public_key_path = null
    key_name        = "existing-key"
  }

  assert {
    condition     = aws_instance.app_server.ami == "ami-0123456789abcdef0"
    error_message = "Явно заданий ami_id має мати пріоритет"
  }
  assert {
    condition     = length(aws_key_pair.deployer) == 0 && aws_instance.app_server.key_name == "existing-key"
    error_message = "Без public_key_path використовується існуючий Key Pair"
  }
}

run "outputs" {
  command = apply

  assert {
    condition     = output.instance_ip == "203.0.113.10"
    error_message = "instance_ip має містити публічну IP"
  }
  assert {
    condition     = output.app_url == "http://203.0.113.10:3000"
    error_message = "Неправильний app_url"
  }
  assert {
    condition     = output.ssh_command == "ssh -i ~/.ssh/nodeapp_lab9 ubuntu@203.0.113.10"
    error_message = "Неправильний ssh_command"
  }
}
