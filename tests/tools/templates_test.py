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
RPG 템플릿(templates_list.txt 의 "RPG 템플릿" 묶음, 데모 「떠나기 전에」의 항구 마을과 여관):
  - 템플릿의 rpg-game.json 은 엔진의 것에서 묶음에 든 맵만 남긴 것이고, 맵 파일과 정의 파일과 타일셋,
    이벤트가 가리키는 맵과 씬과 파일, Lua 의 require 와 리소스 경로, 글꼴의 그림 페이지가 모두 묶음 안이다
  - 묶음의 파일만 늘어놓은 임시 폴더(진입 파일은 scripts/lua/main.lua, 설정은 resources/data/rpg-game.json)에서
    엔진이 타이틀을 그리고(골든 rpgdemo_title), 자동 시연으로 "시작"을 골라 맵 씬으로 넘어가고, 에디터의
    "이 맵에서 실행" 변수(play.env)로 항구 마을을 그리고(골든 rpgdemo_town 의 맵 부분), 자동 재생(play.probe)으로
    여관에서 항구 마을로 옮겨 간다. 모두 종료 코드 0 이고 오류 줄이 없다
템플릿 묶음의 목록과 도구:
  - tools/templates_list.txt 의 파일이 다 있고, git 이 추적하지 않는 것은 플래피 그림 넷뿐이다
  - tools/pack_templates.py 는 빠진 파일이 있으면 실패하고, MANIFEST 에 커밋과 크기와 sha256 과 generated 를 적는다

사용법: python3 tests/tools/templates_test.py [엔진 실행 파일]      기본 build/Initial2D
종료 코드: 0 전부 통과, 1 실패가 있다
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapfile  # noqa: E402
sys.path.insert(0, os.path.join(REPO, "tests"))
import run_engine_tests as engine_tests  # noqa: E402  골든의 정규화와 허용 오차를 같이 쓴다

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

# RPG 템플릿: templates_list.txt 에서 이 이름으로 시작하는 묶음(빈 줄로 나뉜 한 덩어리)
RPG_SECTION = "RPG 템플릿"
RPG_TEMPLATE = "resources/templates/rpg"
ENGINE_RPG_GAME = "resources/data/rpg-game.json"
# 새 프로젝트 안의 자리가 엔진 경로와 다른 파일. 나머지는 엔진 경로 그대로 둔다
RPG_PLACE = {
    RPG_TEMPLATE + "/main.lua": "scripts/lua/main.lua",
    RPG_TEMPLATE + "/rpg-game.json": ENGINE_RPG_GAME,
}
# 타이틀과 두 씬이 쓰는 32px 글꼴은 공통 묶음(한글 비트맵 폰트)에서 온다
RPG_COMMON = ["resources/fonts/hangul.fnt", "resources/fonts/hangul_0.png"]
# 코드에 경로가 있지만 싣지 않는 파일: RTP 후보(재배포 금지)와 여관의 개인 소장 곡(없으면 bless.ogg)
RPG_OPTIONAL_PREFIX = "./resources/rtp/"
RPG_OPTIONAL = {"./resources/audio/inn.ogg"}
# 맵 씬 골든과 견주는 논리 영역 (384x448 중). 위쪽의 안내 글, 배회하는 아이의 구역(맵 y 19..24),
# 아래쪽의 대화창을 뺀 맵 부분이다 (집, 광장, 생선 장수, 짐 상자)
TOWN_REGION = (0, 84, 384, 330)

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


def list_sections():
    """templates_list.txt 를 빈 줄로 나눈 묶음들. [(첫 주석 줄에서 '# ' 를 뗀 이름, 경로 목록)]"""
    sections = []
    for block in read("tools/templates_list.txt").split("\n\n"):
        lines = [l.strip() for l in block.splitlines() if l.strip()]
        if not lines:
            continue
        title = lines[0][1:].strip() if lines[0].startswith("#") else ""
        sections.append((title, [l for l in lines if not l.startswith("#")]))
    return sections


def rpg_section():
    for title, paths in list_sections():
        if title.startswith(RPG_SECTION):
            return paths
    return []


def rpg_files():
    """RPG 템플릿으로 새 프로젝트에 놓는 엔진 경로: 묶음 전부와 공통 글꼴"""
    return rpg_section() + RPG_COMMON


def rpg_dest(rel):
    return RPG_PLACE.get(rel, rel)


def bare(path):
    return path[2:] if isinstance(path, str) and path.startswith("./") else path


def json_strings(value):
    """JSON 값 안의 문자열 전부 (이벤트가 가리키는 파일 경로를 찾는다)"""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from json_strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from json_strings(v)


