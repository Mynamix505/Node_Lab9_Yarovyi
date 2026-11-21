// Практичне заняття №9. Dockerfile для Node.js-додатку + PostgreSQL + Docker Compose
// Студент: Яровий Михайло, група КН-42
import express from 'express';
import pg from 'pg';
import { pathToFileURL } from 'node:url';

export const AUTHOR = 'Яровий Михайло, група КН-42';

// Параметри підключення: зі змінних середовища, дефолти відповідають docker-compose.yml
export function dbConfig(env = process.env) {
  return {
    host: env.DB_HOST || 'db',
    port: Number(env.DB_PORT || 5432),
    user: env.DB_USER || 'postgres',
    password: env.DB_PASSWORD || 'postgres',
    database: env.DB_NAME || 'appdb',
    connectionTimeoutMillis: 5000,
  };
}

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

// Postgres у контейнері db ініціалізується кілька секунд, тому пробуємо кілька разів
export async function connectWithRetry(pool, { retries = 10, delayMs = 2000, log = console } = {}) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      await pool.query('SELECT 1');
      log.log('Connected to PostgreSQL database successfully!');
      return true;
    } catch (error) {
      log.error(`Спроба ${attempt}/${retries}: PostgreSQL недоступний (${error.message})`);
      if (attempt < retries) await sleep(delayMs);
    }
  }
  log.error('Не вдалося підключитися до PostgreSQL після всіх спроб');
  return false;
}

export function createApp(pool, env = process.env) {
  const app = express();

  app.get('/', async (req, res) => {
    let db = 'connected';
    try {
      await pool.query('SELECT 1');
    } catch {
      db = 'disconnected';
    }
    res.json({
      message: 'Node.js-застосунок у Docker працює!',
      lab: 'Практичне заняття №9',
      author: AUTHOR,
      imageTag: env.IMAGE_TAG || 'local',
      db,
    });
  });

  app.get('/health', async (req, res) => {
    try {
      const { rows } = await pool.query('SELECT NOW() AS now, version() AS pg_version');
      res.json({ status: 'ok', db: 'connected', time: rows[0].now, pg_version: rows[0].pg_version });
    } catch (error) {
      res.status(500).json({ status: 'error', db: 'disconnected', error: error.message });
    }
  });

  app.use((req, res) => res.status(404).json({ error: 'Not found' }));
  return app;
}

async function main() {
  const pool = new pg.Pool(dbConfig());
  pool.on('error', error => console.error('PostgreSQL pool:', error.message));

  const port = Number(process.env.PORT || 3000);
  const server = createApp(pool).listen(port, '0.0.0.0', () => {
    console.log(`Сервер запущено на http://0.0.0.0:${port} (IMAGE_TAG=${process.env.IMAGE_TAG || 'local'})`);
  });
  await connectWithRetry(pool);

  // Коректна зупинка за `docker stop` (SIGTERM)
  const shutdown = () => {
    setTimeout(() => process.exit(1), 10000).unref();
    server.close(() => pool.end().finally(() => process.exit(0)));
  };
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
