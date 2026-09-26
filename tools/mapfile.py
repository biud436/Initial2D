#!/usr/bin/env python3
"""맵 파일 쓰기 (맵 포맷 v2의 정해진 형식, docs/plans/02-tilemap.md).

맵 생성기가 함께 쓰는 모듈이다. 에디터(InitialEditor의
packages/ext-tilemap/src/model/format.ts, serializeMap)가 쓰는 것과 바이트 단위로 같은
텍스트를 만든다. 그래서 생성기가 쓴 맵을 에디터로 열어 저장해도 git diff가 비고,
에디터가 고친 맵은 고친 칸만 diff에 나온다.

정해진 형식:
  - JSON.stringify(value, null, 2)와 같다. 2칸 들여쓰기, "키": 값, 한글은 그대로(UTF-8),
    끝에 줄바꿈 하나. 실수는 JavaScript의 숫자 표기를 따른다 (3.0은 3으로 쓴다)
  - 타일 배열(layers[].data, collision)은 맵 한 줄을 한 줄에 쓴다. 칸은 공백 없이 ,로 잇고
    줄은 키가 있는 줄보다 두 칸 더 들여 쓴다. 닫는 ]는 키와 같은 들여쓰기다
  - 최상위 키 순서: version, name, id, width, height, tileWidth, tileHeight, layers,
    collision, tilesets, events, objects, 그 밖의 키 (원래 순서). version은 늘 2다
  - collision과 events는 있을 때만, objects는 비어 있지 않을 때만 쓴다
  - 오브젝트는 id, type, x, y, width, height, props, 그 밖의 키 순서. y가 없으면 0,
    width와 height는 있을 때만, props는 비어 있지 않을 때만 쓴다
  - JavaScript 객체처럼 정수 모양의 키("0", "12")가 다른 키보다 앞에 온다

write_map은 이미 있는 파일의 objects와 events, 그리고 생성기가 만들지 않는 최상위 키를
이어받는다. 타일, collision, tilesets는 생성기가 새로 쓴다 (손으로 칠한 타일은 덮인다).

사용법:
    from mapfile import write_map
    write_map(path, data)

    python3 tools/mapfile.py selftest            # 에디터와 같은 텍스트를 쓰는가
    python3 tools/mapfile.py check FILE...       # 파일이 정해진 형식인가 (아니면 종료 코드 1)
    python3 tools/mapfile.py format FILE...      # 파일을 정해진 형식으로 다시 쓴다
"""

import json
import os
import re
import sys
import tempfile

MAP_VERSION_WRITTEN = 2

ROOT_KEYS = ("version", "name", "id", "width", "height", "tileWidth", "tileHeight",
             "layers", "collision", "tilesets", "events", "objects")
LAYER_KEYS = ("name", "data")
TILESET_KEYS = ("image", "firstGid", "columns")
OBJECT_KEYS = ("id", "type", "x", "y", "width", "height", "props")

# 생성기가 만드는 키. write_map은 이 키들을 기존 파일에서 가져오지 않는다
GENERATED_KEYS = ("version", "name", "id", "width", "height", "tileWidth", "tileHeight",
                  "layers", "collision", "tilesets")

_ARRAY_INDEX = re.compile(r"^(0|[1-9][0-9]*)$")


class _Rows:
    """타일 배열 하나. 맵 한 줄씩 쓴다."""

    def __init__(self, data, width):
        self.data = data
        self.width = width


def _is_number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _extra(d, known):
    return {k: v for k, v in d.items() if k not in known}


def _js_keys(d):
    """JavaScript 객체의 키 순서: 배열 첨자 모양의 키가 오름차순으로 먼저, 나머지는 넣은 순서."""
    index = sorted((k for k in d if _ARRAY_INDEX.match(k) and int(k) < 2 ** 32 - 1), key=int)
    taken = set(index)
    return index + [k for k in d if k not in taken]


