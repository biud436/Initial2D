// 프로젝트 파일 접근 계층: 화이트리스트와 경로 탈출 차단 (docs/plans/03-editor-bridge.md)
//
// 브리지가 만지는 파일은 프로젝트 루트 아래의 화이트리스트로 한정한다.
//   디렉터리: scripts/, resources/, .initial-editor/ (에디터 전용 상태: 레이아웃 등)
//   파일:     game.json (엔진 설정이자 에디터가 프로젝트로 인식하는 표식)
// 브라우저에서 오는 경로는 전부 이 모듈을 통과해야 한다.
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';

export const DEFAULT_ALLOWED_DIRS = ['scripts', 'resources', '.initial-editor'];
export const DEFAULT_ALLOWED_FILES = ['game.json'];

// 브리지가 원자적 쓰기에 쓰는 임시 파일 이름 (목록과 감시에서 숨긴다)
const TMP_PATTERN = /\.bridge-\d+-\d+\.tmp$/;

export class BridgeError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// URL 경로(예: "scripts/games/flappy.lua")를 정규화된 상대 경로로 바꾼다.
// 절대 경로, 백슬래시, NUL, ".." 탈출, 화이트리스트 밖은 전부 거부한다.
// 루트 자체("")는 여기서 받지 않는다 (목록은 listDir 이 따로 다룬다).
export function normalizeRelPath(relPath, allowedDirs = DEFAULT_ALLOWED_DIRS, allowedFiles = DEFAULT_ALLOWED_FILES) {
  if (typeof relPath !== 'string' || relPath.length === 0) {
    throw new BridgeError(400, 'empty path');
  }
  if (relPath.includes('\0') || relPath.includes('\\')) {
    throw new BridgeError(400, 'invalid character in path');
  }
  if (relPath.startsWith('/')) {
    throw new BridgeError(400, 'absolute path not allowed');
  }
  const normalized = path.posix.normalize(relPath).replace(/\/+$/, '');
  if (normalized === '.' || normalized === '..' || normalized === '' || normalized.startsWith('../')) {
    throw new BridgeError(403, 'path escapes project root');
  }
  const top = normalized.split('/')[0];
  if (allowedDirs.includes(top)) return normalized;
  if (!normalized.includes('/') && allowedFiles.includes(normalized)) return normalized;
  throw new BridgeError(403, `path outside allowed dirs (${allowedDirs.join(', ')}) and files (${allowedFiles.join(', ')})`);
}

export class ProjectFiles {
  constructor(root, allowedDirs = DEFAULT_ALLOWED_DIRS, allowedFiles = DEFAULT_ALLOWED_FILES) {
    this.root = path.resolve(root);
    this.allowedDirs = allowedDirs;
    this.allowedFiles = allowedFiles;
  }

  // 상대 경로 → 절대 경로 (검사 포함)
  resolve(relPath) {
    const normalized = normalizeRelPath(relPath, this.allowedDirs, this.allowedFiles);
    return { rel: normalized, abs: path.join(this.root, normalized) };
  }

