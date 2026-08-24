// 브리지 서버 검수 — node --test tools/bridge/test/
// 임시 프로젝트 폴더에 서버를 띄우고 HTTP API, 화이트리스트, HMR push, WebSocket 알림을 확인한다.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { createBridge, isOriginAllowed } from '../server.js';
import { normalizeRelPath, BridgeError } from '../lib/files.js';
import { decodeBundle, encodeBundle } from '../lib/hmr.js';
import { decodeFrame, encodeFrame } from '../lib/ws.js';

const EDITOR_ORIGIN = 'http://localhost:5173';

async function makeProject() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'i2d-bridge-'));
  await fs.mkdir(path.join(root, 'scripts', 'games'), { recursive: true });
  await fs.mkdir(path.join(root, 'resources', 'maps'), { recursive: true });
  await fs.mkdir(path.join(root, 'resources', 'tiles'), { recursive: true });
  await fs.writeFile(path.join(root, 'scripts', 'main.lua'), 'print("main")\n');
  await fs.writeFile(path.join(root, 'scripts', 'games', 'flappy.lua'), 'return {}\n');
  await fs.writeFile(path.join(root, 'scripts', 'games', 'notes.txt'), 'not lua\n');
  await fs.writeFile(path.join(root, 'resources', 'maps', 'sample.json'), '{"version":1}\n');
  await fs.writeFile(path.join(root, 'resources', 'tiles', 'a.png'), Buffer.from([0x89, 0x50, 0x4e, 0x47]));
  await fs.writeFile(path.join(root, 'secret.txt'), 'top secret\n');
  return root;
}

// 엔진 HotReloadServer 를 흉내 내는 TCP 서버: 번들을 끝까지 읽고 "OK\n" 또는 "ER\n" 으로 답한다.
function fakeHmrServer(onBundle) {
  const server = net.createServer((socket) => {
    let buffer = Buffer.alloc(0);
    socket.on('data', (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      let files;
      try {
        files = decodeBundle(buffer);
      } catch (err) {
        if (err.message === 'truncated bundle') return; // 더 기다린다
        socket.end('ER\n');
        return;
      }
      onBundle(files);
      socket.end('OK\n');
    });
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port }));
  });
}

async function api(base, method, route, { body, headers = {} } = {}) {
  const res = await fetch(base + route, { method, body, headers });
  const type = res.headers.get('content-type') || '';
  const payload = type.includes('application/json') ? await res.json() : Buffer.from(await res.arrayBuffer());
  return { status: res.status, headers: res.headers, body: payload };
}

describe('normalizeRelPath', () => {
  it('accepts whitelisted relative paths', () => {
    assert.equal(normalizeRelPath('scripts/games/flappy.lua'), 'scripts/games/flappy.lua');
    assert.equal(normalizeRelPath('resources/maps/./map1.json'), 'resources/maps/map1.json');
    assert.equal(normalizeRelPath('scripts/a/../b.lua'), 'scripts/b.lua');
  });
  it('rejects escapes and non-whitelisted roots', () => {
    for (const bad of ['../secret.txt', 'scripts/../secret.txt', '/etc/passwd', 'secret.txt', 'src/main.cpp', 'scripts\\x.lua', '', 'scripts/a\0.lua']) {
      assert.throws(() => normalizeRelPath(bad), BridgeError, `should reject ${JSON.stringify(bad)}`);
    }
  });
});

describe('isOriginAllowed', () => {
  it('allows loopback origins on any port and explicit extras', () => {
    assert.ok(isOriginAllowed(undefined));
    assert.ok(isOriginAllowed('http://localhost:5173'));
    assert.ok(isOriginAllowed('http://127.0.0.1:3000'));
    assert.ok(isOriginAllowed('http://[::1]:8080'));
    assert.ok(isOriginAllowed('https://editor.example.com', ['https://editor.example.com']));
  });
  it('rejects non-loopback origins', () => {
    assert.equal(isOriginAllowed('http://evil.example.com'), false);
    assert.equal(isOriginAllowed('http://192.168.0.5:5173'), false);
    assert.equal(isOriginAllowed('null'), false);
  });
});

