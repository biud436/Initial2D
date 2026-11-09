#!/usr/bin/env python3
"""Windows 빌드 채널의 맥 서버 검사 (W1, docs/plans/w1-windows-build-channel.md).

임시 설정 폴더에서 init 과 trust 를 하고 127.0.0.1 의 빈 포트로 서버를 띄운다. Windows 클라이언트(client.ps1)
자리는 같은 프로토콜을 말하는 Python 가짜 에이전트가 맡는다.
  - init: 키 권한 600, 찍은 지문이 인증서의 SHA-256 이고 TLS 로 받은 서버 인증서와 같다. 다시 부르면 그대로 둔다
  - trust: Windows 가 내보내는 꼴(BOM, CRLF, 76자 줄)의 PEM 을 받고, 인증서가 아닌 것은 거부한다
  - serve: 등록된 클라이언트가 없으면 시작하지 않는다. 등록된 클라이언트는 PING, 한글 ECHO, 모르는 명령, QUIT 이
    차례로 답한다. 등록되지 않은 인증서, 인증서 없음, clientAuth 용도가 없는 인증서, 평문은 거부되고 서버 로그에
    rejected 줄이 남고 서버는 계속 돈다. 아무것도 보내지 않는 연결은 --idle 뒤에 닫힌다
  - build: 스냅숏에 커밋하지 않은 변경, 추적하지 않는 파일, 지운 파일이 들어가고 .gitignore 대상은 빠진다. 원본
    저장소의 색인, 상태, refs 는 그대로다. 로그와 결과물이 오고 종료 코드가 빌드의 것이다. 같은 상태를 다시
    빌드하면 묶음을 보내지 않고, 바뀐 뒤에는 클라이언트가 가진 것을 뺀 묶음을 보낸다. 실패한 빌드의 코드,
    없는 레시피 2, 클라이언트 없음 3 (Windows 가 꺼진 경우), 결과 전에 끊김 4, 위험한 결과물 경로는 받지 않는다
  - status: 클라이언트의 hello 를 찍고 0
사용법: python3 tests/tools/winbuild_test.py
종료 코드: 0 전부 통과, 1 실패가 있다
"""
import base64
import importlib.util
import json
import os
import queue
import re
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SERVER = ROOT / "tools" / "winbuild" / "server.py"

spec = importlib.util.spec_from_file_location("winbuild_server", SERVER)
srv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(srv)

failures = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok or not detail else f"\n     {detail}"))
    if not ok:
        failures.append(name)


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True).stdout.strip()


