#!/usr/bin/env python3
"""Initial2D 엔진 테스트 러너 (macOS/SDL2 백엔드).

커밋된 리소스와 Lua 테스트 씬(tests/engine/scenes/)만으로 엔진의
렌더링·애니메이션·텍스트·프리미티브·오디오·입력 API를 프레임 덤프의
픽셀 검증으로 확인한다. 게임 실행 파일(build/Initial2D)이 필요하다.

사용법: python3 tests/run_engine_tests.py [빌드된 실행 파일 경로] [--only=이름조각,...]
  --only=mruby_units      mruby 단위 테스트만 (이름 조각은 test_ 함수 이름에 부분 일치)
"""

import itertools
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time

from PIL import Image, ImageChops

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_args = [a for a in sys.argv[1:] if not a.startswith("--")]
# 씬마다 임시 작업 폴더에서 실행하므로 상대 경로는 여기서 절대 경로로 바꾼다
GAME = os.path.abspath(_args[0]) if _args else os.path.join(REPO, "build", "Initial2D")

# 골든 스크린샷 (docs/plans/09-testing.md 3.3절)
# 갱신은 의도적 절차로만: --update-golden 을 명시하고, 갱신된 이미지를 눈으로 확인한 뒤 커밋한다.
GOLDEN_DIR = os.path.join(REPO, "tests", "golden")
UPDATE_GOLDEN = "--update-golden" in sys.argv
LOGICAL_SIZE = (768, 896)          # 논리 해상도 — Retina 배율 차이를 정규화한다
GOLDEN_PIXEL_TOL = 24              # 채널당 허용 오차
# 초과 픽셀 허용 비율. 실측 근거(2026-08-15 CI 첫 실행):
#   로컬(Retina 2배, 가속) 골든 대 CI(1배, 소프트웨어 렌더러) 캡처의 소음 = 1.04%
#   서로 다른 씬(진짜 차이)의 비율 = 25.77%
# → 소음의 약 2배, 신호의 1/12 지점인 2%로 설정.
GOLDEN_DIFF_RATIO = 0.02
# 한 칸 검사. 비율만으로는 맵 타일 한 칸(렌더 배율 2에서 32x32, 화면의 0.15%)이 바뀐 화면도 통과한다.
# 캡처가 논리 해상도 그대로면(헤드리스, CI) 리샘플 잡음이 없으므로, 16x16 창 어디에서든 다른 픽셀이
# 창 넓이의 1/4을 넘게 모이면 실패로 본다. 비스듬한 가장자리 한 줄이 통째로 달라도 23픽셀이다.
GOLDEN_WINDOW = 16
GOLDEN_WINDOW_MAX = 64

PASSES = []
FAILS = []

# 작업 폴더. 테스트 하나가 끝나면 그 테스트가 만든 폴더를 지운다. 실패한 테스트의 폴더는
# 남기고 경로를 찍는다. INITIAL2D_KEEP_WORK=1 이면 전부 남긴다.
KEEP_WORK = os.environ.get("INITIAL2D_KEEP_WORK") == "1"
WORKDIRS = []


def new_workdir(prefix):
    work = tempfile.mkdtemp(prefix=prefix)
    WORKDIRS.append(work)
    return work


def settle_workdirs(failed):
    if failed or KEEP_WORK:
        for work in WORKDIRS:
            if os.path.isdir(work):
                print(f"  작업 폴더를 남김: {work}")
    else:
        for work in WORKDIRS:
            shutil.rmtree(work, ignore_errors=True)
    WORKDIRS.clear()

# 이 빌드가 실행할 수 있는 스크립트 언어 (S1). `Initial2D --features` 가 "lua" 또는
# "lua mruby" 를 찍는다. mruby 가 없는 빌드에서는 mruby 테스트를 눈에 띄게 건너뛴다
# (CI 는 brew install mruby 로 항상 켠다).
def engine_features():
    try:
        out = subprocess.run([GAME, "--features"], capture_output=True, text=True, timeout=30)
        return set(out.stdout.split())
    except (OSError, subprocess.SubprocessError):
        return set()


HAS_MRUBY = False


def check(name, cond, detail=""):
    if cond:
        PASSES.append(name)
        print(f"  PASS  {name}")
    else:
        FAILS.append(name)
        print(f"  FAIL  {name}  {detail}")


def stage_scripts(work):
    """저자의 scripts/ 를 통째로 워크 디렉터리에 복사한다.

    씬 테스트는 main.lua만 갈아 끼우고 나머지는 실물을 그대로 쓴다 (게임이
    실제로 여는 파일과 테스트가 여는 파일이 같아야 한다). 8단계의 데모 씬
    테스트는 scripts/games/ 까지 진짜를 얹어 돌린다.
    """
    scripts = os.path.join(work, "scripts")
    shutil.copytree(os.path.join(REPO, "scripts"), scripts)
    os.remove(os.path.join(scripts, "lua", "main.lua"))   # 테스트 씬이 대신 들어온다
    return scripts


def make_workdir(scene, fixtures=False):
    work = new_workdir("initial2d-test-")
    os.symlink(os.path.join(REPO, "resources"), os.path.join(work, "resources"))
    if fixtures:
        # 포맷 계약 픽스처 (09-testing.md 3.5절). 씬 로더 씬이 tests/fixtures/scenes/ 를 연다
        shutil.copytree(os.path.join(REPO, "tests", "fixtures"),
                        os.path.join(work, "fixtures"))
    scripts = stage_scripts(work)
    # 입력 재생기 (09-testing.md 3.4절) — 씬 테스트가 사람 대신 키를 누른다
    luatests = os.path.join(scripts, "lua", "luatests")
    os.makedirs(luatests, exist_ok=True)
    shutil.copy(os.path.join(REPO, "tests", "lua", "input_replay.lua"), luatests)
    # Ruby 씬을 위한 재생기도 같은 자리에 (tests/ruby/input_replay.rb 가 있을 때)
    rb_replay = os.path.join(REPO, "tests", "ruby", "input_replay.rb")
    if os.path.exists(rb_replay):
        rbtests = os.path.join(scripts, "ruby", "rbtests")
        os.makedirs(rbtests, exist_ok=True)
        shutil.copy(rb_replay, rbtests)
    # 언어별 폴더: .lua 씬은 scripts/lua/main.lua 로, .rb 씬은 scripts/ruby/main.rb 로 들어간다.
    # main.lua 는 stage_scripts 가 지웠으므로 .rb 씬이면 엔진이 스스로 mruby 를 고른다
    # (ScriptRuntime 의 3번 규칙). .lua 씬이면 저자의 scripts/ruby/main.rb 가 함께 복사되어
    # 있어도 main.lua 가 이긴다.
    entry = os.path.join("ruby", "main.rb") if scene.endswith(".rb") else os.path.join("lua", "main.lua")
    shutil.copy(os.path.join(REPO, "tests", "engine", "scenes", scene),
                os.path.join(scripts, entry))
    return work


def link_resources(work, copy=()):
    """work/resources 를 저장소의 resources 에 잇는다. copy 에 적은 폴더(maps, data)만 복사해
    테스트가 고칠 수 있게 하고, 나머지는 폴더마다 심링크한다 (저장소의 파일은 건드리지 않는다)."""
    res = os.path.join(REPO, "resources")
    dst_root = os.path.join(work, "resources")
    if os.path.islink(dst_root):
        os.remove(dst_root)
    if not copy:
        os.symlink(res, dst_root)
        return
    os.makedirs(dst_root)
    for name in os.listdir(res):
        src = os.path.join(res, name)
        dst = os.path.join(dst_root, name)
        if name in copy:
            shutil.copytree(src, dst)
        else:
            os.symlink(src, dst)


def make_game_workdir(copy=()):
    """진짜 허브(scripts/lua/main.lua)로 게임을 띄우는 워크 디렉터리 (M2).

    make_workdir 와 달리 main.lua 를 지우지 않고 scripts/ 를 그대로 복사한다. copy 에 적은
    resources 폴더만 복사한다 (link_resources).
    """
    work = new_workdir("initial2d-game-")
    link_resources(work, copy)
    shutil.copytree(os.path.join(REPO, "scripts"), os.path.join(work, "scripts"))
    return work


def run_scene(scene, frames, exit_after, extra_env=None, fixtures=False, prepare=None):
    """prepare(work) 는 실행 전에 작업 폴더를 고친다 (예: link_resources 로 맵을 복사해 칸 하나를 바꾼다)."""
    work = make_workdir(scene, fixtures)
    if prepare:
        prepare(work)
    env = dict(os.environ)
    if extra_env:
        env.update(extra_env)
    env["INITIAL2D_SCREENSHOT"] = os.path.join(work, "shot_%04ld.bmp")
    env["INITIAL2D_SCREENSHOT_FRAME"] = ",".join(str(f) for f in frames)
    env["INITIAL2D_EXIT_AFTER"] = str(exit_after)

    result = subprocess.run([GAME], cwd=work, env=env,
                            capture_output=True, text=True, timeout=120)
    shots = {}
    for f in frames:
        path = os.path.join(work, f"shot_{f:04d}.bmp")
        if os.path.exists(path):
            shots[f] = Image.open(path).convert("RGB")
    return work, result, shots


def near(pixel, target, tol=28):
    return all(abs(a - b) <= tol for a, b in zip(pixel, target))


def px(img, scale, x, y):
    """논리 좌표 → 디바이스 픽셀 (Retina 배율 반영)"""
    return img.getpixel((int(x * scale), int(y * scale)))


def count_color_in(img, scale, x0, y0, x1, y1, target, tol=28, invert=False):
    """논리 좌표 사각형 안에서 target 색(invert면 target이 아닌 색) 픽셀을 센다."""
    n = 0
    for yy in range(int(y0 * scale), int(y1 * scale), 2):
        for xx in range(int(x0 * scale), int(x1 * scale), 2):
            if near(img.getpixel((xx, yy)), target, tol) != invert:
                n += 1
    return n


def golden_mask(norm, golden):
    """채널 하나라도 GOLDEN_PIXEL_TOL 을 넘게 다른 픽셀은 1, 나머지는 0인 바이트열 (행 우선)."""
    over = [ch.point(lambda v: 1 if v > GOLDEN_PIXEL_TOL else 0)
            for ch in ImageChops.difference(norm, golden).split()]
    return ImageChops.lighter(ImageChops.lighter(over[0], over[1]), over[2]).tobytes()


def densest_window(mask, width, height, k, ignore=()):
    """k x k 창 가운데 mask 의 1이 가장 많은 창의 (개수, x, y). ignore 의 사각형 (x0, y0, x1, y1) 안은 0으로 센다."""
    if ignore:
        mask = bytearray(mask)
        for x0, y0, x1, y1 in ignore:
            x0, x1 = max(x0, 0), min(x1, width)
            for y in range(max(y0, 0), min(y1, height)):
                mask[y * width + x0:y * width + x1] = bytes(x1 - x0)
    best = (0, 0, 0)
    cols = [0] * (width - k + 1)
    rows = []
    for y in range(height):
        acc = list(itertools.accumulate(mask[y * width:(y + 1) * width], initial=0))
        rows.append([acc[x + k] - acc[x] for x in range(width - k + 1)])
        cols = [c + r for c, r in zip(cols, rows[y])]
        if y >= k:
            cols = [c - r for c, r in zip(cols, rows[y - k])]
        if y >= k - 1:
            top = max(cols)
            if top > best[0]:
                best = (top, cols.index(top), y - k + 1)
    return best


def golden_diff(img, golden, ignore=()):
    """캡처와 골든의 차이: (다른 픽셀 비율, 가장 붐비는 창 (개수, x, y)). 창은 캡처가 논리 해상도
    그대로일 때만 세고, 리샘플한 캡처(Retina 창)면 None 이다."""
    mask = golden_mask(img.resize(LOGICAL_SIZE, Image.BILINEAR), golden)
    ratio = mask.count(1) / len(mask)
    if img.size != LOGICAL_SIZE:
        return ratio, None
    return ratio, densest_window(mask, *LOGICAL_SIZE, GOLDEN_WINDOW, ignore)


def check_golden(name, img, ignore=()):
    """캡처를 논리 해상도로 정규화해 tests/golden/<name>.png 와 비교한다. ignore 는 캡처할 때마다
    그림이 달라지는 자리(논리 좌표 사각형)이고 한 칸 검사에서만 뺀다."""
    norm = img.resize(LOGICAL_SIZE, Image.BILINEAR)
    path = os.path.join(GOLDEN_DIR, f"{name}.png")
    if UPDATE_GOLDEN or not os.path.exists(path):
        os.makedirs(GOLDEN_DIR, exist_ok=True)
        newly = not os.path.exists(path)
        norm.save(path)
        print(f"  GOLDEN {'생성' if newly else '갱신'}: {os.path.relpath(path, REPO)}"
              f" — 눈으로 확인한 뒤 커밋할 것")
        return
    ratio, window = golden_diff(img, Image.open(path).convert("RGB"), ignore)
    check(f"골든 일치: {name}", ratio <= GOLDEN_DIFF_RATIO,
          f"차이 픽셀 {ratio:.2%} (허용 {GOLDEN_DIFF_RATIO:.0%}) — 의도된 변경이면 --update-golden")
    if window is None:
        print(f"  NOTE  골든 한 칸 검사: {name} — 리샘플한 캡처라 건너뜀 (헤드리스로 돌리면 한다)")
        return
    count, x, y = window
    check(f"골든 한 칸 검사: {name}", count <= GOLDEN_WINDOW_MAX,
          f"({x}, {y}) 의 {GOLDEN_WINDOW}x{GOLDEN_WINDOW} 창에 다른 픽셀 {count}개"
          f" (허용 {GOLDEN_WINDOW_MAX}) — 의도된 변경이면 --update-golden")


WHITE = (255, 255, 255)
TILE1 = (216, 145, 37)   # tile1.png 단색
RED = (255, 0, 0)


