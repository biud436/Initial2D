#!/usr/bin/env python3
"""내보낸 게임의 게임 폴더 찾기 (엔진 3, docs/plans/engine3-exported-game.md).

엔진 실행 파일을 임시 폴더의 macOS 앱 묶음과 game 폴더 옆에 복사해 띄운다. 게임마다 스크립트가 시작할 때
"game:<표지>" 한 줄을 찍으므로 어느 게임이 떴는지 stdout 으로 안다.
  - 묶음(<이름>.app/Contents/MacOS/ 와 Contents/Resources/game/)은 작업 폴더에 다른 게임이 있어도, 작업 폴더가
    / 여도, 상대 경로로도, 심볼릭 링크로도 묶음의 게임을 연다
  - 실행 파일 옆의 game 폴더도 같다. 묶음과 game 폴더가 없거나 game.json 이 없으면 예전처럼 작업 폴더의 게임이다
  - 묶음을 읽기 전용으로 만들어도 뜨고, 실행 뒤 묶음과 작업 폴더의 파일 목록과 내용이 그대로다 (config.setting 없음)
  - stdout 은 게임이 찍은 줄뿐이다 (예전의 config.setting 경로 줄이 없다)
  - game.json 의 icon: 읽지 못하는 파일, 문자열이 아닌 값, 문자열이 아닌 name 은 stderr 한 줄씩. 맞는 PNG 와
    icon 이 없는 게임은 아무것도 찍지 않는다
Lua 와 Ruby 둘 다 (Ruby 는 --features 에 mruby 가 있을 때).

사용법: python3 tests/tools/exported_game_test.py [엔진 실행 파일]      기본 build/Initial2D
종료 코드: 0 전부 통과, 1 실패가 있다
"""

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import zlib
import struct

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TIMEOUT = 30

failures = 0
passes = 0


def check(cond, label, detail=""):
    global failures, passes
    if cond:
        passes += 1
        print(f"  PASS  {label}")
    else:
        failures += 1
        print(f"  FAIL  {label}")
        if detail:
            for line in str(detail).rstrip().splitlines():
                print(f"        {line}")


