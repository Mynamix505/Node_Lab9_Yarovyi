# Значення змінних для terraform plan / apply. Секретів тут немає — файл можна комітити.
# Студент: Яровий Михайло, група КН-42

# Регіон AWS (для AWS Academy Learner Lab — лише us-east-1)
aws_region = "us-east-1"

# AMI: порожній рядок = найновіший Ubuntu 24.04 LTS (знаходиться автоматично).
# Щоб зафіксувати конкретний образ, підставте ID з EC2 → AMI Catalog, напр. "ami-0xxxxxxxxxxxxxxxx"
ami_id = ""

# Тип інстансу (Free Tier: t3.micro або t2.micro)
instance_type = "t3.micro"

# Назва Key Pair в AWS. Варіанти:
#  а) Key Pair уже створено в консолі EC2 → вкажіть його назву, а public_key_path закоментуйте;
#  б) залиште public_key_path — Terraform сам створить Key Pair "nodeapp-lab12-key" з вашого публічного ключа.
key_name = "nodeapp-lab12-key"

# Публічний ключ, з якого створюється Key Pair (пара до ключа в секреті EC2_SSH_KEY)
public_key_path = "~/.ssh/nodeapp_lab9.pub"

# Приватний ключ для SSH (лише для підказки ssh_command; у Git НЕ потрапляє)
private_key_path = "~/.ssh/nodeapp_lab9"

# Порт Node.js-застосунку (має збігатися з docker-compose.yml)
app_port = 3000