describe('hmr bundle codec', () => {
  it('round-trips through the engine wire format', () => {
    const files = [
      { path: 'scripts/main.lua', data: Buffer.from('print(1)') },
      { path: 'scripts/한글.lua', data: Buffer.alloc(0) },
    ];
    const encoded = encodeBundle(files);
    assert.equal(encoded.toString('ascii', 0, 4), 'I2DH');
    assert.equal(encoded.readUInt32LE(4), 2);
    const decoded = decodeBundle(encoded);
    assert.deepEqual(decoded.map((f) => f.path), files.map((f) => f.path));
    assert.equal(decoded[0].data.toString(), 'print(1)');
    assert.equal(decoded[1].data.length, 0);
  });
});

describe('websocket frames', () => {
  it('encodes and decodes text frames of every length class', () => {
    for (const size of [0, 5, 125, 126, 70000]) {
      const text = 'x'.repeat(size);
      const frame = encodeFrame(0x1, Buffer.from(text));
      const decoded = decodeFrame(frame);
      assert.ok(decoded && decoded.fin && decoded.opcode === 0x1);
      assert.equal(decoded.payload.toString(), text);
      assert.equal(decoded.rest.length, 0);
    }
  });
  it('unmasks client frames', () => {
    const payload = Buffer.from('ping');
    const mask = Buffer.from([1, 2, 3, 4]);
    const masked = Buffer.from(payload.map((b, i) => b ^ mask[i & 3]));
    const frame = Buffer.concat([Buffer.from([0x81, 0x80 | payload.length]), mask, masked]);
    assert.equal(decodeFrame(frame).payload.toString(), 'ping');
  });
});

