// 엔진 HotReloadServer(TCP 5959)로 스크립트 번들을 push 한다.
// tools/hmr_push.py 와 같은 프로토콜(docs/porting/android-hmr-plan.md):
//   "I2DH" | u32 fileCount | (u32 pathLen | path | u32 dataLen | data)* → 응답 "OK\n" 또는 "ER\n"
// 정수는 전부 리틀 엔디언. 엔진은 번들을 받으면 Lua VM을 풀 리스타트한다.
import net from 'node:net';

export const HMR_MAGIC = 'I2DH';

export function encodeBundle(files) {
  if (!Array.isArray(files) || files.length === 0) {
    throw new Error('bundle must contain at least one file');
  }
  const chunks = [];
  const u32 = (value) => {
    const b = Buffer.alloc(4);
    b.writeUInt32LE(value >>> 0, 0);
    return b;
  };
  chunks.push(Buffer.from(HMR_MAGIC, 'ascii'));
  chunks.push(u32(files.length));
  for (const file of files) {
    const pathBytes = Buffer.from(file.path, 'utf8');
    const data = Buffer.isBuffer(file.data) ? file.data : Buffer.from(file.data);
    chunks.push(u32(pathBytes.length), pathBytes, u32(data.length), data);
  }
  return Buffer.concat(chunks);
}

// 테스트와 디버깅용 디코더 (엔진과 같은 규칙으로 파싱)
export function decodeBundle(buffer) {
  let offset = 0;
  const need = (n) => {
    if (offset + n > buffer.length) throw new Error('truncated bundle');
  };
  need(4);
  if (buffer.toString('ascii', 0, 4) !== HMR_MAGIC) throw new Error('bad magic');
  offset = 4;
  const readU32 = () => {
    need(4);
    const v = buffer.readUInt32LE(offset);
    offset += 4;
    return v;
  };
  const count = readU32();
  const files = [];
  for (let i = 0; i < count; i++) {
    const pathLen = readU32();
    need(pathLen);
    const filePath = buffer.toString('utf8', offset, offset + pathLen);
    offset += pathLen;
    const dataLen = readU32();
    need(dataLen);
    const data = buffer.subarray(offset, offset + dataLen);
    offset += dataLen;
    files.push({ path: filePath, data });
  }
  if (offset !== buffer.length) throw new Error('trailing bytes in bundle');
  return files;
}

// 번들을 보내고 엔진의 3바이트 응답을 기다린다. resolve: { ok, reply }
export function pushBundle({ host = '127.0.0.1', port = 5959, files, timeoutMs = 5000 }) {
  const payload = encodeBundle(files);
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port });
    let reply = Buffer.alloc(0);
    let settled = false;
    const finish = (fn, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      socket.destroy();
      fn(value);
    };
    const timer = setTimeout(() => finish(reject, new Error(`HMR push timed out after ${timeoutMs}ms`)), timeoutMs);
    socket.on('connect', () => socket.write(payload));
    socket.on('data', (chunk) => {
      reply = Buffer.concat([reply, chunk]);
      if (reply.length >= 3) {
        const text = reply.toString('ascii', 0, 3);
        finish(resolve, { ok: text === 'OK\n', reply: text.trim(), files: files.length });
      }
    });
    socket.on('end', () => {
      if (reply.length < 3) finish(reject, new Error('HMR server closed without reply'));
    });
    socket.on('error', (err) => finish(reject, err));
  });
}
