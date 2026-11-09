#!/usr/bin/env python3
"""Windows 빌드 채널의 맥 서버 (docs/plans/w1-windows-build-channel.md).

Windows 클라이언트(tools/winbuild/client.ps1)가 이 서버의 포트로 접속한다. 연결은 TLS 1.2 이상이고 양쪽이 서로의
인증서를 고정한다. 서버는 trust 로 등록한 클라이언트 인증서만 받고, 클라이언트는 서버 인증서의 SHA-256 지문을 확인한다.
두 기기 사이에 비밀은 오가지 않는다.

  python3 tools/winbuild/server.py init                         # 서버 키와 인증서를 만들고 지문을 찍는다
  python3 tools/winbuild/server.py trust client.pem --name U    # 클라이언트 인증서(PEM)를 등록한다
  python3 tools/winbuild/server.py fingerprint                  # 서버 지문과 등록된 클라이언트
  python3 tools/winbuild/server.py status --host <mac-lan-address> # Windows 클라이언트가 접속하는지 본다
  python3 tools/winbuild/server.py build gdi-release --host <mac-lan-address>
  python3 tools/winbuild/server.py serve --host <mac-lan-address>  # 에코 서버 (클라이언트의 -Echo 확인용)

build 는 작업 트리(커밋하지 않은 변경과 추적하지 않는 파일 포함, .gitignore 대상 제외)를 스냅숏 커밋으로 만들어
git 묶음으로 보내고, 클라이언트가 레시피대로 빌드하는 동안 로그를 찍고, 결과물을 build/winbuild/<레시피>/ 에 받는다.
포트는 build 와 status 가 도는 동안만 열린다. 클라이언트가 --wait 초 안에 접속하지 않으면 Windows 가 꺼져 있거나
클라이언트가 돌지 않는 것이므로 종료 코드 3 으로 끝난다. 종료 코드는 빌드의 종료 코드이고, 그 밖에 2 레시피 없음,
3 클라이언트 없음, 4 연결 끊김, 5 시간 초과다.
설정 폴더는 ~/.config/initial2d-winbuild 이고 --config-dir 나 INITIAL2D_WINBUILD_HOME 으로 바꾼다.
"""
import argparse
import asyncio
import base64
import hashlib
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_PORT = 5970
DEFAULT_IDLE = 60
DEFAULT_WAIT = 15
DEFAULT_TIMEOUT = 1800
HANDSHAKE_TIMEOUT = 10
MAX_LINE = 1 << 20
CHUNK = 1 << 20
SHA_RE = re.compile(r"[0-9a-f]{40}")

EXIT_NO_RECIPE = 2
EXIT_NO_CLIENT = 3
EXIT_LOST = 4
EXIT_TIMEOUT = 5

OPENSSL_CONFIG = """[req]
distinguished_name = dn
prompt = no
[dn]
CN = {cn}
[ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = {eku}
"""


# ---------------------------------------------------------------- 인증서

def config_dir(arg) -> Path:
    if arg:
        return Path(arg)
    env = os.environ.get("INITIAL2D_WINBUILD_HOME")
    return Path(env) if env else Path.home() / ".config" / "initial2d-winbuild"


def fingerprint_der(der: bytes) -> str:
    return hashlib.sha256(der).hexdigest().upper()


def make_self_signed(key_path: Path, crt_path: Path, cn: str, eku: str, days: int = 3650) -> None:
    """openssl 로 RSA 2048 자체 서명 인증서를 만든다. eku 는 serverAuth 나 clientAuth."""
    with tempfile.NamedTemporaryFile("w", suffix=".cnf", delete=False) as f:
        f.write(OPENSSL_CONFIG.format(cn=cn, eku=eku))
        cfg = f.name
    try:
        subprocess.run(
            ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key_path),
             "-out", str(crt_path), "-days", str(days), "-config", cfg, "-extensions", "ext"],
            check=True, capture_output=True,
        )
    finally:
        os.unlink(cfg)
    os.chmod(key_path, 0o600)


def read_pem_cert(text: str) -> bytes:
    """PEM 글에서 첫 인증서의 DER 을 꺼낸다. BOM, CRLF, 76자 줄(Windows 의 base64)도 받는다."""
    m = re.search(r"-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----", text, re.S)
    if not m:
        raise ValueError("no PEM certificate block")
    der = base64.b64decode(re.sub(r"\s+", "", m.group(1)), validate=True)
    probe = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    probe.load_verify_locations(cadata=der)  # 인증서가 아니면 ssl.SSLError
    return der