describe('bridge server', () => {
  let root;
  let bridge;
  let base;
  const logs = [];

  before(async () => {
    root = await makeProject();
    bridge = createBridge({ project: root, hmrPort: 1, log: (m) => logs.push(m) });
    const addr = await bridge.listen(0);
    base = `http://127.0.0.1:${addr.port}`;
  });

  after(async () => {
    await bridge.close();
    await fs.rm(root, { recursive: true, force: true });
  });

  it('GET /api/health', async () => {
    const res = await api(base, 'GET', '/api/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.name, 'initial2d-bridge');
  });

  it('GET /api/project lists scripts, maps and tilesets', async () => {
    const res = await api(base, 'GET', '/api/project');
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.scripts, ['scripts/games/flappy.lua', 'scripts/main.lua']);
    assert.deepEqual(res.body.maps, ['resources/maps/sample.json']);
    assert.deepEqual(res.body.tilesets, ['resources/tiles/a.png']);
    assert.deepEqual(res.body.hmr, { host: '127.0.0.1', port: 1 });
  });

  it('GET /api/files reads text and binary with content types', async () => {
    const lua = await api(base, 'GET', '/api/files/scripts/main.lua');
    assert.equal(lua.status, 200);
    assert.match(lua.headers.get('content-type'), /text\/plain/);
    assert.equal(lua.body.toString(), 'print("main")\n');
    assert.ok(Number(lua.headers.get('x-bridge-mtime')) > 0);

    const png = await api(base, 'GET', '/api/files/resources/tiles/a.png');
    assert.equal(png.status, 200);
    assert.equal(png.headers.get('content-type'), 'image/png');
    assert.equal(png.body.length, 4);
  });

  it('HEAD /api/files answers existence without a body', async () => {
    const hit = await fetch(`${base}/api/files/resources/tiles/a.png`, { method: 'HEAD' });
    assert.equal(hit.status, 200);
    assert.equal(hit.headers.get('content-length'), '4');
    assert.equal((await hit.arrayBuffer()).byteLength, 0);
    const miss = await fetch(`${base}/api/files/resources/tiles/missing.png`, { method: 'HEAD' });
    assert.equal(miss.status, 404);
  });

  it('GET missing file → 404, path escape → 403, other roots → 403', async () => {
    assert.equal((await api(base, 'GET', '/api/files/scripts/nope.lua')).status, 404);
    assert.equal((await api(base, 'GET', '/api/files/scripts/../secret.txt')).status, 403);
    assert.equal((await api(base, 'GET', '/api/files/scripts/..%2Fsecret.txt')).status, 403);
    assert.equal((await api(base, 'GET', '/api/files/secret.txt')).status, 403);
    assert.equal((await api(base, 'GET', '/api/files/src/main.cpp')).status, 403);
    // 디렉터리는 파일이 아니다
    assert.equal((await api(base, 'GET', '/api/files/scripts')).status, 404);
  });

  it('PUT writes (creating parent dirs), GET reads it back, DELETE removes it', async () => {
    const put = await api(base, 'PUT', '/api/files/scripts/maps/map1.lua', {
      body: 'return { name = "마을" }\n',
      headers: { 'Content-Type': 'text/plain' },
    });
    assert.equal(put.status, 200, JSON.stringify(put.body));
    assert.deepEqual(put.body, { ok: true, path: 'scripts/maps/map1.lua', bytes: Buffer.byteLength('return { name = "마을" }\n') });
    const onDisk = await fs.readFile(path.join(root, 'scripts', 'maps', 'map1.lua'), 'utf8');
    assert.equal(onDisk, 'return { name = "마을" }\n');
    // 임시 파일이 남지 않는다
    const leftovers = (await fs.readdir(path.join(root, 'scripts', 'maps'))).filter((n) => n.includes('.tmp'));
    assert.deepEqual(leftovers, []);

    const del = await api(base, 'DELETE', '/api/files/scripts/maps/map1.lua');
    assert.equal(del.status, 200);
    await assert.rejects(fs.stat(path.join(root, 'scripts', 'maps', 'map1.lua')));
  });

  it('PUT outside whitelist is refused and writes nothing', async () => {
    const res = await api(base, 'PUT', '/api/files/src/evil.cpp', { body: 'x' });
    assert.equal(res.status, 403);
    await assert.rejects(fs.stat(path.join(root, 'src', 'evil.cpp')));
    const escape = await api(base, 'PUT', '/api/files/scripts/../pwned.txt', { body: 'x' });
    assert.equal(escape.status, 403);
    await assert.rejects(fs.stat(path.join(root, 'pwned.txt')));
  });

  it('CORS: loopback origins get headers, foreign origins get 403', async () => {
    const preflight = await fetch(`${base}/api/files/scripts/main.lua`, {
      method: 'OPTIONS',
      headers: { Origin: EDITOR_ORIGIN, 'Access-Control-Request-Method': 'PUT' },
    });
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get('access-control-allow-origin'), EDITOR_ORIGIN);
    assert.match(preflight.headers.get('access-control-allow-methods'), /PUT/);

    const ok = await fetch(`${base}/api/health`, { headers: { Origin: 'http://127.0.0.1:4000' } });
    assert.equal(ok.status, 200);
    assert.equal(ok.headers.get('access-control-allow-origin'), 'http://127.0.0.1:4000');

    const bad = await fetch(`${base}/api/health`, { headers: { Origin: 'http://evil.example.com' } });
    assert.equal(bad.status, 403);
    assert.equal(bad.headers.get('access-control-allow-origin'), null);
  });

  it('POST /api/reload pushes every scripts/**/*.lua to the HMR server', async () => {
    let received = null;
    const { server, port } = await fakeHmrServer((files) => {
      received = files;
    });
    try {
      const res = await api(base, 'POST', '/api/reload', {
        body: JSON.stringify({ port }),
        headers: { 'Content-Type': 'application/json' },
      });
      assert.equal(res.status, 200, JSON.stringify(res.body));
      assert.equal(res.body.ok, true);
      assert.equal(res.body.reply, 'OK');
      assert.equal(res.body.files, 2);
      assert.deepEqual(received.map((f) => f.path), ['scripts/games/flappy.lua', 'scripts/main.lua']);
      assert.equal(received[1].data.toString(), 'print("main")\n');
    } finally {
      server.close();
    }
  });

  it('POST /api/reload reports a clear 502 when the game is not running', async () => {
    const res = await api(base, 'POST', '/api/reload', {
      body: JSON.stringify({ port: 1 }),
      headers: { 'Content-Type': 'application/json' },
    });
    assert.equal(res.status, 502);
    assert.equal(res.body.ok, false);
    assert.match(res.body.error, /HMR push failed/);
  });

  it('WebSocket /ws greets and reports external and bridge-origin file changes', async () => {
    const wsUrl = base.replace('http://', 'ws://') + '/ws';
    const ws = new WebSocket(wsUrl);
    const messages = [];
    const waitFor = (predicate, timeoutMs = 4000) =>
      new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error(`timeout waiting; got ${JSON.stringify(messages)}`)), timeoutMs);
        const check = () => {
          const hit = messages.find(predicate);
          if (hit) {
            clearTimeout(timer);
            resolve(hit);
            return true;
          }
          return false;
        };
        if (check()) return;
        ws.addEventListener('message', () => check());
      });
    ws.addEventListener('message', (ev) => messages.push(JSON.parse(ev.data)));
    await new Promise((resolve, reject) => {
      ws.addEventListener('open', resolve);
      ws.addEventListener('error', reject);
    });
    const hello = await waitFor((m) => m.type === 'hello');
    assert.equal(hello.type, 'hello');

    // 외부(다른 편집기)에서 파일을 고치면 origin=external
    await fs.writeFile(path.join(root, 'scripts', 'games', 'flappy.lua'), 'return { edited = true }\n');
    const external = await waitFor((m) => m.type === 'change' && m.path === 'scripts/games/flappy.lua');
    assert.equal(external.origin, 'external');

    // 브리지 PUT 으로 쓰면 origin=bridge (에디터가 자기 저장을 무시할 수 있게)
    await api(base, 'PUT', '/api/files/scripts/main.lua', { body: 'print("v2")\n' });
    const own = await waitFor((m) => m.type === 'change' && m.path === 'scripts/main.lua');
    assert.equal(own.origin, 'bridge');

    // HMR push 뒤 엔진이 같은 내용을 되쓰는 것은 bridge, 그 직후라도 내용이 다른 외부 편집은 external
    const { server, port } = await fakeHmrServer(() => {});
    try {
      const reload = await api(base, 'POST', '/api/reload', { body: JSON.stringify({ port }) });
      assert.equal(reload.status, 200);
    } finally {
      server.close();
    }
    messages.length = 0;
    await fs.writeFile(path.join(root, 'scripts', 'games', 'flappy.lua'), 'return { edited = true }\n'); // 엔진의 되쓰기와 동일 내용
    const rewrite = await waitFor((m) => m.type === 'change' && m.path === 'scripts/games/flappy.lua');
    assert.equal(rewrite.origin, 'bridge');
    // origin까지 조건에 넣는다. macOS fs.watch는 한 쓰기에 이벤트를 여러 번 낼 수
    // 있어, 앞선 PUT(v2)의 늦은 중복 이벤트(내용이 일치해 bridge — 올바른 분류다)가
    // 느린 러너에서 여기까지 밀려와 경로만 보는 대기에 먼저 걸렸다 (CI에서 간헐 실패).
    // 분류가 정말 잘못되면 external이 영영 오지 않아 타임아웃으로 실패한다.
    await fs.writeFile(path.join(root, 'scripts', 'main.lua'), 'print("v3 from vim")\n');
    const foreign = await waitFor((m) =>
      m.type === 'change' && m.path === 'scripts/main.lua' && m.origin === 'external');
    assert.equal(foreign.origin, 'external');

    ws.close();
  });
});