def run_assert_scene(scene, dump_name):
    """assert 씬의 검증 본체. Lua 씬과 mruby 씬이 같은 그림을 그리므로 같은 검사와
    같은 골든(assert_scene_f35)을 쓴다 — 두 바인딩이 같은 엔진 호출로 이어진다는 증거."""
    frames = [12, 35, 60]
    work, result, shots = run_scene(scene, frames, 70)

    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("스크립트 오류 없음", "PANIC" not in log and "error" not in log.lower().replace("iccp", ""),
          log[-200:])
    # 엔진의 커스텀 print는 인자를 구분자 없이 이어서 출력한다
    check("폰트 로드 성공", "fontReady:true" in log, log[:200])
    # GetVolume 은 설정한 0..255 값을 돌려준다. 설정하지 않았으면 255
    check("오디오 볼륨 질의(BGM+SE 재생 후)", "volume:255" in log, log[-300:])
    check("프레임 덤프 3장 생성", len(shots) == 3, f"{len(shots)}장")

    if len(shots) != 3:
        return

    img = shots[35]
    scale = img.width / 768.0

    # [A] 텍스트: 주황 배경판(32..416,150..534) 위 흰 글리프
    check("텍스트 배경판(단색 스프라이트 8배 스케일)",
          near(px(img, scale, 100, 500), TILE1), str(px(img, scale, 100, 500)))
    glyphs = count_color_in(img, scale, 60, 175, 410, 230, WHITE, 12)
    check("BMFont 한글 글리프 픽셀 존재", glyphs > 40, f"white px={glyphs}")

    # [B] 애니메이션: 캡처 3장에서 스프라이트 영역이 2개 이상 서로 달라야 함
    crops = []
    for f in frames:
        im = shots[f]
        s = im.width / 768.0
        crops.append(im.crop((int(500 * s), int(200 * s), int(564 * s), int(264 * s))).tobytes())
    distinct = len(set(crops))
    check("프레임 애니메이션 진행(캡처 간 픽셀 변화)", distinct >= 2, f"distinct={distinct}/3")

    # [C] 회전 45°: 회전된 중심은 타일색, 비회전 모서리 자리는 배경(흰색)
    center = px(img, scale, 600, 534)
    corner = px(img, scale, 644, 504)
    check("45도 회전 — 회전된 위치에 타일 픽셀", near(center, TILE1), str(center))
    check("45도 회전 — 원래 모서리 자리는 배경", near(corner, WHITE, 12), str(corner))

    # [D] 반투명 opacity=128: 흰 배경과 타일색의 중간값
    blended = px(img, scale, 524, 724)
    expected = tuple((a + b) // 2 for a, b in zip(TILE1, WHITE))
    check("opacity 128 알파 블렌딩", near(blended, expected, 24),
          f"{blended} vs {expected}")

    # [G] draw_point 빨간 점 블록 (700..708, 60..68)
    dot = px(img, scale, 703, 63)
    check("draw_set_color + draw_point", near(dot, RED, 12), str(dot))

    # 애니메이션 스프라이트 자리는 캡처 프레임이 어느 tick 에 걸리느냐에 따라 그림이 달라진다 ([B]가 따로 본다)
    check_golden("assert_scene_f35", img, ignore=[(500, 200, 564, 264)])
    shutil.copy(os.path.join(work, "shot_0035.bmp"), f"/tmp/initial2d_{dump_name}.bmp")


def test_assert_scene():
    print("\n[1] assert_scene — 렌더링·애니메이션·텍스트·프리미티브·오디오")
    run_assert_scene("assert_scene.lua", "assert_scene")


def test_mruby_assert_scene():
    """같은 씬을 mruby 로 (S1). 골든까지 Lua 씬과 같은 것을 쓴다."""
    print("\n[1m] mruby_assert_scene — 같은 검증 씬을 mruby 로, 같은 골든에 견준다")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다 (brew install mruby 후 cmake 다시 실행)")
        return
    run_assert_scene("mruby_assert_scene.rb", "mruby_assert_scene")


# 입력 경로 (C++): INITIAL2D_TEST_EVENTS 가 SDL 이벤트 큐에 넣은 마우스 이벤트가 HandleEvent, Input::update,
# 바인딩을 거쳐 스크립트에 보이는가. 이벤트 사이는 20 프레임이다 (헤드리스는 한 프레임이 한 틱보다 짧을 수 있다)
INPUT_EVENTS = "10:mousedown:0,30:wheel:1,50:wheel:-1,70:wheel:-3,90:mousedown:1"
INPUT_EXPECTED = [
    ("왼쪽 버튼을 누른 틱: IsAnyMouseDown 과 IsMouseDown(0) 이 참",
     "input:any_mouse=true left=true any_key=false wheel=0"),
    ("휠을 위로 굴린 틱의 GetMouseZ 는 -1",
     "input:any_mouse=false left=false any_key=false wheel=-1"),
    ("휠을 아래로 굴린 틱의 GetMouseZ 는 1",
     "input:any_mouse=false left=false any_key=false wheel=1"),
    ("한 번에 여러 칸 굴려도 GetMouseZ 는 1",
     "input:any_mouse=false left=false any_key=false wheel=1"),
    ("오른쪽 버튼을 누른 틱: IsAnyMouseDown 은 참, IsMouseDown(0) 은 거짓",
     "input:any_mouse=true left=false any_key=false wheel=0"),
    ("SetMouseZ 는 이번 틱의 값을 바꾼다", "input:set_wheel=7"),
    ("다음 틱의 휠 값은 새 이벤트에서 온다 (없으면 0)", "input:after_set_wheel=0"),
]


def check_input_events_run(result):
    log = result.stdout + result.stderr
    lines = [l for l in log.splitlines() if l.startswith("input:")]
    check("입력 씬이 이벤트 다섯 개를 보고 스스로 끝났다",
          result.returncode == 0 and len(lines) == len(INPUT_EXPECTED), "\n".join(lines) or log[-400:])
    for i, (label, expected) in enumerate(INPUT_EXPECTED):
        got = lines[i] if i < len(lines) else None
        check(label, got == expected, f"got={got!r}")


def test_input_events_lua():
    print("\n[1i] input_events_lua: SDL 마우스 이벤트가 Lua 의 Input 에 보이는가")
    _, result, _ = run_scene("input_events_scene.lua", [], 600,
                             extra_env={"INITIAL2D_TEST_EVENTS": INPUT_EVENTS})
    check_input_events_run(result)


def test_input_events_mruby():
    print("\n[1i-m] input_events_mruby: 같은 이벤트를 Ruby 의 Input 으로")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다 (brew install mruby 후 cmake 다시 실행)")
        return
    _, result, _ = run_scene("mruby_input_events_scene.rb", [], 600,
                             extra_env={"INITIAL2D_TEST_EVENTS": INPUT_EVENTS})
    check_input_events_run(result)


def test_mruby_units():
    """tests/ruby/ 의 mruby 단위 테스트를 엔진 바이너리로 실행한다 (S1)."""
    print("\n[0m] mruby_unit_tests — mruby 단위 테스트 (엔진 VM에서 실행)")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다 (brew install mruby 후 cmake 다시 실행)")
        return
    work = new_workdir("initial2d-mrbtest-")
    os.symlink(os.path.join(REPO, "resources"), os.path.join(work, "resources"))
    shutil.copytree(os.path.join(REPO, "tests", "fixtures"),
                    os.path.join(work, "fixtures"))
    scripts = stage_scripts(work)
    rbtests = os.path.join(scripts, "ruby", "rbtests")
    shutil.copytree(os.path.join(REPO, "tests", "ruby"), rbtests)
    shutil.move(os.path.join(rbtests, "run_tests.rb"),
                os.path.join(scripts, "ruby", "main.rb"))

    env = dict(os.environ)
    env["INITIAL2D_SCRIPT"] = "mruby"   # 명시 선택 경로. 자동 감지는 .rb 씬 테스트가 본다
    env["INITIAL2D_EXIT_AFTER"] = "10"  # System.exit 미동작 시의 안전망

    result = subprocess.run([GAME], cwd=work, env=env,
                            capture_output=True, text=True, timeout=60)
    log = result.stdout + result.stderr
    for line in log.splitlines():
        if line.startswith(("  PASS", "  FAIL", "[")):
            print("   " + line)

    check("mruby 테스트 프로세스 정상 종료", result.returncode == 0,
          f"rc={result.returncode} | {log[-300:]}")
    m = re.search(r"MRUBY_TESTS_RESULT: (\d+) PASS / (\d+) FAIL", log)
    check("mruby 테스트 결과 요약 존재", m is not None, log[-300:])
    if m:
        check("mruby 테스트 전부 통과",
              int(m.group(2)) == 0 and int(m.group(1)) > 0,
              f"{m.group(1)} PASS / {m.group(2)} FAIL")


def test_mruby_flappy_scene():
    """mruby 로 쓴 플래피 (scripts/ruby/games/flappy.rb) 가 자동 시연으로 실제로 돈다 (S1).

    씬이 스스로 틱을 세어 끝내므로 헤드리스의 프레임 속도와 무관하다. 검증은
    stdout 의 상태 전이(ready -> play)와 점수, 그리고 화면이 비어 있지 않은가.
    """
    print("\n[1f] mruby_flappy_scene — mruby 로 쓴 플래피가 자동 시연으로 돈다")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다 (brew install mruby 후 cmake 다시 실행)")
        return
    # 헤드리스는 초당 1000프레임 가까이 돌아 EXIT_AFTER 는 안전망으로만 (씬이 420틱에 끝낸다)
    work, result, shots = run_scene("mruby_flappy_scene.rb", [150], 60000,
                                    {"INITIAL2D_AUTOPLAY": "1"})
    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode} | {log[-300:]}")
    check("스크립트 오류 없음", "error" not in log.lower().replace("iccp", ""), log[-300:])
    check("대기에서 시작한다", "flappy:state:ready" in log, log[-300:])
    check("자동 시연이 플레이로 들어간다", "flappy:state:play" in log, log[-300:])
    m = re.search(r"flappyFinal state=(\w+) score=(\d+) best=(\d+) ticks=(\d+)", log)
    check("최종 요약 존재 (씬이 스스로 끝냈다)", m is not None, log[-300:])
    if m:
        check("파이프를 하나 이상 지난다 (best >= 1)", int(m.group(3)) >= 1, m.group(0))
    # 씨앗 1의 판: 5점을 내고 파이프에 부딪혀 죽은 뒤 대기로 돌아온다 — 상태 기계가 한 바퀴 돈다
    check("부딪히면 게임 오버", "flappy:state:dead" in log, log[-300:])
    check("게임 오버 뒤 자동으로 다시 대기", log.count("flappy:state:ready") >= 2, log[-300:])
    check("프레임 덤프 생성", 150 in shots)
    if 150 in shots:
        img = shots[150]
        scale = img.width / 768.0
        ground = count_color_in(img, scale, 0, 896 - 64, 768, 896, WHITE, 12, invert=True)
        check("지면이 그려져 있다 (아래 띠가 비어 있지 않다)", ground > 500, f"px={ground}")
        sky = count_color_in(img, scale, 0, 0, 768, 200, WHITE, 12, invert=True)
        check("배경이 그려져 있다", sky > 500, f"px={sky}")
        shutil.copy(os.path.join(work, "shot_0150.bmp"), "/tmp/initial2d_mruby_flappy.bmp")


def test_lua_error_scene():
    """Lua 스크립트 오류가 PANIC(abort, 134)이 아니라 "파일:줄: 메시지" 한 줄과 종료 코드 1로 끝난다.
    mruby 와 같은 무게이며, 에디터(InitialEditor E1)의 콘솔이 그 줄을 링크로 만든다."""
    print("\n[1g] lua_error_scene — Lua 오류는 abort 가 아니라 보고와 종료 코드 1")
    work, result, _ = run_scene("lua_error_scene.lua", [], 600)
    log = result.stdout + result.stderr
    check("종료 코드 1", result.returncode == 1, f"returncode={result.returncode}")
    check("PANIC 이 없다", "PANIC" not in log, log[-300:])
    check("파일:줄: 메시지 한 줄",
          re.search(r"Lua error in update: \./scripts/lua/main\.lua:15: attempt to index a nil value", log) is not None,
          log[-400:])
    check("init 은 돌았다", "lua_error:init" in log, log[-300:])
    shutil.rmtree(work, ignore_errors=True)
HMR_PORT = 5959   # HotReloadServer 가 여는 포트 (AppSDL2.cpp)

HMR_CASES = {
    # 언어: (진입 파일, 처음 파일, 고장 난 파일, 고친 파일, 고장 난 파일의 오류 줄 정규식)
    "lua": (
        os.path.join("scripts", "lua", "main.lua"),
        "function Initialize() print(\"hmr:good:init\") end\n"
        "function Update(elapsed) end\n"
        "function Render() end\n"
        "function Destroy() print(\"hmr:good:destroy\") end\n",
        "function Initialize(\nend\n",
        "local n = 0\n"
        "function Initialize() print(\"hmr:fixed:init\") end\n"
        "function Update(elapsed)\n"
        "  n = n + 1\n"
        "  if n == 10 then print(\"hmr:fixed:tick\") GameExit() end\n"
        "end\n"
        "function Render() end\n"
        "function Destroy() print(\"hmr:fixed:destroy\") end\n",
        r"Lua error in scripts/lua/main\.lua: \./scripts/lua/main\.lua:2: <name> or '\.\.\.' expected near 'end'",
    ),
    "mruby": (
        os.path.join("scripts", "ruby", "main.rb"),
        "def init; puts \"hmr:good:init\"; end\n"
        "def update(elapsed); end\n"
        "def render; end\n"
        "def destroy; puts \"hmr:good:destroy\"; end\n",
        "def init(\nend\n",
        "$n = 0\n"
        "def init; puts \"hmr:fixed:init\"; end\n"
        "def update(elapsed)\n"
        "  $n += 1\n"
        "  if $n == 10 then puts \"hmr:fixed:tick\"; System.exit; end\n"
        "end\n"
        "def render; end\n"
        "def destroy; puts \"hmr:fixed:destroy\"; end\n",
        r"mruby: uncaught exception in scripts/ruby/main\.rb",
    ),
    # 고장 난 파일의 init 이 C++ 예외를 던지는 바인딩을 부른다 (타입이 틀린 맵의 Tilemap.new).
    # 바인딩 경계에서 Ruby 예외가 되어 스크립트 오류와 같게 끝나야 한다.
    "mruby_cpp": (
        os.path.join("scripts", "ruby", "main.rb"),
        "def init; puts \"hmr:good:init\"; end\n"
        "def update(elapsed); end\n"
        "def render; end\n"
        "def destroy; puts \"hmr:good:destroy\"; end\n",
        "def init; Tilemap.new(\"maps/bad.json\"); puts \"hmr:broken:after\"; end\n"
        "def update(elapsed); puts \"hmr:broken:update\"; end\n"
        "def render; end\n"
        "def destroy; puts \"hmr:broken:destroy\"; end\n",
        "$n = 0\n"
        "def init; puts \"hmr:fixed:init\"; end\n"
        "def update(elapsed)\n"
        "  $n += 1\n"
        "  if $n == 10 then puts \"hmr:fixed:tick\"; System.exit; end\n"
        "end\n"
        "def render; end\n"
        "def destroy; puts \"hmr:fixed:destroy\"; end\n",
        r"scripts/ruby/main\.rb:1:in initialize: Json::LogicError: Value is not convertible to Int\. \(RuntimeError\)",
    ),
}

# 언어 말고 더 까는 파일 (경로 -> 내용)
HMR_EXTRA_FILES = {
    "mruby_cpp": {os.path.join("maps", "bad.json"): "{\"version\": \"x\", \"width\": 1}\n"},
}