def server_fingerprint(d: Path) -> str:
    return fingerprint_der(read_pem_cert((d / "server.crt").read_text()))


def trusted_clients(d: Path):
    folder = d / "clients"
    return sorted(folder.glob("*.pem")) if folder.is_dir() else []


def server_context(d: Path):
    """서버 TLS 문맥과 등록된 클라이언트 이름. 준비가 안 됐으면 (None, 이유)."""
    if not (d / "server.crt").exists():
        return None, "no server certificate. run: server.py init"
    clients = trusted_clients(d)
    if not clients:
        return None, "no trusted client. run: server.py trust <client.pem>"
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(d / "server.crt", d / "server.key")
    ctx.verify_mode = ssl.CERT_REQUIRED
    ctx.load_verify_locations(cadata="".join(p.read_text() for p in clients))
    return ctx, [p.stem for p in clients]


def guard_config_dir(d: Path) -> None:
    """설정 폴더를 700 으로 두고, 어느 git 저장소 안에 있어도 올라가지 않게 모두 무시하는 .gitignore 를 둔다."""
    d.mkdir(parents=True, exist_ok=True)
    os.chmod(d, 0o700)
    ignore = d / ".gitignore"
    if not ignore.exists():
        ignore.write_text("# server.key and trusted client certificates: never commit\n*\n")


def cmd_init(args) -> int:
    d = config_dir(args.config_dir)
    key, crt = d / "server.key", d / "server.crt"
    guard_config_dir(d)
    if crt.exists() and not args.force:
        print(f"server certificate already exists: {crt}")
    else:
        make_self_signed(key, crt, "Initial2D winbuild server", "serverAuth")
        print(f"server certificate: {crt}")
    print(f"SHA256 {server_fingerprint(d)}")
    return 0


def cmd_fingerprint(args) -> int:
    d = config_dir(args.config_dir)
    if not (d / "server.crt").exists():
        print("no server certificate. run: server.py init", file=sys.stderr)
        return 1
    print(f"server SHA256 {server_fingerprint(d)}")
    for pem in trusted_clients(d):
        print(f"client {pem.stem} SHA256 {fingerprint_der(read_pem_cert(pem.read_text()))}")
    return 0


def cmd_trust(args) -> int:
    d = config_dir(args.config_dir)
    text = sys.stdin.read() if args.pem == "-" else Path(args.pem).read_text(encoding="utf-8-sig")
    try:
        der = read_pem_cert(text)
    except (ValueError, ssl.SSLError) as e:
        print(f"not a certificate: {e}", file=sys.stderr)
        return 1
    fp = fingerprint_der(der)
    name = args.name or fp[:16]
    if not re.fullmatch(r"[A-Za-z0-9._-]+", name):
        print(f"bad name: {name!r} (letters, digits, . _ -)", file=sys.stderr)
        return 1
    guard_config_dir(d)
    folder = d / "clients"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.pem").write_text(ssl.DER_cert_to_PEM_cert(der))
    print(f"trusted client {name} SHA256 {fp}")
    return 0


# ---------------------------------------------------------------- 연결

def log(peer: str, text: str) -> None:
    print(f"{datetime.now():%H:%M:%S} {peer} {text}", flush=True)


def common_name(cert: dict) -> str:
    for rdn in cert.get("subject", ()):
        for key, value in rdn:
            if key == "commonName":
                return value
    return "?"


async def accept_tls(reader, writer, ctx: ssl.SSLContext):
    """평문 연결을 TLS 로 올린다. 거부되면 로그를 남기고 None, 받으면 'host:port'."""
    host, port = writer.get_extra_info("peername")[:2]
    peer = f"{host}:{port}"
    try:
        await writer.start_tls(ctx, ssl_handshake_timeout=HANDSHAKE_TIMEOUT)
    except (ssl.SSLError, ConnectionError, asyncio.TimeoutError, OSError) as e:
        # 붙었다가 아무것도 보내지 않고 닫는 연결은 Windows 에이전트가 포트가 열렸는지 보는 것이라 남기지 않는다
        if not (isinstance(e, (ConnectionResetError, ssl.SSLEOFError)) and not str(e)):
            log(peer, f"rejected: {type(e).__name__}: {e}")
        writer.transport.abort()
        return None
    tls = writer.get_extra_info("ssl_object")
    fp = fingerprint_der(tls.getpeercert(binary_form=True))
    log(peer, f"connected: {common_name(tls.getpeercert())} SHA256 {fp[:16]}... {tls.version()}")
    return peer


