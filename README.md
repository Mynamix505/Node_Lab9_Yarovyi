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
| `.github/workflows/deploy.yml` | джоби `build-and-push` (тести → Docker Hub), `deploy` (`docker compose` з образом з Docker Hub) і опційний `deploy-ec2` |
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

При `git push` у `main` виконуються:
1. **`build-and-push`** — тести, потім збірка й публікація `mynamix505/nodeapp:<хеш коміту>`, `:main` і `:latest` у Docker Hub.
2. **`deploy`** — `docker compose pull app && docker compose up -d --no-build` (образ з Docker Hub за хешем), потім перевірка `/`, `/health` і рядка `Connected to PostgreSQL database successfully!`.
3. **`deploy-ec2`** (вимкнено) — те саме на Amazon EC2 через SSH. Вмикається змінною `EC2_DEPLOY=true` після підготовки сервера скриптом `scripts/setup-ec2.sh`.

Секрети: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`; для EC2 ще `EC2_HOST`, `EC2_USERNAME`, `EC2_SSH_KEY`.

- Репозиторій: https://github.com/Mynamix505/Node_Lab9_Yarovyi
- Образ: https://hub.docker.com/r/mynamix505/nodeapp/tags

Деталі, команди перевірки та пояснення кожної інструкції — у [SOLUTION.md](SOLUTION.md).