def json_commands(value, code):
    """JSON 값 안의 커맨드 가운데 code 가 같은 것 전부 (가지 안까지)"""
    if isinstance(value, dict):
        if value.get("code") == code:
            yield value
        for v in value.values():
            yield from json_commands(v, code)
    elif isinstance(value, list):
        for v in value:
            yield from json_commands(v, code)


def lua_code(text):
    """Lua 소스에서 주석을 뺀다 (-- 줄 주석과 --[[ ]] 블록 주석)"""
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def test_rpg_static():
    print("[RPG 템플릿: 목록]")
    paths = rpg_section()
    files = set(rpg_files())
    staged = {rpg_dest(p) for p in files}
    check("목록에 '%s' 묶음이 있다" % RPG_SECTION, bool(paths))
    if not paths:
        return
    check("진입 파일과 게임 설정이 묶음에 있다", set(RPG_PLACE) <= set(paths), sorted(set(RPG_PLACE) - set(paths)))
    all_paths = [p for _, ps in list_sections() for p in ps]
    check("공통 글꼴 %s 이 목록에 있다" % ", ".join(RPG_COMMON), set(RPG_COMMON) <= set(all_paths))
    check("엔진의 %s 는 싣지 않는다 (템플릿의 것이 그 자리에 간다)" % ENGINE_RPG_GAME, ENGINE_RPG_GAME not in all_paths)
    missing = [p for p in files if not os.path.isfile(os.path.join(REPO, p))]
    check("묶음의 파일이 다 있다", not missing, missing)
    if missing:
        return

    engine = json.loads(read(ENGINE_RPG_GAME))
    game = json.loads(read(RPG_TEMPLATE + "/rpg-game.json"))
    check("템플릿의 rpg-game.json 은 maps 말고는 엔진의 것과 같다",
          {k: v for k, v in game.items() if k != "maps"} == {k: v for k, v in engine.items() if k != "maps"})
    maps = game.get("maps", [])
    check("템플릿의 맵 항목은 엔진의 항목 그대로다", maps and all(m in engine["maps"] for m in maps), maps)
    names = [m.get("name") for m in maps]
    check("맵은 항구 마을과 여관 (%s)" % ", ".join(map(str, names)), names == ["port_town", "inn"])
    check("alt 가 있는 맵이 없다 (alt 는 RTP 칩셋의 판이다)", not any("alt" in m for m in maps))
    check("맵 파일과 정의 파일과 아이템 표가 묶음에 있다",
          all(m["file"] in files and m["def"] in files for m in maps) and game.get("items") in files,
          [p for m in maps for p in (m["file"], m["def"]) if p not in files])

    entry = read(RPG_TEMPLATE + "/main.lua")
    scenes = set(re.findall(r"^\s*(\w+)\s*=\s*RpgDemo\w*Scene\s*,", entry, flags=re.M))
    check("진입 파일이 title 과 rpg 두 씬만 등록한다", scenes == {"title", "rpg"}, sorted(scenes))

    problems = []
    for m in maps:
        data = json.loads(read(m["file"]))
        for ts in data.get("tilesets", []):
            if ts.get("image") not in files:
                problems.append("%s: 타일셋 %s" % (m["file"], ts.get("image")))
        events = data.get("events", [])
        for cmd in json_commands(events, "transfer"):
            if cmd.get("map") not in names:
                problems.append("%s: transfer %s" % (m["file"], cmd.get("map")))
        for cmd in json_commands(events, "scene"):
            if cmd.get("name") not in scenes:
                problems.append("%s: scene %s" % (m["file"], cmd.get("name")))
        for s in json_strings(events):
            if bare(s).startswith("resources/") and bare(s) not in files:
                problems.append("%s: %s" % (m["file"], s))
    check("맵의 타일셋, transfer 의 맵, scene 의 씬, 이벤트의 파일이 묶음 안이다", not problems, problems)

    problems = []
    lua_files = [p for p in files if p.endswith(".lua")]
    for rel in lua_files:
        code = lua_code(read(rel))
        for mod in re.findall(r"require\s*\(?\s*[\"']([^\"']+)[\"']", code):
            if mod + ".lua" not in staged:
                problems.append("%s: require %s" % (rel, mod))
        for path in re.findall(r"[\"'](\./resources/[^\"']+\.[a-z0-9]+)[\"']", code):
            if path.startswith(RPG_OPTIONAL_PREFIX) or path in RPG_OPTIONAL:
                continue
            if bare(path) not in staged:
                problems.append("%s: %s" % (rel, path))
    check("Lua %d개의 require 와 리소스 경로가 묶음 안이다 (RTP 후보와 여관 곡은 빼고)" % len(lua_files),
          not problems, problems)

    problems = []
    for rel in [p for p in files if p.endswith(".fnt")]:
        for page in re.findall(r'<page [^>]*file="([^"]+)"', read(rel)):
            if os.path.join(os.path.dirname(rel), page) not in files:
                problems.append("%s: %s" % (rel, page))
    check("글꼴의 그림 페이지가 묶음 안이다", not problems, problems)