class Server:
    """server.py 를 띄우고 출력 줄을 모은다."""

    def __init__(self, cfg, *args):
        self.proc = subprocess.Popen(
            [sys.executable, "-u", str(SERVER), "--config-dir", str(cfg), *args],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8",
        )
        self.lines = []
        self.queue = queue.Queue()
        threading.Thread(target=self._pump, daemon=True).start()
        self.port = None
        deadline = time.time() + 10
        while self.port is None and time.time() < deadline:
            try:
                line = self.queue.get(timeout=0.2)
            except queue.Empty:
                if self.proc.poll() is not None:
                    break
                continue
            m = re.search(r"on 127\.0\.0\.1:(\d+)", line)
            if m:
                self.port = int(m.group(1))

    def _pump(self):
        for line in self.proc.stdout:
            line = line.rstrip("\n")
            self.lines.append(line)
            self.queue.put(line)

    def text(self):
        return "\n".join(self.lines)

    def wait_for(self, pattern, timeout=5):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if re.search(pattern, self.text()):
                return True
            time.sleep(0.05)
        return False

    def finish(self, timeout=30):
        try:
            code = self.proc.wait(timeout)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            code = None
        time.sleep(0.1)
        return code

    def stop(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            self.proc.wait(5)


def client_socket(port, cert=None, key=None, tls12=False):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE  # 서버 지문은 따로 대조한다 (client.ps1 과 같은 방식)
    if tls12:
        ctx.maximum_version = ssl.TLSVersion.TLSv1_2  # client.ps1 은 SslProtocols.Tls12 로 붙는다
    if cert:
        ctx.load_cert_chain(cert, key)
    sock = socket.create_connection(("127.0.0.1", port), timeout=5)
    return ctx.wrap_socket(sock)


def echo_session(port, cert, key, lines, tls12=False):
    s = client_socket(port, cert, key, tls12)
    f = s.makefile("rwb")
    replies = []
    for line in lines:
        f.write((line + "\r\n").encode("utf-8"))
        f.flush()
        replies.append(f.readline().decode("utf-8").rstrip("\n"))
    server_fp = srv.fingerprint_der(s.getpeercert(binary_form=True))
    version = s.version()
    s.close()
    return replies, server_fp, version


def rejected(port, cert=None, key=None, tls12=False):
    """TLS 가 거부되면 True (핸드셰이크나 첫 읽기에서 오류, 또는 답 없이 닫힘)."""
    try:
        s = client_socket(port, cert, key, tls12)
        s.sendall(b"PING\n")
        data = s.recv(100)
        s.close()
        return data != b"PONG\n"
    except (ssl.SSLError, ConnectionError, OSError):
        return True


# ---------------------------------------------------------------- 가짜 에이전트

class FakeAgent:
    """client.ps1 -Agent 와 같은 프로토콜로 한 번 접속해 일을 하나 한다."""

    def __init__(self, port, cert, key, repo, recipes):
        self.port, self.cert, self.key, self.repo, self.recipes = port, cert, key, repo, recipes
        self.job = None
        self.bundle_size = None
        self.error = None

    def haves(self):
        try:
            sha = git(self.repo, "rev-parse", "--verify", "-q", "refs/winbuild/snapshot")
        except subprocess.CalledProcessError:
            return []
        return [sha, git(self.repo, "rev-parse", f"{sha}^")]

    def run(self, recipe_impl, disconnect_after_job=False):
        try:
            s = client_socket(self.port, self.cert, self.key)
            f = s.makefile("rwb")

            def send(message, payload=b""):
                if payload:
                    message = dict(message, size=len(payload))
                f.write((json.dumps(message, ensure_ascii=False) + "\n").encode("utf-8"))
                if payload:
                    f.write(payload)
                f.flush()

            send({"type": "hello", "agent": "fake", "host": "FAKE", "have": self.haves(),
                  "recipes": sorted(self.recipes)})
            job = json.loads(f.readline())
            self.job = job
            if job["type"] != "job":
                s.close()
                return
            size = int(job.get("size") or 0)
            self.bundle_size = size
            if size:
                with tempfile.TemporaryDirectory() as tmp:
                    bundle = Path(tmp) / "in.bundle"
                    bundle.write_bytes(f.read(size))
                    git(self.repo, "fetch", "-q", "--force", str(bundle),
                        "refs/winbuild/snapshot:refs/winbuild/snapshot")
            git(self.repo, "-c", "advice.detachedHead=false", "checkout", "-q", "--force", "--detach", job["snapshot"])
            git(self.repo, "clean", "-q", "-fd")
            if disconnect_after_job:
                s.close()
                return
            logs, artifacts, code = recipe_impl(self.repo)
            for text in logs:
                send({"type": "log", "text": text})
            send({"type": "tick"})
            for path, data in artifacts.items():
                import hashlib
                send({"type": "artifact", "path": path, "sha256": hashlib.sha256(data).hexdigest()}, data)
            send({"type": "result", "exit": code, "seconds": 0.1, "snapshot": job["snapshot"]})
            f.readline()  # bye
            s.close()
        except Exception as e:  # noqa: BLE001 (시험 실패로 보고한다)
            self.error = f"{type(e).__name__}: {e}"


def selftest_recipe(repo):
    a = (repo / "a.txt").read_text(encoding="utf-8")
    new = (repo / "new.txt").read_text(encoding="utf-8")
    report = f"a={a.strip()} new={new.strip()} ignored={(repo / 'ignored.txt').exists()} gone={(repo / 'gone.txt').exists()}"
    return ["building 한글 로그", report], {"out/report.txt": report.encode("utf-8")}, 0


def run_build(cfg, src, out, recipe, agent_kwargs, recipe_impl, wait=10, **run_kwargs):
    server = Server(cfg, "build", recipe, "--host", "127.0.0.1", "--port", "0", "--repo", str(src),
                    "--out", str(out), "--wait", str(wait))
    agent = None
    if agent_kwargs is not None and server.port:
        agent = FakeAgent(server.port, **agent_kwargs)
        t = threading.Thread(target=agent.run, args=(recipe_impl,), kwargs=run_kwargs)
        t.start()
        t.join(30)
    code = server.finish()
    return code, server.text(), agent


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        cfg = tmp / "cfg"

        # ------------------------------------------------ init, fingerprint
        out = subprocess.run([sys.executable, str(SERVER), "--config-dir", str(cfg), "init"],
                             capture_output=True, text=True)
        fp = re.search(r"SHA256 ([0-9A-F]{64})", out.stdout)
        check("init prints a SHA-256 fingerprint", out.returncode == 0 and fp, out.stdout + out.stderr)
        server_fp = fp.group(1) if fp else ""
        mode = (cfg / "server.key").stat().st_mode & 0o777
        check("server key is 600", mode == 0o600, oct(mode))
        # 설정 폴더가 어느 git 저장소 안에 있어도 키가 올라갈 후보가 되지 않는다
        subprocess.run(["git", "init", "-q", str(tmp)], check=True)
        untracked = subprocess.run(["git", "-C", str(tmp), "status", "--porcelain", "--untracked-files=all", "--", "cfg"],
                                   capture_output=True, text=True).stdout
        check("config folder is ignored by any enclosing git repo", untracked == "", untracked)
        subprocess.run(["rm", "-rf", str(tmp / ".git")], check=True)
        der = srv.read_pem_cert((cfg / "server.crt").read_text())
        check("fingerprint is the certificate SHA-256", srv.fingerprint_der(der) == server_fp)
        before = (cfg / "server.crt").read_bytes()
        subprocess.run([sys.executable, str(SERVER), "--config-dir", str(cfg), "init"], capture_output=True)
        check("init again keeps the certificate", (cfg / "server.crt").read_bytes() == before)

        # ------------------------------------------------ 클라이언트 인증서
        good_key, good_crt = tmp / "good.key", tmp / "good.crt"
        srv.make_self_signed(good_key, good_crt, "Initial2D winbuild client TEST", "clientAuth")
        other_key, other_crt = tmp / "other.key", tmp / "other.crt"
        srv.make_self_signed(other_key, other_crt, "stranger", "clientAuth")
        purpose_key, purpose_crt = tmp / "purpose.key", tmp / "purpose.crt"
        srv.make_self_signed(purpose_key, purpose_crt, "server purpose only", "serverAuth")

        no_clients = subprocess.run([sys.executable, str(SERVER), "--config-dir", str(cfg), "serve",
                                     "--host", "127.0.0.1", "--port", "0"], capture_output=True, text=True, timeout=10)
        check("serve refuses without a trusted client", no_clients.returncode != 0
              and "no trusted client" in no_clients.stderr, no_clients.stderr)

        # Windows 의 [Convert]::ToBase64String(..., InsertLineBreaks) 꼴: 76자 줄, CRLF, BOM
        good_der = srv.read_pem_cert(good_crt.read_text())
        b64 = base64.b64encode(good_der).decode()
        windows_pem = "-----BEGIN CERTIFICATE-----\r\n" + "\r\n".join(
            b64[i:i + 76] for i in range(0, len(b64), 76)) + "\r\n-----END CERTIFICATE-----\r\n"
        win_file = tmp / "windows.pem"
        win_file.write_bytes(b"\xef\xbb\xbf" + windows_pem.encode("ascii"))
        out = subprocess.run([sys.executable, str(SERVER), "--config-dir", str(cfg), "trust", str(win_file),
                              "--name", "TEST"], capture_output=True, text=True)
        check("trust takes a Windows-style PEM", out.returncode == 0
              and srv.fingerprint_der(good_der) in out.stdout, out.stdout + out.stderr)
        bad_file = tmp / "bad.pem"
        bad_file.write_text("-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n")
        out = subprocess.run([sys.executable, str(SERVER), "--config-dir", str(cfg), "trust", str(bad_file)],
                             capture_output=True, text=True)
        check("trust rejects a non-certificate", out.returncode != 0, out.stdout)

        # ------------------------------------------------ serve (에코)
        server = Server(cfg, "serve", "--host", "127.0.0.1", "--port", "0", "--idle", "1")
        check("serve starts", server.port is not None, server.text())
        if server.port:
            replies, seen_fp, _ = echo_session(server.port, good_crt, good_key,
                                               ["PING", "ECHO 안녕 한글", "HELLO", "QUIT"])
            check("echo replies", replies == ["PONG", "안녕 한글", "ERR unknown command: HELLO", "BYE"], repr(replies))
            check("TLS server certificate matches the init fingerprint", seen_fp == server_fp)
            check("log names the client", server.wait_for(r"connected: Initial2D winbuild client TEST"), server.text())
            replies, seen_fp, version = echo_session(server.port, good_crt, good_key, ["ECHO tls12"], tls12=True)
            check("TLS 1.2 client works (client.ps1 uses Tls12)", replies == ["tls12"] and version == "TLSv1.2"
                  and seen_fp == server_fp, f"{replies} {version}")
            check("untrusted certificate is rejected", rejected(server.port, other_crt, other_key))
            check("untrusted certificate is rejected on TLS 1.2", rejected(server.port, other_crt, other_key, True))
            check("no certificate is rejected", rejected(server.port))
            check("certificate without clientAuth is rejected", rejected(server.port, purpose_crt, purpose_key))
            plain = socket.create_connection(("127.0.0.1", server.port), timeout=5)
            plain.sendall(b"PING\n")
            try:
                data = plain.recv(100)
            except OSError:
                data = b""
            plain.close()
            check("plain TCP gets no echo", b"PONG" not in data, repr(data))
            # Windows 에이전트의 포트 확인: 붙었다가 바로 닫는 연결은 거부 줄을 남기지 않는다
            time.sleep(0.5)  # 앞의 평문 연결이 남기는 거부 줄이 먼저 찍히도록
            before = server.text().count("rejected:")
            probe = socket.create_connection(("127.0.0.1", server.port), timeout=5)
            probe.close()
            time.sleep(0.5)
            check("a bare connect and close is not logged", server.text().count("rejected:") == before, server.text())
            check("rejections are logged", server.wait_for(r"rejected:.*(?s:.*)rejected:.*(?s:.*)rejected:"), server.text())
            s = client_socket(server.port, good_crt, good_key)
            started = time.time()
            try:
                s.settimeout(5)
                gone = s.recv(10) == b""
            except (ssl.SSLError, OSError):
                gone = True
            check("idle connection is closed", gone and 0.8 <= time.time() - started < 4.5,
                  f"{time.time() - started:.2f}s")
            replies, _, _ = echo_session(server.port, good_crt, good_key, ["PING"])
            check("server still serves after rejections", replies == ["PONG"], repr(replies))
        server.stop()

        # ------------------------------------------------ build
        src = tmp / "src"
        src.mkdir()
        git(src, "init", "-q")
        git(src, "config", "user.email", "t@example.com")
        git(src, "config", "user.name", "t")
        (src / ".gitignore").write_text("ignored.txt\nbuild/\n")
        (src / "a.txt").write_text("one\n")
        (src / "gone.txt").write_text("bye\n")
        git(src, "add", ".")
        git(src, "commit", "-q", "-m", "base")
        (src / "a.txt").write_text("two\n")
        (src / "new.txt").write_text("새 파일\n", encoding="utf-8")
        (src / "ignored.txt").write_text("secret\n")
        (src / "gone.txt").unlink()
        status_before = git(src, "status", "--porcelain")
        index_before = (src / ".git" / "index").read_bytes()

        agent_repo = tmp / "agent"
        agent_repo.mkdir()
        git(agent_repo, "init", "-q")
        out_dir = tmp / "out"
        agent_kwargs = dict(cert=good_crt, key=good_key, repo=agent_repo, recipes=["selftest", "fail"])

        code, text, agent = run_build(cfg, src, out_dir, "selftest", agent_kwargs, selftest_recipe)
        check("build exits with the build's code", code == 0, text + f"\nagent error: {agent and agent.error}")
        report = (out_dir / "out" / "report.txt")
        check("artifact arrives", report.exists() and report.read_text(encoding="utf-8")
              == "a=two new=새 파일 ignored=False gone=False", report.read_text(encoding="utf-8") if report.exists() else text)
        check("logs are printed", "building 한글 로그" in text and "result: exit 0" in text, text)
        check("source repo status and index untouched", git(src, "status", "--porcelain") == status_before
              and (src / ".git" / "index").read_bytes() == index_before)
        check("no refs left in the source repo", git(src, "for-each-ref", "refs/winbuild") == "")
        first_size = agent.bundle_size if agent else None

        code, text, agent = run_build(cfg, src, out_dir, "selftest", agent_kwargs, selftest_recipe)
        check("same state sends no bundle", code == 0 and agent and agent.bundle_size == 0
              and "already has this snapshot" in text, text)

        (src / "a.txt").write_text("three\n")
        code, text, agent = run_build(cfg, src, out_dir, "selftest", agent_kwargs, selftest_recipe)
        check("changed state sends a smaller bundle and builds it", code == 0 and agent and agent.error is None
              and 0 < agent.bundle_size < first_size
              and report.read_text(encoding="utf-8").startswith("a=three"),
              f"{agent and agent.bundle_size} vs {first_size}\n{text}\n{agent and agent.error}")

        code, text, _ = run_build(cfg, src, out_dir, "fail", agent_kwargs,
                                  lambda repo: (["error C2065: boom"], {}, 7))
        check("failed build exit code passes through", code == 7 and "error C2065" in text, text)

        code, text, _ = run_build(cfg, src, out_dir, "nope", agent_kwargs, selftest_recipe)
        check("unknown recipe exits 2", code == 2 and "selftest" in text, text)

        code, text, _ = run_build(cfg, src, out_dir, "selftest", None, None, wait=1)
        check("no client exits 3 (Windows off)", code == 3 and "Windows is off" in text, text)

        code, text, _ = run_build(cfg, src, out_dir, "selftest", agent_kwargs, selftest_recipe,
                                  disconnect_after_job=True)
        check("disconnect before the result exits 4", code == 4, text)

        code, text, _ = run_build(cfg, src, out_dir, "selftest", agent_kwargs,
                                  lambda repo: ([], {"../evil.txt": b"x"}, 0))
        check("unsafe artifact path is refused", code == 4 and not (out_dir.parent / "evil.txt").exists(), text)

        # ------------------------------------------------ status
        server = Server(cfg, "status", "--host", "127.0.0.1", "--port", "0", "--wait", "10")
        agent = FakeAgent(server.port, **agent_kwargs)
        t = threading.Thread(target=agent.run, args=(selftest_recipe,))
        t.start()
        t.join(10)
        code = server.finish()
        check("status prints the hello", code == 0 and '"host": "FAKE"' in server.text()
              and agent.job == {"type": "bye"}, server.text())

    print()
    print("all passed" if not failures else f"{len(failures)} failed: {', '.join(failures)}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
