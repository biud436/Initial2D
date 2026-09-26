#!/usr/bin/env python3
"""정의 파일(Lua)의 이벤트를 맵 파일의 events 로 옮긴다 (docs/plans/m2-rpg-events.md 6절).

에디터는 맵 파일의 events 만 편집한다. 정의 파일(scripts/lua/maps/<이름>.lua)에 적힌 이벤트를
맵 파일로 한 번 옮겨 두면 그 뒤로는 에디터에서 고칠 수 있다.

하는 일:
  1. resources/data/rpg-game.json 에서 맵의 file 과 def 를 찾는다. alt 가 있는 맵(마을, 오두막)은
     두 파일에 같은 이벤트를 두 벌 둬야 해서 옮기지 않는다
  2. 테스트 러너처럼 작업 폴더를 세우고 tools/export_events.lua 를 main.lua 자리에 넣어 엔진 VM 에서
     정의 파일을 읽는다 (게임과 같은 Lua). 외형과 얼굴은 논리 이름 { "set", "index" } 가 되고,
     순서는 MapData.merge 의 병합 순서, 키 순서는 2.6절이다
  3. 함수, 스키마에 없는 칸, 검사에 걸리는 이벤트는 옮기지 않고 이유를 알린다 (정의 파일에 남긴다)
  4. 맵 파일에 있던 이벤트는 바이트 그대로 두고, mapfile.write_map 으로 events 만 바꿔 쓴다

옮긴 뒤 정의 파일에서 옮긴 이벤트와 그것만 쓰던 지역 값을 손으로 지운다. 남겨 두면 같은 id 의
Lua 가 이겨 에디터의 편집이 게임에 안 보인다. 다시 돌려도 결과는 같다.

RTP 경로가 맵 파일에 들어가지 않도록 INITIAL2D_NO_RTP=1 로 돌린다.

사용법:
    python3 tools/export_events.py port_town inn        # 두 맵의 이벤트를 맵 파일로
    python3 tools/export_events.py --dry-run port_town  # 쓰지 않고 보고만
    python3 tools/export_events.py --engine PATH ...    # 엔진 실행 파일 (기본 build/Initial2D)
    python3 tools/export_events.py selftest             # 키 순서, 표식, 남기는 이벤트, 되풀이
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mapfile import dumps, write_map  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORTER = os.path.join(REPO, "tools", "export_events.lua")
DEFAULT_ENGINE = os.path.join(REPO, "build", "Initial2D")
GAME_JSON = os.path.join("resources", "data", "rpg-game.json")


class ExportError(Exception):
    pass


def load_entries(root, names):
    """rpg-game.json 에서 맵 이름마다 등록 항목을 찾는다."""
    with open(os.path.join(root, GAME_JSON), encoding="utf-8") as f:
        game = json.load(f)
    by_name = {m.get("name"): m for m in game.get("maps", []) if isinstance(m, dict)}
    entries = []
    for name in names:
        entry = by_name.get(name)
        if entry is None:
            raise ExportError("%s: rpg-game.json 에 등록되지 않은 맵" % name)
        if entry.get("alt"):
            raise ExportError("%s: alt 가 있는 맵은 옮기지 않는다 (%s 와 %s 에 같은 이벤트를 두 벌 둬야 한다)"
                              % (name, entry["file"], ", ".join(entry["alt"])))
        entries.append({"name": name, "file": entry["file"], "def": entry["def"]})
    return entries


def read_map_events(root, entry):
    """맵 파일과 그 events. 이벤트는 id 가 겹치지 않는 객체여야 병합할 수 있다."""
    path = os.path.join(root, entry["file"])
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    events = data.get("events")
    if events is None:
        events = []
    if not isinstance(events, list):
        raise ExportError("%s: events 가 배열이 아니다" % entry["file"])
    seen = set()
    for i, ev in enumerate(events, 1):
        if not isinstance(ev, dict) or not isinstance(ev.get("id"), str) or ev["id"] == "":
            raise ExportError("%s: events[%d] 에 id 가 없다. 먼저 고친다" % (entry["file"], i))
        if ev["id"] in seen:
            raise ExportError("%s: events[%d] 의 id %s 가 앞 이벤트와 겹친다. 먼저 고친다"
                              % (entry["file"], i, ev["id"]))
        seen.add(ev["id"])
    return path, data, events


def run_exporter(root, entries, engine):
    """엔진 VM 에서 export_events.lua 를 돌려 결과(맵마다 순서와 남긴 이벤트)를 돌려준다."""
    if not os.path.exists(engine):
        raise ExportError("엔진 실행 파일이 없다: %s (cmake --build build)" % engine)
    work = tempfile.mkdtemp(prefix="initial2d-export-")
    try:
        shutil.copytree(os.path.join(root, "scripts"), os.path.join(work, "scripts"))
        shutil.copy(EXPORTER, os.path.join(work, "scripts", "lua", "main.lua"))
        os.symlink(os.path.abspath(os.path.join(root, "resources")), os.path.join(work, "resources"))
        with open(os.path.join(work, "export_request.json"), "w", encoding="utf-8") as f:
            json.dump({"maps": entries}, f, ensure_ascii=False)
        env = dict(os.environ)
        env.setdefault("SDL_VIDEODRIVER", "dummy")
        env.setdefault("SDL_AUDIODRIVER", "dummy")
        env.update({"INITIAL2D_NO_RTP": "1", "INITIAL2D_EXIT_AFTER": "120", "INITIAL2D_SCRIPT": "lua"})
        run = subprocess.run([engine], cwd=work, env=env, capture_output=True, text=True, timeout=120)
        result_path = os.path.join(work, "export_result.json")
        if not os.path.exists(result_path):
            raise ExportError("엔진이 결과를 남기지 않았다 (rc=%d)\n%s" % (run.returncode, (run.stdout + run.stderr)[-800:]))
        with open(result_path, encoding="utf-8") as f:
            result = json.load(f)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    if result.get("error"):
        raise ExportError(result["error"])
    return result["maps"]


def assemble(map_events, exported):
    """맵 파일의 이벤트(원래 객체 그대로)와 옮긴 이벤트를 병합 순서대로 잇는다."""
    if exported["mapCount"] != len(map_events):
        raise ExportError("엔진이 본 맵 파일 이벤트 수(%d)와 파일의 수(%d)가 다르다"
                          % (exported["mapCount"], len(map_events)))
    events, moved = [], []
    for item in exported["order"]:
        if "map" in item:
            events.append(map_events[item["map"] - 1])
        else:
            events.append(item["event"])
            moved.append(item["event"]["id"])
    return events, moved


def export(root, names, engine=DEFAULT_ENGINE, dry_run=False, out=print):
    """맵마다 이벤트를 옮긴다. 쓴 맵의 보고 목록을 돌려준다."""
    entries = load_entries(root, names)
    loaded = [read_map_events(root, e) for e in entries]
    results = run_exporter(root, entries, engine)
    reports = []
    for entry, (path, data, map_events), exported in zip(entries, loaded, results):
        events, moved = assemble(map_events, exported)
        left = exported["left"]
        out("%s (%s): 이벤트 %d개. 맵 파일에 있던 것 %d개, 옮긴 것 %d개"
            % (entry["name"], entry["file"], len(events), len(map_events), len(moved)))
        if moved:
            out("  옮김: " + ", ".join(moved))
        if left:
            out("  옮기지 않음 (정의 파일에 남긴다. 게임에서는 맵 파일의 이벤트 뒤에 온다):")
            for item in left:
                for problem in item["problems"]:
                    out("    %s  %s" % (item["id"], problem))
        if not dry_run:
            data["events"] = events
            write_map(path, data)
            if moved:
                out("  다음: %s 에서 옮긴 이벤트와 그것만 쓰던 지역 값을 지운다" % entry["def"])
        reports.append({"name": entry["name"], "moved": moved, "left": [l["id"] for l in left],
                        "events": events})
    return reports


# ---- self-test ----------------------------------------------------------------

SELFTEST_DEF = r'''
local Assets = require("scripts/lua/rpg/assets")

local CHARSET = Assets.npcCharset()
local PLAYER = Assets.playerCharset()
local FACESET = Assets.faceset()
local BGM = Assets.pick({ "./resources/audio/none.ogg", "./resources/audio/bless.ogg" })

local function farewell()
	return { { text = "잘 가요.", face = { index = 2, file = FACESET }, code = "message" } }
end

return {
	map = "./resources/maps/selftest.json",
	start = { x = 1, y = 1, dir = "down" },
	bgm = { file = BGM, volume = 80 },
	scripts = { wave = function() end },
	events = {
		{ commands = { { seconds = 2.5, text = "시험장", code = "showLocation" } },
		  trigger = "auto", y = 0, x = 0, id = "arrival" },
		{ id = "door", x = 2, y = 1, trigger = "touch", commands = {
			{ id = "door", file = "./resources/audio/door.wav", code = "playSe" },
			{ dir = "up", y = 12, x = 10, map = "inn", code = "transfer" } } },
		{ wander = { area = { h = 3, w = 4, y = 0, x = 1 }, maxWait = 90, minWait = 20 },
		  commands = {
			{ code = "if", elseDo = {}, thenDo = { { code = "message", text = "줄\n바꿈 \"따옴표\"\t탭" } },
			  cond = { value = 2, op = ">=", item = "shell" } },
			{ code = "choice", cancel = 2, options = { "예", "아니요" }, branches = { farewell(), farewell() } },
			{ code = "script", name = "wave", args = { b = 1, a = { 1, 2 } } },
			{ code = "if", cond = {}, thenDo = { { code = "setVar", value = 1.5, op = "+", key = "count" } } },
		  },
		  speed = 2, solid = true, through = false, charset = { index = 3, file = CHARSET },
		  dir = "left", y = 2, x = 3, id = "kid", trigger = "action" },
		{ id = "twin", x = 4, y = 2, charset = { file = PLAYER, index = 0 } },
		{ id = "fn", x = 5, y = 2, commands = { { code = "script", run = function() end } } },
		{ id = "memo", x = 6, y = 2, memo = "메모" },
		{ id = "misplaced", x = 7, y = 2, commands = { { code = "message", text = CHARSET } } },
		{ id = "wrongkind", x = 8, y = 2, charset = { file = FACESET } },
		{ id = "bad", x = -1, y = 2 },
		{ id = "sign", x = 9, y = 2, commands = { { code = "message", text = "정의 파일", note = 1 } } },
	},
}
'''

SELFTEST_MAP_EVENTS = [
    {"id": "sign", "x": 9, "y": 2, "note": "모르는 키", "commands": [{"text": "맵 파일", "code": "message"}]},
    {"id": "door", "x": 2, "y": 1, "commands": []},
]

# 맵 파일의 events 부터 끝까지. 에디터가 같은 이벤트를 새로 쓸 때의 키 순서다 (2.6절)
SELFTEST_EXPECTED = r'''  "events": [
    {
      "id": "sign",
      "x": 9,
      "y": 2,
      "note": "모르는 키",
      "commands": [
        {
          "text": "맵 파일",
          "code": "message"
        }
      ]
    },
    {
      "id": "door",
      "x": 2,
      "y": 1,
      "trigger": "touch",
      "commands": [
        {
          "code": "playSe",
          "file": "./resources/audio/door.wav",
          "id": "door"
        },
        {
          "code": "transfer",
          "map": "inn",
          "x": 10,
          "y": 12,
          "dir": "up"
        }
      ]
    },
    {
      "id": "arrival",
      "x": 0,
      "y": 0,
      "trigger": "auto",
      "commands": [
        {
          "code": "showLocation",
          "text": "시험장",
          "seconds": 2.5
        }
      ]
    },
    {
      "id": "kid",
      "x": 3,
      "y": 2,
      "dir": "left",
      "trigger": "action",
      "charset": {
        "set": "npc",
        "index": 3
      },
      "through": false,
      "solid": true,
      "speed": 2,
      "wander": {
        "minWait": 20,
        "maxWait": 90,
        "area": {
          "x": 1,
          "y": 0,
          "w": 4,
          "h": 3
        }
      },
      "commands": [
        {
          "code": "if",
          "cond": {
            "item": "shell",
            "op": ">=",
            "value": 2
          },
          "thenDo": [
            {
              "code": "message",
              "text": "줄\n바꿈 \"따옴표\"\t탭"
            }
          ],
          "elseDo": []
        },
        {
          "code": "choice",
          "options": [
            "예",
            "아니요"
          ],
          "cancel": 2,
          "branches": [
            [
              {
                "code": "message",
                "text": "잘 가요.",
                "face": {
                  "set": "npc",
                  "index": 2
                }
              }
            ],
            [
              {
                "code": "message",
                "text": "잘 가요.",
                "face": {
                  "set": "npc",
                  "index": 2
                }
              }
            ]
          ]
        },
        {
          "code": "script",
          "name": "wave",
          "args": {
            "a": [
              1,
              2
            ],
            "b": 1
          }
        },
        {
          "code": "if",
          "cond": {},
          "thenDo": [
            {
              "code": "setVar",
              "key": "count",
              "op": "+",
              "value": 1.5
            }
          ]
        }
      ]
    },
    {
      "id": "twin",
      "x": 4,
      "y": 2,
      "charset": {
        "set": "player",
        "index": 0
      }
    }
  ]
}
'''

SELFTEST_LEFT = {
    "fn": ["events[5].commands[1].run: 함수는 맵 파일에 쓸 수 없다"],
    "memo": ["events[6].memo: 스키마에 없는 칸"],
    "misplaced": ["events[7].commands[1].text: 자산 표식 @charset:npc 이 외형이나 얼굴의 file 자리 밖에 있다"],
    "wrongkind": ["events[8].charset.file: charset 자리에 @face:npc 표식"],
    "bad": ["events[9].x: 0 이상의 정수가 아니다 (지금은 -1)"],
    "sign": ["events[10].commands[1].note: 스키마에 없는 인자"],
}


def _selftest_project(tmp):
    """scripts/ 는 저장소의 것, resources/ 는 스키마와 시험용 맵과 게임 설정만."""
    shutil.copytree(os.path.join(REPO, "scripts"), os.path.join(tmp, "scripts"))
    with open(os.path.join(tmp, "scripts", "lua", "maps", "selftest.lua"), "w", encoding="utf-8") as f:
        f.write(SELFTEST_DEF)
    res = os.path.join(tmp, "resources")
    os.makedirs(os.path.join(res, "maps"))
    os.makedirs(os.path.join(res, "data"))
    os.symlink(os.path.join(REPO, "resources", "schema"), os.path.join(res, "schema"))
    maps = [{"name": "selftest", "file": "resources/maps/selftest.json", "def": "scripts/lua/maps/selftest.lua"},
            {"name": "twin", "file": "resources/maps/twin.json", "alt": ["resources/maps/twin_rtp.json"],
             "def": "scripts/lua/maps/selftest.lua"},
            {"name": "noid", "file": "resources/maps/noid.json", "def": "scripts/lua/maps/selftest.lua"}]
    with open(os.path.join(res, "data", "rpg-game.json"), "w", encoding="utf-8") as f:
        json.dump({"version": 1, "maps": maps, "items": "resources/data/items.json"}, f, ensure_ascii=False)
    base = {"version": 2, "name": "selftest", "id": 1, "width": 12, "height": 4, "tileWidth": 16, "tileHeight": 16,
            "layers": [{"name": "ground", "data": [1] * 48}],
            "tilesets": [{"image": "resources/tiles/port16.png", "firstGid": 1, "columns": 8}]}
    for name, events in (("selftest", SELFTEST_MAP_EVENTS), ("twin", []), ("noid", [{"x": 1, "y": 1}])):
        with open(os.path.join(res, "maps", name + ".json"), "w", encoding="utf-8") as f:
            f.write(dumps(dict(base, events=events)))
    return os.path.join(res, "maps", "selftest.json")


def cmd_selftest(engine):
    failures = []

    def check(cond, label, detail=""):
        print(("  PASS  " if cond else "  FAIL  ") + label + ("" if cond or not detail else "  |  " + detail))
        if not cond:
            failures.append(label)

    if not os.path.exists(engine):
        print("  SKIP  엔진 실행 파일이 없다: %s (cmake --build build 뒤에 다시)" % engine)
        print("export_events selftest: SKIP")
        return 0

    quiet = []
    with tempfile.TemporaryDirectory() as tmp:
        target = _selftest_project(tmp)
        with open(target, encoding="utf-8") as f:
            original = f.read()

        reports = export(tmp, ["selftest"], engine, dry_run=True, out=quiet.append)
        with open(target, encoding="utf-8") as f:
            check(f.read() == original, "--dry-run 은 쓰지 않는다")
        check(any("옮김: door, arrival, kid, twin" in line for line in quiet), "보고에 옮긴 이벤트가 병합 순서로 나온다",
              " / ".join(quiet[:3]))

        del quiet[:]
        reports = export(tmp, ["selftest"], engine, out=quiet.append)
        with open(target, encoding="utf-8") as f:
            text = f.read()
        start = text.find('  "events": [')
        got = text[start:] if start >= 0 else ""
        check(got == SELFTEST_EXPECTED, "events 가 2.6절의 키 순서와 병합 순서로 쓰인다")
        if got != SELFTEST_EXPECTED:
            for i, (a, b) in enumerate(zip(got.splitlines(), SELFTEST_EXPECTED.splitlines())):
                if a != b:
                    print("        %d행: %r / 기대 %r" % (i + 1, a, b))
                    break
        check(dumps(json.loads(text)) == text, "맵 파일이 정해진 형식이다 (mapfile.py check)")
        check(reports[0]["moved"] == ["door", "arrival", "kid", "twin"], "옮긴 이벤트", str(reports[0]["moved"]))
        left = {}
        for line in quiet:
            parts = line.strip().split("  ", 1)
            if line.startswith("    ") and len(parts) == 2:
                left.setdefault(parts[0], []).append(parts[1])
        check(left == SELFTEST_LEFT, "함수, 모르는 칸, 자리 밖의 표식, 다른 종류의 표식, 검사에 걸린 이벤트는 남긴다",
              json.dumps(left, ensure_ascii=False))

        export(tmp, ["selftest"], engine, out=quiet.append)
        with open(target, encoding="utf-8") as f:
            check(f.read() == text, "다시 돌려도 바이트가 같다")

        for name, needle in (("twin", "alt"), ("noid", "id 가 없다"), ("nowhere", "등록되지 않은")):
            before = None
            path = os.path.join(tmp, "resources", "maps", name + ".json")
            if os.path.exists(path):
                with open(path, encoding="utf-8") as f:
                    before = f.read()
            try:
                export(tmp, [name], engine, out=quiet.append)
                check(False, "%s: 옮기지 않고 멈춘다" % name)
            except ExportError as e:
                unchanged = before is None or open(path, encoding="utf-8").read() == before
                check(needle in str(e) and unchanged, "%s: 옮기지 않고 멈춘다 (%s)" % (name, needle), str(e))

    print("export_events selftest: %d FAIL" % len(failures))
    return 1 if failures else 0


def main(argv):
    engine = DEFAULT_ENGINE
    dry_run = False
    names = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--engine" and i + 1 < len(argv):
            engine = argv[i + 1]
            i += 1
        elif a == "--dry-run":
            dry_run = True
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            names.append(a)
        i += 1
    if names == ["selftest"]:
        return cmd_selftest(engine)
    if not names:
        print(__doc__)
        return 2
    try:
        export(REPO, names, engine, dry_run=dry_run)
    except ExportError as e:
        print("export_events: " + str(e), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