def _js_number(x):
    """Number.prototype.toString()과 같은 표기."""
    if isinstance(x, int):
        return str(x)
    if x != x or x in (float("inf"), float("-inf")):
        return "null"
    if x == 0:
        return "0"
    if x < 0:
        return "-" + _js_number(-x)
    # repr은 되읽으면 같은 값이 되는 가장 짧은 십진 숫자열을 준다 (JavaScript와 같은 숫자열)
    r = repr(x).lower()
    mant, _, exp = r.partition("e")
    whole, _, frac = mant.partition(".")
    digits = (whole + frac).lstrip("0")
    scale = int(exp or 0) - len(frac)
    stripped = digits.rstrip("0")
    scale += len(digits) - len(stripped)
    digits = stripped
    k = len(digits)
    n = k + scale
    if k <= n <= 21:
        return digits + "0" * (n - k)
    if 0 < n <= 21:
        return digits[:n] + "." + digits[n:]
    if -6 < n <= 0:
        return "0." + "0" * (-n) + digits
    e = n - 1
    sign = "+" if e >= 0 else "-"
    head = digits if k == 1 else digits[0] + "." + digits[1:]
    return head + "e" + sign + str(abs(e))


_ESCAPES = {'"': '\\"', "\\": "\\\\", "\b": "\\b", "\f": "\\f", "\n": "\\n", "\r": "\\r", "\t": "\\t"}


def _js_string(s):
    """JSON.stringify의 문자열 표기. 제어 문자와 짝 없는 서로게이트만 \\u로 쓴다."""
    out = ['"']
    for ch in s:
        code = ord(ch)
        if ch in _ESCAPES:
            out.append(_ESCAPES[ch])
        elif code < 0x20 or 0xD800 <= code <= 0xDFFF:
            out.append("\\u%04x" % code)
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def _encode(value, indent):
    """value를 JSON.stringify(value, null, 2)의 모양으로. indent는 value가 시작하는 줄의 들여쓰기."""
    inner = indent + "  "
    if value is None:
        return "null"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if _is_number(value):
        return _js_number(value)
    if isinstance(value, str):
        return _js_string(value)
    if isinstance(value, _Rows):
        w = value.width
        rows = [inner + ",".join(str(n) for n in value.data[y:y + w])
                for y in range(0, len(value.data), w)]
        return "[\n" + ",\n".join(rows) + "\n" + indent + "]"
    if isinstance(value, (list, tuple)):
        if not value:
            return "[]"
        return "[\n" + ",\n".join(inner + _encode(v, inner) for v in value) + "\n" + indent + "]"
    if isinstance(value, dict):
        if not value:
            return "{}"
        items = [inner + _js_string(k) + ": " + _encode(value[k], inner) for k in _js_keys(value)]
        return "{\n" + ",\n".join(items) + "\n" + indent + "}"
    raise TypeError("맵 파일에 쓸 수 없는 값: %r" % (value,))


def _object(o):
    out = {"id": o["id"], "type": o["type"], "x": o["x"], "y": o.get("y", 0)}
    if o.get("width") is not None:
        out["width"] = o["width"]
    if o.get("height") is not None:
        out["height"] = o["height"]
    if o.get("props"):
        out["props"] = dict(o["props"])
    out.update(_extra(o, OBJECT_KEYS))
    return out


