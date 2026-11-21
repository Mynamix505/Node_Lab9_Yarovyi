# Практичне заняття №9 — Dockerfile для Node.js + PostgreSQL + CI/CD

**Студент:** Яровий Михайло, група КН-42

Express-застосунок із PostgreSQL. Він запускається у Docker Compose, а GitHub Actions публікує образ у Docker Hub із тегом короткого хешу коміту й розгортає його на EC2.

Повний покроковий розв'язок для звіту: **[SOLUTION.md](SOLUTION.md)**.

## Структура

| Файл | Призначення |
|---|---|
| `index.js` | Express, `GET /` (автор, `IMAGE_TAG`, статус БД), `GET /health` (`SELECT NOW(), version()`), retry-підключення до PostgreSQL |
| `test/app.test.js` | 8 тестів (`node --test`) з підставним пулом БД |
| `Dockerfile` | `node:lts`, кешування шару `npm install`, `EXPOSE 3000` |
| `.dockerignore` | виключає `node_modules`, `.env`, `.git`, документацію тощо |
| `docker-compose.yml` | `app` (`nodeapp`, `build` + `image:…:${IMAGE_TAG}`) та `db` (`postgres:15`, том `postgres_data`) |
| `.env.example` | шаблон змінних `DOCKERHUB_USERNAME`, `IMAGE_TAG`, `DB_*` |
| `.github/workflows/deploy.yml` | джоби `build-and-push` (тести → Docker Hub) і `deploy` (EC2, `docker compose`) |
| `scripts/setup-ec2.sh` | одноразова підготовка EC2: видалення pm2, встановлення Docker + Compose |

## Швидкий старт

```bash
npm install && npm test                       # тести без Docker

docker compose up -d --build                  # app + PostgreSQL
docker compose logs app                       # Connected to PostgreSQL database successfully!
curl http://localhost:3000
curl http://localhost:3000/health
docker compose down
```

Образ із тегом хешу коміту:

```bash
GIT_HASH=$(git rev-parse --short HEAD)
docker build -t <your-name>/nodeapp:$GIT_HASH .
docker run -d -p 3000:3000 -e IMAGE_TAG=$GIT_HASH <your-name>/nodeapp:$GIT_HASH
```

## CI/CD

1. Додати в GitHub Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `EC2_HOST`, `EC2_USERNAME`, `EC2_SSH_KEY`.
2. Один раз підготувати EC2 за допомогою `scripts/setup-ec2.sh`: він видаляє pm2 і встановлює Docker. Відкрити в Security Group порти 22 і 3000.
3. `git push` у `main`. Пайплайн виконує тести, публікує `<user>/nodeapp:<hash>` і `:latest`, а потім запускає на EC2 `docker compose pull app && docker compose up -d`.

Деталі, команди перевірки та пояснення кожної інструкції — у [SOLUTION.md](SOLUTION.md).