async def send_json(writer, message: dict, payload: Path = None) -> None:
    """JSON 한 줄을 보낸다. payload 가 있으면 size 를 채우고 그 뒤에 파일 내용을 그대로 잇는다."""
    if payload is not None:
        message = dict(message, size=payload.stat().st_size)
    writer.write((json.dumps(message, ensure_ascii=False) + "\n").encode("utf-8"))
    if payload is not None:
        with open(payload, "rb") as f:
            for block in iter(lambda: f.read(CHUNK), b""):
                writer.write(block)
                await writer.drain()
    await writer.drain()


async def read_json(reader, timeout=None):
    """JSON 한 줄을 읽는다. 연결이 닫혔으면 None."""
    raw = await asyncio.wait_for(reader.readline(), timeout)
    if not raw:
        return None
    message = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(message, dict) or "type" not in message:
        raise ValueError(f"message without type: {raw[:200]!r}")
    return message


async def read_payload_to_file(reader, size: int, path: Path) -> str:
    digest = hashlib.sha256()
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        while size:
            block = await reader.readexactly(min(CHUNK, size))
            digest.update(block)
            f.write(block)
            size -= len(block)
    return digest.hexdigest()


# ---------------------------------------------------------------- 에코 (serve)

def run_command(line: str):
    """에코 명령 한 줄의 응답과 연결을 계속할지를 돌려준다."""
    name, _, arg = line.partition(" ")
    name = name.upper()
    if name == "PING":
        return "PONG", True
    if name == "ECHO":
        return arg, True
    if name == "QUIT":
        return "BYE", False
    return f"ERR unknown command: {name}", True


async def handle_echo(reader, writer, ctx: ssl.SSLContext, idle: float) -> None:
    peer = await accept_tls(reader, writer, ctx)
    if peer is None:
        return
    try:
        while True:
            try:
                raw = await asyncio.wait_for(reader.readline(), idle)
            except asyncio.TimeoutError:
                log(peer, f"idle for {idle:g}s, closing")
                break
            if not raw:
                break
            line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
            reply, keep = run_command(line)
            log(peer, f"{line!r} -> {reply!r}")
            writer.write((reply + "\n").encode("utf-8"))
            await writer.drain()
            if not keep:
                break
    except (ValueError, asyncio.LimitOverrunError):
        log(peer, "line too long, closing")
    except (ConnectionError, ssl.SSLError) as e:
        log(peer, f"connection error: {e}")
    finally:
        writer.close()
        log(peer, "closed")


async def serve(args) -> int:
    ctx, clients = server_context(config_dir(args.config_dir))
    if ctx is None:
        print(clients, file=sys.stderr)
        return 1
    server = await asyncio.start_server(
        lambda r, w: handle_echo(r, w, ctx, args.idle), args.host, args.port, limit=4096
    )
    port = server.sockets[0].getsockname()[1]
    print(f"listening on {args.host}:{port} (TLS echo, trusted clients: {', '.join(clients)})", flush=True)
    async with server:
        await server.serve_forever()
    return 0


# ---------------------------------------------------------------- 스냅숏

def git(repo: Path, *args, env=None) -> str:
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, env=env)
    if r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout.strip()


def make_snapshot(repo: Path) -> str:
    """HEAD 위에 작업 트리를 얹은 커밋을 만든다. 색인과 refs 는 건드리지 않는다.

    같은 HEAD 와 같은 작업 트리는 같은 커밋 해시가 된다 (날짜를 HEAD 의 것으로 고정한다).
    """
    head = git(repo, "rev-parse", "HEAD")
    date = git(repo, "show", "-s", "--format=%cI", "HEAD")
    index = Path(git(repo, "rev-parse", "--git-path", "index"))
    if not index.is_absolute():
        index = repo / index
    with tempfile.TemporaryDirectory() as tmp:
        tmp_index = Path(tmp) / "index"
        if index.exists():
            shutil.copyfile(index, tmp_index)
        env = dict(
            os.environ, GIT_INDEX_FILE=str(tmp_index),
            GIT_AUTHOR_NAME="winbuild", GIT_AUTHOR_EMAIL="winbuild@localhost", GIT_AUTHOR_DATE=date,
            GIT_COMMITTER_NAME="winbuild", GIT_COMMITTER_EMAIL="winbuild@localhost", GIT_COMMITTER_DATE=date,
        )
        if index.exists():
            git(repo, "add", "-A", env=env)
        else:
            git(repo, "read-tree", "HEAD", env=env)
            git(repo, "add", "-A", env=env)
        tree = git(repo, "write-tree", env=env)
        return git(repo, "commit-tree", tree, "-p", head, "-m", "winbuild snapshot", env=env)