def stage_rpg_project():
    """RPG 템플릿의 파일만 새 프로젝트처럼 늘어놓는다 (엔진 저장소의 다른 폴더는 없다)"""
    work = tempfile.mkdtemp(prefix="initial2d-rpg-template-")
    for src in rpg_files():
        dst = os.path.join(work, rpg_dest(src))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy(os.path.join(REPO, src), dst)
    return work


def rpg_play_env(rpg_map, route=None):
    """템플릿의 rpg-game.json 의 play.env (route 가 있으면 play.probe 까지)를 에디터처럼 채운다.
    채울 값이 없는 자리표시자가 든 변수는 넣지 않는다 (tests/run_engine_tests.py 의 rpg_play_env 와 같은 규칙)"""
    play = json.loads(read(RPG_TEMPLATE + "/rpg-game.json"))["play"]
    values = {"rpg.map": rpg_map, "route": route}
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


def run_rpg(game, work, extra_env, exit_after, frame=None):
    env = dict(os.environ)
    env.setdefault("SDL_VIDEODRIVER", "dummy")
    env.setdefault("SDL_AUDIODRIVER", "dummy")
    for key in [k for k in env if k.startswith("INITIAL2D_")]:
        del env[key]
    env.update(extra_env)
    env["INITIAL2D_EXIT_AFTER"] = str(exit_after)
    shot = os.path.join(work, "shot_%04d.bmp" % frame) if frame else None
    if shot:
        env["INITIAL2D_SCREENSHOT"] = shot
        env["INITIAL2D_SCREENSHOT_FRAME"] = str(frame)
        if os.path.exists(shot):
            os.remove(shot)
    result = subprocess.run([game], cwd=work, env=env, capture_output=True, text=True, timeout=120)
    img = Image.open(shot).convert("RGB") if shot and os.path.exists(shot) else None
    return result, img


def bad_lines(result):
    """스크립트 오류, 씬 오류, rpg:error 와 그 밖의 error 줄 (libpng 의 iCCP 경고는 뺀다)"""
    out = []
    for line in (result.stdout + result.stderr).splitlines():
        low = line.lower()
        if ("error" in low and "iccp" not in low) or "attempt to" in low or "panic" in low \
                or line.startswith("scene:"):
            out.append(line)
    return out


