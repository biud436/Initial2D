#!/usr/bin/env node
// Initial2D 에디터 브리지 서버 (docs/plans/03-editor-bridge.md)
//
// 웹 앱인 InitialEditor가 로컬 게임 프로젝트의 파일(scripts/, resources/)을 읽고 쓰게 하고,
// 저장 직후 실행 중인 게임의 HMR 서버(127.0.0.1:5959)로 push 해 즉시 반영되게 한다.
//
// 사용법:
//   node tools/bridge/server.js                     # 저장소 루트를 프로젝트로, 127.0.0.1:5960
//   node tools/bridge/server.js --project ~/mygame  # 다른 프로젝트 폴더
//   node tools/bridge/server.js --port 5961 --hmr-port 5959 --allow-origin http://localhost:3000
//
// API (전부 127.0.0.1 전용, 화이트리스트 밖 경로는 403):
//   GET    /api/health           서버 상태
//   GET    /api/project          프로젝트 정보 (스크립트, 맵, 타일셋 목록)
//   GET    /api/files/<path>     파일 읽기 (텍스트와 바이너리, Content-Type은 확장자로)
//   PUT    /api/files/<path>     파일 쓰기 (본문이 파일 내용, 상위 폴더 자동 생성)
//   DELETE /api/files/<path>     파일 삭제
//   POST   /api/reload           scripts/**/*.lua 를 엔진 HMR 서버로 push (본문 JSON {host, port} 선택)
//   WS     /ws                   파일 변경 알림 {type:"change", path, event, origin}
//
// 의존성 없음 (Node 20 이상의 내장 모듈만 사용).
import crypto from 'node:crypto';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

import { BridgeError, ProjectFiles, contentTypeFor } from './lib/files.js';
import { pushBundle } from './lib/hmr.js';
import { WebSocketHub } from './lib/ws.js';

export const BRIDGE_VERSION = '0.1.0';
export const DEFAULT_PORT = 5960;
export const DEFAULT_HMR_PORT = 5959;
const MAX_BODY_BYTES = 32 * 1024 * 1024;
const SELF_WRITE_WINDOW_MS = 3000;
const WATCH_DEBOUNCE_MS = 120;

const LOOPBACK_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]']);

// 브라우저 Origin 검사. 브리지는 루프백에만 바인드되므로, 루프백 origin(에디터 dev 서버가
// 어떤 포트를 쓰든)과 명시적으로 추가한 origin 만 허용한다. Origin 헤더가 없는 요청(curl,
// 테스트, 같은 origin)은 CORS 대상이 아니므로 통과시킨다.
export function isOriginAllowed(origin, extraOrigins = []) {
  if (!origin) return true;
  if (extraOrigins.includes(origin)) return true;
  try {
    const url = new URL(origin);
    return (url.protocol === 'http:' || url.protocol === 'https:') && LOOPBACK_HOSTS.has(url.hostname);
  } catch {
    return false;
  }
}

function readBody(req, limit = MAX_BODY_BYTES) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > limit) {
        reject(new BridgeError(413, `body exceeds ${limit} bytes`));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function sendJson(res, status, payload, extraHeaders = {}) {
  const body = Buffer.from(JSON.stringify(payload), 'utf8');
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': body.length,
    'Cache-Control': 'no-store',
    ...extraHeaders,
  });
  res.end(body);
}

