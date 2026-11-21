# Практичне заняття №9. Створення Dockerfile для Node.js-додатку

**Дисципліна:** DevOps / Хмарні технології та контейнеризація
**Студент:** Яровий Михайло, група КН-42
**Додаткове завдання:** PostgreSQL + Docker Compose + CI/CD (Docker Hub → EC2)

---

## 1. Застосунок

`index.js` — Express-сервер на порту `3000` (слухає `0.0.0.0`, щоб бути доступним ззовні контейнера) з підключенням до PostgreSQL через `pg.Pool`. Параметри беруться зі змінних середовища:

| Змінна | За замовчуванням | Призначення |
|---|---|---|
| `DB_HOST` | `db` | ім'я сервісу PostgreSQL у `docker-compose.yml` |
| `DB_PORT` | `5432` | порт PostgreSQL |
| `DB_USER` / `DB_PASSWORD` | `postgres` / `postgres` | обліковий запис |
| `DB_NAME` | `appdb` | база даних |
| `IMAGE_TAG` | `local` | тег образу (короткий хеш коміту), показується на `/` |

**Retry-логіка.** `depends_on` гарантує лише порядок запуску контейнерів, а Postgres усередині контейнера `db` ініціалізується ще кілька секунд. Тому `connectWithRetry()` робить до 10 спроб `SELECT 1` з паузою 2 с і при успіху пише в лог:

```
Connected to PostgreSQL database successfully!
```

Додатково в `docker-compose.yml` для `db` налаштовано `healthcheck` (`pg_isready`), а `app` стартує лише за умови `service_healthy`.

**Маршрути:**

| Маршрут | Відповідь |
|---|---|
| `GET /` | `{ message, lab, author: "Яровий Михайло, група КН-42", imageTag, db: "connected" \| "disconnected" }` |
| `GET /health` | `SELECT NOW() AS now, version() AS pg_version` → `200 { status: "ok", db: "connected", time, pg_version }` або `500 { status: "error", db: "disconnected", error }` |

---

## 2. Dockerfile (основне завдання, п. 1)

```dockerfile
FROM node:lts
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

| Інструкція | Пояснення |
|---|---|
| `FROM node:lts` | Офіційний образ Node.js з актуальною LTS-версією: довгострокова підтримка й оновлення безпеки, у складі вже є `npm`. Повний (не `alpine`) образ — як у методичці, без проблем із нативними модулями |
| `WORKDIR /usr/src/app` | Робоча директорія в контейнері; створюється автоматично, усі подальші команди виконуються в ній |
| `COPY package*.json ./` | Копіюються **лише** `package.json` і `package-lock.json` |
| `RUN npm install` | Встановлення залежностей (`express`, `pg`) за lock-файлом |
| `COPY . .` | Копіювання решти коду (з урахуванням `.dockerignore`) |
| `EXPOSE 3000` | Документує порт, який слухає застосунок |
| `CMD ["npm", "start"]` | Команда запуску: `npm start` → `node index.js` |

**Чому `package*.json` копіюється перед рештою коду.** Docker кешує кожен шар і перебудовує шар лише тоді, коли змінились його вхідні файли. Шар `RUN npm install` залежить тільки від `package*.json`. Якщо змінюється лише `index.js`, Docker бере `node_modules` з кешу й перебудовує тільки останній шар `COPY . .`, тому збірка займає секунди. Якби код копіювався одразу повністю, будь-яка правка в коді знову запускала б завантаження всіх залежностей.

## 3. .dockerignore (основне завдання, п. 2)

```
node_modules        # залежності встановлюються всередині образу; локальні (Windows) можуть бути несумісні
npm-debug.log, *.log, .npm-cache
.env, .env.*, !.env.example, *.pem   # секрети не потрапляють в образ
.git, .gitignore, .gitattributes, .github
Dockerfile, .dockerignore, docker-compose.yml
README.md, SOLUTION.md, CLAUDE.md
test, scripts       # тести та службові скрипти не потрібні в продакшн-образі
```

Менший контекст збірки означає швидшу збірку, менший образ і відсутність у ньому секретів. Також `COPY . .` не перезапише `node_modules`, встановлені в образі.

## 4. Локальна збірка та запуск з тегом хешу коміту (основне завдання, п. 3)

```bash
GIT_HASH=$(git rev-parse --short HEAD)
docker build -t <your-name>/nodeapp:$GIT_HASH .
docker images <your-name>/nodeapp