def run_hot_reload_error(lang):
    """핫 리로드 서버로 고장 난 파일, 고친 파일을 차례로 보내고 로그와 종료 코드를 본다."""
    sys.path.insert(0, os.path.join(REPO, "tools"))
    from hmr_push import push   # tools/hmr_push.py 와 같은 프로토콜

    entry, good, broken, fixed, error_re = HMR_CASES[lang]
    work = new_workdir("initial2d-hmr-")
    os.makedirs(os.path.join(work, os.path.dirname(entry)))
    with open(os.path.join(work, entry), "w", encoding="utf-8") as fp:
        fp.write(good)
    for rel, text in HMR_EXTRA_FILES.get(lang, {}).items():
        os.makedirs(os.path.join(work, os.path.dirname(rel)), exist_ok=True)
        with open(os.path.join(work, rel), "w", encoding="utf-8") as fp:
            fp.write(text)
    sources = {}
    for name, text in (("broken", broken), ("fixed", fixed)):
        sources[name] = os.path.join(work, f"push_{name}")
        with open(sources[name], "w", encoding="utf-8") as fp:
            fp.write(text)

    env = dict(os.environ)
    env["INITIAL2D_HMR"] = "1"
    env["INITIAL2D_EXIT_AFTER"] = "100000"   # 안전망. 고친 스크립트가 10 틱에 스스로 끝낸다
    proc = subprocess.Popen([GAME], cwd=work, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    lines = []

    def pump():
        for line in proc.stdout:
            lines.append(line.rstrip("\n"))

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()

    def wait_for(pattern, timeout=15.0):
        end = time.time() + timeout
        while time.time() < end:
            if any(re.search(pattern, l) for l in lines):
                return True
            if proc.poll() is not None and not reader.is_alive():
                break
            time.sleep(0.05)
        return any(re.search(pattern, l) for l in lines)

    try:
        if not wait_for(r"HotReload: listening on 127\.0\.0\.1:%d" % HMR_PORT):
            # 포트를 다른 프로세스가 쓰고 있으면 이 프로세스로 보낸다는 보장이 없어 보내지 않는다
            print(f"  SKIP: 핫 리로드 서버가 {HMR_PORT} 을 열지 못했습니다 | {' / '.join(lines[-3:])}")
            return None
        check(f"[{lang}] 처음 스크립트가 돈다", wait_for(r"hmr:good:init"), " / ".join(lines[-5:]))

        push("127.0.0.1", HMR_PORT, [(entry.replace(os.sep, "/"), sources["broken"])])
        check(f"[{lang}] 고장 난 파일: 시작 때와 같은 형식의 오류 줄", wait_for(error_re), " / ".join(lines[-5:]))
        check(f"[{lang}] 고장 난 파일: 리로드 실패 줄",
              wait_for(r"HotReload: reload failed with 1 files \(script error\)"), " / ".join(lines[-5:]))
        check(f"[{lang}] 이전 VM 의 destroy 훅이 불린다", "hmr:good:destroy" in lines, " / ".join(lines[-5:]))
        time.sleep(0.5)
        check(f"[{lang}] 고장 난 파일 뒤에도 게임은 돈다", proc.poll() is None, f"rc={proc.poll()}")
        check(f"[{lang}] 고장 난 파일 뒤에는 스크립트가 멈춘다 (update 없음)",
              not any(l.startswith("hmr:broken:") for l in lines), " / ".join(lines[-5:]))

        push("127.0.0.1", HMR_PORT, [(entry.replace(os.sep, "/"), sources["fixed"])])
        check(f"[{lang}] 고친 파일: 리로드 성공 줄", wait_for(r"HotReload: reloaded with 1 files"), " / ".join(lines[-5:]))
        check(f"[{lang}] 고친 스크립트의 init", wait_for(r"hmr:fixed:init"), " / ".join(lines[-5:]))
        check(f"[{lang}] 고친 스크립트의 Update 가 돈다", wait_for(r"hmr:fixed:tick"), " / ".join(lines[-5:]))
        try:
            rc = proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            rc = None
        check(f"[{lang}] 정상 종료 (종료 코드 0)", rc == 0, f"rc={rc} | {' / '.join(lines[-5:])}")
        return lines
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        reader.join(timeout=5)
        shutil.rmtree(work, ignore_errors=True)


def test_hot_reload_error():
    """핫 리로드(INITIAL2D_HMR=1)로 스크립트 오류가 든 파일을 받으면 시작 때와 같은 형식의 오류 줄을 찍고
    게임은 스크립트만 멈춘 채 산다. 고친 파일을 받으면 새 VM 이 돌고, 게임이 스스로 끝내면 종료 코드는 0 이다.
    브라우저의 reload() 와 같은 동작이다 (R3, docs/plans/r3-emscripten.md 8절). 시작 때와 Update 의 오류는
    전처럼 게임을 끝낸다 (test_lua_error_scene)."""
    print("\n[1h] hot_reload_error — 핫 리로드의 스크립트 오류는 게임을 끝내지 않고, 고친 파일로 되살아난다")
    run_hot_reload_error("lua")
    if HAS_MRUBY:
        run_hot_reload_error("mruby")
        run_hot_reload_error("mruby_cpp")
    else:
        print("  SKIP (mruby): 이 빌드에는 mruby 가 없습니다")


MRUBY_DEFINE_RE = re.compile(r"mrb_define_(?:method|module_function|class_method|singleton_method)\s*\(([^;]*)\)\s*;")


def test_mruby_binding_guard():
    """mruby 바인딩을 등록하는 mrb_define_* 가 전부 MRUBY_GUARD(함수) 를 넘기는가 (src/mrb_*.cpp).
    MRUBY_GUARD 가 C++ 예외를 Ruby 예외로 바꾼다. 빠진 바인딩이 C++ 예외를 던지면 VM 의 C 프레임을
    지나가며 네이티브는 abort 하고, 브라우저는 반쯤 풀린 VM 을 계속 쓴다 (mrb_prot.h)."""
    print("\n[0g] mruby_binding_guard: 모든 mruby 바인딩이 C++ 예외를 Ruby 예외로 바꾸는 래퍼를 거친다")
    src = os.path.join(REPO, "src")
    total = 0
    unguarded = []
    for name in sorted(os.listdir(src)):
        if not (name.startswith("mrb_") and name.endswith(".cpp")):
            continue
        with open(os.path.join(src, name), encoding="utf-8") as fp:
            text = fp.read()
        for m in MRUBY_DEFINE_RE.finditer(text):
            total += 1
            if "MRUBY_GUARD(" not in m.group(1):
                line = text.count("\n", 0, m.start()) + 1
                unguarded.append(f"{name}:{line}")
    check("mrb_define_* 호출을 찾았다", total > 50, f"{total}개")
    check("전부 MRUBY_GUARD 를 거친다", not unguarded, ", ".join(unguarded[:10]))


MRUBY_CPP_EXCEPTION_SCENE = """\
$n = 0
def init
  begin
    Tilemap.new("maps/bad.json")
    puts "cpp:not raised"
  rescue => e
    puts "cpp:rescued #{e.class}: #{e.message}"
  end
  puts "cpp:load #{Tilemap.load("maps/bad.json").inspect}"
end
def update(elapsed)
  $n += 1
  Tilemap.new("maps/bad.json") if $n == 3
end
def render; end
def destroy; puts "cpp:destroy"; end
"""


def test_mruby_cpp_exception():
    """바인딩 안에서 난 C++ 예외(타입이 틀린 맵의 Json::LogicError)가 바인딩 경계에서 Ruby 의 RuntimeError 가 된다.
    rescue 로 잡히고 Tilemap.load 는 nil 이다. 잡지 않으면 스크립트 오류와 같은 줄 묶음과 종료 코드 1 이다
    (abort 가 아니다). 브라우저도 같다 (tools/web_smoke.mjs 15)."""
    print("\n[1c] mruby_cpp_exception: 바인딩의 C++ 예외는 Ruby 예외가 된다 (rescue, 잡히지 않으면 종료 코드 1)")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다")
        return
    work = new_workdir("initial2d-cppexc-")
    try:
        os.makedirs(os.path.join(work, "scripts", "ruby"))
        os.makedirs(os.path.join(work, "maps"))
        with open(os.path.join(work, "scripts", "ruby", "main.rb"), "w", encoding="utf-8") as fp:
            fp.write(MRUBY_CPP_EXCEPTION_SCENE)
        with open(os.path.join(work, "maps", "bad.json"), "w", encoding="utf-8") as fp:
            fp.write('{"version": "x", "width": 1}\n')
        env = dict(os.environ)
        env["INITIAL2D_EXIT_AFTER"] = "60"
        result = subprocess.run([GAME], cwd=work, env=env, capture_output=True, text=True, timeout=60)
        log = result.stdout + result.stderr
        check("rescue 가 RuntimeError 로 잡는다 (타입: 메시지)",
              "cpp:rescued RuntimeError: Json::LogicError: Value is not convertible to Int." in log, log[-400:])
        check("Tilemap.load 는 nil", "cpp:load nil" in log, log[-400:])
        err = result.stderr.splitlines()
        block = [
            "mruby: uncaught exception in update",
            "trace (most recent call last):",
            "\t[2] scripts/ruby/main.rb:16",
            "\t[1] scripts/ruby/main.rb:13:in update",
            "scripts/ruby/main.rb:13:in initialize: Json::LogicError: Value is not convertible to Int. (RuntimeError)",
        ]
        found = any(err[i:i + len(block)] == block for i in range(len(err)))
        check("잡히지 않으면 스크립트 오류와 같은 줄 묶음", found, " / ".join(err[-6:]))
        check("종료 코드 1 (abort 가 아니다)", result.returncode == 1, f"rc={result.returncode}")
        check("오류 뒤 destroy 훅은 불리지 않는다", "cpp:destroy" not in log, log[-300:])
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check_flappy_run(work, result, shots, keep_as):
    """플래피 자동 시연 한 판의 검사. test_mruby_flappy_scene 과 같은 항목이다 (R1 의 씬 판이
    같은 검사를 그대로 통과해야 하므로 여기 한 벌 더 두었다. 원래 테스트는 손대지 않는다)."""
    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode} | {log[-300:]}")
    check("스크립트 오류 없음", "error" not in log.lower().replace("iccp", ""), log[-300:])
    check("대기에서 시작한다", "flappy:state:ready" in log, log[-300:])
    check("자동 시연이 플레이로 들어간다", "flappy:state:play" in log, log[-300:])
    m = re.search(r"flappyFinal state=(\w+) score=(\d+) best=(\d+) ticks=(\d+)", log)
    check("최종 요약 존재 (씬이 스스로 끝냈다)", m is not None, log[-300:])
    if m:
        check("파이프를 하나 이상 지난다 (best >= 1)", int(m.group(3)) >= 1, m.group(0))
        check("900틱에 끝낸다", int(m.group(4)) == 900, m.group(0))
    check("부딪히면 게임 오버", "flappy:state:dead" in log, log[-300:])
    check("게임 오버 뒤 자동으로 다시 대기", log.count("flappy:state:ready") >= 2, log[-300:])
    check("프레임 덤프 생성", 150 in shots)
    if 150 in shots:
        img = shots[150]
        scale = img.width / 768.0
        ground = count_color_in(img, scale, 0, 896 - 64, 768, 896, WHITE, 12, invert=True)
        check("지면이 그려져 있다 (아래 띠가 비어 있지 않다)", ground > 500, f"px={ground}")
        sky = count_color_in(img, scale, 0, 0, 768, 200, WHITE, 12, invert=True)
        check("배경이 그려져 있다", sky > 500, f"px={sky}")
        shutil.copy(os.path.join(work, "shot_0150.bmp"), keep_as)


def test_scene_flappy_lua():
    """플래피를 씬 파일과 컴포넌트로 다시 만든 것(resources/scenes/flappy.json + scripts/lua/components/flappy/)
    이 씬 로더로 부팅해 자동 시연으로 돈다 (R1). 검사는 mruby_flappy_scene 과 같다."""
    print("\n[1s] scene_flappy_lua: 씬 로더로 연 플래피(Lua 컴포넌트)가 자동 시연으로 돈다")
    work, result, shots = run_scene("scene_flappy_scene.lua", [150], 60000,
                                    {"INITIAL2D_AUTOPLAY": "1", "INITIAL2D_SCENE": "flappy"})
    check_flappy_run(work, result, shots, "/tmp/initial2d_scene_flappy_lua.bmp")


def test_scene_flappy_mruby():
    """같은 씬 파일을 Ruby 컴포넌트(scripts/ruby/components/flappy/)로 (R1)."""
    print("\n[1s-m] scene_flappy_mruby: 씬 로더로 연 플래피(Ruby 컴포넌트)가 자동 시연으로 돈다")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다 (brew install mruby 후 cmake 다시 실행)")
        return
    work, result, shots = run_scene("mruby_scene_flappy_scene.rb", [150], 60000,
                                    {"INITIAL2D_AUTOPLAY": "1", "INITIAL2D_SCENE": "flappy"})
    check_flappy_run(work, result, shots, "/tmp/initial2d_scene_flappy_mruby.bmp")


# 씬 로더 픽스처의 label 위치 (tests/fixtures/scenes/sample_v1.json). 샘플 맵의 장식 레이어가
# 비어 있는 띠(y 816..880)라 글자가 가려지지 않는다.
LABEL_X, LABEL_Y = 96, 816


def check_scene_loader_run(work, result, shots, keep_as):
    """씬 로더 픽스처 씬의 검사. 두 언어가 같은 stdout 형식과 같은 골든(scene_loader)을 쓴다."""
    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode} | {log[-300:]}")
    check("스크립트 오류 없음", "error" not in log.lower().replace("iccp", ""), log[-300:])
    check("픽스처의 name", "scene:name:sample" in log, log[-300:])
    check("오브젝트 순서 = 파일 순서", "scene:order:map,tile,anim,mover,label" in log, log[-300:])
    check("루트의 모르는 키를 보존한다", "scene:editorOnly:보존" in log, log[-300:])
    check("오브젝트의 모르는 키를 보존한다", "scene:tileEditorOnly:true" in log, log[-300:])
    check("width 0 은 이미지 전체 (tile1.png 48x48)", "scene:tile:96,400 frame 48x48" in log, log[-300:])
    check("tilemap 이 두 레이어로 열렸다", "scene:map:layers 2" in log, log[-300:])
    check("anim 은 startFrame 1 (눌린 버튼) 에 멈춰 있다", "scene:anim:frame 1" in log, log[-300:])
    check("첫 틱에 mover 가 tile 을 102 옮겼다", "scene:tick1:tile.x=198" in log, log[-300:])
    check("둘째 틱에 limit 300 에서 멈춘다", "scene:tick2:tile.x=300" in log, log[-300:])
    check("끝까지 300 에 머문다", "scene:final:tile.x=300" in log, log[-300:])
    check("close 뒤 닫힘", "scene:closed:true" in log, log[-300:])
    check("프레임 덤프 생성", 150 in shots)
    if 150 in shots:
        img = shots[150]
        scale = img.width / 768.0
        # 맵(잔디)이 화면을 채운다: 왼쪽 위 구역에 흰색 아닌 픽셀이 대부분 (count_color_in 은 2px 걸러 센다)
        grass = count_color_in(img, scale, 0, 0, 200, 150, WHITE, 12, invert=True)
        check("타일맵이 그려져 있다", grass > 200 * 150 / 4 * 0.9, f"px={grass}")
        # 글자(흰 글리프)가 label 자리에 있다 (두 줄이면 표본 150개 이상, 한 줄이면 그 절반쯤)
        glyphs = count_color_in(img, scale, LABEL_X, LABEL_Y, LABEL_X + 400, LABEL_Y + 70, WHITE, 40)
        check("글자가 그려져 있다 (두 줄)", glyphs > 150, f"px={glyphs}")
        check_golden("scene_loader", img)
        shutil.copy(os.path.join(work, "shot_0150.bmp"), keep_as)


def test_scene_loader_lua():
    """씬 포맷 v1 픽스처(tests/fixtures/scenes/sample_v1.json)를 Lua 씬 로더로 열어 그린다 (R1)."""
    print("\n[1r] scene_loader_lua: 픽스처 씬을 Lua 씬 로더로 열어 타입 넷을 그린다")
    work, result, shots = run_scene("scene_loader_scene.lua", [150], 240, fixtures=True)
    check_scene_loader_run(work, result, shots, "/tmp/initial2d_scene_loader_lua.bmp")


def test_scene_loader_mruby():
    """같은 픽스처를 Ruby 씬 로더로. 같은 골든에 견준다 (R1)."""
    print("\n[1r-m] scene_loader_mruby: 픽스처 씬을 Ruby 씬 로더로 열어 같은 골든에 견준다")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다 (brew install mruby 후 cmake 다시 실행)")
        return
    work, result, shots = run_scene("mruby_scene_loader_scene.rb", [150], 240, fixtures=True)
    check_scene_loader_run(work, result, shots, "/tmp/initial2d_scene_loader_mruby.bmp")


# 씬 로더 params 픽스처(tests/fixtures/scenes/params_v1.json)의 stdout. 두 언어가 같은 줄을 찍어야 한다
# (r1-scene-loader.md 5.4절). 선언의 기본값, 덮어쓴 값, 한 오브젝트의 두 컴포넌트, 선언이 없는 컴포넌트,
# params 로 움직인 오브젝트, 훅에 넘어간 값, 검증 오류의 문장.
SCENE_PARAMS_LINES = [
    "params:order:plain,custom,pair,loose,old,mark",
    'params:plain:count=3 enabled=true kind="ground" speed=1.5 title="제목"',
    'params:custom:count=7 enabled=false kind="pipes" note="첫 줄\\n둘째 줄" speed=2.5 target="mark" title="바뀐 제목"',
    'params:pair:count=1 enabled=true kind="ground" speed=1.5 title="제목"',
    "params:probes:pair=1",
    'params:loose:list=[1,2] nested={a=1} word="그대로"',
    "params:separate:true",
    "params:error:scene: params 'components/sample/probe': kind must be one of ground, pipes (custom)",
    "params:tick1:mark=3,5",
    "params:tick2:mark=6,10",
    "params:tick3:mark=9,15",
    "params:hooks:destroy=바뀐 제목,init=바뀐 제목,render=바뀐 제목,update=바뀐 제목",
    "params:closed:true",
]


def check_scene_params_run(result):
    """params 픽스처 씬의 검사. 두 언어가 같은 줄을 같은 순서로 찍는다."""
    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode} | {log[-300:]}")
    check("스크립트 오류 없음", "error in" not in log.lower() and "uncaught" not in log.lower(), log[-300:])
    lines = [line for line in result.stdout.splitlines() if line.startswith("params:")]
    for want in SCENE_PARAMS_LINES:
        check(f"stdout: {want}", want in lines, " / ".join(lines)[-400:])
    check("params 줄이 이 순서로 이것뿐이다", lines == SCENE_PARAMS_LINES, " / ".join(lines)[-400:])


def test_scene_params_lua():
    """컴포넌트 params (선언 파일, 기본값, 덮어쓰기, 검사)를 Lua 씬 로더로 (r1 5.4절)."""
    print("\n[1p] scene_params_lua: params 픽스처 씬을 Lua 씬 로더로 열어 컴포넌트가 받은 값을 본다")
    _, result, _ = run_scene("scene_params_scene.lua", [], 6000, fixtures=True)
    check_scene_params_run(result)


def test_scene_params_mruby():
    """같은 픽스처를 Ruby 씬 로더로. new(params) 클래스, 모듈 경로 클래스, 인자 없는 클래스가 섞여 있다."""
    print("\n[1p-m] scene_params_mruby: 같은 params 픽스처를 Ruby 씬 로더로, 같은 줄을 찍는다")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다 (brew install mruby 후 cmake 다시 실행)")
        return
    _, result, _ = run_scene("mruby_scene_params_scene.rb", [], 6000, fixtures=True)
    check_scene_params_run(result)


def test_lua_units():
    """tests/lua/ 의 Lua 단위 테스트를 엔진 바이너리로 실행한다 (09-testing.md 3.2절)."""
    print("\n[0] lua_unit_tests — Lua 단위 테스트 (엔진 VM에서 실행)")
    work = new_workdir("initial2d-luatest-")
    os.symlink(os.path.join(REPO, "resources"), os.path.join(work, "resources"))
    # 포맷 계약 픽스처 (09-testing.md 3.5절) — 에디터 저장소와 공유하는 파일
    shutil.copytree(os.path.join(REPO, "tests", "fixtures"),
                    os.path.join(work, "fixtures"))
    # 테스트 대상은 저자의 scripts/ 전부다 (main.lua만 러너로 갈아 끼운다)
    scripts = stage_scripts(work)
    luatests = os.path.join(scripts, "lua", "luatests")
    shutil.copytree(os.path.join(REPO, "tests", "lua"), luatests)
    shutil.move(os.path.join(luatests, "run_tests.lua"),
                os.path.join(scripts, "lua", "main.lua"))

    env = dict(os.environ)
    env["INITIAL2D_EXIT_AFTER"] = "10"  # GameExit() 미동작 시의 안전망

    result = subprocess.run([GAME], cwd=work, env=env,
                            capture_output=True, text=True, timeout=60)
    log = result.stdout + result.stderr
    for line in log.splitlines():
        if line.startswith(("  PASS", "  FAIL", "[")):
            print("   " + line)

    check("Lua 테스트 프로세스 정상 종료", result.returncode == 0,
          f"rc={result.returncode}")
    import re
    m = re.search(r"LUA_TESTS_RESULT: (\d+) PASS / (\d+) FAIL", log)
    check("Lua 테스트 결과 요약 존재", m is not None, log[-300:])
    if m:
        check("Lua 테스트 전부 통과",
              int(m.group(2)) == 0 and int(m.group(1)) > 0,
              f"{m.group(1)} PASS / {m.group(2)} FAIL")


FENCE_BROWN = (128, 88, 88)    # 울타리·바위 밝은 갈색
POND_TEAL = (112, 192, 160)    # 연못 내부 밝은 청록
POND_SAND = (216, 200, 128)    # 연못 모래 테두리
GRASS_BASE = (64, 176, 128)    # 잔디 기본색