def make_bundle(repo: Path, snapshot: str, haves, out: Path) -> bool:
    """클라이언트에 없는 것만 담은 묶음을 쓴다. 클라이언트가 이미 그 스냅숏을 가졌으면 False."""
    haves = [h for h in haves if isinstance(h, str) and SHA_RE.fullmatch(h)]
    if snapshot in haves:
        return False
    bases = []
    for h in haves:
        if subprocess.run(["git", "-C", str(repo), "cat-file", "-e", f"{h}^{{commit}}"],
                          capture_output=True).returncode == 0:
            bases.append(h)
    ref = "refs/winbuild/snapshot"
    git(repo, "update-ref", ref, snapshot)
    try:
        git(repo, "bundle", "create", str(out), ref, *[f"^{b}" for b in bases])
    finally:
        git(repo, "update-ref", "-d", ref)
    return True


def safe_relative(path: str) -> PurePosixPath:
    p = PurePosixPath(path.replace("\\", "/"))
    if p.is_absolute() or not p.parts or ".." in p.parts or ":" in p.parts[0]:
        raise ValueError(f"unsafe artifact path: {path!r}")
    return p


# ---------------------------------------------------------------- build, status

class Session:
    """build 와 status 가 받는 클라이언트 하나."""

    def __init__(self):
        self.claimed = False
        self.hello = asyncio.Event()
        self.done = asyncio.get_running_loop().create_future()


async def wait_for_client(args, on_hello) -> int:
    """포트를 열고 클라이언트 하나를 기다린다. on_hello(reader, writer, peer, hello) 가 종료 코드를 돌려준다."""
    ctx, clients = server_context(config_dir(args.config_dir))
    if ctx is None:
        print(clients, file=sys.stderr)
        return 1
    session = Session()

    async def handle(reader, writer):
        peer = await accept_tls(reader, writer, ctx)
        if peer is None:
            return
        try:
            hello = await read_json(reader, HANDSHAKE_TIMEOUT)
            if not hello or hello.get("type") != "hello":
                log(peer, f"expected hello, got {hello!r}")
                return
            if session.claimed:
                await send_json(writer, {"type": "bye", "reason": "busy"})
                return
            session.claimed = True
            session.hello.set()
            log(peer, f"hello: {hello.get('host')} agent {hello.get('agent')} recipes {hello.get('recipes')}")
            code = await on_hello(reader, writer, peer, hello)
            if not session.done.done():
                session.done.set_result(code)
        except (asyncio.IncompleteReadError, ConnectionError, ssl.SSLError, asyncio.TimeoutError, ValueError) as e:
            log(peer, f"connection lost: {type(e).__name__}: {e}")
            if session.claimed and not session.done.done():
                session.done.set_result(EXIT_LOST)
        finally:
            writer.close()

    server = await asyncio.start_server(handle, args.host, args.port, limit=MAX_LINE)
    port = server.sockets[0].getsockname()[1]
    print(f"waiting for the Windows client on {args.host}:{port} (up to {args.wait:g}s)", flush=True)
    async with server:
        try:
            await asyncio.wait_for(session.hello.wait(), args.wait)
        except asyncio.TimeoutError:
            print(f"no Windows client connected within {args.wait:g}s: Windows is off, "
                  f"or the client is not running (client.ps1 -Agent)", file=sys.stderr)
            return EXIT_NO_CLIENT
        try:
            return await asyncio.wait_for(session.done, args.timeout)
        except asyncio.TimeoutError:
            print(f"timed out after {args.timeout:g}s", file=sys.stderr)
            return EXIT_TIMEOUT


async def status(args) -> int:
    async def on_hello(reader, writer, peer, hello):
        print(json.dumps(hello, ensure_ascii=False, indent=2))
        await send_json(writer, {"type": "bye"})
        return 0

    return await wait_for_client(args, on_hello)