# Запуск лише контейнера застосунку (без БД: / покаже db: "disconnected", /health — 500)
docker run -d --name nodeapp -p 3000:3000 -e IMAGE_TAG=$GIT_HASH <your-name>/nodeapp:$GIT_HASH
curl http://localhost:3000
docker logs nodeapp
docker rm -f nodeapp

# Публікація в Docker Hub
docker login
docker push <your-name>/nodeapp:$GIT_HASH
```

PowerShell-варіант: `$GIT_HASH = git rev-parse --short HEAD`, далі `docker build -t "<your-name>/nodeapp:$GIT_HASH" .`

## 5. Docker Compose: застосунок + PostgreSQL (додаткове завдання, п. 1)

Сервіси в `docker-compose.yml`:

- **`app`** (`container_name: nodeapp`):
  - має одночасно `build: .` та `image: ${DOCKERHUB_USERNAME}/nodeapp:${IMAGE_TAG:-latest}`. Локально `docker compose up --build` збирає образ з Dockerfile, а на EC2 `docker compose pull app` завантажує готовий образ із Docker Hub за тегом;
  - порт `3000:3000`, `restart: unless-stopped`;
  - змінні `DB_*` та `IMAGE_TAG`;
  - `depends_on: db: condition: service_healthy`.
- **`db`** (`container_name: postgres_db`):
  - образ `postgres:15`, `POSTGRES_USER/PASSWORD/DB`, порт `5432:5432`;
  - іменований том `postgres_data:/var/lib/postgresql/data` (дані зберігаються між перезапусками);
  - `healthcheck: pg_isready`.

Локальний запуск:

```bash
docker compose config --quiet          # перевірка синтаксису
docker compose up -d --build
docker compose ps
docker compose logs app                # має бути: Connected to PostgreSQL database successfully!
curl http://localhost:3000
curl http://localhost:3000/health
docker compose down                    # down -v видалить і том з даними
```

## 6. GitHub Secrets (Settings → Secrets and variables → Actions)

| Secret | Значення |
|---|---|
| `DOCKERHUB_USERNAME` | логін Docker Hub |
| `DOCKERHUB_TOKEN` | Personal Access Token Docker Hub (Account settings → Personal access tokens, права Read & Write) — не пароль |
| `EC2_HOST` | публічний IP або DNS інстансу EC2 |
| `EC2_USERNAME` | користувач SSH (`ubuntu` для Ubuntu AMI) |
| `EC2_SSH_KEY` | повний вміст приватного ключа `.pem`, разом із рядками `-----BEGIN ...-----` / `-----END ...-----` |

Ключі й токени зберігаються лише в Secrets і не комітяться (`.env` та `*.pem` у `.gitignore`).

## 7. CI/CD пайплайн `.github/workflows/deploy.yml` (основне п. 4 + додаткове п. 4)

Запускається при `push` у `main` (або вручну через `workflow_dispatch`).

**Джоб `build-and-push`:**
1. `actions/checkout@v4`, `actions/setup-node@v4`, потім `npm ci`, `npm run check`, `npm test`. Якщо тести не пройшли, образ не публікується.
2. `SHORT_SHA=$(git rev-parse --short=7 HEAD)` записується в `GITHUB_ENV` і у вихід джоба `image_tag`.
3. `docker/metadata-action@v5` формує мітки OCI та додаткові теги: назву гілки (`type=ref,event=branch`) і `latest`.
4. `docker/login-action@v3` виконує вхід за секретами `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN`.
5. `docker/build-push-action@v5` збирає й пушить `<user>/nodeapp:<SHORT_SHA>`, `<user>/nodeapp:main` та `<user>/nodeapp:latest` (з кешем шарів GitHub Actions).

**Джоб `deploy`** (`needs: build-and-push`):
1. `appleboy/scp-action@v0.1.7` копіює актуальний `docker-compose.yml` у `~/nodeapp` на EC2.
2. `appleboy/ssh-action@v1` виконує на сервері:

```bash
cd ~/nodeapp
export DOCKERHUB_USERNAME IMAGE_TAG          # IMAGE_TAG = короткий хеш коміту з першого джоба
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
docker compose pull app                      # спершу pull: якщо реєстр недоступний, старий контейнер продовжує працювати
docker rm -f nodeapp || true                 # прибрати старий контейнер з таким ім'ям
docker compose up -d --no-build
docker image prune -f
docker compose ps
curl -fsS http://localhost:3000/health       # до 15 спроб; інакше вивід логів і помилка джоба
```

Так на EC2 завжди працює саме та версія образу, яка відповідає коміту. Відкат до попередньої версії: `IMAGE_TAG=<старий_хеш> docker compose up -d --no-build`.

## 8. Підготовка EC2 (одноразово)

**Security Group:** вхідні правила для SSH `22` та TCP `3000`. Порт `5432` назовні не відкривати: застосунок звертається до БД усередині мережі Compose.

Підключитися до сервера: `ssh -i devops-key.pem ubuntu@<EC2_HOST>`.

**1. Повне видалення pm2.** Старий Node.js-процес із практичних 5–6 інакше займатиме порт `3000`, і контейнер не запуститься з помилкою `port is already allocated`:

```bash
pm2 stop all || true
pm2 delete all || true
pm2 unstartup || true          # друкує команду sudo env PATH=... pm2 unstartup systemd ... — виконайте її
npm uninstall -g pm2 || true   # якщо pm2 ставився через sudo: sudo npm uninstall -g pm2
rm -rf ~/.pm2
sudo ss -ltnp | grep 3000 || echo "порт 3000 вільний"
```

**2. Docker Engine + Docker Compose plugin:**

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # docker без sudo (потрібно перелогінитися)
exit                            # і підключитися знову
docker --version
docker compose version
mkdir -p ~/nodeapp
```

