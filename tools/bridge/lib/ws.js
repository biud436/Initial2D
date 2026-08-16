// 의존성 없는 최소 WebSocket 서버 (RFC 6455, 서버 → 클라이언트 텍스트 브로드캐스트 용도).
// 파일 변경 알림만 보내면 되므로 핸드셰이크, 텍스트 프레임 송신, ping/pong, close 만 구현한다.
// 클라이언트가 보내는 텍스트 프레임은 파싱만 하고 'message' 이벤트로 넘긴다 (현재는 미사용).
import crypto from 'node:crypto';
import { EventEmitter } from 'node:events';

const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

const OP_TEXT = 0x1;
const OP_CLOSE = 0x8;
const OP_PING = 0x9;
const OP_PONG = 0xa;

export function encodeFrame(opcode, payload = Buffer.alloc(0)) {
  const len = payload.length;
  let header;
  if (len < 126) {
    header = Buffer.from([0x80 | opcode, len]);
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x80 | opcode;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x80 | opcode;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(len), 2);
  }
  return Buffer.concat([header, payload]);
}

// 버퍼 앞에서 프레임 하나를 떼어낸다. 부족하면 null.
export function decodeFrame(buffer) {
  if (buffer.length < 2) return null;
  const fin = (buffer[0] & 0x80) !== 0;
  const opcode = buffer[0] & 0x0f;
  const masked = (buffer[1] & 0x80) !== 0;
  let len = buffer[1] & 0x7f;
  let offset = 2;
  if (len === 126) {
    if (buffer.length < 4) return null;
    len = buffer.readUInt16BE(2);
    offset = 4;
  } else if (len === 127) {
    if (buffer.length < 10) return null;
    len = Number(buffer.readBigUInt64BE(2));
    offset = 10;
  }
  let mask = null;
  if (masked) {
    if (buffer.length < offset + 4) return null;
    mask = buffer.subarray(offset, offset + 4);
    offset += 4;
  }
  if (buffer.length < offset + len) return null;
  const payload = Buffer.from(buffer.subarray(offset, offset + len));
  if (mask) {
    for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
  }
  return { fin, opcode, payload, rest: buffer.subarray(offset + len) };
}

export class WebSocketHub extends EventEmitter {
  constructor() {
    super();
    this.clients = new Set();
  }

  // http.Server 'upgrade' 이벤트 핸들러에서 호출한다.
  handleUpgrade(req, socket) {
    const key = req.headers['sec-websocket-key'];
    if (!key || (req.headers.upgrade || '').toLowerCase() !== 'websocket') {
      socket.write('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n');
      socket.destroy();
      return null;
    }
    const accept = crypto.createHash('sha1').update(key + GUID).digest('base64');
    socket.write(
      'HTTP/1.1 101 Switching Protocols\r\n' +
        'Upgrade: websocket\r\n' +
        'Connection: Upgrade\r\n' +
        `Sec-WebSocket-Accept: ${accept}\r\n\r\n`,
    );
    socket.setNoDelay(true);
    const client = { socket, buffer: Buffer.alloc(0) };
    this.clients.add(client);

    socket.on('data', (chunk) => {
      client.buffer = Buffer.concat([client.buffer, chunk]);
      for (;;) {
        const frame = decodeFrame(client.buffer);
        if (!frame) break;
        client.buffer = frame.rest;
        if (frame.opcode === OP_CLOSE) {
          try {
            socket.write(encodeFrame(OP_CLOSE, frame.payload.subarray(0, 2)));
          } catch {
            /* ignore */
          }
          socket.end();
          break;
        } else if (frame.opcode === OP_PING) {
          socket.write(encodeFrame(OP_PONG, frame.payload));
        } else if (frame.opcode === OP_TEXT) {
          this.emit('message', frame.payload.toString('utf8'), client);
        }
      }
    });
    const drop = () => {
      this.clients.delete(client);
      this.emit('close', client);
    };
    socket.on('close', drop);
    socket.on('error', drop);
    this.emit('connection', client);
    return client;
  }

  sendTo(client, text) {
    if (client.socket.destroyed) return false;
    client.socket.write(encodeFrame(OP_TEXT, Buffer.from(text, 'utf8')));
    return true;
  }

  broadcast(text) {
    let sent = 0;
    for (const client of this.clients) {
      if (this.sendTo(client, text)) sent += 1;
    }
    return sent;
  }

  // 종료 핸드셰이크를 지킨다: close 프레임을 보내고 FIN 을 날린 뒤, 상대가 1초 안에 닫지
  // 않으면 강제로 끊는다. (곧바로 destroy 하면 상대가 close 프레임을 보내는 중일 때 RST 가
  // 나가고, 일부 클라이언트는 그 소켓을 한참 붙들고 있는다.)
  closeAll() {
    for (const client of this.clients) {
      const { socket } = client;
      try {
        socket.write(encodeFrame(OP_CLOSE, Buffer.from([0x03, 0xe9])));
        socket.end();
      } catch {
        socket.destroy();
        continue;
      }
      const timer = setTimeout(() => socket.destroy(), 1000);
      timer.unref();
      socket.once('close', () => clearTimeout(timer));
    }
    this.clients.clear();
  }
}
