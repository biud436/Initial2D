#!/usr/bin/env python3
"""Initial2D 엔진 테스트 러너 (macOS/SDL2 백엔드).

커밋된 리소스와 Lua 테스트 씬(tests/engine/scenes/)만으로 엔진의
렌더링·애니메이션·텍스트·프리미티브·오디오·입력 API를 프레임 덤프의
픽셀 검증으로 확인한다. 게임 실행 파일(build/Initial2D)이 필요하다.

사용법: python3 tests/run_engine_tests.py [빌드된 실행 파일 경로]
"""

import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_args = [a for a in sys.argv[1:] if not a.startswith("--")]
GAME = _args[0] if _args else os.path.join(REPO, "build", "Initial2D")

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

PASSES = []
FAILS = []


def check(name, cond, detail=""):
    if cond:
        PASSES.append(name)
        print(f"  PASS  {name}")
    else:
        FAILS.append(name)
        print(f"  FAIL  {name}  {detail}")


def make_workdir(scene):
    work = tempfile.mkdtemp(prefix="initial2d-test-")
    os.symlink(os.path.join(REPO, "resources"), os.path.join(work, "resources"))
    scripts = os.path.join(work, "scripts")
    os.makedirs(scripts)
    # 저자의 Lua 모듈은 그대로 사용한다
    for module in ("image.lua", "Font.lua"):
        src = os.path.join(REPO, "scripts", module)
        if os.path.exists(src):
            shutil.copy(src, scripts)
    shutil.copytree(os.path.join(REPO, "scripts", "ui"), os.path.join(scripts, "ui"))
    shutil.copytree(os.path.join(REPO, "scripts", "rpg"), os.path.join(scripts, "rpg"))
    shutil.copy(os.path.join(REPO, "tests", "engine", "scenes", scene),
                os.path.join(scripts, "main.lua"))
    return work


def run_scene(scene, frames, exit_after, extra_env=None):
    work = make_workdir(scene)
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


def check_golden(name, img):
    """캡처를 논리 해상도로 정규화해 tests/golden/<name>.png 와 비교한다."""
    norm = img.resize(LOGICAL_SIZE, Image.BILINEAR)
    path = os.path.join(GOLDEN_DIR, f"{name}.png")
    if UPDATE_GOLDEN or not os.path.exists(path):
        os.makedirs(GOLDEN_DIR, exist_ok=True)
        newly = not os.path.exists(path)
        norm.save(path)
        print(f"  GOLDEN {'생성' if newly else '갱신'}: {os.path.relpath(path, REPO)}"
              f" — 눈으로 확인한 뒤 커밋할 것")
        return
    golden = Image.open(path).convert("RGB")
    a, b = norm.tobytes(), golden.tobytes()
    total = len(a) // 3
    bad = 0
    for i in range(0, len(a), 3):
        if (abs(a[i] - b[i]) > GOLDEN_PIXEL_TOL
                or abs(a[i + 1] - b[i + 1]) > GOLDEN_PIXEL_TOL
                or abs(a[i + 2] - b[i + 2]) > GOLDEN_PIXEL_TOL):
            bad += 1
    ratio = bad / total
    check(f"골든 일치: {name}", ratio <= GOLDEN_DIFF_RATIO,
          f"차이 픽셀 {ratio:.2%} (허용 {GOLDEN_DIFF_RATIO:.0%}) — 의도된 변경이면 --update-golden")


WHITE = (255, 255, 255)
TILE1 = (216, 145, 37)   # tile1.png 단색
RED = (255, 0, 0)


def test_assert_scene():
    print("\n[1] assert_scene — 렌더링·애니메이션·텍스트·프리미티브·오디오")
    frames = [12, 35, 60]
    work, result, shots = run_scene("assert_scene.lua", frames, 70)

    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "error" not in log.lower().replace("iccp", ""),
          log[-200:])
    # 엔진의 커스텀 print는 인자를 구분자 없이 이어서 출력한다
    check("폰트 로드 성공", "fontReady:true" in log, log[:200])
    check("오디오 볼륨 질의(BGM+SE 재생 후)", "volume:128" in log)
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

    check_golden("assert_scene_f35", img)
    shutil.copy(os.path.join(work, "shot_0035.bmp"), "/tmp/initial2d_assert_scene.bmp")


def test_lua_units():
    """tests/lua/ 의 Lua 단위 테스트를 엔진 바이너리로 실행한다 (09-testing.md 3.2절)."""
    print("\n[0] lua_unit_tests — Lua 단위 테스트 (엔진 VM에서 실행)")
    work = tempfile.mkdtemp(prefix="initial2d-luatest-")
    os.symlink(os.path.join(REPO, "resources"), os.path.join(work, "resources"))
    # 포맷 계약 픽스처 (09-testing.md 3.5절) — 에디터 저장소와 공유하는 파일
    shutil.copytree(os.path.join(REPO, "tests", "fixtures"),
                    os.path.join(work, "fixtures"))
    scripts = os.path.join(work, "scripts")
    luatests = os.path.join(scripts, "luatests")
    shutil.copytree(os.path.join(REPO, "tests", "lua"), luatests)
    shutil.move(os.path.join(luatests, "run_tests.lua"),
                os.path.join(scripts, "main.lua"))
    # 테스트 대상 공용 Lua 모듈 (scripts/image.lua, scripts/ui/*, scripts/rpg/*)
    shutil.copy(os.path.join(REPO, "scripts", "image.lua"), scripts)
    shutil.copytree(os.path.join(REPO, "scripts", "ui"), os.path.join(scripts, "ui"))
    shutil.copytree(os.path.join(REPO, "scripts", "rpg"), os.path.join(scripts, "rpg"))

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

    test_lua_units()
    test_assert_scene()
    test_tilemap_scene()
    test_rpg_walk_scene()
    test_resolution()
    test_rtp_charset()

    print(f"\n결과: {len(PASSES)} PASS / {len(FAILS)} FAIL")
    if FAILS:
        for f in FAILS:
            print(f"  - {f}")
        sys.exit(1)


if __name__ == "__main__":
    main()