  // 검사를 통과한 절대 경로 (존재 여부는 보지 않는다)
  async resolveChecked(relPath) {
    const resolved = this.resolve(relPath);
    await this.assertInsideRoot(resolved.abs);
    return resolved;
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
    const { rel, abs } = await this.resolveChecked(relPath);
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

  // 종류와 크기. 없으면 404
  async stat(relPath) {
    const { rel, abs } = await this.resolveChecked(relPath);
    try {
      const stat = await fsp.stat(abs);
      return { rel, kind: stat.isDirectory() ? 'dir' : 'file', size: stat.size, mtimeMs: stat.mtimeMs };
    } catch (err) {
      if (err.code === 'ENOENT' || err.code === 'ENOTDIR') throw new BridgeError(404, `not found: ${rel}`);
      throw err;
    }
  }

  // 원자적 쓰기: 같은 디렉터리에 임시 파일을 만들고 rename 한다.
  async write(relPath, data) {
    const { rel, abs } = await this.resolveChecked(relPath);
    await fsp.mkdir(path.dirname(abs), { recursive: true });
    const tmp = `${abs}.bridge-${process.pid}-${Date.now()}.tmp`;
    try {
      await fsp.writeFile(tmp, data);
      await fsp.rename(tmp, abs);
    } catch (err) {
      await fsp.rm(tmp, { force: true }).catch(() => {});
      if (err.code === 'EISDIR' || err.code === 'ENOTDIR') throw new BridgeError(409, `not a file: ${rel}`);
      throw err;
    }
    return { rel, bytes: data.length };
  }

  // 파일은 unlink, 디렉터리는 통째로 지운다 (에디터가 먼저 묻는다)
  async remove(relPath) {
    const { rel, abs } = await this.resolveChecked(relPath);
    try {
      const stat = await fsp.stat(abs);
      if (stat.isDirectory()) {
        await fsp.rm(abs, { recursive: true, force: true });
        return { rel, kind: 'dir' };
      }
      await fsp.unlink(abs);
      return { rel, kind: 'file' };
    } catch (err) {
      if (err instanceof BridgeError) throw err;
      if (err.code === 'ENOENT' || err.code === 'ENOTDIR') throw new BridgeError(404, `not found: ${rel}`);
      throw err;
    }
  }

  async mkdir(relPath) {
    const { rel, abs } = await this.resolveChecked(relPath);
    try {
      const existing = await fsp.stat(abs).catch(() => null);
      if (existing && !existing.isDirectory()) throw new BridgeError(409, `not a directory: ${rel}`);
      await fsp.mkdir(abs, { recursive: true });
      return { rel };
    } catch (err) {
      if (err instanceof BridgeError) throw err;
      if (err.code === 'ENOTDIR') throw new BridgeError(409, `parent is not a directory: ${rel}`);
      throw err;
    }
  }

  // 파일이나 디렉터리 이름 바꾸기 (옮기기). 대상이 이미 있으면 409
  async rename(fromRel, toRel) {
    const from = await this.resolveChecked(fromRel);
    const to = await this.resolveChecked(toRel);
    if (from.rel === to.rel) return { from: from.rel, to: to.rel };
    const source = await fsp.stat(from.abs).catch(() => null);
    if (!source) throw new BridgeError(404, `not found: ${from.rel}`);
    if (await fsp.stat(to.abs).catch(() => null)) throw new BridgeError(409, `already exists: ${to.rel}`);
    await fsp.mkdir(path.dirname(to.abs), { recursive: true });
    await fsp.rename(from.abs, to.abs);
    return { from: from.rel, to: to.rel, kind: source.isDirectory() ? 'dir' : 'file' };
  }

  // 한 층 목록. 루트("")는 화이트리스트에 있는 것 중 실제로 존재하는 것만 보인다.
  // 항목: { name, path, kind: 'file' | 'dir', size, mtime }
  async listDir(dirRel) {
    if (dirRel === '' || dirRel === '.' || dirRel === '/') {
      const out = [];
      for (const name of this.allowedDirs) {
        const stat = await fsp.stat(path.join(this.root, name)).catch(() => null);
        if (stat && stat.isDirectory()) out.push({ name, path: name, kind: 'dir', mtime: Math.floor(stat.mtimeMs) });
      }
      for (const name of this.allowedFiles) {
        const stat = await fsp.stat(path.join(this.root, name)).catch(() => null);
        if (stat && stat.isFile()) out.push({ name, path: name, kind: 'file', size: stat.size, mtime: Math.floor(stat.mtimeMs) });
      }
      return out;
    }
    const { rel, abs } = await this.resolveChecked(dirRel);
    let entries;
    try {
      entries = await fsp.readdir(abs, { withFileTypes: true });
    } catch (err) {
      if (err.code === 'ENOENT' || err.code === 'ENOTDIR') throw new BridgeError(404, `not a directory: ${rel}`);
      throw err;
    }
    const out = [];
    for (const entry of entries) {
      if (TMP_PATTERN.test(entry.name)) continue;
      const full = path.join(abs, entry.name);
      let stat;
      try {
        stat = await fsp.stat(full); // 심링크는 따라간다
      } catch {
        continue; // 깨진 링크 등은 숨긴다
      }
      const item = { name: entry.name, path: `${rel}/${entry.name}`, kind: stat.isDirectory() ? 'dir' : 'file', mtime: Math.floor(stat.mtimeMs) };
      if (item.kind === 'file') item.size = stat.size;
      out.push(item);
    }
    out.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
    return out;
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

  // 감시가 아는 경로 집합을 만들기 위해 파일과 디렉터리를 전부 나열한다 (닷 항목 제외)
  async walkAll() {
    const out = new Set();
    const walk = async (dir) => {
      let entries;
      try {
        entries = await fsp.readdir(dir, { withFileTypes: true });
      } catch {
        return;
      }
      for (const entry of entries) {
        if (entry.name.startsWith('.') || TMP_PATTERN.test(entry.name)) continue;
        const full = path.join(dir, entry.name);
        out.add(path.relative(this.root, full).split(path.sep).join('/'));
        if (entry.isDirectory()) await walk(full);
      }
    };
    for (const dirAbs of this.existingAllowedDirs()) await walk(dirAbs);
    for (const name of this.allowedFiles) {
      if (fs.existsSync(path.join(this.root, name))) out.add(name);
    }
    return out;
  }

  // 화이트리스트 디렉터리 중 실제로 존재하는 것들의 절대 경로 (감시용). 닷 디렉터리는 제외
  existingAllowedDirs() {
    return this.allowedDirs
      .filter((dir) => !dir.startsWith('.'))
      .map((dir) => path.join(this.root, dir))
      .filter((abs) => fs.existsSync(abs));
  }
}

export function contentTypeFor(relPath) {
  const ext = path.posix.extname(relPath).toLowerCase();
  switch (ext) {
    case '.lua':
    case '.rb':
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