export function createBridge(options = {}) {
  const projectRoot = path.resolve(options.project || process.cwd());
  const hmrHost = options.hmrHost || '127.0.0.1';
  const hmrPort = options.hmrPort || DEFAULT_HMR_PORT;
  const extraOrigins = options.allowOrigins || [];
  const watchEnabled = options.watch !== false;
  const log = options.log || (() => {});

  if (!fs.existsSync(projectRoot) || !fs.statSync(projectRoot).isDirectory()) {
    throw new Error(`project root is not a directory: ${projectRoot}`);
  }

  const files = new ProjectFiles(projectRoot, options.allowedDirs);
  const hub = new WebSocketHub();
  // rel path → { at, hash }: 브리지가 최근에 쓴(또는 HMR push 로 엔진이 되쓸) 내용.
  // 감시 이벤트가 오면 파일 내용의 해시를 비교해 브리지 발 변경인지 외부 편집인지 가른다.
  const recentWrites = new Map();
  const sha1 = (data) => crypto.createHash('sha1').update(data).digest('hex');
  const rememberWrite = (rel, data) => recentWrites.set(rel, { at: Date.now(), hash: sha1(data) });
  const watchers = [];
  const pendingChanges = new Map(); // rel path → { event, timer }

  function corsHeaders(origin) {
    if (!origin) return {};
    return {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, PUT, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Requested-With',
      'Access-Control-Expose-Headers': 'X-Bridge-Mtime, Content-Type',
      'Access-Control-Max-Age': '600',
      Vary: 'Origin',
    };
  }

  function projectName() {
    return path.basename(projectRoot);
  }

  async function projectInfo() {
    const [scripts, maps, tilesets] = await Promise.all([
      files.list('scripts', (rel) => rel.endsWith('.lua')),
      files.list('resources/maps', (rel) => rel.endsWith('.json')),
      files.list('resources/tiles', (rel) => /\.(png|jpe?g)$/i.test(rel)),
    ]);
    return {
      name: projectName(),
      root: projectRoot,
      bridgeVersion: BRIDGE_VERSION,
      allowedDirs: files.allowedDirs,
      scripts,
      maps,
      tilesets,
      hmr: { host: hmrHost, port: hmrPort },
    };
  }

  async function collectScripts() {
    const rels = await files.list('scripts', (rel) => rel.endsWith('.lua'));
    const out = [];
    for (const rel of rels) {
      const { data } = await files.read(rel);
      out.push({ path: rel, data });
    }
    return out;
  }

  async function handleReload(body) {
    let opts = {};
    if (body.length > 0) {
      try {
        opts = JSON.parse(body.toString('utf8'));
      } catch {
        throw new BridgeError(400, 'reload body must be JSON');
      }
    }
    const bundle = await collectScripts();
    if (bundle.length === 0) throw new BridgeError(409, 'no *.lua under scripts/');
    const host = typeof opts.host === 'string' ? opts.host : hmrHost;
    const port = Number.isInteger(opts.port) ? opts.port : hmrPort;
    try {
      const result = await pushBundle({ host, port, files: bundle });
      // 엔진은 받은 번들을 자기 cwd에 다시 써 넣는다. 게임이 프로젝트 루트에서 실행 중이면
      // 그 쓰기가 감시에 잡히므로, 내용이 같은 그 변경은 브리지 발 변경으로 표시한다.
      for (const file of bundle) rememberWrite(file.path, file.data);
      log(`reload ${bundle.length} files -> ${host}:${port} ${result.reply}`);
      return { ...result, host, port };
    } catch (err) {
      throw new BridgeError(502, `HMR push failed (${host}:${port}): ${err.message} — 게임이 INITIAL2D_HMR=1 로 실행 중인지 확인`);
    }
  }

  async function route(req, res, url) {
    const origin = req.headers.origin;
    const cors = corsHeaders(origin);
    const method = req.method || 'GET';
    const pathname = decodeURIComponent(url.pathname);

    if (method === 'OPTIONS') {
      res.writeHead(204, cors);
      res.end();
      return;
    }

    if (pathname === '/api/health' && method === 'GET') {
      sendJson(res, 200, { ok: true, name: 'initial2d-bridge', version: BRIDGE_VERSION, project: projectName() }, cors);
      return;
    }

    if (pathname === '/api/project' && method === 'GET') {
      sendJson(res, 200, await projectInfo(), cors);
      return;
    }

    if (pathname.startsWith('/api/files/')) {
      const rel = pathname.slice('/api/files/'.length);
      if (method === 'GET') {
        const { rel: normalized, data, mtimeMs } = await files.read(rel);
        res.writeHead(200, {
          'Content-Type': contentTypeFor(normalized),
          'Content-Length': data.length,
          'Cache-Control': 'no-store',
          'X-Bridge-Mtime': String(Math.floor(mtimeMs)),
          ...cors,
        });
        res.end(data);
        return;
      }
      if (method === 'PUT') {
        const body = await readBody(req);
        const { rel: normalized, bytes } = await files.write(rel, body);
        rememberWrite(normalized, body);
        log(`PUT ${normalized} ${bytes}B`);
        sendJson(res, 200, { ok: true, path: normalized, bytes }, cors);
        return;
      }
      if (method === 'DELETE') {
        const { rel: normalized } = await files.remove(rel);
        recentWrites.set(normalized, { at: Date.now(), hash: null });
        log(`DELETE ${normalized}`);
        sendJson(res, 200, { ok: true, path: normalized }, cors);
        return;
      }
      throw new BridgeError(405, `method ${method} not allowed`);
    }

    if (pathname === '/api/reload' && method === 'POST') {
      const body = await readBody(req, 64 * 1024);
      const result = await handleReload(body);
      sendJson(res, 200, { ok: result.ok, files: result.files, reply: result.reply, host: result.host, port: result.port }, cors);
      return;
    }

    throw new BridgeError(404, `no route for ${method} ${pathname}`);
  }

  const httpServer = http.createServer(async (req, res) => {
    const origin = req.headers.origin;
    const url = new URL(req.url || '/', 'http://bridge.local');
    if (!isOriginAllowed(origin, extraOrigins)) {
      sendJson(res, 403, { ok: false, error: `origin not allowed: ${origin}` });
      return;
    }
    try {
      await route(req, res, url);
    } catch (err) {
      const status = err instanceof BridgeError ? err.status : 500;
      if (status >= 500) log(`error ${req.method} ${url.pathname}: ${err.stack || err.message}`);
      if (!res.headersSent) {
        sendJson(res, status, { ok: false, error: err.message }, corsHeaders(origin));
      } else {
        res.end();
      }
    }
  });

  httpServer.on('upgrade', (req, socket) => {
    const url = new URL(req.url || '/', 'http://bridge.local');
    if (url.pathname !== '/ws' || !isOriginAllowed(req.headers.origin, extraOrigins)) {
      socket.write('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n');
      socket.destroy();
      return;
    }
    const client = hub.handleUpgrade(req, socket);
    if (client) {
      hub.sendTo(client, JSON.stringify({ type: 'hello', project: projectName(), version: BRIDGE_VERSION }));
    }
  });

  async function classifyChange(rel) {
    const recent = recentWrites.get(rel);
    if (!recent || Date.now() - recent.at > SELF_WRITE_WINDOW_MS) {
      recentWrites.delete(rel);
      return 'external';
    }
    let hash = null;
    try {
      hash = sha1(await fsp.readFile(path.join(projectRoot, rel)));
    } catch {
      hash = null; // 삭제됨
    }
    if (hash === recent.hash) return 'bridge';
    recentWrites.delete(rel);
    return 'external';
  }

  async function emitChange(rel, event) {
    const origin = await classifyChange(rel);
    hub.broadcast(JSON.stringify({ type: 'change', path: rel, event, origin, at: Date.now() }));
  }

  function startWatching() {
    for (const dirAbs of files.existingAllowedDirs()) {
      let watcher;
      try {
        watcher = fs.watch(dirAbs, { recursive: true }, (event, filename) => {
          if (!filename) return;
          const name = typeof filename === 'string' ? filename : filename.toString();
          if (name.split(/[\\/]/).some((seg) => seg.startsWith('.') || seg.endsWith('.tmp'))) return;
          const rel = path
            .relative(projectRoot, path.join(dirAbs, name))
            .split(path.sep)
            .join('/');
          const pending = pendingChanges.get(rel);
          if (pending) clearTimeout(pending.timer);
          const timer = setTimeout(() => {
            pendingChanges.delete(rel);
            emitChange(rel, event);
          }, WATCH_DEBOUNCE_MS);
          pendingChanges.set(rel, { event, timer });
        });
      } catch (err) {
        log(`watch failed for ${dirAbs}: ${err.message}`);
        continue;
      }
      watcher.on('error', (err) => log(`watch error ${dirAbs}: ${err.message}`));
      watchers.push(watcher);
    }
  }

  return {
    httpServer,
    hub,
    files,
    projectRoot,
    listen(port = DEFAULT_PORT, host = '127.0.0.1') {
      return new Promise((resolve, reject) => {
        httpServer.once('error', reject);
        httpServer.listen(port, host, () => {
          httpServer.off('error', reject);
          if (watchEnabled) startWatching();
          resolve(httpServer.address());
        });
      });
    },
    address() {
      return httpServer.address();
    },
    close() {
      for (const { timer } of pendingChanges.values()) clearTimeout(timer);
      pendingChanges.clear();
      for (const watcher of watchers) watcher.close();
      watchers.length = 0;
      hub.closeAll();
      return new Promise((resolve) => {
        httpServer.close(() => resolve());
        httpServer.closeAllConnections?.();
      });
    },
  };
}