def dumps(data):
    """맵 하나를 정해진 형식의 텍스트로 (끝의 줄바꿈 포함)."""
    width = data["width"]
    name = data.get("name")
    map_id = data.get("id")
    out = {
        "version": MAP_VERSION_WRITTEN,
        "name": name if isinstance(name, str) else "",
        "id": map_id if _is_number(map_id) else 0,
        "width": width,
        "height": data["height"],
        "tileWidth": data["tileWidth"],
        "tileHeight": data["tileHeight"],
        "layers": [],
    }
    for i, layer in enumerate(data["layers"]):
        lname = layer.get("name")
        entry = {"name": lname if isinstance(lname, str) else "layer%d" % (i + 1),
                 "data": _Rows(layer["data"], width)}
        entry.update(_extra(layer, LAYER_KEYS))
        out["layers"].append(entry)
    if data.get("collision") is not None:
        out["collision"] = _Rows(data["collision"], width)
    tilesets = []
    for t in data["tilesets"]:
        entry = {"image": t["image"], "firstGid": t["firstGid"], "columns": t["columns"]}
        entry.update(_extra(t, TILESET_KEYS))
        tilesets.append(entry)
    out["tilesets"] = tilesets
    if data.get("events") is not None:
        out["events"] = data["events"]
    if data.get("objects"):
        out["objects"] = [_object(o) for o in data["objects"]]
    out.update(_extra(data, ROOT_KEYS))
    return _encode(out, "") + "\n"


def write_map(path, data):
    """data를 path에 정해진 형식으로 쓰고, 기존 파일의 objects, events, 모르는 최상위 키는 이어받는다.
    기존 파일이 JSON이 아니면 오브젝트를 잃지 않도록 쓰지 않고 멈춘다."""
    merged = dict(data)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            text = f.read()
        try:
            old = json.loads(text)
        except ValueError as e:
            raise SystemExit("%s: 기존 맵 파일을 읽지 못해 쓰지 않는다 (%s)" % (path, e))
        for key, value in old.items():
            if key not in GENERATED_KEYS and key not in merged:
                merged[key] = value
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(dumps(merged))
    return merged


# ---- self-test ----------------------------------------------------------------

# 에디터의 serializeMap이 SELFTEST_MAP을 쓴 결과. InitialEditor의 format.ts를
# 묶어 node로 돌려 얻은 텍스트이며, 여기서는 그것과 한 바이트도 다르지 않아야 한다.
SELFTEST_MAP = {
    "version": 1,
    "name": "tiny",
    "id": 7,
    "width": 4,
    "height": 3,
    "tileWidth": 16,
    "tileHeight": 16,
    "layers": [
        {"name": "ground", "data": [1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1]},
        {"data": [0] * 12, "note": "보존"},
    ],
    "collision": [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0],
    "tilesets": [{"columns": 8, "image": "resources/tiles/a.png", "firstGid": 1, "margin": 0}],
    "custom": {"b": 1, "10": [], "2": {}},
    "objects": [
        {"type": "start", "id": "start", "x": 56, "y": 384, "props": {}},
        {"id": "tracks", "type": "landmark", "x": 300, "width": 48,
         "props": {"title": "여러 갈래의 \"발자국\"", "text": "줄\n바꿈\t탭", "hallucination": 3.0},
         "editorOnly": 1},
        {"id": "f", "type": "spawn", "x": 1990.5, "y": -0.0, "height": 1e21,
         "props": {"minX": 1e-7, "maxX": 123456.789, "boss": False, "tag": None}},
    ],
    "events": [],
    "1": "정수 모양의 키",
}

SELFTEST_EXPECTED = r'''{
  "1": "정수 모양의 키",
  "version": 2,
  "name": "tiny",
  "id": 7,
  "width": 4,
  "height": 3,
  "tileWidth": 16,
  "tileHeight": 16,
  "layers": [
    {
      "name": "ground",
      "data": [
        1,1,1,1,
        1,2,2,1,
        1,1,1,1
      ]
    },
    {
      "name": "layer2",
      "data": [
        0,0,0,0,
        0,0,0,0,
        0,0,0,0
      ],
      "note": "보존"
    }
  ],
  "collision": [
    0,0,0,0,
    0,1,1,0,
    0,0,0,0
  ],
  "tilesets": [
    {
      "image": "resources/tiles/a.png",
      "firstGid": 1,
      "columns": 8,
      "margin": 0
    }
  ],
  "events": [],
  "objects": [
    {
      "id": "start",
      "type": "start",
      "x": 56,
      "y": 384
    },
    {
      "id": "tracks",
      "type": "landmark",
      "x": 300,
      "y": 0,
      "width": 48,
      "props": {
        "title": "여러 갈래의 \"발자국\"",
        "text": "줄\n바꿈\t탭",
        "hallucination": 3
      },
      "editorOnly": 1
    },
    {
      "id": "f",
      "type": "spawn",
      "x": 1990.5,
      "y": 0,
      "height": 1e+21,
      "props": {
        "minX": 1e-7,
        "maxX": 123456.789,
        "boss": false,
        "tag": null
      }
    }
  ],
  "custom": {
    "2": {},
    "10": [],
    "b": 1
  }
}
'''


