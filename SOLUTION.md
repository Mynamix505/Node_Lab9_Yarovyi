# Практичне заняття №12. Автоматичне створення інфраструктури й деплою через Terraform і GitHub Actions

**Дисципліна:** DevOps / Хмарні технології та контейнеризація
**Студент:** Яровий Михайло, група КН-42
**Репозиторій:** https://github.com/Mynamix505/Node_Lab9_Yarovyi (продовження ПР9; її розв'язок — у `SOLUTION_PR9.md`)

---

## Поточний статус виконання

| Етап | Статус |
|---|---|
| Встановлення Terraform | ✅ Terraform v1.17.2 (winget, `Hashicorp.Terraform`), `terraform -v` працює |
| Конфігурація `terraform/` (`main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars`) | ✅ створено |
| `terraform init` | ✅ встановлено провайдер `hashicorp/aws` v5.100.0, створено `.terraform.lock.hcl` |
| `terraform fmt -check`, `terraform validate` | ✅ `Success! The configuration is valid.` |
| `terraform test` (офлайн, мок-провайдер AWS) | ✅ `Success! 4 passed, 0 failed.` |
| `terraform plan` / `apply` / `destroy` у реальному AWS | ⏸ **не виконувалось**: немає акаунта AWS. `plan` зупиняється на автентифікації (`no EC2 IMDS role found`), інструкцію наведено нижче (розділи 4–7) |
| CI/CD: build → Docker Hub → `docker compose` deploy | ✅ працює (ПР9, run 44944494179) |
| Джоб `deploy-ec2` (SSH на EC2 через `EC2_HOST`) | ✅ підготовлено; вмикається змінною `EC2_DEPLOY=true` після `terraform apply` |

---

## 1. Структура

```text
Node_Lab9_Yarovyi/
├── terraform/
│   ├── main.tf                  # провайдер AWS, AMI Ubuntu 24.04, Key Pair, Security Group (22, 3000), EC2 + user_data
│   ├── variables.tf             # aws_region, ami_id, instance_type, key_name, public_key_path, private_key_path, app_port, ssh_user
│   ├── outputs.tf               # instance_ip, instance_id, ami_id, security_group_id, ssh_command, app_url
│   ├── terraform.tfvars         # значення змінних (без секретів)
│   ├── terraform.tfvars.example # шаблон
│   ├── .terraform.lock.hcl      # зафіксована версія провайдера (комітиться)
│   └── tests/main.tftest.hcl    # офлайн-тести конфігурації
├── .github/workflows/
│   ├── deploy.yml               # build-and-push → deploy → deploy-ec2 (SSH, EC2_HOST)
│   └── terraform.yml            # fmt / validate / test у CI
├── .gitignore                   # .terraform/, *.tfstate*, *.tfplan, *.pem, .env, node_modules/
└── Dockerfile, docker-compose.yml, index.js … (з ПР9, без змін)
```

## 2. Опис конфігурації Terraform

### 2.1. `variables.tf`

