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
GAME = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "build", "Initial2D")

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
    for module in ("image.lua", "tilemap.lua", "Font.lua"):
        src = os.path.join(REPO, "scripts", module)
        if os.path.exists(src):
            shutil.copy(src, scripts)
    shutil.copy(os.path.join(REPO, "tests", "engine", "scenes", scene),
                os.path.join(scripts, "main.lua"))
    return work


def run_scene(scene, frames, exit_after):
    work = make_workdir(scene)
    env = dict(os.environ)
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


def count_color_in(img, scale, x0, y0, x1, y1, target, tol=28):
    n = 0
    for yy in range(int(y0 * scale), int(y1 * scale), 2):
        for xx in range(int(x0 * scale), int(x1 * scale), 2):
            if near(img.getpixel((xx, yy)), target, tol):
                n += 1
    return n


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

    shutil.copy(os.path.join(work, "shot_0035.bmp"), "/tmp/initial2d_assert_scene.bmp")


def test_tilemap_scene():
    print("\n[2] tilemap_scene — 저자 Lua 타일맵 모듈 (회전·반투명 타일 16개)")
    work, result, shots = run_scene("tilemap_scene.lua", [30], 40)

    log = result.stdout + result.stderr
    check("프로세스 정상 종료", result.returncode == 0, f"rc={result.returncode}")
    check("Lua 오류 없음", "PANIC" not in log and "attempt to" not in log, log[-200:])
    check("프레임 덤프 생성", 30 in shots)

    if 30 in shots:
        img = shots[30]
        scale = img.width / 768.0
        # 타일 영역(0..192 논리)에 비-배경 픽셀이 충분히 존재해야 함
        tiles = 0
        for yy in range(0, int(192 * scale), 3):
            for xx in range(0, int(192 * scale), 3):
                if not near(img.getpixel((xx, yy)), WHITE, 10):
                    tiles += 1
        check("타일 렌더링(비-배경 픽셀)", tiles > 300, f"px={tiles}")
        shutil.copy(os.path.join(work, "shot_0030.bmp"), "/tmp/initial2d_tilemap_scene.bmp")


def main():
    if not os.path.exists(GAME):
        print(f"실행 파일이 없습니다: {GAME} — 먼저 cmake --build build 를 실행하세요")
        sys.exit(2)

    test_assert_scene()
    test_tilemap_scene()

    print(f"\n결과: {len(PASSES)} PASS / {len(FAILS)} FAIL")
    if FAILS:
        for f in FAILS:
            print(f"  - {f}")
        sys.exit(1)


if __name__ == "__main__":
    main()