def cmd_selftest():
    failures = []

    def check(cond, label):
        print(("  PASS  " if cond else "  FAIL  ") + label)
        if not cond:
            failures.append(label)

    text = dumps(SELFTEST_MAP)
    check(text == SELFTEST_EXPECTED, "에디터의 serializeMap과 같은 텍스트")
    if text != SELFTEST_EXPECTED:
        for i, (a, b) in enumerate(zip(text.splitlines(), SELFTEST_EXPECTED.splitlines())):
            if a != b:
                print("        %d행: %r / 기대 %r" % (i + 1, a, b))
                break
    check(dumps(json.loads(text)) == text, "정해진 형식을 다시 쓰면 그대로다")
    check(_js_number(0.1 + 0.2) == "0.30000000000000004", "실수의 가장 짧은 표기")
    check(_js_number(123e-20) == "1.23e-18" and _js_number(2.5e25) == "2.5e+25", "지수 표기")
    check(_js_number(0.000001) == "0.000001" and _js_number(1e21) == "1e+21", "지수 표기의 경계")
    check(_js_string("\x01\ud800") == '"\\u0001\\ud800"', "제어 문자와 짝 없는 서로게이트")

    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "m.json")
        base = {k: v for k, v in SELFTEST_MAP.items() if k not in ("objects", "events", "custom", "1")}
        write_map(path, dict(SELFTEST_MAP))
        regen = dict(base, layers=[{"name": "ground", "data": [9] * 12}], collision=None)
        write_map(path, regen)
        with open(path, encoding="utf-8") as f:
            back = json.load(f)
        check(back["objects"] == json.loads(text)["objects"], "다시 생성해도 objects가 남는다")
        check(back["events"] == [] and back["custom"] == SELFTEST_MAP["custom"] and back["1"] == "정수 모양의 키",
              "다시 생성해도 events와 모르는 최상위 키가 남는다")
        check(back["layers"] == [{"name": "ground", "data": [9] * 12}] and "collision" not in back,
              "타일과 collision은 생성기가 새로 쓴다")
        with open(path, "w", encoding="utf-8") as f:
            f.write("{ 깨진")
        try:
            write_map(path, regen)
            check(False, "읽지 못하는 기존 파일에는 쓰지 않는다")
        except SystemExit:
            check(True, "읽지 못하는 기존 파일에는 쓰지 않는다")

    print("mapfile selftest: %d FAIL" % len(failures))
    return 1 if failures else 0


def cmd_check(paths, fix=False):
    bad = 0
    for path in paths:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        want = dumps(json.loads(text))
        if text == want:
            print("  OK    " + path)
            continue
        if fix:
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(want)
            print("  고침  " + path)
        else:
            bad += 1
            print("  FAIL  %s: 정해진 형식이 아니다 (python3 tools/mapfile.py format %s)" % (path, path))
    return 1 if bad else 0


def main(argv):
    if len(argv) >= 1 and argv[0] == "selftest":
        return cmd_selftest()
    if len(argv) >= 2 and argv[0] in ("check", "format"):
        return cmd_check(argv[1:], fix=(argv[0] == "format"))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