def tiny_png(path):
    """2x2 불투명 PNG (아이콘 시험용)."""
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + b"\xd8\xc8\x80\xff" * 2 for _ in range(2))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw))
           + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def make_game(folder, label, lang, game_json=None):
    """game.json 과 진입 파일 하나짜리 게임. 시작할 때 game:<label> 을 찍는다."""
    os.makedirs(folder, exist_ok=True)
    config = {"name": f"게임 {label}", "windowWidth": 64, "windowHeight": 48, "script": lang}
    if game_json:
        config.update(game_json)
    with open(os.path.join(folder, "game.json"), "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False)
    if lang == "lua":
        path = os.path.join(folder, "scripts", "lua", "main.lua")
        text = (f'function Initialize() print("game:{label}") end\n'
                "function Update(elapsed) end\nfunction Render() end\nfunction Destroy() end\n")
    else:
        path = os.path.join(folder, "scripts", "ruby", "main.rb")
        text = (f'def init\n  puts "game:{label}"\nend\n'
                "def update(elapsed)\nend\ndef render\nend\ndef destroy\nend\n")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def make_bundle(root, exe, label, lang, game_json=None, with_game_json=True):
    """<root>/Bird.app 묶음. 실행 파일 경로를 돌려준다."""
    contents = os.path.join(root, "Bird.app", "Contents")
    macos = os.path.join(contents, "MacOS")
    os.makedirs(macos, exist_ok=True)
    target = os.path.join(macos, "Bird")
    shutil.copy2(exe, target)
    game = os.path.join(contents, "Resources", "game")
    make_game(game, label, lang, game_json)
    if not with_game_json:
        os.remove(os.path.join(game, "game.json"))
    return target


def run(exe, cwd, args=()):
    env = {k: v for k, v in os.environ.items() if not k.startswith("INITIAL2D_")}
    env.update({"SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy", "INITIAL2D_EXIT_AFTER": "3"})
    try:
        p = subprocess.run([exe, *args], cwd=cwd, env=env, capture_output=True, text=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return 142, "", f"시간 제한 {TIMEOUT}초를 넘겼다"
    return p.returncode, p.stdout, p.stderr


def snapshot(folder):
    """폴더 안의 모든 파일과 폴더의 상대 경로, 크기, 내용 해시."""
    out = {}
    for dirpath, dirnames, filenames in os.walk(folder):
        for name in dirnames:
            out[os.path.relpath(os.path.join(dirpath, name), folder) + "/"] = None
        for name in filenames:
            path = os.path.join(dirpath, name)
            with open(path, "rb") as f:
                out[os.path.relpath(path, folder)] = zlib.crc32(f.read())
    return out


# 디버그 빌드의 App::Initialize 가 LOG_D 로 찍는 줄 (릴리스 빌드에는 없다)
DEBUG_LINES = {"생성되었습니다."}


def lines(text):
    return [line for line in text.splitlines() if line.strip() and line not in DEBUG_LINES]


def expect_game(label, result, want):
    rc, out, err = result
    check(rc == 0 and lines(out) == [f"game:{want}"], label,
          f"종료 코드 {rc}\nstdout:\n{out}\nstderr:\n{err[-1500:]}")


def make_writable(folder):
    os.chmod(folder, os.stat(folder).st_mode | stat.S_IWUSR)
    for dirpath, dirnames, filenames in os.walk(folder):
        for name in dirnames + filenames:
            path = os.path.join(dirpath, name)
            os.chmod(path, os.stat(path).st_mode | stat.S_IWUSR)


def make_read_only(folder):
    for dirpath, dirnames, filenames in os.walk(folder, topdown=False):
        for name in filenames:
            path = os.path.join(dirpath, name)
            os.chmod(path, os.stat(path).st_mode & ~(stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH))
        os.chmod(dirpath, 0o555)


def suite(exe, lang, tmp):
    print(f"[{lang}]")
    root = os.path.join(tmp, lang)
    other = os.path.join(root, "other")
    make_game(other, "cwd", lang)

    # 묶음
    bundle_root = os.path.join(root, "bundle")
    bundle_exe = make_bundle(bundle_root, exe, "bundle", lang)
    expect_game("묶음: 작업 폴더에 다른 게임이 있어도 묶음의 게임", run(bundle_exe, other), "bundle")
    expect_game("묶음: 작업 폴더가 / 여도 묶음의 게임", run(bundle_exe, "/"), "bundle")
    expect_game("묶음: 상대 경로로 띄워도 묶음의 게임",
                run(os.path.join(".", "Bird.app", "Contents", "MacOS", "Bird"), bundle_root), "bundle")
    link_dir = os.path.join(root, "bin")
    os.makedirs(link_dir)
    os.symlink(bundle_exe, os.path.join(link_dir, "bird"))
    expect_game("묶음: 심볼릭 링크로 띄워도 묶음의 게임", run(os.path.join(link_dir, "bird"), other), "bundle")

    # 실행 파일 옆의 game 폴더
    beside = os.path.join(root, "beside")
    os.makedirs(beside)
    beside_exe = os.path.join(beside, "Initial2D")
    shutil.copy2(exe, beside_exe)
    make_game(os.path.join(beside, "game"), "beside", lang)
    expect_game("game 폴더: 실행 파일 옆의 game 폴더", run(beside_exe, other), "beside")
    expect_game("game 폴더: 작업 폴더가 / 여도", run(beside_exe, "/"), "beside")

    # 후보가 없으면 작업 폴더 (예전 동작)
    plain = os.path.join(root, "plain")
    os.makedirs(plain)
    plain_exe = os.path.join(plain, "Initial2D")
    shutil.copy2(exe, plain_exe)
    before = snapshot(other)
    expect_game("후보 없음: 작업 폴더의 게임", run(plain_exe, other), "cwd")
    after = snapshot(other)
    check(before == after, "후보 없음: 작업 폴더에 아무것도 쓰지 않는다 (config.setting 없음)",
          f"새로 생긴 것: {sorted(set(after) - set(before))}, 바뀐 것: "
          f"{sorted(k for k in before if k in after and before[k] != after[k])}")

    nojson_root = os.path.join(root, "nojson")
    nojson_exe = make_bundle(nojson_root, exe, "nojson", lang, with_game_json=False)
    expect_game("game.json 없는 묶음: 작업 폴더의 게임", run(nojson_exe, other), "cwd")

    # 읽기 전용 묶음
    ro_root = os.path.join(root, "readonly")
    ro_exe = make_bundle(ro_root, exe, "readonly", lang)
    app = os.path.join(ro_root, "Bird.app")
    make_read_only(app)
    try:
        before = snapshot(app)
        expect_game("읽기 전용 묶음: / 에서 뜬다", run(ro_exe, "/"), "readonly")
        after = snapshot(app)
        check(before == after, "읽기 전용 묶음: 묶음의 파일이 그대로다",
              f"새로 생긴 것: {sorted(set(after) - set(before))}")
    finally:
        make_writable(app)
    before = snapshot(app)
    run(ro_exe, other)
    after = snapshot(app)
    check(before == after, "쓸 수 있는 묶음: 실행 뒤 묶음의 파일이 그대로다",
          f"새로 생긴 것: {sorted(set(after) - set(before))}")

    # 이름과 아이콘. want 는 stderr 의 아이콘과 이름 줄이 차례로 시작할 글자다
    def icon_case(index, name, game_json, want, png=None):
        folder = os.path.join(root, f"icon{index}")
        make_game(folder, "icon", lang, game_json)
        if png:
            tiny_png(os.path.join(folder, png))
        rc, out, err = run(plain_exe, folder)
        got = [line for line in err.splitlines()
               if "icon" in line.lower() or line.startswith("game.json name")]
        ok = len(got) == len(want) and all(line.startswith(w) for line, w in zip(got, want))
        check(rc == 0 and lines(out) == ["game:icon"] and ok,
              f"아이콘: {name}", f"종료 코드 {rc}\nstdout:\n{out}\n아이콘 줄: {got}\n기대(앞부분): {want}")

    icon_case(1, "맞는 PNG 는 아무것도 찍지 않는다", {"icon": "resources/icons/bird.png"}, [],
              png="resources/icons/bird.png")
    icon_case(2, "기본 아이콘 파일이 있으면 아무것도 찍지 않는다", {}, [], png="resources/icons/icon.png")
    icon_case(3, "icon 도 기본 파일도 없으면 아무것도 찍지 않는다", {}, [])
    icon_case(4, "읽지 못하는 파일은 한 줄", {"icon": "resources/icons/nope.png"},
              ["game.json icon: cannot load resources/icons/nope.png ("])
    icon_case(5, "문자열이 아닌 icon 은 한 줄", {"icon": 3}, ["game.json icon: expected a string"])
    icon_case(6, "문자열이 아닌 name 은 한 줄", {"name": ["새"]}, ["game.json name: expected a string"])


def main():
    exe = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "build", "Initial2D"))
    if not os.path.isfile(exe):
        print(f"엔진 실행 파일이 없다: {exe}")
        return 1
    features = subprocess.run([exe, "--features"], capture_output=True, text=True).stdout.split()
    print(f"검사: {exe} ({' '.join(features)})")
    tmp = tempfile.mkdtemp(prefix="initial2d_exported_")
    try:
        suite(exe, "lua", tmp)
        if "mruby" in features:
            suite(exe, "mruby", tmp)
        else:
            print("SKIP: 이 빌드에는 mruby 가 없어 Ruby 판을 건너뜁니다")
    finally:
        make_writable(tmp)
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"\n결과: {passes} PASS / {failures} FAIL")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