def test_tilemap_scene():
    """새 Tilemap API (C++ 렌더러): 샘플 맵 80x70, 카메라 오프셋과 컬링.

    같은 씬을 카메라 고정값만 바꿔 두 번 실행한다 (INITIAL2D_TEST_CAM).
    """
    print("\n[2] tilemap_scene — Tilemap.* API (샘플 맵, 카메라 오프셋, 컬링)")

    # [A] 카메라 (0,0): 좌상단 — 외곽 울타리 윗줄과 연못 (8,6)
    work, result, shots = run_scene("tilemap_scene.lua", [30], 40)
    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-200:])
    check("맵 로드와 크기", "tilemapSize:80x70 tile:16x16 layers:2" in log, log[:300])
    check("IsPassable 잔디=true", "passableGrass:true" in log)
    check("IsPassable 울타리=false", "passableFence:false" in log)
    check("IsPassable 범위 밖=false", "passableOut:false" in log)
    check("GetTileId 울타리 gid=73", "fenceGid:73" in log)
    check("좌상단 프레임 덤프 생성", 30 in shots)

    if 30 in shots:
        img = shots[30]
        scale = img.width / 768.0
        fence = count_color_in(img, scale, 150, 32, 760, 48, FENCE_BROWN)
        check("좌상단: 외곽 울타리 갈색 픽셀", fence > 150, f"px={fence}")
        teal = count_color_in(img, scale, 128, 96, 160, 128, POND_TEAL)
        sand = count_color_in(img, scale, 128, 96, 160, 128, POND_SAND)
        check("좌상단: 연못(8,6) 내부 청록", teal > 15, f"px={teal}")
        check("좌상단: 연못(8,6) 모래 테두리", sand > 10, f"px={sand}")
        grass = count_color_in(img, scale, 296, 296, 360, 360, GRASS_BASE)
        check("좌상단: 잔디 기본색 영역", grass > 300, f"px={grass}")
        check_golden("tilemap_scene_topleft", img)
        shutil.copy(os.path.join(work, "shot_0030.bmp"), "/tmp/initial2d_tilemap_topleft.bmp")

    # [B] 카메라 우하단 끝 (512,224): 오른쪽·아래 울타리와 연못 (60,52) — 컬링 검증
    work2, result2, shots2 = run_scene("tilemap_scene.lua", [30], 40,
                                       extra_env={"INITIAL2D_TEST_CAM": "bottomright"})
    log2 = result2.stdout + result2.stderr
    check("우하단 실행 정상 종료", result2.returncode == 0, f"rc={result2.returncode}")
    check("우하단 프레임 덤프 생성", 30 in shots2)

    if 30 in shots2:
        img2 = shots2[30]
        scale2 = img2.width / 768.0
        rfence = count_color_in(img2, scale2, 720, 272, 736, 304, FENCE_BROWN)
        check("우하단: 오른쪽 울타리 기둥", rfence > 10, f"px={rfence}")
        bfence = count_color_in(img2, scale2, 200, 848, 700, 864, FENCE_BROWN)
        check("우하단: 아래 울타리", bfence > 150, f"px={bfence}")
        teal2 = count_color_in(img2, scale2, 448, 608, 480, 640, POND_TEAL)
        check("우하단: 연못(60,52) 내부 청록", teal2 > 15, f"px={teal2}")
        check_golden("tilemap_scene_bottomright", img2)
        shutil.copy(os.path.join(work2, "shot_0030.bmp"), "/tmp/initial2d_tilemap_bottomright.bmp")

    # [C] 렌더 배율 2: 창 크기는 그대로고 논리 해상도가 절반이라 같은 내용이 2배로
    #     그려진다. 맵 3번째 줄의 울타리(월드 y 32..48)가 화면 y 64..96으로 내려온다.
    _, result3, shots3 = run_scene("tilemap_scene.lua", [30], 40,
                                   extra_env={"INITIAL2D_SCALE": "2"})
    check("배율 2 실행 정상 종료", result3.returncode == 0, f"rc={result3.returncode}")
    if 30 in shots3:
        img3 = shots3[30]
        s3 = img3.width / 768.0
        doubled = count_color_in(img3, s3, 300, 64, 760, 96, FENCE_BROWN)
        original = count_color_in(img3, s3, 300, 32, 760, 48, FENCE_BROWN)
        check("배율 2: 울타리가 2배 위치(y 64~96)에 그려진다", doubled > 150, f"px={doubled}")
        check("배율 2: 원래 위치(y 32~48)에는 울타리가 없다", original == 0, f"px={original}")


# 플레이스홀더 CharSet(tools/generate_charset.py)의 색. 맵 팔레트와 겹치지 않는
# 색을 골라 두었기 때문에 색 카운트만으로 캐릭터를 특정할 수 있다.
HAIR_PURPLE = (168, 96, 200)   # 3번 캐릭터 머리
HAIR_BROWN = (96, 56, 32)      # 데모 주인공(0번 캐릭터) 머리
HOUSE_WALL = (214, 188, 150)   # 집 벽 (village16.png의 벽 타일)
SHIRT_WHITE = (236, 236, 240)  # 3번 캐릭터 옷
SHIRT_RED = (206, 62, 62)      # 0번 캐릭터 옷


def test_rpg_walk_scene():
    """캐릭터 렌더링: 레이어 사이 그리기, 보간 좌표, 걷기 자세 (5단계).

    같은 캐릭터를 두 곳에 세운다. (12,12)는 가림 없는 잔디, (5,3)은 위 칸이
    상층 울타리다. 머리색 픽셀 수를 비교하면 "캐릭터가 상층 타일 뒤로 지나간다"를
    눈이 아니라 숫자로 확인할 수 있다.
    """
    print("\n[5] rpg_walk_scene — 캐릭터 렌더링과 레이어 분할 그리기")
    work, result, shots = run_scene("rpg_walk_scene.lua", [20], 30)

    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-300:])
    check("맵 로드", "rpgMap:80x70 layers:2" in log, log[:300])
    # 픽셀 좌표: 프레임(24x32)이 타일(16x16)보다 커서 가로는 가운데, 세로는 발을 맞춘다
    check("기준 캐릭터 좌표와 프레임", "rpgRef:188,176 frame:34" in log, log[:400])
    check("가려질 캐릭터 좌표와 프레임", "rpgHid:76,32 frame:34" in log, log[:400])
    check("이동 중 캐릭터의 보간 좌표", "rpgWalk:260,176 frame:14 moving:true" in log,
          log[:400])
    check("반 칸 오프셋", "rpgWalkOffset:-8.0" in log, log[:400])
    check("y정렬 순서 (위쪽 캐릭터부터)", "rpgOrder:hid,ref,walk" in log, log[:400])
    check("카메라 좌상단 고정", "rpgCamera:0,0" in log, log[:400])
    check("프레임 덤프 생성", 20 in shots)

    if 20 not in shots:
        return

    img = shots[20]
    scale = img.width / 768.0

    # [A] 가림 없는 캐릭터: 머리색이 보인다 (머리 타원은 프레임 안 (6,3)~(17,15))
    ref_hair = count_color_in(img, scale, 194, 179, 206, 192, HAIR_PURPLE)
    check("기준 캐릭터의 머리색 픽셀", ref_hair > 6, f"px={ref_hair}")
    ref_shirt = count_color_in(img, scale, 196, 192, 204, 200, SHIRT_WHITE, 12)
    check("기준 캐릭터의 옷 픽셀", ref_shirt > 3, f"px={ref_shirt}")

    # [B] 상층 울타리 아래 캐릭터: 같은 머리가 가려진다
    hid_hair = count_color_in(img, scale, 82, 35, 94, 48, HAIR_PURPLE)
    check("울타리 뒤 캐릭터의 머리가 가려진다",
          hid_hair * 3 < ref_hair, f"가려짐 {hid_hair} vs 기준 {ref_hair}")
    fence_over = count_color_in(img, scale, 82, 35, 94, 48, FENCE_BROWN)
    check("머리 자리에 상층 울타리가 그려져 있다", fence_over > 3, f"px={fence_over}")
    hid_shirt = count_color_in(img, scale, 84, 49, 92, 57, SHIRT_WHITE, 12)
    check("울타리 아래 몸통은 보인다", hid_shirt > 3, f"px={hid_shirt}")

    # [C] 이동 중 캐릭터: 반 칸(8px) 어긋난 자리에 그려진다
    walk_shirt = count_color_in(img, scale, 268, 191, 276, 201, SHIRT_RED, 20)
    check("이동 중 캐릭터가 보간된 자리에 있다", walk_shirt > 3, f"px={walk_shirt}")
    walk_empty = count_color_in(img, scale, 288, 191, 296, 201, SHIRT_RED, 20)
    check("도착 칸에는 아직 몸통이 없다", walk_empty == 0, f"px={walk_empty}")

    check_golden("rpg_walk_scene", img)
    shutil.copy(os.path.join(work, "shot_0020.bmp"), "/tmp/initial2d_rpg_walk.bmp")


def test_rpg_event_scene():
    """이벤트 시스템 통합: 진짜 맵과 진짜 이벤트 정의로 트리거와 전환 (6단계).

    단위 테스트가 규칙을 보고, 여기서는 좌표와 파일이 실제로 맞물리는지를 본다.
    화면 대신 stdout으로 검증한다 (입력 없이 도는 씬).
    """
    print("\n[6] rpg_event_scene — 이벤트 트리거, 대화 분기, 맵 전환")
    work = make_workdir("rpg_event_scene.lua")
    env = dict(os.environ)
    env["INITIAL2D_EXIT_AFTER"] = "60"
    result = subprocess.run([GAME], cwd=work, env=env,
                            capture_output=True, text=True, timeout=120)
    log = result.stdout + result.stderr

    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-300:])

    def has(needle, name):
        check(name, needle in log, f"'{needle}' 없음 | {log[-400:]}")

    has("village:70x40 events:6", "마을 맵과 이벤트 6개 로드")
    has("playerStart:34,21", "정의 파일의 시작 위치")

    # [A] 병렬 이벤트
    has("busyAfterMapStart:false", "parallel만으로는 조작이 잠기지 않는다")
    has("parallelCount:1", "병렬 이벤트가 등록된다")
    has("patrolMoved:true", "병렬 순찰이 실제로 움직인다")
    has("busyDuringPatrol:false", "순찰이 도는 동안에도 잠기지 않는다")

    # [B] 말 걸기와 분기
    has("actionTarget:elder", "바라보는 칸의 이벤트를 집는다")
    has("confirm:true", "결정키로 실행 시작")
    has("busyWhileTalking:true", "대화 중 조작 잠금")
    has("elderTurned:down", "말을 걸면 이쪽을 돌아본다")
    has("line1:어서 오시게. 처음 보는 얼굴이군.", "첫 대사")
    has("choiceShown:1", "선택지 표시")
    has("line2:왼쪽 집 문으로 들어가면 우리 오두막이라네.", "선택 1번의 분기 대사")
    has("busyAfterTalk:false", "대화가 끝나면 잠금 해제")
    has("stateFlag:true", "스크립트가 남긴 상태가 유지된다")

    # [B2] 상인과 맵을 넘는 상태 (8단계)
    has("merchantTarget:merchant", "상인을 바라보면 상인이 집힌다")
    has("merchantLine1:길이 험하지 않은 마을이지만", "상인의 첫 대사")
    has("merchantChoice:1", "상인이 선택지를 띄운다")
    has("merchantLine2:자, 받게.", "받겠다고 하면 건네준다")
    has("herbFlag:true", "받은 사실이 state에 남는다")
    has("merchantAgain:약초는 잘 챙겨 두시게", "다시 말을 걸면 다른 대사")
    has("merchantChoiceAgain:0", "두 번째에는 선택지가 없다")

    # [C] 문 밟기 → 전환 요청
    has("transfer:room,10,12", "문을 밟으면 전환 요청이 나간다")
    has("busyAfterTransfer:false", "전환 뒤 조작 잠금이 남지 않는다")

    # [D] 맵 교체와 auto
    has("roomLoaded:true", "두 번째 맵 로드")
    has("room:20x14 events:3", "오두막 맵과 이벤트")
    has("autoBusy:true", "auto 이벤트가 맵 진입 시 조작을 잠근다")
    has("autoLine:오두막 안이다. 아래 문으로 나갈 수 있다.", "auto 대사")
    has("busyAfterAuto:false", "auto가 끝나면 잠금 해제")
    has("residentTarget:resident", "오두막 주민을 바라보면 주민이 집힌다")
    has("residentLine:상인 아저씨한테 약초를 받으셨군요",
        "마을에서 남긴 state가 다른 맵의 대사를 바꾼다")
    has("secondVisitLines:0", "두 번째 방문에서는 state를 보고 조용히 넘어간다")


# 플레이스홀더 대화창 스킨(tools/generate_windowskin.py)의 색
SKIN_FRAME_LIGHT = (196, 214, 246)   # 테두리의 밝은 선
SKIN_BG_TOP = (36, 52, 96)           # 창 바탕 (위쪽 띠)
SKIN_ARROW = (232, 240, 255)         # 스크롤·대기 화살표


def parse_rects(log):
    """씬이 stdout으로 알려 준 사각형들 (이름 → (x, y, w, h))."""
    rects = {}
    for line in log.splitlines():
        if line.startswith("dlg") and ":" in line:
            name, _, value = line.partition(":")
            parts = value.split(",")
            if len(parts) == 4 and all(p.strip().lstrip("-").isdigit() for p in parts):
                rects[name] = tuple(int(p) for p in parts)
    return rects


def mean_luma(img, scale, x0, y0, x1, y1):
    total, n = 0, 0
    for yy in range(int(y0 * scale), int(y1 * scale), 2):
        for xx in range(int(x0 * scale), int(x1 * scale), 2):
            r, g, b = img.getpixel((xx, yy))
            total += r + g + b
            n += 1
    return total / max(1, n)


def test_rpg_dialogue_scene():
    """대화창 렌더링: 스킨 조립, 얼굴, 이름 창, 선택 커서 (7단계).

    창의 위치와 크기는 씬이 stdout으로 알려 준다 (Lua가 계산한 값). 그래서 배치
    규칙이 바뀌어도 러너를 고칠 필요 없이, "그 사각형 안에 무엇이 그려졌는가"만
    본다. 스킨은 커밋된 플레이스홀더라 RTP 없이도 돈다.
    """
    print("\n[7] rpg_dialogue_scene — 대화창 스킨, 타자 효과, 얼굴, 선택지")
    work, result, shots = run_scene("rpg_dialogue_scene.lua", [20], 30)

    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-300:])
    check("폰트 로드", "dlgFont:true" in log, log[:200])
    check("스킨 배율 2로 조립", "scale:2" in log, log[:200])

    # [A] 쪽 나눔과 타자 효과 (프레임당 3글자)
    check("긴 대사가 두 쪽으로 나뉜다", "dlgPages:2" in log, log[:400])
    check("처음에는 한 글자도 안 나온다", "dlgReveal0:0" in log)
    check("한 프레임에 3글자", "dlgReveal1:3" in log and "dlgReveal2:6" in log, log[:400])
    check("보이는 글자는 앞에서부터", "dlgVisible:어서 오시게" in log, log[:400])
    check("결정키가 남은 글자를 즉시 보여 준다", "dlgRevealAll:true" in log)
    check("그 누름으로 창이 닫히지는 않는다", "dlgBusy:true" in log)
    check("선택지가 떠 있다", "dlgChoiceActive:true" in log)
    check("줄바꿈된 첫 줄", "dlgLine1:어서 오시게. 처음 보는 얼굴이군. 이 마을은" in log,
          log[:600])

    if 20 not in shots:
        check("프레임 덤프 생성", False, "스크린샷 없음")
        return
    check("프레임 덤프 생성", True)

    img = shots[20]
    scale = img.width / 768.0
    rects = parse_rects(log)
    for name in ("dlgMsgRect", "dlgFaceRect", "dlgTextRect", "dlgNameRect",
                 "dlgChoiceRect", "dlgChoiceRow1", "dlgChoiceRow2"):
        if name not in rects:
            check(f"{name} 좌표 출력", False, log[:400])
            return

    # [B] 창틀: 테두리의 밝은 선이 창 위쪽에 있다 (스킨 y=1 → 배율 2로 창의 2~3픽셀)
    mx, my, mw, mh = rects["dlgMsgRect"]
    border = count_color_in(img, scale, mx + 40, my + 2, mx + mw - 40, my + 4,
                            SKIN_FRAME_LIGHT, 20)
    check("대화창 위 테두리(밝은 선)", border > 80, f"px={border}")
    side = count_color_in(img, scale, mx + 2, my + 40, mx + 4, my + mh - 40,
                          SKIN_FRAME_LIGHT, 20)
    check("대화창 왼쪽 테두리", side > 20, f"px={side}")

    # 바탕: 창 안쪽(글자가 없는 오른쪽 아래)은 스킨 바탕색 계열
    inside = px(img, scale, mx + mw - 14, my + mh - 14)
    check("창 안쪽은 스킨 바탕색", inside[2] > inside[0] and 20 <= inside[2] <= 120,
          str(inside))

    # [C] 글자: 텍스트 영역에 흰 글리프가 있다
    tx, ty, tw, th = rects["dlgTextRect"]
    glyphs = count_color_in(img, scale, tx, ty, tx + tw, ty + th, WHITE, 30)
    check("대사 글자가 그려진다", glyphs > 150, f"white px={glyphs}")

    # [D] 얼굴: 얼굴 칸에 창 바탕이 아닌 색(피부·머리)이 있다
    fx, fy, fw, fh = rects["dlgFaceRect"]
    face = count_color_in(img, scale, fx + 8, fy + 8, fx + fw - 8, fy + fh - 8,
                          SKIN_BG_TOP, 40, invert=True)
    check("얼굴 그림이 창 왼쪽에 그려진다", face > 100, f"px={face}")
    # 글자 영역은 얼굴 오른쪽에서 시작한다
    check("글자가 얼굴만큼 밀려 있다", tx >= fx + fw, f"textX={tx} faceRight={fx + fw}")

    # [E] 이름 창: 대화창 위에 붙고 안에 글자가 있다
    nx, ny, nw, nh = rects["dlgNameRect"]
    check("이름 창이 대화창 위에 있다", ny + nh <= my + 8, f"name={ny + nh} msg={my}")
    name_glyphs = count_color_in(img, scale, nx, ny, nx + nw, ny + nh, WHITE, 30)
    check("이름 글자가 그려진다", name_glyphs > 10, f"px={name_glyphs}")

    # [F] 선택지: 커서가 고른 항목(첫 줄)을 덮어 그 줄이 더 밝다
    r1 = rects["dlgChoiceRow1"]
    r2 = rects["dlgChoiceRow2"]
    luma1 = mean_luma(img, scale, r1[0], r1[1], r1[0] + r1[2], r1[1] + r1[3])
    luma2 = mean_luma(img, scale, r2[0], r2[1], r2[0] + r2[2], r2[1] + r2[3])
    check("선택 커서가 고른 항목을 덮는다", luma1 > luma2 * 1.15,
          f"1번 줄 {luma1:.0f} vs 2번 줄 {luma2:.0f}")

    cx, cy, cw, ch = rects["dlgChoiceRect"]
    check("선택지 창은 대화창 위에 붙는다", cy + ch <= my, f"choice={cy + ch} msg={my}")
    check("선택지 창은 대화창 오른쪽 끝에 맞춘다", abs((cx + cw) - (mx + mw)) <= 2,
          f"choiceRight={cx + cw} msgRight={mx + mw}")

    check_golden("rpg_dialogue_scene", img)
    shutil.copy(os.path.join(work, "shot_0020.bmp"), "/tmp/initial2d_rpg_dialogue.bmp")

    # [G] 같은 씬을 "다음 쪽을 기다리는" 상태로 한 번 더: 창 아래 대기 화살표
    work2, result2, shots2 = run_scene("rpg_dialogue_scene.lua", [20], 30,
                                       extra_env={"INITIAL2D_DLG_MODE": "arrow"})
    log2 = result2.stdout + result2.stderr
    check("대기 상태 실행 정상 종료", result2.returncode == 0, f"rc={result2.returncode}")
    check("첫 쪽에서 멈춰 있다", "dlgArrowPage:1/2" in log2, log2[:400])
    rects2 = parse_rects(log2)
    if 20 in shots2 and "dlgArrowRect" in rects2:
        img2 = shots2[20]
        s2 = img2.width / 768.0
        ax, ay, aw, ah = rects2["dlgArrowRect"]
        arrow = count_color_in(img2, s2, ax, ay, ax + aw, ay + ah, SKIN_ARROW, 30)
        beside = count_color_in(img2, s2, ax - 40, ay, ax - 8, ay + ah, SKIN_ARROW, 30)
        check("창 아래 가운데에 대기 화살표", arrow > 20, f"px={arrow}")
        check("화살표 옆은 비어 있다 (창 바탕)", beside == 0, f"px={beside}")
    else:
        check("대기 화살표 프레임 덤프", False, log2[-300:])