| Змінна | Тип | За замовчуванням | Призначення |
|---|---|---|---|
| `aws_region` | string | `us-east-1` | регіон AWS |
| `ami_id` | string | `""` | ID образу; порожній — автоматично найновіший Ubuntu 24.04 LTS від Canonical |
| `instance_type` | string | `t3.micro` | тип інстансу (Free Tier) |
| `key_name` | string | — (обов'язкова) | назва Key Pair в EC2 |
| `public_key_path` | string | `null` | якщо задано — Terraform сам створює Key Pair з цього публічного ключа |
| `private_key_path` | string | `~/.ssh/id_rsa` | шлях до приватного ключа (для підказки `ssh_command`) |
| `app_port` | number | `3000` | порт застосунку (з валідацією 1–65535) |
| `ssh_user` | string | `ubuntu` | користувач SSH в образі Ubuntu |

### 2.2. `main.tf`

- **`terraform { required_version = ">= 1.5.0" }`** і провайдер `hashicorp/aws ~> 5.0`; `provider "aws" { region = var.aws_region }`.
- **`data "aws_ami" "ubuntu"`** — пошук найновішого образу `ubuntu-noble-24.04-amd64-server-*` власника `099720109477` (Canonical). Використовується, якщо `ami_id = ""`. Тому конфігурація працює в будь-якому регіоні без ручного пошуку AMI.
- **`aws_key_pair.deployer`** (з `count`) створюється лише при заданому `public_key_path`. Інакше використовується існуючий Key Pair `key_name`.
- **`aws_security_group.app_sg`**:
  - `ingress` 22/tcp (SSH для GitHub Actions) та `var.app_port`/tcp (застосунок) з `0.0.0.0/0`;
  - `egress` — увесь вихідний трафік (потрібен для `apt`, Docker Hub).
- **`aws_instance.app_server`**:
  - `ami`, `instance_type`, `key_name` зі змінних, Security Group, публічна IP;
  - диск gp3 20 ГБ, лише IMDSv2, теги `Name = "nodeapp-lab12-yarovyi"`.
- **`user_data`** виконується при першому старті:
  - видаляє `pm2`, якщо він є;
  - встановлює `docker.io` + `docker-compose-v2`, вмикає службу Docker і додає `ubuntu` до групи `docker`;
  - створює `~/nodeapp`, куди CI/CD копіює `docker-compose.yml`.

  Отже, сервер одразу готовий до деплою, і `setup-ec2.sh` з ПР9 вручну запускати не потрібно.

### 2.3. `outputs.tf`

`instance_ip` (значення для секрету `EC2_HOST`), `instance_id`, `ami_id`, `security_group_id`, `ssh_command`, `app_url`.

### 2.4. `terraform.tfvars`

Заповнено робочими значеннями без секретів: `us-east-1`, `t3.micro`, автоматичний AMI. Key Pair `nodeapp-lab12-key` створюється з публічного ключа `~/.ssh/nodeapp_lab9.pub`. Його пара — приватний ключ, який уже записаний у секрет `EC2_SSH_KEY`. Тому після `apply` GitHub Actions одразу може зайти на сервер.

Якщо Key Pair створено в консолі AWS (файл `.pem`), у `terraform.tfvars` вкажіть його назву в `key_name`, закоментуйте `public_key_path`, а вміст `.pem` запишіть у секрет `EC2_SSH_KEY`.

### 2.5. `.gitignore`

Додано `.terraform/`, `**/.terraform/`, `terraform.tfstate`, `terraform.tfstate.*`, `terraform.tfstate.backup`, `*.tfplan`, `crash.log`. Також там уже були `*.pem`, `.env` і `node_modules/`. Стан (`tfstate`) містить IP, ID ресурсів і може містити секрети, тому в Git він не потрапляє. Файл `.terraform.lock.hcl` навпаки комітиться, щоб усі використовували однакову версію провайдера.

## 3. Встановлення Terraform (Windows)

```powershell
winget install --id Hashicorp.Terraform -e
# перезапустіть термінал (winget додає terraform до PATH)
terraform -v          # Terraform v1.17.2 on windows_amd64
```

Ручний варіант: завантажити zip з https://developer.hashicorp.com/terraform/install, розпакувати `terraform.exe`, наприклад, у `C:\terraform`. Потім додати цю папку до `PATH`: «Змінні середовища» → `Path` → «Створити». Перезапустити термінал.

## 4. Облікові дані AWS

Terraform бере ключі зі змінних середовища або з `aws configure`.

**AWS Academy Learner Lab:** Start Lab → **AWS Details** → **AWS CLI: Show** → скопіювати три значення:

```powershell
$env:AWS_ACCESS_KEY_ID     = "ASIA..."
$env:AWS_SECRET_ACCESS_KEY = "..."
$env:AWS_SESSION_TOKEN     = "..."      # лише для тимчасових ключів (Academy)
```

**Власний акаунт:** IAM → Users → Security credentials → Create access key, далі `aws configure` або ті самі змінні без `AWS_SESSION_TOKEN`.

Ключі не записуються в `.tf`-файли й не комітяться.

## 5. Створення інфраструктури

```powershell
cd terraform
terraform init                # завантаження провайдера aws
terraform fmt -check          # форматування
terraform validate            # синтаксис і типи
terraform test                # офлайн-тести (не потребують AWS)
terraform plan                # що буде створено: aws_key_pair, aws_security_group, aws_instance (3 to add)
terraform apply               # підтвердити: yes
terraform output              # instance_ip, ssh_command, app_url
```

Очікуваний результат `apply`:

```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:
app_url           = "http://<IP>:3000"
instance_ip       = "<IP>"
security_group_id = "sg-..."
ssh_command       = "ssh -i ~/.ssh/nodeapp_lab9 ubuntu@<IP>"
```

Через 1–2 хвилини `user_data` завершить встановлення Docker. Перевірити:

```powershell
ssh -i ~/.ssh/nodeapp_lab9 ubuntu@<IP> "cloud-init status; docker --version; docker compose version"
```

## 6. Підключення GitHub Actions до нового EC2

1. Оновити `EC2_HOST` отриманою IP. Інші секрети (`EC2_USERNAME=ubuntu`, `EC2_SSH_KEY`, `DOCKERHUB_*`) уже налаштовані:
   ```powershell
   gh secret set EC2_HOST --body (terraform output -raw instance_ip)
   ```
   Або вручну: GitHub → **Settings → Secrets and variables → Actions → EC2_HOST → Update**.
2. Увімкнути джоб `deploy-ec2`:
   ```powershell
   gh variable set EC2_DEPLOY --body true
   ```
   Або вручну: **Settings → Secrets and variables → Actions → Variables → New variable**, `EC2_DEPLOY` = `true`.
3. Запустити деплой: `git push` у `main` або `gh workflow run deploy.yml`.

Що робить пайплайн (`.github/workflows/deploy.yml`):

| Джоб | Дії |
|---|---|
| `build-and-push` | тести → `docker build` → push `mynamix505/nodeapp:<короткий хеш>` і `:latest` |
| `deploy` | `docker compose pull/up` на runner і перевірка `/` та `/health` |
| `deploy-ec2` | `scp` `docker-compose.yml` → `ssh` на `EC2_HOST`: очікування завершення `cloud-init`, `docker login`, видалення `pm2`, `docker compose pull app`, `docker rm -f nodeapp`, `docker compose up -d --no-build`, `docker image prune -f`, перевірка `curl /health` |

4. Перевірка:
   ```powershell
   curl.exe (terraform output -raw app_url)
   curl.exe "$(terraform output -raw app_url)/health"
   ```
   Очікувано `"db":"connected"` і `"imageTag":"<хеш коміту>"`.

## 7. Видалення ресурсів (обов'язково після перевірки)

```powershell
cd terraform
terraform destroy             # підтвердити: yes
# Destroy complete! Resources: 3 destroyed.
gh variable set EC2_DEPLOY --body false   # щоб пайплайн не намагався деплоїти на видалений сервер
```

Перевірити в консолі AWS:
- **EC2 → Instances**: `nodeapp-lab12-yarovyi` у стані *Terminated*;
- **EC2 → Security Groups**: `nodeapp-lab12-yarovyi-sg` відсутня;
- **EC2 → Key Pairs**: `nodeapp-lab12-key` відсутній.

У Learner Lab після цього натиснути **End Lab**.

## 8. Що перевірено без AWS

```text
> terraform -v
Terraform v1.17.2 on windows_amd64

> terraform init
- Installing hashicorp/aws v5.100.0...
Terraform has been successfully initialized!

> terraform validate
Success! The configuration is valid.

> terraform fmt -check -recursive      (без змін)

> terraform test
tests\main.tftest.hcl... in progress
  run "security_group_opens_22_and_app_port"... pass
  run "instance_uses_variables_and_bootstrap"... pass
  run "explicit_ami_and_existing_key_pair"... pass
  run "outputs"... pass
Success! 4 passed, 0 failed.

> terraform plan
Error: failed to refresh cached credentials, no EC2 IMDS role found
```

Що перевіряють тести `terraform test` (провайдер AWS підмінено `mock_provider`, реальні ресурси не створюються):
1. Security Group має рівно два вхідні правила (порти 22 і 3000) і повний вихідний доступ.
2. Інстанс має тип `t3.micro` і тег `Name`, бере AMI з data source, а `user_data` встановлює Docker Compose і прибирає pm2. Key Pair створюється з публічного ключа.
3. Явно заданий `ami_id` має пріоритет, а без `public_key_path` використовується існуючий Key Pair.
4. Виходи `instance_ip`, `app_url`, `ssh_command` формуються правильно.

Ті самі перевірки щоразу виконує workflow **Terraform check** (`.github/workflows/terraform.yml`) при зміні `terraform/`.

## Висновки

Інфраструктура для деплою описана як код. Одна команда `terraform apply` створює Security Group з портами 22 і 3000 та інстанс EC2 з Ubuntu 24.04, на якому `user_data` автоматично встановлює Docker і Docker Compose. `terraform output` видає IP для секрету `EC2_HOST`, після чого GitHub Actions збирає образ, публікує його в Docker Hub і розгортає на сервері через `docker compose`. `terraform destroy` повністю прибирає ресурси, тому зайвих витрат немає. Конфігурацію перевірено `validate` та офлайн-тестами з мок-провайдером. Реальні `plan/apply/destroy` не виконувались, бо немає акаунта AWS, а їх покрокову інструкцію наведено в розділах 4–7.
