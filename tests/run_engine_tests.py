#!/usr/bin/env python3
"""Initial2D 엔진 테스트 러너 (macOS/SDL2 백엔드).

커밋된 리소스와 Lua 테스트 씬(tests/engine/scenes/)만으로 엔진의
렌더링·애니메이션·텍스트·프리미티브·오디오·입력 API를 프레임 덤프의
픽셀 검증으로 확인한다. 게임 실행 파일(build/Initial2D)이 필요하다.

사용법: python3 tests/run_engine_tests.py [빌드된 실행 파일 경로]
"""

import os
import re
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


def stage_scripts(work):
    """저자의 scripts/ 를 통째로 워크 디렉터리에 복사한다.

    씬 테스트는 main.lua만 갈아 끼우고 나머지는 실물을 그대로 쓴다 (게임이
    실제로 여는 파일과 테스트가 여는 파일이 같아야 한다). 8단계의 데모 씬
    테스트는 scripts/games/ 까지 진짜를 얹어 돌린다.
    """
    scripts = os.path.join(work, "scripts")
    shutil.copytree(os.path.join(REPO, "scripts"), scripts)
    os.remove(os.path.join(scripts, "main.lua"))   # 테스트 씬이 대신 들어온다
    return scripts


def make_workdir(scene):
    work = tempfile.mkdtemp(prefix="initial2d-test-")
    os.symlink(os.path.join(REPO, "resources"), os.path.join(work, "resources"))
    scripts = stage_scripts(work)
    # 입력 재생기 (09-testing.md 3.4절) — 씬 테스트가 사람 대신 키를 누른다
    luatests = os.path.join(scripts, "luatests")
    os.makedirs(luatests, exist_ok=True)
    shutil.copy(os.path.join(REPO, "tests", "lua", "input_replay.lua"), luatests)
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
    # 테스트 대상은 저자의 scripts/ 전부다 (main.lua만 러너로 갈아 끼운다)
    scripts = stage_scripts(work)
    luatests = os.path.join(scripts, "luatests")
    shutil.copytree(os.path.join(REPO, "tests", "lua"), luatests)
    shutil.move(os.path.join(luatests, "run_tests.lua"),
                os.path.join(scripts, "main.lua"))

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
    work = make_workdir("aldebaran_scene.lua")
    env = dict(os.environ)
    env["INITIAL2D_EXIT_AFTER"] = "90"
    env["INITIAL2D_NO_RTP"] = "1"     # 골든과 같은 그림으로 (RTP는 기계마다 다르다)
    result = subprocess.run([GAME], cwd=work, env=env,
                            capture_output=True, text=True, timeout=2400)
    log = result.stdout + result.stderr

    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-300:])

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
    _, r_tomb, _ = run_scene("aldebaran_scene.lua", [], 300,
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
    _, r_pad, s_pad = run_scene("aldebaran_scene.lua", [10], 15,
                                {"INITIAL2D_ALDEBARAN_STOP": "touch",
                                 "INITIAL2D_SKIP_INTRO": "1",
                                 "INITIAL2D_NO_RTP": "1",
                                 "INITIAL2D_VPAD": "1"})
    log_pad = r_pad.stdout + r_pad.stderr
    check("터치 실행 정상 종료", r_pad.returncode == 0, f"rc={r_pad.returncode}")
    for needle, name in [("touchWalk:true", "터치: 가상 패드로 걷는다"),
                         ("touchJump:true", "터치: 점프 버튼"),
                         ("touchAttack:true", "터치: 공격 버튼"),
                         ("touchPause:true", "터치: 정지 버튼"),
                         ("touchResume:true", "터치: 항목을 눌러 계속 하기")]:
        check(name, needle in log_pad, log_pad[-400:])
    check("터치 UI 화면 덤프", 10 in s_pad)

    # 골든 1: 스테이지 첫 화면 (컷씬을 생략하고 시간을 얼려 고정한다)
    _, r2, shots = run_scene("aldebaran_scene.lua", [20], 30,
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
    _, r_tg, s_tg = run_scene("aldebaran_scene.lua", [20], 30,
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
    _, r3, s_title = run_scene("aldebaran_scene.lua", [20], 30,
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

    test_lua_units()
    test_assert_scene()
    test_tilemap_scene()
    test_rpg_walk_scene()
    test_rpg_event_scene()
    test_rpg_dialogue_scene()
    test_rpgdemo_scene()
    test_aldebaran_scene()
    test_resolution()
    test_rtp_charset()

    print(f"\n결과: {len(PASSES)} PASS / {len(FAILS)} FAIL")
    if FAILS:
        for f in FAILS:
            print(f"  - {f}")
        sys.exit(1)


if __name__ == "__main__":
    main()
