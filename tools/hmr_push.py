#!/usr/bin/env python3
"""수정한 Lua 스크립트를 실행 중인 게임의 HotReloadServer로 전송한다. (이슈 #16)

사용법:
    adb forward tcp:5959 tcp:5959      # Android 기기 최초 1회
    python3 tools/hmr_push.py          # scripts/*.lua 전체를 1회 push
    python3 tools/hmr_push.py --watch  # 저장할 때마다 자동 push

프로토콜: docs/porting/android-hmr-plan.md 참조.
게임 상태는 리로드 시 초기화된다(풀 리스타트 시맨틱).
"""
import argparse
import os
import socket
import struct
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT_DIR = os.path.join(ROOT, "scripts")


def collect_files():
    """(상대경로, 절대경로) 목록 — scripts/ 이하 *.lua 전부."""
    files = []
    for dirpath, _dirnames, filenames in os.walk(SCRIPT_DIR):
        for name in sorted(filenames):
            if not name.endswith(".lua"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
            files.append((rel, full))
    return files


def push(host, port, entries):
    payload = bytearray(b"I2DH")
    payload += struct.pack("<I", len(entries))
    for rel, full in entries:
        with open(full, "rb") as fp:
            data = fp.read()
        encoded = rel.encode("utf-8")
        payload += struct.pack("<I", len(encoded)) + encoded
        payload += struct.pack("<I", len(data)) + data

    with socket.create_connection((host, port), timeout=5) as sock:
        sock.sendall(payload)
        reply = sock.recv(3)

    ok = reply == b"OK\n"
    stamp = time.strftime("%H:%M:%S")
    print("[%s] push %d files -> %s" % (stamp, len(entries), "OK" if ok else "REJECTED"))
    return ok


def snapshot(entries):
    return {rel: os.path.getmtime(full) for rel, full in entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5959)
    parser.add_argument("--watch", action="store_true",
                        help="mtime 폴링으로 변경 감지 시 자동 push")
    args = parser.parse_args()

    entries = collect_files()
    if not entries:
        print("scripts/ 에 *.lua 파일이 없습니다", file=sys.stderr)
        return 1

    try:
        push(args.host, args.port, entries)
    except OSError as e:
        print("연결 실패: %s — 게임이 실행 중인지, adb forward tcp:5959 tcp:5959 를 했는지 확인"
              % e, file=sys.stderr)
        return 1

    if not args.watch:
        return 0

    print("watch 모드 — %s 변경 감지 중 (Ctrl+C로 종료)" % SCRIPT_DIR)
    last = snapshot(entries)
    while True:
        time.sleep(0.5)
        entries = collect_files()
        current = snapshot(entries)
        if current != last:
            last = current
            try:
                # VM이 풀 리스타트되므로 항상 전체 번들을 보낸다
                push(args.host, args.port, entries)
            except OSError as e:
                print("push 실패: %s" % e, file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