# 데모 화면에서 눈으로 확인한 색 (INITIAL2D_NO_RTP=1, 저장소 자산 기준)
TITLE_SKY = (36, 40, 74)         # 타이틀 배경 위쪽 밤하늘
DEMO_SEA = (46, 108, 156)        # 항구의 바다 (tools/generate_port_tileset.py)
DEMO_PLANK = (150, 106, 68)      # 부두 널
DEMO_SHIRT = SHIRT_RED           # 플레이어(0번 캐릭터)의 빨간 옷


def test_rpgdemo_scene():
    """인수 테스트: 기획서대로의 데모를 처음부터 끝까지 (docs/design/port-town.md).

    가짜 씬이 아니라 게임이 실제로 여는 파일(scripts/games/rpgdemo/*.lua,
    scripts/maps/port_town.lua, inn.lua)을 얹고 입력 재생기로 키를 눌러
    10단계의 심부름 사슬을 한 줄로 통과시킨다 (docs/plans/11-game-systems.md).

      타이틀 → 부두 → 생선 장수 → 잠긴 창고 → 여관(열쇠를 받지만 은화가 없어
      방을 못 잡는다) → 창고를 연다(등유) → 등대지기(등유를 주고 은화 두 닢)
      → 등대지기(하늘 끝) → 여관(은화로 방을 잡는다) → 배 → 에필로그

    대사와 좌표와 소지품이 stdout에 남고 여기서 검사한다.

    RTP는 기계마다 있고 없고가 달라 INITIAL2D_NO_RTP=1로 저장소 자산만 쓰게
    고정한다 (골든도 그래야 커밋할 수 있다 — RTP는 재배포 금지).
    """
    print("\n[8] rpgdemo_scene — 데모 인수 시나리오 (기획서 전체 흐름)")
    work = make_workdir("rpgdemo_scene.lua")
    env = dict(os.environ)
    env["INITIAL2D_EXIT_AFTER"] = "30"
    env["INITIAL2D_NO_RTP"] = "1"
    result = subprocess.run([GAME], cwd=work, env=env,
                            capture_output=True, text=True, timeout=900)
    log = result.stdout + result.stderr

    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-300:])
    # 틀린 맵 파일 이벤트는 건너뛰고 rpg:error 만 남는다 (M2). 조용히 지나가지 않게 여기서 본다
    check("stdout 에 rpg:error 가 없다", "rpg:error" not in result.stdout,
          [ln for ln in result.stdout.splitlines() if "rpg:error" in ln][:3])

    def has(needle, name):
        check(name, needle in log, f"'{needle}' 없음 | {log[-500:]}")

    # [A] 타이틀
    has("titleScene:title", "타이틀 씬으로 시작")
    has("titleMenuOpen:true", "커서 메뉴가 열린다")
    has("titleItems:3 index:1", "항목 3개, 커서는 첫 항목")
    has("helpShown:true", "조작 방법을 고르면 설명 창이 뜬다")
    has("helpClosed:true", "설명을 끝까지 넘기면 닫힌다")
    has("menuBack:true", "설명이 닫히면 메뉴로 돌아온다")
    has("sceneAfterStart:rpg", "시작을 고르면 맵 씬으로 넘어간다")

    # [B] 부두 도착 — 기획서 4.1절의 시작 칸과 선장의 첫 인사
    has("mapLoaded:port_town error:nil", "항구 마을 맵 로드")
    has("playerAt:16,43", "배에서 막 내린 자리")
    has("location:항구 마을", "맵에 들어서면 장소 이름이 뜬다")
    has("captainLine:짐은 다 내렸네.", "선장이 먼저 말을 건다 (auto)")
    has("captainLine2:급할 것 없으면 마을을 좀 둘러보게.", "선장의 두 번째 대사")

    # [C] 맵 파일(JSON)에 실려 온 이벤트가 실제로 돈다 (포맷 v2, 마일스톤 3)
    has("crateLine:누군가의 짐이다.", "맵 파일에 실린 이벤트가 그대로 실행된다")

    # [C] 광장: 생선 장수의 선택지와 그 뒤에 달라지는 창고
    has("fishLine:오늘 물건은 아침에 다 나갔어요.", "생선 장수의 첫 대사")
    has("fishChoice:true", "생선 장수가 선택지를 띄운다")
    has("warehouseStory:저 창고요? 주인이 남쪽으로 떠난 지 삼 년째예요.", "창고의 사연")
    has("keyHint:열쇠는 여관 주인이 맡아 뒀어요.", "다음에 갈 곳을 대사가 말한다")
    has("warehouseLocked:삼 년째 잠긴 문이다.", "사연을 들은 뒤 창고 문의 설명이 달라진다")

    # 소지품 창 (10단계): 아직 아무것도 없다
    has("menuOpened:true", "취소키로 소지품 창이 열린다")
    has("bagEmpty:[]", "처음에는 가진 것이 없다")
    has("menuClosed:true", "같은 키로 닫힌다")

    # [D] 여관: 열쇠를 받지만, 은화가 없어 방을 못 잡는다
    has("innAt:10,12", "여관 문으로 들어서면 1층 입구")
    has("innLocation:항구 여관", "실내에서도 장소 이름")
    has("hostLine:어서 오세요.", "여관 주인의 첫 대사")
    has("hostKeyLine:창고 얘기를 들으셨군요.", "창고 사연을 듣고 오면 열쇠를 내준다")
    has("hostKeyGot:창고 열쇠를 받았다.", "열쇠를 받는다 (giveItem)")
    has("hostChoice:true", "방을 잡을지 묻는 선택지")
    has("noSilverLine:...두 닢이 모자라시네요.", "은화가 없으면 방을 잡을 수 없다")
    has("bookedAfterRefuse:false", "거절당하면 booked 깃발이 서지 않는다")
    has("bagKey:창고 열쇠", "소지품 창에 열쇠가 보인다")
    has("backAt:13,30", "아래 문으로 나오면 여관 문 앞")

    # [E] 열쇠로 창고를 연다
    has("warehouseOpen:열쇠가 맞는다.", "열쇠를 가지고 있으면 창고가 열린다")
    has("oilGot:선반에 등유 한 통이 남아 있다.", "창고 안에서 등유를 얻는다")
    has("bagOil:창고 열쇠,등유 한 통", "소지품이 순서대로 쌓인다")

    # [F] 언덕: 등유를 건네고 은화 두 닢을 받는다
    has("keeperOilLine:...그건 창고 것이군.", "등유를 들고 가면 노인이 먼저 알아본다")
    has("silverGot:은화 두 닢을 받았다.", "사례로 은화 두 닢")
    has("lampReady:true", "오늘 밤 등대에 불이 켜진다")
    has("bagSilver:창고 열쇠,은화x2", "등유는 나가고 은화가 둘 들어왔다 (takeItem/giveItem)")
    has("keeperLine:...배를 기다리나.", "등유를 넘긴 뒤에는 원래의 대화로 돌아온다")
    has("altarLine:제단이 있었네.", "하늘 끝을 물으면 제단 이야기가 나온다")
    has("gateLine:숲으로 가는 길은 막혀 있다. 바람이",
        "그 이야기를 들은 뒤에는 북쪽 문의 설명도 달라진다")

    # [G] 여관: 이번에는 은화로 방을 잡는다
    has("bookedLine:그럼 짐을 올려 두세요.", "은화 두 닢이 있으면 방을 내준다")
    has("booked:true", "방을 잡았다")
    has("bagPaid:창고 열쇠", "방값으로 은화가 나갔다 (소지품에 열쇠만 남는다)")

    # [H] 배: 마지막 선택과 에필로그, 그리고 타이틀 복귀
    has("shipLine:저녁 배가 밧줄을 풀 준비를 하고 있다. 언덕의 등대에는",
        "등대에 기름을 채웠으면 배 앞의 글도 달라진다")
    has("shipChoice:true", "떠날지 묻는 선택지")
    has("farewellLine:밧줄 푸네.", "떠나기로 하면 선장이 배웅한다")
    has("epilogue1:배는 저녁 물때에 항구를 떠났다.", "에필로그 첫 줄")
    has("epilogue2:등 뒤에서 등대에 불이 켜졌다.", "등대에 불을 켰으면 한 줄이 붙는다")
    has("epilogue3:여관의 방 하나가 하룻밤 비어 있었다.", "방을 잡았으면 또 한 줄이 붙는다")
    has("finalScene:title", "에필로그 뒤에는 타이틀로 돌아온다")
    has("demoDone:true", "시나리오 끝까지 통과")
    check("걷다가 막힌 곳이 없다", "timeout" not in log,
          [ln for ln in log.splitlines() if "timeout" in ln][:3])

    # ---- 화면 두 장 (골든) -------------------------------------------------
    shot_env = {"INITIAL2D_NO_RTP": "1", "INITIAL2D_DEMO_STOP": "title"}
    _, r_title, s_title = run_scene("rpgdemo_scene.lua", [20], 30, shot_env)
    check("타이틀 화면 덤프", 20 in s_title, f"rc={r_title.returncode}")
    if 20 in s_title:
        img = s_title[20]
        scale = img.width / 768.0
        sky = count_color_in(img, scale, 20, 20, 200, 120, TITLE_SKY, 30)
        check("타이틀 배경의 밤하늘", sky > 100, f"px={sky}")
        frame = count_color_in(img, scale, 80, 610, 400, 800, SKIN_FRAME_LIGHT, 30)
        check("메뉴 창의 테두리", frame > 40, f"px={frame}")
        check_golden("rpgdemo_title", img)

    shot_env = {"INITIAL2D_NO_RTP": "1", "INITIAL2D_DEMO_STOP": "town"}
    _, r_town, s_town = run_scene("rpgdemo_scene.lua", [20], 30, shot_env)
    check("마을 첫 화면 덤프", 20 in s_town, f"rc={r_town.returncode}")
    if 20 in s_town:
        img = s_town[20]
        # 맵 씬은 렌더 배율 2 — 논리 해상도가 384x448이다
        scale = img.width / 384.0
        # 카메라가 맵 아래 끝에서 멈추므로 플레이어는 화면 가운데가 아니라
        # 부두 위(논리 y 355 언저리)에 선다.
        sea = count_color_in(img, scale, 20, 350, 140, 400, DEMO_SEA, 30)
        check("부두 앞의 바다", sea > 200, f"px={sea}")
        plank = count_color_in(img, scale, 172, 395, 182, 412, DEMO_PLANK, 40)
        check("부두 널", plank > 10, f"px={plank}")
        hero = count_color_in(img, scale, 187, 357, 197, 370, DEMO_SHIRT, 30)
        check("플레이어가 부두 위에 서 있다", hero > 5, f"px={hero}")
        check_golden("rpgdemo_town", img)

    # 대조: 마을 첫 화면 안의 한 칸(over 레이어 (10, 26), 에디터 test:engine-map 의 대조와 같은 칸과 타일)을
    # 칠한 맵으로 같은 화면을 찍으면, 비율 검사는 통과하는 크기라도 한 칸 검사는 실패해야 한다.
    def paint_one_cell(work):
        link_resources(work, copy=("maps",))
        path = os.path.join(work, "resources", "maps", "port_town.json")
        with open(path, encoding="utf-8") as fp:
            town = json.load(fp)
        town["layers"][2]["data"][26 * town["width"] + 10] = 45
        with open(path, "w", encoding="utf-8") as fp:
            json.dump(town, fp)

    _, r_cell, s_cell = run_scene("rpgdemo_scene.lua", [20], 30, shot_env, prepare=paint_one_cell)
    check("한 칸 칠한 마을 화면 덤프", 20 in s_cell, f"rc={r_cell.returncode}")
    town_golden = os.path.join(GOLDEN_DIR, "rpgdemo_town.png")
    if 20 in s_cell and os.path.exists(town_golden) and not UPDATE_GOLDEN:
        ratio, window = golden_diff(s_cell[20], Image.open(town_golden).convert("RGB"))
        if window is None:
            print("  NOTE  한 칸 검사의 대조 — 리샘플한 캡처라 건너뜀 (헤드리스로 돌리면 한다)")
        else:
            check("대조: 한 칸 칠한 마을 화면은 골든 한 칸 검사에서 실패한다", window[0] > GOLDEN_WINDOW_MAX,
                  f"가장 붐비는 창 {window}, 비율 {ratio:.2%}")
            print(f"  대조의 차이 픽셀 {ratio:.2%} (비율 검사의 허용 {GOLDEN_DIFF_RATIO:.0%}), 가장 붐비는 창 {window}")

    # 소지품 창이 열린 화면 (10단계). 창 두 칸과 커서, 개수와 설명이 한 장에 있다.
    shot_env = {"INITIAL2D_NO_RTP": "1", "INITIAL2D_DEMO_STOP": "bag"}
    _, r_bag, s_bag = run_scene("rpgdemo_scene.lua", [20], 30, shot_env)
    check("소지품 창 덤프", 20 in s_bag, f"rc={r_bag.returncode}")
    if 20 in s_bag:
        img = s_bag[20]
        scale = img.width / 384.0
        frame = count_color_in(img, scale, 8, 170, 376, 280, SKIN_FRAME_LIGHT, 30)
        check("소지품 창의 테두리", frame > 40, f"px={frame}")
        check_golden("rpgdemo_bag", img)

    # 여관 벽 앞에 선 캐릭터 (2026-08-20 사용자 보고의 회귀 테스트).
    # 캐릭터 프레임(24x32)은 타일(16x16)보다 커서 머리가 윗 칸으로 올라간다.
    # 장식 레이어를 캐릭터 **위**에 그리면 그 칸의 집 벽이 머리를 통째로 덮는다.
    # 맵 정의의 groundLayers가 그 경계를 정하며(port_town은 2), 여기서 머리색
    # 픽셀 수로 확인한다 — 되돌아가면 이 수가 0에 가까워진다.
    shot_env = {"INITIAL2D_NO_RTP": "1", "INITIAL2D_DEMO_STOP": "wall"}
    _, r_wall, s_wall = run_scene("rpgdemo_scene.lua", [20], 30, shot_env)
    check("여관 문 앞 화면 덤프", 20 in s_wall, f"rc={r_wall.returncode}")
    if 20 in s_wall:
        img = s_wall[20]
        scale = img.width / 384.0
        wall = count_color_in(img, scale, 170, 196, 215, 214, HOUSE_WALL, 24)
        check("캐릭터가 집 벽 앞에 서 있다", wall > 200, f"px={wall}")
        # 허용 오차를 좁게 잡는다. 문 타일의 갈색(108,74,50)이 머리색과 가까워서
        # 기본 오차(24)로는 "가려진 머리"까지 머리로 세어 버린다 — 이 테스트를
        # 처음 넣었을 때 실제로 통과해 버렸다.
        hair = count_color_in(img, scale, 184, 201, 199, 213, HAIR_BROWN, 8)
        check("집 벽이 캐릭터의 머리를 덮지 않는다", hair > 40, f"머리색 px={hair}")


