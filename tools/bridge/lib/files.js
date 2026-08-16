// 프로젝트 파일 접근 계층 — 화이트리스트와 경로 탈출 차단 (docs/plans/03-editor-bridge.md)
//
// 브리지가 만지는 파일은 프로젝트 루트 아래의 화이트리스트 디렉터리(scripts/, resources/)로
// 한정한다. 브라우저에서 오는 경로는 전부 이 모듈을 통과해야 한다.
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';

export const DEFAULT_ALLOWED_DIRS = ['scripts', 'resources'];

export class BridgeError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// URL 경로(예: "scripts/games/flappy.lua")를 정규화된 상대 경로로 바꾼다.
// 절대 경로, 백슬래시, NUL, ".." 탈출, 화이트리스트 밖은 전부 거부한다.
export function normalizeRelPath(relPath, allowedDirs = DEFAULT_ALLOWED_DIRS) {
  if (typeof relPath !== 'string' || relPath.length === 0) {
    throw new BridgeError(400, 'empty path');
  }
  if (relPath.includes('\0') || relPath.includes('\\')) {
    throw new BridgeError(400, 'invalid character in path');
  }
  if (relPath.startsWith('/')) {
    throw new BridgeError(400, 'absolute path not allowed');
  }
  const normalized = path.posix.normalize(relPath);
  if (normalized === '.' || normalized === '..' || normalized.startsWith('../')) {
    throw new BridgeError(403, 'path escapes project root');
  }
  const top = normalized.split('/')[0];
  if (!allowedDirs.includes(top)) {
    throw new BridgeError(403, `path outside allowed dirs (${allowedDirs.join(', ')})`);
  }
  return normalized;
}

export class ProjectFiles {
  constructor(root, allowedDirs = DEFAULT_ALLOWED_DIRS) {
    this.root = path.resolve(root);
    this.allowedDirs = allowedDirs;
  }

  // 상대 경로 → 절대 경로 (검사 포함)
  resolve(relPath) {
    const normalized = normalizeRelPath(relPath, this.allowedDirs);
    return { rel: normalized, abs: path.join(this.root, normalized) };
  }

  // 심볼릭 링크로 루트 밖에 나가는 경우까지 막는다 (존재하는 조상까지 realpath 비교).
  async assertInsideRoot(abs) {
    const rootReal = await fsp.realpath(this.root);
    let probe = abs;
    for (;;) {
      try {
        const real = await fsp.realpath(probe);
        if (real !== rootReal && !real.startsWith(rootReal + path.sep)) {
          throw new BridgeError(403, 'path resolves outside project root');
        }
        return;
      } catch (err) {
        if (err instanceof BridgeError) throw err;
        if (err.code !== 'ENOENT' && err.code !== 'ENOTDIR') throw err;
        const parent = path.dirname(probe);
        if (parent === probe) return;
        probe = parent;
      }
    }
  }

  async read(relPath) {
    const { rel, abs } = this.resolve(relPath);
    await this.assertInsideRoot(abs);
    try {
      const stat = await fsp.stat(abs);
      if (!stat.isFile()) throw new BridgeError(404, `not a file: ${rel}`);
      const data = await fsp.readFile(abs);
      return { rel, data, mtimeMs: stat.mtimeMs };
    } catch (err) {
      if (err instanceof BridgeError) throw err;
      if (err.code === 'ENOENT') throw new BridgeError(404, `not found: ${rel}`);
      throw err;
    }
  }

  // 원자적 쓰기: 같은 디렉터리에 임시 파일을 만들고 rename 한다.
  async write(relPath, data) {
    const { rel, abs } = this.resolve(relPath);
    await this.assertInsideRoot(abs);
    await fsp.mkdir(path.dirname(abs), { recursive: true });
    const tmp = `${abs}.bridge-${process.pid}-${Date.now()}.tmp`;
    try {
      await fsp.writeFile(tmp, data);
      await fsp.rename(tmp, abs);
    } catch (err) {
      await fsp.rm(tmp, { force: true }).catch(() => {});
      throw err;
    }
    return { rel, bytes: data.length };
  }

  async remove(relPath) {
    const { rel, abs } = this.resolve(relPath);
    await this.assertInsideRoot(abs);
    try {
      const stat = await fsp.stat(abs);
      if (!stat.isFile()) throw new BridgeError(404, `not a file: ${rel}`);
      await fsp.unlink(abs);
      return { rel };
    } catch (err) {
      if (err instanceof BridgeError) throw err;
      if (err.code === 'ENOENT') throw new BridgeError(404, `not found: ${rel}`);
      throw err;
    }
  }

  // 화이트리스트 디렉터리 하나를 재귀 순회해 조건에 맞는 파일의 상대 경로를 정렬해 돌려준다.
  // 닷파일과 닷디렉터리는 건너뛴다.
  async list(dirRel, predicate = () => true) {
    const { abs } = this.resolve(dirRel);
    const out = [];
    const walk = async (dir) => {
      let entries;
      try {
        entries = await fsp.readdir(dir, { withFileTypes: true });
      } catch (err) {
        if (err.code === 'ENOENT') return;
        throw err;
      }
      entries.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
      for (const entry of entries) {
        if (entry.name.startsWith('.')) continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          await walk(full);
        } else if (entry.isFile()) {
          const rel = path.relative(this.root, full).split(path.sep).join('/');
          if (predicate(rel)) out.push(rel);
        }
      }
    };
    await walk(abs);
    return out;
  }

  // 화이트리스트 디렉터리 중 실제로 존재하는 것들의 절대 경로 (감시용)
  existingAllowedDirs() {
    return this.allowedDirs
      .map((dir) => path.join(this.root, dir))
      .filter((abs) => fs.existsSync(abs));
  }
}

export function contentTypeFor(relPath) {
  const ext = path.posix.extname(relPath).toLowerCase();
  switch (ext) {
    case '.lua':
    case '.txt':
    case '.fnt':
    case '.md':
      return 'text/plain; charset=utf-8';
    case '.json':
      return 'application/json; charset=utf-8';
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.ogg':
      return 'audio/ogg';
    case '.wav':
      return 'audio/wav';
    default:
      return 'application/octet-stream';
  }
}
