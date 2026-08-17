#!/usr/bin/env python3
"""RPG 데모의 맵 파일을 만든다 (마을과 오두막 안, 각각 두 벌).

지오메트리는 한 벌만 정의하고 타일 번호만 바꿔 두 벌을 뽑는다.

  village.json      / room.json       — 직접 그린 타일셋 (커밋된다, 누구나 돈다)
  village_rtp.json  / room_rtp.json   — RPG Maker 2003 RTP 칩셋 (로컬에만 있다)

RTP 그림은 재배포할 수 없으므로 저장소에 넣지 않는다. 대신 맵 정의
(scripts/maps/*.lua)가 칩셋 파일이 있는지 보고 있으면 RTP 판을, 없으면 기본 판을
연다. 두 판의 지오메트리가 같으므로 이벤트 좌표는 하나로 충분하다.

RTP 칩셋은 왼쪽 12열이 오토타일 블록이고 나머지 18열이 평범한 타일이다. 맵 포맷
v1에는 오토타일이 없으므로, 오토타일 블록에서는 속을 채우는 칸만 골라 쓰고
건물과 장식은 평범한 구역에서 가져왔다 (번호는 실물을 확대해 눈으로 확인).

Usage: python3 tools/generate_demo_maps.py
"""

import json
import os
import random

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPS = os.path.join(REPO, "resources", "maps")

# ---- 스킨 -----------------------------------------------------------------
# house는 위에서 아래로 읽는 행 배열이고, door는 그 안에서 문이 있는 칸이다.

PLACEHOLDER = {
    "outdoor": {"image": "resources/tiles/village16.png", "columns": 8},
    "indoor": {"image": "resources/tiles/village16.png", "columns": 8},
    "grass": 46,
    "path": 45,
    "decor": [8, 16, 24, 32, 40, 48, 56, 64, 72],
    "blocker": [[59, 60], [67, 68]],          # 연못 2x2
    "house": [[105, 106, 107], [108, 109, 110], [111, 113, 112]],
    "door": (2, 1),
    "fence": {"tl": 73, "tm": 74, "tr": 75, "l": 81, "r": 83,
              "bl": 89, "bm": 90, "br": 91},
    "yard": 45,
    "floor": 114,
    "wall_top": 115,
    "wall": 116,
    "void": 117,
    "indoor_door": 113,
}

RTP = {
    "outdoor": {"image": "resources/rtp/ChipSet/Exterior.png", "columns": 30},
    "indoor": {"image": "resources/rtp/ChipSet/Interior.png", "columns": 30},
    "grass": 241,
    "path": 363,
    "decor": [289, 290, 349, 350, 260],
    "blocker": [[261, 261], [291, 291]],      # 나무 두 그루 (위/아래 두 칸짜리)
    "house": [[103, 104, 105], [133, 134, 135],
              [193, 194, 193], [223, 224, 223]],
    "door": (3, 1),
    "fence": {"tl": 379, "tm": 380, "tr": 381, "l": 409, "r": 411,
              "bl": 439, "bm": 440, "br": 441},
    "yard": 363,
    "floor": 158,
    "wall_top": 103,
    "wall": 104,
    "void": 313,
    "indoor_door": None,                       # 실내는 벽을 비워 출입구로 쓴다
}

# ---- 지오메트리 ------------------------------------------------------------

VW, VH = 70, 40
PATH_Y, PATH_X = 21, 34
# 집은 문 위치를 기준으로 놓는다. 스킨마다 집 높이가 달라도(직접 그린 3줄,
# RTP 4줄) 문이 같은 칸에 오므로 이벤트 좌표를 한 벌만 쓰면 된다.
DOOR_A = (13, 14)       # 들어갈 수 있는 집
DOOR_B = (51, 14)       # 잠긴 집
GARDEN = (20, 27, 7, 6, 3)
BLOCKERS = [(56, 28), (58, 28)]

RW, RH = 20, 14        # 방 크기 그대로. 화면보다 작은 부분은 씬이 검게 깐다