def rpg_play_env(rpg_map, at=None, state=None, route=None, event=None):
    """resources/data/rpg-game.json 의 play.env (route 가 있으면 play.probe 까지)를 채운다.

    에디터의 실행 명령과 같은 규칙이다 (docs/plans/m2-rpg-events.md 2.4절): 자리표시자에
    채울 값이 없는 변수는 넣지 않는다. route 의 빈 글은 값이다 (걸음 없이 auto 만 기다린다).
    event는 "이 이벤트 자동 재생"의 이벤트 id다 ({event}).
    """
    with open(os.path.join(REPO, "resources", "data", "rpg-game.json"), encoding="utf-8") as f:
        play = json.load(f)["play"]
    values = {"rpg.map": rpg_map, "state": state or None, "route": route, "event": event}
    if at is not None:
        values.update({"cx": str(at[0]), "cy": str(at[1]), "dir": at[2]})
    wanted = dict(play["env"])
    if route is not None:
        wanted.update(play["probe"])
    env = {}
    for key, template in wanted.items():
        names = re.findall(r"\{([^}]+)\}", template)
        if any(values.get(n) is None for n in names):
            continue
        env[key] = re.sub(r"\{([^}]+)\}", lambda m: str(values[m.group(1)]), template)
    return env


def run_game(work, extra_env, exit_after=6000, raw=False):
    """진짜 허브로 게임을 띄운다. INITIAL2D_RPG_ROUTE 가 있으면 게임이 스스로 끝나고,
    exit_after 는 끝나지 않았을 때의 안전망이다. raw 면 stdout 을 바이트 그대로 돌려준다
    (text 모드는 CR 을 줄바꿈으로 바꾸므로 줄 끊김 검사에 쓸 수 없다)."""
    env = dict(os.environ)
    env["INITIAL2D_NO_RTP"] = "1"
    env["INITIAL2D_EXIT_AFTER"] = str(exit_after)
    env.update(extra_env)
    return subprocess.run([GAME], cwd=work, env=env,
                          capture_output=True, text=not raw, timeout=300)


def rpg_lines(stdout):
    return [ln for ln in stdout.splitlines() if ln.startswith("rpg:")]