def golden_diff(img, name, region=None):
    """골든과 다른 픽셀의 비율. 논리 해상도로 정규화하고(run_engine_tests.check_golden 과 같다)
    region(768x896 좌표의 사각형)이 있으면 그 안만 본다"""
    norm = img.resize(engine_tests.LOGICAL_SIZE, Image.BILINEAR)
    golden = Image.open(os.path.join(engine_tests.GOLDEN_DIR, name + ".png")).convert("RGB")
    if region is not None:
        norm, golden = norm.crop(region), golden.crop(region)
    tol = engine_tests.GOLDEN_PIXEL_TOL
    a, b = norm.tobytes(), golden.tobytes()
    bad = sum(1 for i in range(0, len(a), 3)
              if abs(a[i] - b[i]) > tol or abs(a[i + 1] - b[i + 1]) > tol or abs(a[i + 2] - b[i + 2]) > tol)
    return bad / (len(a) // 3)


def rpg_lines(result):
    return [l for l in result.stdout.splitlines() if l.startswith("rpg:")]


def test_rpg_engine(game):
    print("[RPG 템플릿: 엔진] %s" % game)
    if not os.path.exists(game):
        check("엔진 실행 파일이 있다", False, "%s (cmake --build build)" % game)
        return
    if not rpg_section():
        return
    work = stage_rpg_project()
    try:
        top = sorted(os.listdir(work))
        count = sum(len(f) for _, _, f in os.walk(work))
        check("새 프로젝트에는 묶음의 파일 %d개만 있다 (scripts, resources)" % len(rpg_files()),
              top == ["resources", "scripts"] and count == len(rpg_files()), "%s, %d" % (top, count))
        limit = engine_tests.GOLDEN_DIFF_RATIO

        # [1] 타이틀: 메뉴 창이 다 열린 뒤(고정 스텝 4번)의 화면. 프레임마다 1ms 이상 걸리므로 200 이면 넉넉하다
        result, img = run_rpg(game, work, {}, 210, frame=200)
        check("타이틀: 종료 코드 0", result.returncode == 0, "rc=%d" % result.returncode)
        check("타이틀: 오류 줄이 없다", not bad_lines(result), bad_lines(result)[:5])
        check("타이틀: 스크린샷", img is not None)
        if img is not None:
            colors = len(set(img.getdata()))
            check("타이틀: 화면이 비어 있지 않다", colors > 1000, "색 %d개" % colors)
            ratio = golden_diff(img, "rpgdemo_title")
            print("  INFO  타이틀: 골든과 다른 픽셀 %.2f%%" % (ratio * 100))
            check("타이틀: 골든 rpgdemo_title 과 같다", ratio <= limit, "차이 %.2f%%" % (ratio * 100))

        # [2] 자동 시연: 타이틀이 "시작"을 고르면 진입 파일의 SwitchScene 이 맵 씬을 연다.
        # 빈 경로는 걸음 없이 auto 이벤트만 기다린 뒤 rpg:route:done 을 찍고 GameExit 로 끝낸다
        result, _ = run_rpg(game, work, {"INITIAL2D_AUTOPLAY": "1", "INITIAL2D_RPG_ROUTE": "",
                                         "INITIAL2D_RPG_TRACE": "1"}, 20000)
        lines = rpg_lines(result)
        check("시작: 종료 코드 0", result.returncode == 0, "rc=%d" % result.returncode)
        check("시작: 오류 줄이 없다", not bad_lines(result), bad_lines(result)[:5])
        check("시작: 타이틀에서 맵 씬으로 넘어가 항구 마을을 연다 (이벤트 17개, 건너뜀 없음)",
              "rpg:map:port_town events:17 skipped:0" in lines, lines[:4])
        check("시작: 선장의 인사가 나오고 스스로 끝난다",
              any(l.startswith("rpg:message:선장|") for l in lines) and lines[-1:] == ["rpg:route:done"],
              lines[-3:])

        # [3] 에디터의 "이 맵에서 실행" (play.env, 위치와 시작 상태 없이). 페이드(14스텝)가 끝난 뒤의 화면
        env = rpg_play_env("port_town")
        check("이 맵에서 실행: 변수 SCRIPT=lua, SCENE=rpg, MAP=port_town, TRACE",
              env == {"INITIAL2D_SCRIPT": "lua", "INITIAL2D_SCENE": "rpg", "INITIAL2D_MAP": "port_town",
                      "INITIAL2D_RPG_TRACE": "1"}, env)
        result, img = run_rpg(game, work, env, 410, frame=400)
        lines = rpg_lines(result)
        check("이 맵에서 실행: 종료 코드 0", result.returncode == 0, "rc=%d" % result.returncode)
        check("이 맵에서 실행: 오류 줄이 없다", not bad_lines(result), bad_lines(result)[:5])
        check("이 맵에서 실행: 항구 마을의 시작 칸에 선다",
              lines[:2] == ["rpg:map:port_town events:17 skipped:0", "rpg:player:port_town,16,43,up"], lines[:3])
        check("이 맵에서 실행: 스크린샷", img is not None)
        if img is not None:
            x0, y0, x1, y1 = TOWN_REGION
            region = (x0 * 2, y0 * 2, x1 * 2, y1 * 2)   # 맵 씬의 렌더 배율 2
            ratio = golden_diff(img, "rpgdemo_town", region)
            print("  INFO  이 맵에서 실행: 맵 부분에서 골든과 다른 픽셀 %.2f%%" % (ratio * 100))
            check("이 맵에서 실행: 맵 부분이 골든 rpgdemo_town 과 같다", ratio <= limit, "차이 %.2f%%" % (ratio * 100))

        # [4] 자동 재생 (play.probe): 여관의 출입구를 밟아 항구 마을로 옮겨 간다
        env = rpg_play_env("inn", route="down")
        result, _ = run_rpg(game, work, env, 20000)
        lines = rpg_lines(result)
        check("여관에서 항구로: 종료 코드 0", result.returncode == 0, "rc=%d" % result.returncode)
        check("여관에서 항구로: 오류 줄이 없다", not bad_lines(result), bad_lines(result)[:5])
        check("여관에서 항구로: 여관을 열고 (이벤트 6개) 출입구의 transfer 로 항구 마을에 선다",
              "rpg:map:inn events:6 skipped:0" in lines and "rpg:transfer:port_town,13,30,down" in lines
              and "rpg:player:port_town,13,30,down" in lines, lines)
        check("여관에서 항구로: 스스로 끝난다", lines[-1:] == ["rpg:route:done"], lines[-3:])
    finally:
        shutil.rmtree(work, ignore_errors=True)


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
    test_rpg_static()
    test_rpg_engine(game)
    test_list_and_pack()
    print("templates_test: %d PASS / %d FAIL" % (len(PASSES), len(FAILS)))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
