// Студент: Яровий Михайло, група КН-42
// Тести з підставним пулом PostgreSQL. Запуск: npm test
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApp, connectWithRetry, dbConfig } from '../index.js';

async function withServer(pool, env, callback) {
  const server = createApp(pool, env).listen(0, '127.0.0.1');
  await once(server, 'listening');
  try {
    await callback(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
}

const okPool = { query: async () => ({ rows: [{ now: '2026-11-21T10:00:00Z', pg_version: 'PostgreSQL 15.8' }] }) };
const badPool = { query: async () => { throw new Error('connection refused'); } };
const silent = { log() {}, error() {} };

test('GET / повертає автора, тег образу та статус БД', async () => {
  await withServer(okPool, { IMAGE_TAG: 'a1b2c3d' }, async url => {
    const res = await fetch(url);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.author, 'Яровий Михайло, група КН-42');
    assert.equal(body.imageTag, 'a1b2c3d');
    assert.equal(body.db, 'connected');
  });
});

test('GET / без IMAGE_TAG показує local і disconnected при недоступній БД', async () => {
  await withServer(badPool, {}, async url => {
    const body = await (await fetch(url)).json();
    assert.equal(body.imageTag, 'local');
    assert.equal(body.db, 'disconnected');
  });
});

test('GET /health — 200 і час БД', async () => {
  await withServer(okPool, {}, async url => {
    const res = await fetch(`${url}/health`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.status, 'ok');
    assert.equal(body.db, 'connected');
    assert.equal(body.time, '2026-11-21T10:00:00Z');
  });
});

test('GET /health — 500 при помилці БД', async () => {
  await withServer(badPool, {}, async url => {
    const res = await fetch(`${url}/health`);
    assert.equal(res.status, 500);
    assert.equal((await res.json()).status, 'error');
  });
});

test('невідомий маршрут — 404', async () => {
  await withServer(okPool, {}, async url => {
    assert.equal((await fetch(`${url}/missing`)).status, 404);
  });
});

test('connectWithRetry успішна з третьої спроби', async () => {
  let calls = 0;
  const pool = { query: async () => { if (++calls < 3) throw new Error('starting up'); } };
  const logs = [];
  const ok = await connectWithRetry(pool, { retries: 5, delayMs: 0, log: { log: m => logs.push(m), error() {} } });
  assert.equal(ok, true);
  assert.equal(calls, 3);
  assert.deepEqual(logs, ['Connected to PostgreSQL database successfully!']);
});

test('connectWithRetry повертає false після вичерпання спроб', async () => {
  assert.equal(await connectWithRetry(badPool, { retries: 3, delayMs: 0, log: silent }), false);
});

test('dbConfig: дефолти для Docker Compose та змінні середовища', () => {
  const d = dbConfig({});
  assert.equal(d.host, 'db');
  assert.equal(d.port, 5432);
  assert.equal(d.user, 'postgres');
  assert.equal(d.database, 'appdb');
  assert.equal(dbConfig({ DB_HOST: 'localhost', DB_PORT: '5433' }).port, 5433);
});