function defaultProjectRoot() {
  // tools/bridge/server.js → 저장소 루트
  return path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
}

export async function main(argv = process.argv.slice(2)) {
  const { values } = parseArgs({
    args: argv,
    options: {
      project: { type: 'string', short: 'p' },
      port: { type: 'string' },
      'hmr-host': { type: 'string' },
      'hmr-port': { type: 'string' },
      'allow-origin': { type: 'string', multiple: true },
      'no-watch': { type: 'boolean' },
      quiet: { type: 'boolean', short: 'q' },
      help: { type: 'boolean', short: 'h' },
    },
  });
  if (values.help) {
    process.stdout.write(
      [
        'Initial2D 에디터 브리지 서버',
        '',
        '  node tools/bridge/server.js [--project DIR] [--port 5960] [--hmr-host 127.0.0.1] [--hmr-port 5959]',
        '                              [--allow-origin URL]... [--no-watch] [--quiet]',
        '',
        '  --project       게임 프로젝트 루트 (기본: 이 저장소 루트)',
        '  --port          브리지 HTTP/WS 포트 (기본: 5960, 127.0.0.1 전용)',
        '  --hmr-host/port 엔진 HotReloadServer 주소 (기본: 127.0.0.1:5959)',
        '  --allow-origin  루프백 외 추가 허용 origin (반복 가능)',
        '  --no-watch      파일 변경 감시(WebSocket 알림) 끄기',
        '',
      ].join('\n'),
    );
    return 0;
  }
  const port = values.port ? Number(values.port) : DEFAULT_PORT;
  const bridge = createBridge({
    project: values.project || defaultProjectRoot(),
    hmrHost: values['hmr-host'],
    hmrPort: values['hmr-port'] ? Number(values['hmr-port']) : DEFAULT_HMR_PORT,
    allowOrigins: values['allow-origin'] || [],
    watch: !values['no-watch'],
    log: values.quiet ? () => {} : (msg) => process.stdout.write(`[bridge] ${msg}\n`),
  });
  const address = await bridge.listen(port);
  process.stdout.write(
    `[bridge] project ${bridge.projectRoot}\n` +
      `[bridge] listening on http://127.0.0.1:${address.port}  (ws://127.0.0.1:${address.port}/ws)\n` +
      `[bridge] HMR target ${values['hmr-host'] || '127.0.0.1'}:${values['hmr-port'] || DEFAULT_HMR_PORT} — 게임은 INITIAL2D_HMR=1 로 실행\n`,
  );
  const shutdown = () => {
    bridge.close().then(() => process.exit(0));
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((err) => {
    process.stderr.write(`[bridge] ${err.message}\n`);
    process.exit(1);
  });
}
