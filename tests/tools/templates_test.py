#!/usr/bin/env python3
"""새 프로젝트 템플릿 검사 (R4, docs/plans/r4-dist-build.md).

타일맵 템플릿(resources/templates/tilemap/)이 규칙대로인가:
  - map.json 이 tools/mapfile.py 로 읽히고 다시 쓰면 바이트가 같다 (에디터의 serializeMap 과 같은 형식)
  - 맵 포맷 v2, 16px 타일 48x56 칸(768x896), 레이어 둘과 통행 레이어, 오브젝트 없음.
    타일셋은 git 이 추적하는 파일이고 모든 gid 가 그 안에 있다
  - 표식 타일(44, 모래 #d8c880)은 맵에 쓰이지 않고, 표식을 칠해 보는 칸(24, 28)은 deco 가 비어 있다
  - scene.json 은 tilemap 오브젝트 하나, map-objects.json 은 marker 타입 하나이고 play 절이 없다
  - 새 프로젝트처럼 늘어놓은 임시 폴더에서 엔진이 템플릿의 진입 파일로 그 씬을 연다
    (씬 로더의 검사를 통과하고 종료 코드 0). Lua 와 Ruby 둘 다. 칸(24, 28)을 표식 타일로 칠하면 스크린샷의 그 칸이 표식 색이다
템플릿 묶음의 목록과 도구:
  - tools/templates_list.txt 의 파일이 다 있고, git 이 추적하지 않는 것은 플래피 그림 넷뿐이다
  - tools/pack_templates.py 는 빠진 파일이 있으면 실패하고, MANIFEST 에 커밋과 크기와 sha256 과 generated 를 적는다

사용법: python3 tests/tools/templates_test.py [엔진 실행 파일]      기본 build/Initial2D
종료 코드: 0 전부 통과, 1 실패가 있다
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapfile  # noqa: E402

from PIL import Image  # noqa: E402

TEMPLATE = "resources/templates/tilemap"
TILESET = "resources/tiles/tileset16-8x13.png"
TILE = 16
MAP_W, MAP_H = 48, 56
SCREEN = (768, 896)
MARKER_TILE = 44                  # 0 부터 센 타일 번호 (gid 45). 모래, 256 픽셀 중 251 개가 이 색
MARKER_RGB = (0xD8, 0xC8, 0x80)
MARKER_CELL = (24, 28)            # 에디터의 검사처럼 표식을 칠해 보는 칸
GRASS_RGB = (0x40, 0xB0, 0x80)
GENERATED = {"resources/background_768x896.png", "resources/ground_768x64.png",
             "resources/bird_276x64.png", "resources/object_52x271.png"}

# 새 프로젝트 안의 자리 (에디터의 sync-engine-templates.mjs 가 정하는 to 와 같게 둔다)
COMMON = {
    "lua": {
        "scripts/lua/scene_loader.lua": "scripts/lua/scene_loader.lua",
        "scripts/lua/scene_types/tilemap.lua": "scripts/lua/scene_types/tilemap.lua",
        "resources/templates/main.lua": "scripts/lua/main.lua",
    },
    "ruby": {
        "scripts/ruby/scene_loader.rb": "scripts/ruby/scene_loader.rb",
        "scripts/ruby/scene_types/tilemap.rb": "scripts/ruby/scene_types/tilemap.rb",
        "resources/templates/main.rb": "scripts/ruby/main.rb",
    },
}
TILEMAP_FILES = {
    "resources/fonts/hangul.fnt": "resources/fonts/hangul.fnt",
    "resources/fonts/hangul_0.png": "resources/fonts/hangul_0.png",
    TEMPLATE + "/scene.json": "resources/scenes/main.json",
    TEMPLATE + "/map.json": "resources/maps/start.json",
    TEMPLATE + "/map-objects.json": "resources/schema/map-objects.json",
    TILESET: TILESET,
}

PASSES = []
FAILS = []


def check(name, cond, detail=""):
    if cond:
        PASSES.append(name)
        print("  PASS  " + name)
    else:
        FAILS.append(name)
        print("  FAIL  %s  %s" % (name, detail))


def read(rel):
    with open(os.path.join(REPO, rel), encoding="utf-8") as f:
        return f.read()


def git_tracked(paths):
    out = subprocess.run(["git", "-C", REPO, "ls-files", "-z", "--", *paths],
                         capture_output=True, text=True, check=True).stdout
    return set(out.split("\0")) - {""}


def test_map():
    print("[맵] %s/map.json" % TEMPLATE)
    text = read(TEMPLATE + "/map.json")
    data = json.loads(text)
    check("mapfile.py 로 다시 쓰면 바이트가 같다", mapfile.dumps(data) == text,
          "python3 tools/mapfile.py format %s/map.json" % TEMPLATE)
    check("맵 포맷 v2", data.get("version") == 2)
    check("48x56 칸, 16px 타일 (화면 768x896)",
          (data.get("width"), data.get("height"), data.get("tileWidth"), data.get("tileHeight"))
          == (MAP_W, MAP_H, TILE, TILE)
          and (MAP_W * TILE, MAP_H * TILE) == SCREEN)
    layers = data.get("layers", [])
    check("레이어 둘 (ground, deco)", [l.get("name") for l in layers] == ["ground", "deco"])
    n = MAP_W * MAP_H
    check("레이어마다 칸 수가 맞다", all(len(l.get("data", [])) == n for l in layers))
    collision = data.get("collision")
    check("통행 레이어가 있고 0 과 1 뿐이다",
          isinstance(collision, list) and len(collision) == n and set(collision) <= {0, 1})
    check("오브젝트가 없다", not data.get("objects"))
    check("이벤트가 없다", "events" not in data)

    tilesets = data.get("tilesets", [])
    check("타일셋 하나, 경로는 %s" % TILESET,
          len(tilesets) == 1 and tilesets[0].get("image") == TILESET and tilesets[0].get("firstGid") == 1)
    check("타일셋은 git 이 추적하는 파일이다", TILESET in git_tracked([TILESET]))
    img = Image.open(os.path.join(REPO, TILESET)).convert("RGBA")
    cols, rows = img.width // TILE, img.height // TILE
    check("타일셋의 열 수가 맞다", tilesets and tilesets[0].get("columns") == cols,
          "columns=%s, 그림은 %d열" % (tilesets[0].get("columns") if tilesets else None, cols))
    gids = {g for l in layers for g in l.get("data", [])}
    check("모든 gid 가 타일셋 안이다", max(gids) <= cols * rows and min(gids) >= 0, "gid %s" % sorted(gids))

    tx, ty = (MARKER_TILE % cols) * TILE, (MARKER_TILE // cols) * TILE
    tile = img.crop((tx, ty, tx + TILE, ty + TILE))
    same = sum(1 for p in tile.getdata() if p[:3] == MARKER_RGB and p[3] == 255)
    check("표식 타일 %d 이 #%02x%02x%02x 로 거의 칠해져 있다" % ((MARKER_TILE,) + MARKER_RGB), same >= 240,
          "%d/256" % same)
    check("표식 타일은 맵에 쓰이지 않는다", MARKER_TILE + 1 not in gids)
    cx, cy = MARKER_CELL
    check("표식을 칠해 보는 칸 %s 의 deco 가 비고 통행할 수 있다" % (MARKER_CELL,),
          layers[1]["data"][cy * MAP_W + cx] == 0 and collision[cy * MAP_W + cx] == 0)


def test_scene_and_schema():
    print("[씬과 스키마]")
    scene = json.loads(read(TEMPLATE + "/scene.json"))
    objs = scene.get("objects", [])
    check("씬 포맷 v1", scene.get("version") == 1)
    check("오브젝트는 tilemap 하나 (id map)",
          len(objs) == 1 and objs[0].get("id") == "map" and objs[0].get("type") == "tilemap")
    props = objs[0].get("props", {}) if objs else {}
    check("props.map 은 resources/maps/start.json, groundLayers 1",
          props.get("map") == "resources/maps/start.json" and props.get("groundLayers") == 1)

    schema = json.loads(read(TEMPLATE + "/map-objects.json"))
    types = schema.get("types", [])
    check("스키마 v1", schema.get("version") == 1)
    check("타입은 marker 하나, 점 모양", len(types) == 1 and types[0].get("type") == "marker"
          and types[0].get("shape") == "point")
    check("marker 의 색은 에디터가 아는 이름", types and types[0].get("color") in
          ("accent", "danger", "warning", "success", "muted"))
    fields = types[0].get("fields", []) if types else []
    check("칸은 label (글) 하나", [(f.get("name"), f.get("type")) for f in fields] == [("label", "string")])
    check("play 절이 없다", "play" not in schema)


def stage_project(lang, paint_marker):
    work = tempfile.mkdtemp(prefix="initial2d-template-")
    for src, dst in list(COMMON[lang].items()) + list(TILEMAP_FILES.items()):
        os.makedirs(os.path.dirname(os.path.join(work, dst)), exist_ok=True)
        shutil.copy(os.path.join(REPO, src), os.path.join(work, dst))
    if paint_marker:
        path = os.path.join(work, "resources", "maps", "start.json")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        cx, cy = MARKER_CELL
        data["layers"][0]["data"][cy * MAP_W + cx] = MARKER_TILE + 1
        with open(path, "w", encoding="utf-8") as f:
            f.write(mapfile.dumps(data))
    return work


def cell_count(img, cell, rgb, tol=8):
    scale = img.width / SCREEN[0]
    x0, y0 = int(cell[0] * TILE * scale), int(cell[1] * TILE * scale)
    size = int(TILE * scale)
    n = 0
    for y in range(y0, y0 + size):
        for x in range(x0, x0 + size):
            p = img.getpixel((x, y))
            if all(abs(a - b) <= tol for a, b in zip(p, rgb)):
                n += 1
    return n * 256 // (size * size)


def run_template(game, lang, paint_marker):
    work = stage_project(lang, paint_marker)
    try:
        env = dict(os.environ)
        env.setdefault("SDL_VIDEODRIVER", "dummy")
        env.setdefault("SDL_AUDIODRIVER", "dummy")
        env["INITIAL2D_SCREENSHOT"] = os.path.join(work, "shot_%04ld.bmp")
        env["INITIAL2D_SCREENSHOT_FRAME"] = "5"
        env["INITIAL2D_EXIT_AFTER"] = "10"
        result = subprocess.run([game], cwd=work, env=env, capture_output=True, text=True, timeout=120)
        shot = os.path.join(work, "shot_0005.bmp")
        img = Image.open(shot).convert("RGB") if os.path.exists(shot) else None
        return result, img
    finally:
        shutil.rmtree(work, ignore_errors=True)


def test_engine(game):
    print("[엔진] %s" % game)
    if not os.path.exists(game):
        check("엔진 실행 파일이 있다", False, "%s (cmake --build build)" % game)
        return
    features = subprocess.run([game, "--features"], capture_output=True, text=True, timeout=30).stdout.split()
    for lang in ("lua", "ruby"):
        if lang == "ruby" and "mruby" not in features:
            print("  SKIP  Ruby: 이 빌드에는 mruby 가 없다")
            continue
        label = "Lua" if lang == "lua" else "Ruby"
        result, img = run_template(game, lang, paint_marker=False)
        log = result.stdout + result.stderr
        check("%s: 템플릿 씬을 열고 종료 코드 0" % label, result.returncode == 0,
              "rc=%d | %s" % (result.returncode, log[-300:]))
        check("%s: 오류 줄이 없다" % label, "error" not in log.lower().replace("iccp", ""), log[-300:])
        check("%s: 스크린샷" % label, img is not None)
        if img is not None:
            grass = cell_count(img, MARKER_CELL, GRASS_RGB)
            check("%s: 칸 %s 에 잔디가 그려져 있다" % (label, MARKER_CELL), grass >= 200, "%d/256" % grass)
            fence = cell_count(img, (5, 1), GRASS_RGB)
            check("%s: deco 레이어(울타리)가 위에 그려져 있다" % label, fence < 200, "잔디 %d/256" % fence)

        result, img = run_template(game, lang, paint_marker=True)
        check("%s: 표식을 칠한 맵도 종료 코드 0" % label, result.returncode == 0,
              "rc=%d | %s" % (result.returncode, (result.stdout + result.stderr)[-300:]))
        if img is not None:
            marker = cell_count(img, MARKER_CELL, MARKER_RGB)
            check("%s: 칠한 칸이 표식 색이다" % label, marker >= 240, "%d/256" % marker)
        else:
            check("%s: 칠한 맵의 스크린샷" % label, False)


def test_list_and_pack():
    print("[템플릿 묶음]")
    with open(os.path.join(REPO, "tools", "templates_list.txt"), encoding="utf-8") as f:
        paths = [l.strip() for l in f if l.strip() and not l.strip().startswith("#")]
    missing = [p for p in paths if not os.path.isfile(os.path.join(REPO, p))]
    check("목록의 파일이 다 있다", not missing,
          "%s (생성물이면 python3 tools/generate_placeholder_assets.py)" % missing)
    untracked = set(paths) - git_tracked(paths)
    check("git 이 추적하지 않는 것은 플래피 그림 넷뿐이다", untracked == GENERATED, sorted(untracked ^ GENERATED))
    for rel in list(TILEMAP_FILES) + [s for m in COMMON.values() for s in m]:
        if rel not in paths:
            check("목록에 %s" % rel, False)

    tmp = tempfile.mkdtemp(prefix="initial2d-pack-")
    try:
        bad_list = os.path.join(tmp, "bad.txt")
        with open(bad_list, "w", encoding="utf-8") as f:
            f.write("resources/templates/scene.json\nresources/no-such-file.png\n")
        out = os.path.join(tmp, "bad.zip")
        r = subprocess.run([sys.executable, os.path.join(REPO, "tools", "pack_templates.py"),
                            "--list", bad_list, "--out", out, "--allow-dirty"], capture_output=True, text=True)
        check("pack_templates: 빠진 파일이 있으면 실패한다", r.returncode == 1 and not os.path.exists(out),
              "rc=%d" % r.returncode)

        small = ["resources/templates/scene.json", "resources/fonts/hangul.fnt"]
        good_list = os.path.join(tmp, "good.txt")
        with open(good_list, "w", encoding="utf-8") as f:
            f.write("# 주석\n\n" + "\n".join(small) + "\n")
        out = os.path.join(tmp, "good.zip")
        r = subprocess.run([sys.executable, os.path.join(REPO, "tools", "pack_templates.py"),
                            "--list", good_list, "--out", out, "--allow-dirty"], capture_output=True, text=True)
        check("pack_templates: 묶음을 만든다", r.returncode == 0 and os.path.exists(out), r.stderr[-300:])
        if os.path.exists(out):
            with zipfile.ZipFile(out) as zf:
                names = zf.namelist()
                manifest = json.loads(zf.read("MANIFEST.json"))
                blobs = {n: zf.read(n) for n in small if n in names}
            head = subprocess.run(["git", "-C", REPO, "rev-parse", "HEAD"], capture_output=True,
                                  text=True).stdout.strip()
            check("MANIFEST.json 이 맨 앞, 파일은 엔진 경로 그대로", names == ["MANIFEST.json"] + small, names)
            check("MANIFEST 의 engineCommit 이 HEAD (40자)", manifest.get("engineCommit") == head and len(head) == 40)
            entries = manifest.get("files", [])
            ok = [e.get("path") for e in entries] == small and all(
                e.get("size") == len(blobs.get(e["path"], b""))
                and e.get("sha256") == hashlib.sha256(blobs.get(e["path"], b"")).hexdigest()
                and e.get("generated") is False for e in entries)
            check("MANIFEST 의 크기, sha256, generated", ok, entries)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    game = os.path.abspath(args[0]) if args else os.path.join(REPO, "build", "Initial2D")
    test_map()
    test_scene_and_schema()
    test_engine(game)
    test_list_and_pack()
    print("templates_test: %d PASS / %d FAIL" % (len(PASSES), len(FAILS)))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