async def build(args) -> int:
    repo = Path(args.repo).resolve() if args.repo else ROOT
    snapshot = make_snapshot(repo)
    head = git(repo, "rev-parse", "HEAD")
    print(f"snapshot {snapshot[:12]} (HEAD {head[:12]} and the working tree)", flush=True)
    out_dir = Path(args.out) if args.out else repo / "build" / "winbuild" / args.recipe

    async def on_hello(reader, writer, peer, hello):
        recipes = hello.get("recipes") or []
        if args.recipe not in recipes:
            print(f"unknown recipe {args.recipe!r}. the client has: {', '.join(recipes) or '(none)'}", file=sys.stderr)
            await send_json(writer, {"type": "bye", "reason": "unknown recipe"})
            return EXIT_NO_RECIPE
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / "snapshot.bundle"
            job = {"type": "job", "id": f"{int(time.time())}", "recipe": args.recipe,
                   "snapshot": snapshot, "clean": args.clean}
            if make_bundle(repo, snapshot, hello.get("have") or [], bundle):
                print(f"sending {bundle.stat().st_size / 1e6:.1f} MB", flush=True)
                await send_json(writer, job, bundle)
            else:
                print("the client already has this snapshot", flush=True)
                await send_json(writer, dict(job, size=0))
        started = time.monotonic()
        while True:
            message = await read_json(reader)
            if message is None:
                print("connection lost before the result", file=sys.stderr)
                return EXIT_LOST
            kind = message["type"]
            if kind == "log":
                print(message.get("text", ""), flush=True)
            elif kind == "artifact":
                rel = safe_relative(message["path"])
                target = out_dir / Path(*rel.parts)
                got = await read_payload_to_file(reader, int(message["size"]), target)
                if got != str(message.get("sha256", "")).lower():
                    print(f"sha256 mismatch for {rel}", file=sys.stderr)
                    return EXIT_LOST
                print(f"artifact {target} ({message['size']} bytes)", flush=True)
            elif kind == "result":
                code = int(message.get("exit", 1))
                error = message.get("error")
                seconds = message.get("seconds", time.monotonic() - started)
                print(f"result: exit {code} in {float(seconds):.1f}s" + (f" ({error})" if error else ""), flush=True)
                await send_json(writer, {"type": "bye"})
                return code if 0 <= code <= 255 else 1
            # tick 같은 다른 종류는 연결이 살아 있다는 뜻뿐이다

    return await wait_for_client(args, on_hello)


# ---------------------------------------------------------------- main

def main() -> int:
    if sys.version_info < (3, 11):
        print("server.py needs Python 3.11 or later (StreamWriter.start_tls)", file=sys.stderr)
        return 1
    parser = argparse.ArgumentParser(description="Windows 빌드 채널의 맥 서버")
    parser.add_argument("--config-dir", help="설정 폴더 (기본 ~/.config/initial2d-winbuild)")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("init", help="서버 키와 인증서를 만든다")
    p.add_argument("--force", action="store_true", help="이미 있어도 새로 만든다")
    sub.add_parser("fingerprint", help="서버 지문과 등록된 클라이언트를 찍는다")
    p = sub.add_parser("trust", help="클라이언트 인증서를 등록한다")
    p.add_argument("pem", help="PEM 파일 경로, - 이면 표준 입력")
    p.add_argument("--name", help="등록 이름 (기본은 지문 앞 16자)")

    def listen_options(p):
        p.add_argument("--host", required=True, help="받을 주소. LAN 주소나 127.0.0.1")
        p.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"포트 (기본 {DEFAULT_PORT}, 0 이면 빈 포트)")

    p = sub.add_parser("serve", help="에코 서버를 띄운다")
    listen_options(p)
    p.add_argument("--idle", type=float, default=DEFAULT_IDLE, help=f"말 없는 연결을 닫는 초 (기본 {DEFAULT_IDLE})")
    for name, text in (("status", "Windows 클라이언트가 접속하는지 보고 그 정보를 찍는다"),
                       ("build", "Windows 클라이언트에게 빌드를 시킨다")):
        p = sub.add_parser(name, help=text)
        if name == "build":
            p.add_argument("recipe", help="클라이언트의 recipes.json 에 있는 이름 (예: gdi-release)")
            p.add_argument("--repo", help="스냅숏을 뜰 저장소 (기본은 이 저장소)")
            p.add_argument("--out", help="결과물을 받을 폴더 (기본 build/winbuild/<레시피>)")
            p.add_argument("--clean", action="store_true", help="무시 대상 파일까지 지우고 빌드한다")
        listen_options(p)
        p.add_argument("--wait", type=float, default=DEFAULT_WAIT, help=f"클라이언트를 기다리는 초 (기본 {DEFAULT_WAIT})")
        p.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT, help=f"작업 전체의 초 (기본 {DEFAULT_TIMEOUT})")
    args = parser.parse_args()
    runners = {"serve": serve, "status": status, "build": build}
    if args.command in runners:
        try:
            return asyncio.run(runners[args.command](args))
        except KeyboardInterrupt:
            return 130
    return {"init": cmd_init, "fingerprint": cmd_fingerprint, "trust": cmd_trust}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