Ті самі кроки автоматизовано у скрипті `scripts/setup-ec2.sh`:

```bash
scp -i devops-key.pem scripts/setup-ec2.sh ubuntu@<EC2_HOST>:~
ssh -i devops-key.pem ubuntu@<EC2_HOST> 'bash ~/setup-ec2.sh'
```

## 9. Перевірка роботи обох сервісів

На EC2 (у `~/nodeapp`) або локально:

```bash
docker compose ps                 # nodeapp та postgres_db у стані Up, db — (healthy)
docker compose logs -f            # Ctrl+C для виходу
docker compose logs app | grep "Connected to PostgreSQL"
curl http://localhost:3000
curl http://localhost:3000/health
docker inspect nodeapp --format '{{.Config.Image}}'   # <user>/nodeapp:<хеш коміту>
```

Ззовні (з браузера): `http://<EC2_HOST>:3000` і `http://<EC2_HOST>:3000/health`.

Очікувана відповідь `/`:

```json
{"message":"Node.js-застосунок у Docker працює!","lab":"Практичне заняття №9","author":"Яровий Михайло, група КН-42","imageTag":"<хеш коміту>","db":"connected"}
```

Очікувана відповідь `/health`:

```json
{"status":"ok","db":"connected","time":"...","pg_version":"PostgreSQL 15.x ..."}
```

Значення `imageTag` має збігатися з хешем коміту на вкладці GitHub Actions і з тегом образу на Docker Hub.

## 10. Що перевірено при підготовці

- `npm run check` і `npm test` (8 тестів: `/`, `/health` 200/500, 404, retry-логіка, дефолти `DB_*`): усі пройшли (Node.js 24).
- Запуск `node index.js` без БД: сервер відповідає на `/` з `db: "disconnected"`, `/health` → 500, у лозі видно повторні спроби підключення.
- Синтаксис `docker-compose.yml` і `deploy.yml` перевірено YAML-парсером, `setup-ec2.sh` — командою `bash -n`.
- Docker на машині підготовки не встановлено, тому `docker build` / `docker compose up` і деплой на EC2 потрібно виконати й зафіксувати скріншотами самостійно (розділи 4, 5, 9).

## Висновки

Створено Dockerfile на основі `node:lts`, у якому завдяки порядку інструкцій кешується шар залежностей. `.dockerignore` зменшує контекст збірки й не пропускає секрети в образ. Застосунок працює разом із PostgreSQL 15 у Docker Compose, а retry-логіка та healthcheck усувають гонку під час старту БД. CI/CD-пайплайн тестує код, публікує образ у Docker Hub із тегом короткого хешу коміту й розгортає саме цю версію на EC2 через `docker compose`. Тому кожна версія на сервері однозначно відповідає коміту в Git і може бути відкочена.