def test_rpg_play_here():
    """"여기서 실행"과 자동 재생의 장치를 진짜 허브로 확인한다 (M2, docs/plans/m2-rpg-events.md 5.2절).

    테스트 씬이 아니라 scripts/lua/main.lua 가 INITIAL2D_SCENE=rpg 로 데모 맵 씬을 연다.
    환경 변수는 rpg-game.json 의 play.env 와 play.probe 에서 만든다 (에디터가 넘기는 것과 같다).
    """
    print("\n[8p] rpg_play_here: 여기서 실행, 자동 재생, 시작 상태, 틀린 이벤트 건너뛰기")
    work = make_game_workdir()

    # [A] 맵 파일의 crates(14,40) 옆 15,40 에서 왼쪽을 보고 선다. 아래와 왼쪽 칸은 막혀 있다
    env = rpg_play_env("port_town", at=(15, 40, "left"), route="talk")
    check("실행 변수: SCRIPT, SCENE, MAP, AT, TRACE, AUTOPLAY, ROUTE",
          env.get("INITIAL2D_SCRIPT") == "lua" and env.get("INITIAL2D_SCENE") == "rpg"
          and env.get("INITIAL2D_MAP") == "port_town" and env.get("INITIAL2D_RPG_AT") == "15,40,left"
          and env.get("INITIAL2D_RPG_TRACE") == "1" and env.get("INITIAL2D_AUTOPLAY") == "1"
          and env.get("INITIAL2D_RPG_ROUTE") == "talk" and "INITIAL2D_RPG_STATE" not in env, str(env))
    check("실행 변수: 이벤트가 없으면 HOLD를 넣지 않는다", "INITIAL2D_RPG_HOLD" not in env, str(env))
    r = run_game(work, env)
    lines = rpg_lines(r.stdout)
    log = r.stdout + r.stderr
    check("[A] 정상 종료", r.returncode == 0, f"rc={r.returncode}")
    check("[A] Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-300:])
    check("[A] rpg:error 가 없다", not any(ln.startswith("rpg:error") for ln in lines), str(lines[:5]))

    def index(needle, where=None):
        where = lines if where is None else where
        for i, ln in enumerate(where):
            if ln.startswith(needle):
                return i
        return -1

    check("[A] 맵을 열었다 (이벤트 17개, 건너뜀 없음)", "rpg:map:port_town events:17 skipped:0" in lines,
          str(lines[:4]))
    i_player = index("rpg:player:port_town,15,40,left")
    check("[A] 고른 칸에 고른 방향으로 선다", i_player >= 0, str(lines[:4]))
    check("[A] 새 게임이라 선장의 인사가 먼저 나온다", index("rpg:message:선장|짐은 다 내렸네.") > i_player,
          str(lines[:8]))
    i_event = index("rpg:event:crates")
    i_crate = index("rpg:message:|누군가의 짐이다.")
    check("[A] talk 한 번으로 맵 파일의 crates 가 돈다", i_player < i_event < i_crate, str(lines))
    check("[A] 경로를 다 걷고 스스로 끝난다", bool(lines) and lines[-1] == "rpg:route:done", str(lines[-3:]))

    # [B] 시작 상태 arrived 면 선장의 첫 인사를 건너뛴다
    env = rpg_play_env("port_town", at=(15, 40, "left"), state="arrived", route="talk")
    check("실행 변수: 시작 상태", env.get("INITIAL2D_RPG_STATE") == "arrived", str(env))
    r = run_game(work, env)
    lines = rpg_lines(r.stdout)
    check("[B] 정상 종료", r.returncode == 0, f"rc={r.returncode}")
    check("[B] rpg:error 가 없다", not any(ln.startswith("rpg:error") for ln in lines), str(lines[:5]))
    check("[B] arrival 은 돌지만", "rpg:event:arrival" in lines, str(lines))
    check("[B] 선장의 인사가 없다", not any(ln.startswith("rpg:message:선장|") for ln in lines), str(lines))
    check("[B] crates 의 대사는 그대로", index("rpg:message:|누군가의 짐이다.") >= 0, str(lines))
    check("[B] 스스로 끝난다", bool(lines) and lines[-1] == "rpg:route:done", str(lines[-3:]))

    # [C] 위치 없이 여관을 열고 아래 출입구를 밟는다: 정의 파일의 시작, 그리고 transfer 의 dir.
    # 항구 마을의 start.dir 은 up 이라, down 으로 서면 transfer 의 dir 이 적용된 것이다
    env = rpg_play_env("inn", route="down")
    check("실행 변수: 위치가 없으면 AT 를 넣지 않는다", "INITIAL2D_RPG_AT" not in env, str(env))
    r = run_game(work, env)
    lines = rpg_lines(r.stdout)
    check("[C] 정상 종료", r.returncode == 0, f"rc={r.returncode}")
    check("[C] rpg:error 가 없다", not any(ln.startswith("rpg:error") for ln in lines), str(lines[:5]))
    check("[C] 정의 파일의 시작에 선다", "rpg:player:inn,10,12,up" in lines, str(lines[:4]))
    check("[C] 출입구의 transfer", "rpg:transfer:port_town,13,30,down" in lines, str(lines))
    i_town = index("rpg:map:port_town")
    check("[C] 항구 마을에서 transfer 의 방향으로 선다",
          i_town >= 0 and index("rpg:player:port_town,13,30,down") > i_town, str(lines))
    check("[C] 도착한 맵의 auto 까지 기다렸다 끝난다", bool(lines) and lines[-1] == "rpg:route:done"
          and index("rpg:message:선장|") > i_town, str(lines[-3:]))

    # [D] 틀린 맵 파일 이벤트: 그 이벤트만 건너뛰고 rpg:error 를 찍는다. 나머지는 돈다
    work_d = make_game_workdir(copy=("maps",))
    port = os.path.join(work_d, "resources", "maps", "port_town.json")
    with open(port, encoding="utf-8") as f:
        data = json.load(f)
    base = len(data["events"])
    data["events"].append({"id": "broken", "x": -1, "y": 3, "dir": "north",
                           "charset": {"set": "nobody", "index": 9},
                           "commands": [{"code": "message"},
                                        {"code": "transfer", "map": "inn", "dir": "sideways"}]})
    data["events"].append({"id": "sign", "x": 15, "y": 39, "trigger": "action",
                           "commands": [{"code": "message", "text": "첫 줄\n\"둘째\" 줄"}]})
    with open(port, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    env = rpg_play_env("port_town", at=(15, 40, "up"), state="arrived,item:lamp_oill=1", route="talk")
    r = run_game(work_d, env)
    lines = rpg_lines(r.stdout)
    check("[D] 정상 종료", r.returncode == 0, f"rc={r.returncode}")
    bad = "rpg:error:resources/maps/port_town.json:events[%d]" % (base + 1)
    for suffix in (".x:", ".dir:", ".charset.set:", ".charset.index:",
                   ".commands[1].text:", ".commands[2].dir:"):
        check(f"[D] 문제마다 rpg:error 한 줄 ({suffix[:-1]})",
              any(ln.startswith(bad + suffix) for ln in lines), str(lines[:8]))
    check("[D] 건너뛴 수가 남는다", "rpg:map:port_town events:18 skipped:1" in lines, str(lines[:10]))
    check("[D] 틀린 시작 상태 항목도 rpg:error", any(ln.startswith("rpg:error:state:item:lamp_oill=1:")
                                              for ln in lines), str(lines[:3]))
    check("[D] 나머지 맵 파일 이벤트는 돈다 (대사의 줄바꿈은 \\n)",
          'rpg:message:|첫 줄\\n"둘째" 줄' in lines, str(lines[-4:]))
    check("[D] 스스로 끝난다", bool(lines) and lines[-1] == "rpg:route:done", str(lines[-3:]))

    # [E] 정의 파일의 외형에 file 이 없으면 플레이어 그림으로 조용히 그리지 않고 오류다.
    # 이벤트가 Lua 정의 파일에 남아 있는 마을(RTP 쌍둥이 맵이라 옮기지 않았다)의 촌장으로 본다
    villagefile = os.path.join(work_d, "scripts", "lua", "maps", "village.lua")
    with open(villagefile, encoding="utf-8") as f:
        text = f.read()
    broken = text.replace("charset = { file = CHARSET, index = 2 },", "charset = { index = 2 },")
    check("[E] 마을 정의 파일에 고칠 줄이 하나 있다", broken != text and text.count("charset = { file = CHARSET, index = 2 },") == 1)
    with open(villagefile, "w", encoding="utf-8") as f:
        f.write(broken)
    r = run_game(work_d, rpg_play_env("village"), exit_after=60)
    lines = rpg_lines(r.stdout)
    check("[E] 정상 종료", r.returncode == 0, f"rc={r.returncode}")
    check("[E] 정의 파일의 오류가 stdout 에 나온다",
          "rpg:error:scripts/lua/maps/village.lua:elder: 외형(charset)에 file 없음" in lines, str(lines))

    # [F] 게임 설정과 아이템 표를 못 읽으면: 이유 글의 줄바꿈까지 한 줄로, 한 번만 찍는다
    work_f = make_game_workdir(copy=("data",))
    data_dir = os.path.join(work_f, "resources", "data")
    with open(os.path.join(data_dir, "rpg-game.json"), "w", encoding="utf-8") as f:
        f.write("{ broken")
    r = run_game(work_f, rpg_play_env("port_town"), exit_after=60)
    out = r.stdout.splitlines()
    cfg = [ln for ln in out if ln.startswith("rpg:error:rpg-game.json:")]
    check("[F] 정상 종료", r.returncode == 0, f"rc={r.returncode}")
    check("[F] rpg-game.json 의 오류는 한 번", len(cfg) == 1, str(cfg))
    check("[F] 파서의 이유가 그 한 줄에 다 있다 (줄바꿈은 공백)",
          len(cfg) == 1 and [ln for ln in out if "Missing" in ln] == cfg
          and not cfg[0].endswith(" "), str(out[:6]))
    shutil.copy(os.path.join(REPO, "resources", "data", "rpg-game.json"), data_dir)
    with open(os.path.join(data_dir, "items.json"), "w", encoding="utf-8") as f:
        f.write("{ broken")
    r = run_game(work_f, rpg_play_env("port_town"), exit_after=60)
    out = r.stdout.splitlines()
    bad_items = [ln for ln in out if ln.startswith("rpg:error:resources/data/items.json:")]
    check("[F] 아이템 표의 오류도 한 번, 한 줄", len(bad_items) == 1
          and [ln for ln in out if "Missing" in ln] == bad_items, str(out[:6]))
    check("[F] 아이템 표가 없어도 맵은 열린다", "rpg:map:port_town events:17 skipped:0" in out, str(out[:6]))

    # [F] 두 파일의 모양: null 칸과 배열 자리의 객체는 경로와 함께 한 줄, 그 항목만 빼고 나머지는 쓴다
    with open(os.path.join(REPO, "resources", "data", "items.json"), encoding="utf-8") as f:
        items_json = json.load(f)
    holey = dict(items_json, items=[items_json["items"][0], None] + items_json["items"][1:])
    with open(os.path.join(data_dir, "items.json"), "w", encoding="utf-8") as f:
        json.dump(holey, f, ensure_ascii=False)
    r = run_game(work_f, rpg_play_env("port_town", state="arrived,item:silver=2,item:shell=1", route=""))
    lines = rpg_lines(r.stdout)
    errors = [ln for ln in lines if ln.startswith("rpg:error")]
    check("[F] items[2] 의 null 은 경로와 함께 한 줄", errors == [
        "rpg:error:resources/data/items.json:items[2]: 아이템은 객체여야 함"], str(errors))
    check("[F] null 뒤의 아이템도 표에 있다 (시작 상태의 silver, shell 이 받아들여진다)",
          r.returncode == 0 and bool(lines) and lines[-1] == "rpg:route:done", str(lines[-3:]))
    as_object = dict(items_json, items={it["id"]: it for it in items_json["items"]})
    with open(os.path.join(data_dir, "items.json"), "w", encoding="utf-8") as f:
        json.dump(as_object, f, ensure_ascii=False)
    r = run_game(work_f, rpg_play_env("port_town", route=""))
    lines = rpg_lines(r.stdout)
    check("[F] 객체로 쓴 items 는 items 자리의 한 줄",
          [ln for ln in lines if ln.startswith("rpg:error")]
          == ["rpg:error:resources/data/items.json:items: 아이템 목록은 배열이어야 함"], str(lines[:4]))
    shutil.copy(os.path.join(REPO, "resources", "data", "items.json"), data_dir)

    work_m = make_game_workdir(copy=("data", "maps"))
    game_json = os.path.join(work_m, "resources", "data", "rpg-game.json")
    with open(game_json, encoding="utf-8") as f:
        game = json.load(f)
    with open(game_json, "w", encoding="utf-8") as f:
        json.dump(dict(game, maps=[game["maps"][0], None] + game["maps"][1:]), f, ensure_ascii=False)
    port = os.path.join(work_m, "resources", "maps", "port_town.json")
    with open(port, encoding="utf-8") as f:
        data = json.load(f)
    data["events"].append({"id": "sign", "x": 15, "y": 39,
                           "commands": [{"code": "transfer", "map": "inn", "x": 10, "y": 12}]})
    with open(port, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    r = run_game(work_m, rpg_play_env("port_town", at=(15, 40, "up"), state="arrived", route="talk"))
    lines = rpg_lines(r.stdout)
    check("[F] maps[2] 의 null 은 경로와 함께 한 줄",
          [ln for ln in lines if ln.startswith("rpg:error")]
          == ["rpg:error:rpg-game.json:maps[2]: 맵 항목은 객체여야 함"], str(lines[:4]))
    check("[F] null 뒤에 등록된 여관으로 옮겨 간다", "rpg:map:inn events:6 skipped:0" in lines
          and r.returncode == 0 and lines[-1] == "rpg:route:done", str(lines[-4:]))
    with open(game_json, "w", encoding="utf-8") as f:
        json.dump(dict(game, maps={m["name"]: m for m in game["maps"]}), f, ensure_ascii=False)
    r = run_game(work_m, rpg_play_env("port_town"), exit_after=60)
    lines = rpg_lines(r.stdout)
    check("[F] 객체로 쓴 maps 는 maps 자리의 한 줄",
          r.returncode == 0 and [ln for ln in lines if ln.startswith("rpg:error")]
          == ["rpg:error:rpg-game.json:maps: 맵 목록은 배열이어야 함"], str(lines[:4]))

    # [G] 선택 인자의 타입: 검수에서 게임을 멈추게 한 값들. 말을 걸 자리의 이벤트가 검사에서 빠지고
    # rpg:error 로 알린 뒤 끝까지 돈다 (playSe.id 는 전에 SIGSEGV, 나머지는 Lua 오류였다)
    door = "./resources/audio/door.wav"
    crash_cases = [
        ("playSe.id", [{"code": "playSe", "file": door, "id": True}], ["id"]),
        ("message.name", [{"code": "message", "text": "hi", "name": {"a": 1}}], ["name"]),
        ("transfer.x/y", [{"code": "transfer", "map": "inn", "x": {"a": 1}, "y": [2]}], ["x", "y"]),
        ("playBgm.volume", [{"code": "playBgm", "file": door, "volume": "loud"}], ["volume"]),
        ("scene.text", [{"code": "scene", "name": "title", "text": ["x"]}], ["text"]),
        # items 는 state 안의 소지품 자리다. 깃발이나 변수로 덮으면 아이템 커맨드와 소지품 창이 멈췄다
        ("setFlag.key items", [{"code": "setFlag", "key": "items"}], ["key"]),
        ("setVar.key items", [{"code": "setVar", "key": "items", "value": 5}], ["key"]),
    ]
    work_g = make_game_workdir(copy=("maps",))
    port = os.path.join(work_g, "resources", "maps", "port_town.json")
    with open(os.path.join(REPO, "resources", "maps", "port_town.json"), encoding="utf-8") as f:
        port_data = json.load(f)
    at_index = len(port_data["events"]) + 1
    for name, commands, args in crash_cases:
        data = dict(port_data, events=port_data["events"] + [
            {"id": "sign", "x": 15, "y": 39, "commands": commands + [{"code": "message", "text": "after"}]}])
        with open(port, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        r = run_game(work_g, rpg_play_env("port_town", at=(15, 40, "up"), state="arrived", route="talk"))
        lines = rpg_lines(r.stdout)
        log = r.stdout + r.stderr
        where = "rpg:error:resources/maps/port_town.json:events[%d].commands[1]." % at_index
        got = sorted(ln[len(where):].split(":")[0] for ln in lines if ln.startswith(where))
        check(f"[G] {name}: 그 인자마다 rpg:error 한 줄", got == sorted(args), str(lines[:4]))
        check(f"[G] {name}: 그 이벤트만 건너뛴다", "rpg:map:port_town events:17 skipped:1" in lines,
              str(lines[:6]))
        check(f"[G] {name}: 멈추지 않고 끝까지 돈다 (rc 0, Lua 오류 없음)",
              r.returncode == 0 and "Lua error" not in log and bool(lines)
              and lines[-1] == "rpg:route:done", f"rc={r.returncode} {log[-300:]}")

    # [G] 맵 파일 이벤트의 script 키는 모르는 키다. 전에는 Event.new 의 assert 로 맵 전체가 로드 실패였다
    data = dict(port_data, events=port_data["events"] + [
        {"id": "sign", "x": 15, "y": 39, "script": "not a function",
         "commands": [{"code": "message", "text": "after"}]}])
    with open(port, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    r = run_game(work_g, rpg_play_env("port_town", at=(15, 40, "up"), state="arrived", route="talk"))
    lines = rpg_lines(r.stdout)
    check("[G] script 키가 있는 맵 파일 이벤트도 돈다",
          r.returncode == 0 and "rpg:map:port_town events:18 skipped:0" in lines
          and not any(ln.startswith("rpg:error") for ln in lines)
          and "rpg:event:sign" in lines and lines[-1] == "rpg:route:done", str(lines[-6:]))

    # [H] rpg:error 는 늘 한 줄: 자리 글과 이유 글의 CR, LF, CRLF, U+2028, U+2029 가 공백 하나가 된다
    data = dict(port_data, events=port_data["events"] + [
        {"id": "cr", "x": 15, "y": 39, "commands": [
            {"code": "a\rb\u2028c"},
            {"code": "message", "text": "x", "face": {"set": "n\rpc"}},
            {"code": "c\r\nd\u2029e"}]}])
    with open(port, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=True)
    env = {"INITIAL2D_SCRIPT": "lua", "INITIAL2D_SCENE": "rpg", "INITIAL2D_MAP": "port_town",
           "INITIAL2D_RPG_STATE": "arrived\nitem:shell=1", "INITIAL2D_RPG_AT": "15,40,left\nx",
           "INITIAL2D_RPG_ROUTE": "up\ntalk"}
    r = run_game(work_g, env, exit_after=60, raw=True)
    out = r.stdout.decode("utf-8", "replace")
    by_lf = [ln for ln in out.split("\n") if "rpg:error" in ln]
    where = "rpg:error:resources/maps/port_town.json:events[%d].commands" % at_index
    check("[H] 정상 종료", r.returncode == 0, f"rc={r.returncode}")
    check("[H] 줄 끊는 글자가 든 rpg:error 가 없다",
          len(by_lf) == 6 and not any(ch in ln for ln in by_lf for ch in ("\r", "\u2028", "\u2029")),
          repr(by_lf))
    check("[H] 파이썬 splitlines 로 갈라도 줄 수가 같다 (러너가 stdout 을 가르는 방식)",
          len([ln for ln in out.splitlines() if "rpg:error" in ln]) == len(by_lf), repr(by_lf))
    for label, expect in (
            ("시작 상태의 LF", "rpg:error:state:arrived item:shell=1: 지원하지 않는 접두사 (아이템은 item:<id>)"),
            ("시작 칸의 LF (자리와 이유)", "rpg:error:at:15,40,left x: 지원하지 않는 방향: left x"),
            ("경로의 LF", "rpg:error:route:up talk: 지원하지 않는 경로 단계 (허용: talk, up, down, left, right)"),
            ("code 의 CR 과 U+2028", where + "[1]: 스키마에 없는 커맨드: a b c"),
            ("face.set 의 CR", where + "[2].face.set: 얼굴: 스키마에 없는 face 이름: n pc"),
            ("code 의 CRLF 와 U+2029", where + "[3]: 스키마에 없는 커맨드: c d e")):
        check(f"[H] 한 줄: {label}", expect in by_lf, repr(by_lf))

    # [H] 유니코드의 다른 줄 끊김(VT, FF, FS, GS, RS, NEL)도 한 줄로
    data = dict(port_data, events=port_data["events"] + [
        {"id": "cr", "x": 15, "y": 39, "commands": [{"code": "a\x1cb\x1dc\x1ed"}]}])
    with open(port, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=True)
    env = {"INITIAL2D_SCRIPT": "lua", "INITIAL2D_SCENE": "rpg", "INITIAL2D_MAP": "port_town",
           "INITIAL2D_RPG_STATE": "arrived\x0bitem:shell=1", "INITIAL2D_RPG_AT": "15,40,left\x0cx",
           "INITIAL2D_RPG_ROUTE": "up\x85talk"}
    r = run_game(work_g, env, exit_after=60, raw=True)
    out = r.stdout.decode("utf-8", "replace")
    by_split = [ln for ln in out.splitlines() if "rpg:error" in ln]
    for label, expect in (
            ("시작 상태의 VT", "rpg:error:state:arrived item:shell=1: 지원하지 않는 접두사 (아이템은 item:<id>)"),
            ("시작 칸의 FF", "rpg:error:at:15,40,left x: 지원하지 않는 방향: left x"),
            ("경로의 NEL", "rpg:error:route:up talk: 지원하지 않는 경로 단계 (허용: talk, up, down, left, right)"),
            ("code 의 FS, GS, RS", where + "[1]: 스키마에 없는 커맨드: a b c d")):
        check(f"[H] splitlines 로도 한 줄: {label}", expect in by_split, repr(by_split))

    # [I] 배회하는 아이(kid, 14,20에서 아래를 본다)를 새 게임 그대로 자동 재생한다. 에디터가 고르는
    # 앞 칸 14,21에 위를 보고 서고, 선장의 인사(arrival)가 도는 동안 아이는 INITIAL2D_RPG_HOLD로
    # 제자리에 서 있다 (m2-rpg-events.md 5.2절)
    env = rpg_play_env("port_town", at=(14, 21, "up"), route="talk", event="kid")
    check("실행 변수: 자동 재생은 그 이벤트를 HOLD로 넘기고 늘 trace를 켠다",
          env.get("INITIAL2D_RPG_HOLD") == "kid" and env.get("INITIAL2D_RPG_TRACE") == "1"
          and env.get("INITIAL2D_RPG_ROUTE") == "talk" and env.get("INITIAL2D_RPG_AT") == "14,21,up"
          and "INITIAL2D_RPG_STATE" not in env, str(env))
    r = run_game(work, env)
    lines = rpg_lines(r.stdout)
    log = r.stdout + r.stderr
    check("[I] 정상 종료", r.returncode == 0, f"rc={r.returncode}")
    check("[I] Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-300:])
    check("[I] rpg:error가 없다", not any(ln.startswith("rpg:error") for ln in lines), str(lines[:5]))
    check("[I] rpg:hold:kid가 한 번", lines.count("rpg:hold:kid") == 1
          and not any(ln.startswith("rpg:hold:") and ln != "rpg:hold:kid" for ln in lines), str(lines[:6]))
    i_player = index("rpg:player:port_town,14,21,up")
    i_hold = index("rpg:hold:kid")
    i_arrival = index("rpg:event:arrival")
    check("[I] 플레이어를 세운 뒤, 첫 auto보다 먼저 찍는다", 0 <= i_player < i_hold < i_arrival, str(lines[:6]))
    i_kid = index("rpg:event:kid")
    check("[I] 새 게임이라 선장의 인사 뒤에 아이가 돈다",
          i_arrival < index("rpg:message:선장|") < i_kid, str(lines))
    kid_lines = [ln for ln in lines if ln.startswith("rpg:message:아이|")]
    check("[I] 아이의 대사 셋 (조개도 제단 얘기도 없는 가지)",
          len(kid_lines) == 3 and kid_lines[0].startswith("rpg:message:아이|북쪽 문은")
          and index("rpg:message:아이|") > i_kid, str(lines[i_kid:] if i_kid >= 0 else lines))
    check("[I] 경로를 다 걷고 스스로 끝난다", bool(lines) and lines[-1] == "rpg:route:done", str(lines[-3:]))

    # [I] 모르는 id는 rpg:error 한 줄이고 게임은 그대로 돈다
    r = run_game(work, rpg_play_env("port_town", at=(14, 21, "up"), route="talk", event="nobody"))
    lines = rpg_lines(r.stdout)
    check("[I] 모르는 id: rpg:error 한 줄",
          [ln for ln in lines if ln.startswith("rpg:error")]
          == ["rpg:error:hold:nobody: 맵 port_town에 이 id의 이벤트 없음"], str(lines[:4]))
    check("[I] 모르는 id: rpg:hold 줄이 없고 끝까지 돈다",
          r.returncode == 0 and not any(ln.startswith("rpg:hold:") for ln in lines)
          and bool(lines) and lines[-1] == "rpg:route:done", f"rc={r.returncode} {lines[-3:]}")

    # [I] HOLD는 AT처럼 첫 맵에만 걸린다: 여관에서 시작하면 kid는 여관에 없어 오류 한 줄이고,
    # 출입구로 항구 마을에 가도 다시 찾거나 다시 알리지 않는다
    r = run_game(work, rpg_play_env("inn", route="down", event="kid"))
    lines = rpg_lines(r.stdout)
    check("[I] 첫 맵에만: 여관에서 한 번 알린다",
          [ln for ln in lines if ln.startswith("rpg:error")]
          == ["rpg:error:hold:kid: 맵 inn에 이 id의 이벤트 없음"], str(lines[:4]))
    check("[I] 첫 맵에만: 항구 마을에 가도 rpg:hold가 없다",
          r.returncode == 0 and index("rpg:map:port_town") >= 0
          and not any(ln.startswith("rpg:hold:") for ln in lines)
          and bool(lines) and lines[-1] == "rpg:route:done", str(lines[-4:]))


def test_rpg_auto_chain():
    """auto 이벤트가 여럿이면 그 사이에도 조작이 잠겨 있다 (M2, docs/plans/m2-rpg-events.md 5.3절).

    항구 마을 맵 파일에 auto 둘을 더하고, 위쪽을 누른 채 결정키로 대사를 넘긴다. 첫 auto 가
    끝난 프레임에 플레이어가 걷기 시작하면 안 된다 (tests/engine/scenes/rpg_auto_chain_scene.lua).
    """
    print("\n[8a] rpg_auto_chain: auto 둘 사이에 걷지 않는다")
    work = make_workdir("rpg_auto_chain_scene.lua")
    link_resources(work, copy=("maps",))
    port = os.path.join(work, "resources", "maps", "port_town.json")
    with open(port, encoding="utf-8") as f:
        data = json.load(f)
    data["events"] += [
        {"id": "auto1", "x": 1, "y": 1, "trigger": "auto",
         "commands": [{"code": "message", "text": "AAA"}]},
        {"id": "auto2", "x": 2, "y": 1, "trigger": "auto",
         "commands": [{"code": "message", "text": "BBB"}]},
    ]
    with open(port, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    env = dict(os.environ)
    env.update({"INITIAL2D_NO_RTP": "1", "INITIAL2D_EXIT_AFTER": "30",
                "INITIAL2D_MAP": "port_town", "INITIAL2D_RPG_STATE": "arrived"})
    result = subprocess.run([GAME], cwd=work, env=env,
                            capture_output=True, text=True, timeout=120)
    log = result.stdout + result.stderr

    def has(needle, name):
        check(name, needle in log, f"'{needle}' 없음 | {log[-500:]}")

    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-300:])
    check("stdout 에 rpg:error 가 없다", "rpg:error" not in result.stdout,
          [ln for ln in result.stdout.splitlines() if "rpg:error" in ln][:3])
    has("start:16,43", "배에서 막 내린 자리에서 시작")
    has("autoA:true", "첫 auto 의 대사")
    has("autoB:true", "둘째 auto 의 대사")
    has("lockedUntilDone:true", "둘째 auto 가 끝날 때까지 한 칸도 걷지 않는다")
    has("movedAfter:true", "auto 가 다 끝난 뒤에는 누르고 있던 방향으로 걷는다")


# 알데바란 자산의 색 (tools/generate_aldebaran_assets.py)
ALD_COAT = (196, 164, 110)     # 카르토의 외투
ALD_MOSS = (64, 84, 60)        # 진흙 땅 윗면의 이끼
ALD_STAR = (232, 96, 66)       # 원경의 붉은 별


def test_aldebaran_scene():
    """알데바란 인수 시나리오 (docs/plans/aldebaran-3-content.md 7절).

    타이틀 → 도입 컷씬 → (일부러 두 번 떨어져) 게임 오버와 다시 하기 → 대쉬와
    턱과 다리 → 전투와 성장 → 체크포인트 부활 → 짐도둑 → 배낭 → 에필로그 →
    결과 창 → 타이틀. 골든은 타이틀과 스테이지 첫 화면 두 장.
    """
    print("\n[9] aldebaran_scene — 알데바란 인수 시나리오 (타이틀부터 에필로그까지)")
    run_aldebaran_scene("aldebaran_scene.lua")


def test_mruby_aldebaran_scene():
    """같은 인수 시나리오를 Ruby 알데바란으로 (S2). 검사도 골든 세 장도 Lua 와 같다."""
    print("\n[9m] mruby_aldebaran_scene — Ruby 알데바란, 같은 시나리오와 같은 골든")
    if not HAS_MRUBY:
        print("  SKIP: 이 빌드에는 mruby 가 없습니다 (brew install mruby 후 cmake 다시 실행)")
        return
    run_aldebaran_scene("mruby_aldebaran_scene.rb")


def run_aldebaran_scene(scene):
    work = make_workdir(scene)
    env = dict(os.environ)
    env["INITIAL2D_EXIT_AFTER"] = "90"
    env["INITIAL2D_NO_RTP"] = "1"     # 골든과 같은 그림으로 (RTP는 기계마다 다르다)
    result = subprocess.run([GAME], cwd=work, env=env,
                            capture_output=True, text=True, timeout=2400)
    log = result.stdout + result.stderr

    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("스크립트 오류 없음", "PANIC" not in log and "attempt to" not in log
          and "uncaught exception" not in log, log[-300:])

    def has(needle, name):
        check(name, needle in log, f"'{needle}' 없음 | {log[-400:]}")

    # [A] 타이틀
    has("titleScene:aldebaran_title", "타이틀 씬으로 시작")
    has("titleMenuOpen:true", "커서 메뉴가 열린다")
    has("titleItems:3 index:1", "항목 3개, 커서는 첫 항목")
    has("titleHelpOpen:true", "조작 방법을 고르면 설명 창이 뜬다")
    has("titleHelpClosed:true", "설명을 끝까지 넘기면 닫힌다")
    has("sceneAfterStart:aldebaran", "시작을 고르면 스테이지로")

    # [B] 도입 컷씬
    has("aldebaranMonsters:16", "적 열여섯이 배치된다 (거미 8, 늑대 6, 검은 늑대, 짐도둑)")
    has("introActive:true", "도입 컷씬이 조작을 잠근다")
    has("introWindow:true", "나레이션 창이 실제로 떠 있다")
    has("introDone:true", "나레이션을 넘기면 조작이 풀린다")
    has("introWindowClosed:true", "넘긴 나레이션 창이 화면에서 사라진다")

    # [C] 게임 오버와 다시 하기
    has("firstDeathLives:1", "맞아 죽으면 목숨이 하나 준다")
    has("gameOverChoice:true", "목숨을 다 잃으면 게임 오버 창")
    has("gameOvers:1", "게임 오버 한 번")
    has("retryLives:2", "다시 하기는 목숨 2로")
    has("retryAtStart:true", "다시 하기는 스테이지 처음부터")

    # [D] 다섯 구간을 지나며 흔적을 줍는다 (플롯이 쌓인다)
    has("aldebaranDash:true", "더블탭 대쉬가 걷기보다 빠르다")
    has("aldebaranFound1:여러 갈래의 발자국", "1구간의 흔적")
    has("aldebaranFound2:다져진 포석", "2구간의 흔적")
    has("aldebaranFound3:버려진 짐수레", "3구간의 흔적")
    has("aldebaranFound4:부서진 우리", "4구간의 흔적 (여기서 옛 숲의 환상)")
    has("aldebaranFound5:네 개의 화두", "5구간의 흔적")
    has("aldebaranFoundCount:5", "다섯을 모두 모았다")
    has("aldebaranFirstKill:exp=5,gold=10", "첫 전갈거미를 잡고 보상을 받는다")
    has("aldebaranLevelUp:", "경험치로 레벨이 오른다")
    has("aldebaranLevelHeal:true", "레벨이 오르면 전량 회복")
    has("aldebaranHurt:", "몬스터에게 맞아 HP가 줄었다")
    has("aldebaranHurtInvuln:true", "맞은 직후에는 무적 시간이 선다")
    has("aldebaranPaused:true", "일시 정지가 열린다 (게임 시간 정지)")
    has("aldebaranResumed:true", "계속 하기로 닫힌다")
    has("aldebaranBerserk:true", "폭주를 익히고 쓴다")

    # [E] 검은 늑대와 짐도둑 두 판, 그리고 에필로그
    has("aldebaranBlackWolfDown:true", "마을의 검은 늑대를 쓰러뜨린다")
    has("aldebaranStone:true", "짐도둑이 돌을 던진다")
    has("aldebaranBossPhase2:true", "절반에서 두 번째 판으로 넘어간다")
    has("aldebaranBossDown:true", "짐도둑을 쓰러뜨리면 배낭이 떨어진다")
    has("aldebaranEpilogue:epilogue", "배낭을 주우면 에필로그")
    has("aldebaranResult:true", "에필로그 뒤에 결과 창")
    # A7: 결과 창을 닫으면 타이틀이 아니라 다음 스테이지로 이어진다.
    # (1-1이 마지막이던 시절의 기대 finalScene:aldebaran_title 을 여기로 확장했다)
    has("aldebaranStageAtEnd:forest", "1-1을 끝냈다")
    has("finalScene:aldebaran", "결과 창을 닫아도 같은 씬이다")
    has("aldebaranNextStage:tomb", "1-2 황제의 무덤으로 이어진다")
    has("aldebaranTombClimate:", "무덤의 첫 방에 섰다")
    has("aldebaranAcceptDone:true", "시나리오 끝까지 통과")

    # A7: 1-2 황제의 무덤을 자율 봇이 주파한다. 좌표를 박지 않은 같은 봇이며,
    # 방마다의 기후가 실제로 걸리는지와 새 적 셋을 만나는지를 본다.
    # 24000틱(400초분)이지만 헤드리스는 실시간이 아니라 벽시계로 12초쯤이다.
    _, r_tomb, _ = run_scene(scene, [], 300,
                             {"INITIAL2D_ALDEBARAN_STOP": "tomb",
                              "INITIAL2D_SKIP_INTRO": "1",
                              "INITIAL2D_NO_RTP": "1",
                              "INITIAL2D_ALDEBARAN_TICKS": "24000"})
    log_tomb = r_tomb.stdout + r_tomb.stderr
    check("무덤 실행 정상 종료", r_tomb.returncode == 0, f"rc={r_tomb.returncode}")
    check("무덤 주파 완료", "tombDone:true" in log_tomb, log_tomb[-500:])
    for needle, name in [
            ("tombClimate:snow:true", "달의 방의 눈이 걸린다"),
            ("tombClimate:light:true", "별들의 방의 빛기둥이 걸린다"),
            ("tombClimate:hail:true", "파괴의 방의 우박이 걸린다"),
            ("tombMet:무덤 번병:true", "무덤 번병을 만난다"),
            ("tombMet:순장된 영혼:true", "순장된 영혼을 만난다"),
            ("tombMet:파괴의 조각:true", "파괴의 조각을 만난다"),
            ("tombClimate:flood:true", "태양의 방의 홍수가 걸린다")]:
        check(name, needle in log_tomb, log_tomb[-800:])
    m_reach = re.search(r"tombReach:(\d+)", log_tomb)
    check("무덤을 끝까지 나아간다", m_reach is not None and int(m_reach.group(1)) > 4700,
          log_tomb[-500:])
    check("아포피스를 쓰러뜨리고 에필로그에 닿는다",
          "tombEnding:epilogue" in log_tomb, log_tomb[-500:])
    # 난이도 신호: 1-1은 같은 봇이 무피해로 지나가지만 무덤은 그렇지 않다.
    m_hurt = re.search(r"tombHurt:(\d+)", log_tomb)
    check("무덤에서는 봇이 여러 번 맞는다", m_hurt is not None and int(m_hurt.group(1)) >= 10,
          log_tomb[-500:])

    # 터치 조작의 끝-끝 검증: 가상 패드로 걷고, 버튼으로 뛰고 베고, 정지 버튼과
    # 항목 누름으로 일시 정지를 여닫는다 (재생기의 마우스 = SDL의 첫 손가락)
    _, r_pad, s_pad = run_scene(scene, [10], 15,
                                {"INITIAL2D_ALDEBARAN_STOP": "touch",
                                 "INITIAL2D_SKIP_INTRO": "1",
                                 "INITIAL2D_NO_RTP": "1",
                                 "INITIAL2D_VPAD": "1"})
    log_pad = r_pad.stdout + r_pad.stderr
    check("터치 실행 정상 종료", r_pad.returncode == 0, f"rc={r_pad.returncode}")
    for needle, name in [("touchControls:true", "터치: 배치가 status로 노출된다"),
                         ("touchWalk:true", "터치: 가상 패드로 걷는다"),
                         ("touchJump:true", "터치: 점프 버튼"),
                         ("touchAttack:true", "터치: 공격 버튼"),
                         ("touchPause:true", "터치: 정지 버튼"),
                         ("touchResume:true", "터치: 항목을 눌러 계속 하기"),
                         ("touchSimul:true", "터치: 패드로 달리면서 점프 (멀티터치)")]:
        check(name, needle in log_pad, log_pad[-400:])
    check("터치 UI 화면 덤프", 10 in s_pad)

    # 회귀 (T1 후속, 2026-08-24 실기 검수): 논리 폭이 384보다 넓은 화면(모바일)에서
    # 홍수 물이 왼쪽 384px에만 그려졌다. 1920x896 창(논리 960x448)으로 태양의 방을
    # 열어, 수면의 물결 띠가 화면 폭 전체(오른쪽 절반 포함)에 있는지 본다.
    _, r_fd, s_fd = run_scene(scene, [30], 40,
                              {"INITIAL2D_ALDEBARAN_STOP": "flood",
                               "INITIAL2D_ALDEBARAN_AT": "4300",
                               "INITIAL2D_SKIP_INTRO": "1",
                               "INITIAL2D_NO_RTP": "1",
                               "INITIAL2D_WINDOW": "1920x896"})
    log_fd = r_fd.stdout + r_fd.stderr
    check("홍수 넓은 화면 실행", r_fd.returncode == 0 and 30 in s_fd,
          f"rc={r_fd.returncode}")
    m_fd = re.search(r"floodY:([0-9.]+)", log_fd)
    check("홍수 수위 노출", m_fd is not None, log_fd[-300:])
    if m_fd is not None and 30 in s_fd:
        img_fd = s_fd[30]
        fd_scale = img_fd.width / 960.0
        wy = float(m_fd.group(1))

        def crest(px):
            r, g, b = px[:3]
            # 물(불투명도 150)을 얹은 픽셀은 배경에 따라 둘 중 하나가 된다:
            # 어두운 배경 위에서는 청록 우세(g와 b가 r보다 뚜렷이 크다),
            # 밝은 모래벽 위에서는 밝은 청록(g와 b가 밝고 g가 r 이상).
            return (g > r + 25 and b > r + 25) or (g >= 130 and b >= 130 and g >= r)

        covered, cols = 0, 0
        y0, y1 = int(wy * fd_scale), int((wy + 8) * fd_scale)
        for x in range(8, 952, 8):
            cols += 1
            sx = int(x * fd_scale)
            if any(crest(img_fd.getpixel((sx, y))) for y in range(y0, y1 + 1)):
                covered += 1
        check("홍수 물이 화면 폭 전체를 덮는다", covered >= cols * 0.9,
              f"{covered}/{cols} (wy={wy})")

    # 골든 1: 스테이지 첫 화면 (컷씬을 생략하고 시간을 얼려 고정한다)
    _, r2, shots = run_scene(scene, [20], 30,
                             {"INITIAL2D_ALDEBARAN_STOP": "start",
                              "INITIAL2D_SKIP_INTRO": "1",
                              "INITIAL2D_NO_RTP": "1"})
    check("스테이지 첫 화면 덤프", 20 in shots, f"rc={r2.returncode}")
    if 20 in shots:
        img = shots[20]
        scale = img.width / 384.0
        coat = count_color_in(img, scale, 44, 360, 70, 380, ALD_COAT, 30)
        check("카르토의 외투 픽셀", coat > 8, f"px={coat}")
        moss = count_color_in(img, scale, 96, 384, 200, 389, ALD_MOSS, 24)
        check("진흙 땅의 이끼 윗면", moss > 80, f"px={moss}")
        star = count_color_in(img, scale, 288, 52, 312, 76, ALD_STAR, 40)
        check("원경의 붉은 별", star > 4, f"px={star}")
        check_golden("aldebaran_forest", img)

    # 골든 3 (A7): 1-2 별들의 방. 빛기둥이 켜진 순간을 잡는다 — 이 스테이지에서
    # 가장 많은 것이 한 화면에 있다 (기후, 공중형 적, 발판, 금별 벽).
    _, r_tg, s_tg = run_scene(scene, [20], 30,
                              {"INITIAL2D_ALDEBARAN_STOP": "start",
                               "INITIAL2D_ALDEBARAN_STAGE": "tomb",
                               "INITIAL2D_ALDEBARAN_AT": "2480",
                               "INITIAL2D_SKIP_INTRO": "1",
                               "INITIAL2D_NO_RTP": "1"})
    check("무덤 별들의 방 덤프", 20 in s_tg, f"rc={r_tg.returncode}")
    if 20 in s_tg:
        img = s_tg[20]
        scale = img.width / 384.0
        gold = count_color_in(img, scale, 0, 0, 384, 448, (214, 176, 84), 40)
        check("무덤의 금박이 보인다", gold > 200, f"px={gold}")
        check_golden("aldebaran_tomb_stars", img)

    # 골든 2: 타이틀 (배경에 글자가 구워져 있고 메뉴 창이 왼쪽 아래에 뜬다)
    _, r3, s_title = run_scene(scene, [20], 30,
                               {"INITIAL2D_ALDEBARAN_STOP": "title",
                                "INITIAL2D_NO_RTP": "1"})
    check("타이틀 화면 덤프", 20 in s_title, f"rc={r3.returncode}")
    if 20 in s_title:
        img = s_title[20]
        scale = img.width / 768.0
        star = count_color_in(img, scale, 570, 100, 630, 160, ALD_STAR, 40)
        check("타이틀의 붉은 별", star > 10, f"px={star}")
        frame = count_color_in(img, scale, 84, 600, 380, 790, SKIN_FRAME_LIGHT, 30)
        check("타이틀 메뉴 창의 테두리", frame > 40, f"px={frame}")
        check_golden("aldebaran_title", img)


def test_resolution():
    """game.json과 INITIAL2D_WINDOW의 해상도 설정, 렌더 배율을 검증한다 (1단계)."""
    print("\n[3] resolution_scene — 게임별 해상도 설정과 렌더 배율")
    work = make_workdir("resolution_scene.lua")
    with open(os.path.join(work, "game.json"), "w") as f:
        f.write('{ "windowWidth": 320, "windowHeight": 240 }')

    env = dict(os.environ)
    env.pop("INITIAL2D_WINDOW", None)
    env.pop("INITIAL2D_SCALE", None)
    env["INITIAL2D_EXIT_AFTER"] = "10"
    r1 = subprocess.run([GAME], cwd=work, env=env,
                        capture_output=True, text=True, timeout=60)
    log1 = r1.stdout + r1.stderr
    check("game.json 해상도 적용 (320x240)", "resolution:320x240" in log1, log1[-200:])
    check("기본 렌더 배율은 1", "scale:1" in log1, log1[-200:])
    # 배율은 창이 아니라 논리 해상도를 나눈다 (320x240 → 160x120)
    check("SetRenderScale(2)가 논리 해상도를 절반으로",
          "scaled2:160x120 scale:2" in log1, log1[-300:])
    check("배율 하한 클램프 (0 → 1)", "clampLow:1" in log1, log1[-300:])
    check("배율 상한 클램프 (999 → 16)", "clampHigh:16" in log1, log1[-300:])
    check("배율을 되돌리면 원래 해상도", "restored:320x240" in log1, log1[-300:])

    env["INITIAL2D_WINDOW"] = "200x100"
    r2 = subprocess.run([GAME], cwd=work, env=env,
                        capture_output=True, text=True, timeout=60)
    log2 = r2.stdout + r2.stderr
    check("INITIAL2D_WINDOW가 game.json보다 우선 (200x100)",
          "resolution:200x100" in log2, log2[-200:])

    # INITIAL2D_SCALE은 시작 배율이다 — 창은 200x100, 논리 해상도는 그 절반
    env["INITIAL2D_SCALE"] = "2"
    r3 = subprocess.run([GAME], cwd=work, env=env,
                        capture_output=True, text=True, timeout=60)
    log3 = r3.stdout + r3.stderr
    check("INITIAL2D_SCALE로 시작 배율 지정 (200x100 → 100x50)",
          "resolution:100x50" in log3 and "scale:2" in log3, log3[-300:])


def test_rtp_charset():
    """변환된 CharSet의 투명 배경을 엔진 렌더링으로 확인한다 (4단계).

    resources/rtp/ 는 정품 보유자만 가지는 로컬 자산이라(라이선스상 커밋 금지)
    없으면 건너뛴다. 같은 이유로 골든 스크린샷도 두지 않고, 배경판 색이 캐릭터
    주변으로 비치는지를 픽셀로 확인한다.
    """
    print("\n[4] rtp_charset_scene — RTP CharSet 투명 배경 (팔레트 0번 처리)")
    charset = os.path.join(REPO, "resources", "rtp", "CharSet", "Actor1.png")
    if not os.path.exists(charset):
        print("  SKIP  resources/rtp/CharSet/Actor1.png 없음"
              " — python3 tools/rtp_import.py 로 생성한다")
        return

    work, result, shots = run_scene("rtp_charset_scene.lua", [20], 30)
    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("변환된 CharSet 로드 성공", "charsetLoaded:true" in log, log[-200:])
    check("정면 서기 프레임 번호 = 25", "charsetFrame:25" in log, log[:200])
    check("프레임 덤프 생성", 20 in shots)
    if 20 not in shots:
        return

    img = shots[20]
    scale = img.width / 768.0

    # 캐릭터 프레임은 (100,200)에 8배 → 192x256. 네 귀퉁이는 팔레트 0번(=투명)이라
    # 배경판 색이 그대로 보여야 한다.
    corners = {
        "좌상": (108, 208), "우상": (276, 208),
        "좌하": (108, 440), "우하": (276, 440),
    }
    for name, (x, y) in corners.items():
        pixel = px(img, scale, x, y)
        check(f"프레임 {name} 귀퉁이로 배경이 비친다", near(pixel, TILE1), str(pixel))

    # 캐릭터 몸통 영역에는 배경판이 아닌 색(옷·머리)이 충분히 있어야 한다 —
    # 전부 투명해져 버리는 반대 방향의 실패를 잡는다.
    body = count_color_in(img, scale, 130, 250, 260, 450, TILE1, invert=True)
    check("캐릭터 몸통이 그려져 있다", body > 500, f"비배경 픽셀={body}")

    # 스프라이트 바깥은 여전히 배경판이다 (프레임 분할이 어긋나면 깨진다)
    outside = px(img, scale, 60, 480)
    check("스프라이트 밖은 배경판 색", near(outside, TILE1), str(outside))

    shutil.copy(os.path.join(work, "shot_0020.bmp"), "/tmp/initial2d_rtp_charset.bmp")


def main():
    if not os.path.exists(GAME):
        print(f"실행 파일이 없습니다: {GAME} — 먼저 cmake --build build 를 실행하세요")
        sys.exit(2)

    global HAS_MRUBY
    HAS_MRUBY = "mruby" in engine_features()

    tests = [
        test_lua_units,
        test_mruby_units,
        test_assert_scene,
        test_mruby_assert_scene,
        test_input_events_lua,
        test_input_events_mruby,
        test_mruby_flappy_scene,
        test_lua_error_scene,
        test_mruby_binding_guard,
        test_mruby_cpp_exception,
        test_hot_reload_error,
        test_scene_flappy_lua,
        test_scene_flappy_mruby,
        test_scene_loader_lua,
        test_scene_loader_mruby,
        test_scene_params_lua,
        test_scene_params_mruby,
        test_tilemap_scene,
        test_rpg_walk_scene,
        test_rpg_event_scene,
        test_rpg_dialogue_scene,
        test_rpgdemo_scene,
        test_rpg_play_here,
        test_rpg_auto_chain,
        test_aldebaran_scene,
        test_mruby_aldebaran_scene,
        test_resolution,
        test_rtp_charset,
    ]
    # --only=mruby_units,assert_scene 처럼 이름 조각으로 골라 돌린다 (빠른 되풀이용).
    only = [a[len("--only="):] for a in sys.argv[1:] if a.startswith("--only=")]
    if only:
        wanted = [w for w in only[-1].split(",") if w]
        tests = [t for t in tests if any(w in t.__name__ for w in wanted)]
        if not tests:
            print(f"--only={only[-1]}: 맞는 테스트가 없습니다")
            sys.exit(2)
    for t in tests:
        fails_before = len(FAILS)
        t()
        settle_workdirs(failed=len(FAILS) > fails_before)

    print(f"\n결과: {len(PASSES)} PASS / {len(FAILS)} FAIL")
    if FAILS:
        for f in FAILS:
            print(f"  - {f}")
        sys.exit(1)


if __name__ == "__main__":
    main()