def build_village(skin):
    W, H = VW, VH
    g = [skin["grass"]] * (W * H)
    d = [0] * (W * H)
    c = [0] * (W * H)
    P = lambda a, x, y, v: a.__setitem__(y * W + x, v)

    for x in range(W):
        for y in range(H):
            if x < 1 or y < 1 or x >= W - 1 or y >= H - 1:
                P(c, x, y, 1)

    f = skin["fence"]
    for x in range(1, W - 1):
        P(d, x, 1, f["tl"] if x == 1 else (f["tr"] if x == W - 2 else f["tm"]))
        P(c, x, 1, 1)
        P(d, x, H - 2, f["bl"] if x == 1 else (f["br"] if x == W - 2 else f["bm"]))
        P(c, x, H - 2, 1)
    for y in range(2, H - 2):
        P(d, 1, y, f["l"]); P(c, 1, y, 1)
        P(d, W - 2, y, f["r"]); P(c, W - 2, y, 1)

    for x in range(2, W - 2):
        P(g, x, PATH_Y, skin["path"])
    for y in range(2, H - 2):
        P(g, PATH_X, y, skin["path"])

    def house(door_x, door_y):
        rows = skin["house"]
        dr, dc = skin["door"]
        x0, y0 = door_x - dc, door_y - dr
        for ry, row in enumerate(rows):
            for cx, gid in enumerate(row):
                P(d, x0 + cx, y0 + ry, gid)
                P(c, x0 + cx, y0 + ry, 0 if (ry, cx) == (dr, dc) else 1)
        door = (x0 + dc, y0 + dr)
        for y in range(door[1] + 1, PATH_Y + 1):   # 문 앞으로 이어지는 길
            P(g, door[0], y, skin["path"])
        return door

    door_a = house(*DOOR_A)
    door_b = house(*DOOR_B)

    x0, y0, w, h, gate_dx = GARDEN
    for x in range(x0, x0 + w):
        P(d, x, y0, f["tl"] if x == x0 else (f["tr"] if x == x0 + w - 1 else f["tm"]))
        P(c, x, y0, 1)
        P(d, x, y0 + h - 1, f["bl"] if x == x0 else (f["br"] if x == x0 + w - 1 else f["bm"]))
        P(c, x, y0 + h - 1, 1)
    for y in range(y0 + 1, y0 + h - 1):
        P(d, x0, y, f["l"]); P(c, x0, y, 1)
        P(d, x0 + w - 1, y, f["r"]); P(c, x0 + w - 1, y, 1)
    for x in range(x0 + 1, x0 + w - 1):
        for y in range(y0 + 1, y0 + h - 1):
            P(g, x, y, skin["yard"]); P(c, x, y, 1)
    gx, gy = x0 + gate_dx, y0 + h - 1
    P(d, gx, gy, 0); P(g, gx, gy, skin["yard"]); P(c, gx, gy, 0)

    for bx, by in BLOCKERS:
        block = skin["blocker"]
        for dy, row in enumerate(block):
            for dx, gid in enumerate(row):
                P(d, bx + dx, by + dy, gid); P(c, bx + dx, by + dy, 1)

    rnd = random.Random(20260817)
    placed = 0
    while placed < 90:
        x, y = rnd.randrange(2, W - 2), rnd.randrange(2, H - 2)
        if c[y * W + x] == 0 and d[y * W + x] == 0 and g[y * W + x] == skin["grass"]:
            P(d, x, y, rnd.choice(skin["decor"]))
            placed += 1

    return {"version": 1, "name": "마을", "id": 1, "width": W, "height": H,
            "tileWidth": 16, "tileHeight": 16,
            "layers": [{"name": "ground", "data": g}, {"name": "deco", "data": d}],
            "collision": c,
            "tilesets": [dict(skin["outdoor"], firstGid=1)]}, door_a, door_b


def build_room(skin):
    W, H = RW, RH
    rx, ry, rw, rh = 0, 0, W, H
    g = [skin["floor"]] * (W * H)
    d = [0] * (W * H)
    c = [1] * (W * H)
    P = lambda a, x, y, v: a.__setitem__(y * W + x, v)

    for x in range(rx, rx + rw):
        P(d, x, ry, skin["wall_top"])
        P(d, x, ry + 1, skin["wall"])
        P(d, x, ry + rh - 1, skin["wall"])
    for y in range(ry + 2, ry + rh - 1):
        P(d, rx, y, skin["wall"])
        P(d, rx + rw - 1, y, skin["wall"])

    for y in range(ry + 2, ry + rh - 1):
        for x in range(rx + 1, rx + rw - 1):
            P(c, x, y, 0)

    door = (rx + rw // 2, ry + rh - 1)
    P(d, door[0], door[1], skin["indoor_door"] or 0)   # None이면 벽을 비운다
    P(c, door[0], door[1], 0)

    return {"version": 1, "name": "오두막", "id": 2, "width": W, "height": H,
            "tileWidth": 16, "tileHeight": 16,
            "layers": [{"name": "ground", "data": g}, {"name": "deco", "data": d}],
            "collision": c,
            "tilesets": [dict(skin["indoor"], firstGid=1)]}, door


def write(name, data):
    path = os.path.join(MAPS, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("generated:", os.path.relpath(path, REPO))


def main():
    os.makedirs(MAPS, exist_ok=True)
    for suffix, skin in (("", PLACEHOLDER), ("_rtp", RTP)):
        village, door_a, door_b = build_village(skin)
        room, room_door = build_room(skin)
        write(f"village{suffix}.json", village)
        write(f"room{suffix}.json", room)
        print(f"  집 문 {door_a}, 잠긴 집 {door_b}, 오두막 출입구 {room_door}")


if __name__ == "__main__":
    main()
