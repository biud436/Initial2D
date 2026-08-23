#!/usr/bin/env python3
"""알데바란 스테이지 1-1 「검은 안개의 숲」 맵 생성기 (docs/plans/aldebaran-1-core.md 5절).

128x28 타일, 가로 2048px의 횡스크롤 스테이지 하나를 만든다. 지형과 장식은
**전부 손으로 정한 자리다. 난수로 뿌리지 않는다** (port_town과 같은 규칙).

구간 (x 타일):
    0~ 23  숲 입구 — 평탄한 진흙 길
   24~ 47  오르막 바위 턱 — 2턱씩 세 계단 (점프 연습)
   48~ 63  기암 절벽과 낡은 다리 — 다리 널 사이가 두 칸씩 비어 있다
   64~ 71  이정표 (체크포인트)
   72~ 99  늑대 인간의 숲 — 검은 나무가 빽빽한 내리막
  100~127  막다른 절벽 앞 공터 — 부서진 레굴루스 석상 (짐도둑의 자리)

몬스터 배치는 맵이 아니라 scripts/games/aldebaran/stage.lua 에 있다 — 이벤트
커맨드는 RPG 레이어의 것이고, 액션 게임의 배치는 코드에 더 가깝기 때문이다.

Usage: python3 tools/generate_aldebaran_maps.py
"""

import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "resources", "maps", "aldebaran_forest.json")

W, H = 128, 28

# 타일 gid (tools/generate_aldebaran_assets.py 의 forest16.png, firstGid 1)
MUD_TOP, MUD_FILL, ROCK_TOP, ROCK_FILL = 1, 2, 3, 4
PLANK, PLANK_BROKEN, ROPE_POST, SIGN = 5, 6, 7, 8
TRUNK, TRUNK_THICK, CANOPY, VINE = 9, 10, 11, 12
BAMBOO, SHROOM, WEED, SPIRE = 13, 14, 15, 16
STATUE_TL, STATUE_TR, STATUE_BL, STATUE_BR = 17, 18, 19, 20
SKULL, PEBBLE = 21, 22

# 구간별 지면 높이 (윗면 타일의 y). 절벽 구간(48~63)은 None — 낭떠러지.
# 바위 턱(rock=True)은 흙이 아니라 바위 타일로 그린다.
PROFILE = [
    (0, 23, 24, False),      # 입구
    (24, 31, 22, True),      # 턱 1 (+2)
    (32, 39, 21, True),      # 턱 2 (+1)
    (40, 47, 20, True),      # 왼쪽 절벽 어깨 (+1)
    (48, 63, None, False),   # 낭떠러지 (다리)
    (64, 71, 20, True),      # 오른쪽 절벽 어깨
    (72, 79, 22, True),      # 내리막 턱
    (80, 127, 24, False),    # 늑대 숲과 공터
]

# 다리 널 (y=20). 두 칸짜리 구멍이 둘 — 점프로 넘는다.
BRIDGE_Y = 20
BRIDGE_GAPS = {53, 54, 58, 59}
BRIDGE_BROKEN = {51, 61}          # 반쯤 부서진 널 (지나갈 수는 있다)

# 늑대 숲 위의 낮은 바위 턱 둘 (지면 24 위에 얹힌 2단 턱)
LEDGES = [(86, 90, 22), (96, 100, 22)]

# 장식 — (x, "이름") 목록. y는 그 칸의 지면에서 계산한다.
TREES = [(4, "thin"), (10, "thick"), (16, "thin"), (21, "thin"),
         (34, "thin"), (38, "thick"),
         (69, "thick"), (73, "thin"), (76, "thick"), (81, "thin"), (84, "thick"),
         (88, "thin"), (92, "thick"), (95, "thin"), (98, "thick"),
         (104, "thin"), (109, "thin")]
SHRUBS = [(3, WEED), (7, SHROOM), (12, BAMBOO), (14, WEED), (18, VINE), (22, WEED),
          (27, WEED), (30, SHROOM), (36, BAMBOO), (42, WEED), (45, PEBBLE),
          (66, SIGN), (68, WEED), (74, SKULL), (79, VINE), (83, WEED), (87, SHROOM),
          (91, PEBBLE), (94, SKULL), (99, WEED),
          (103, BAMBOO), (107, PEBBLE), (112, WEED), (120, SKULL), (122, WEED),
          (125, SPIRE), (126, SPIRE)]
STATUE_X, STATUE_TOP = 116, 22    # 2x2 석상 (공터, 지면 24 위)
ROPE_POSTS = [47, 64]             # 다리 양 끝 기둥


def ground_top(x):
    for x0, x1, top, _ in PROFILE:
        if x0 <= x <= x1:
            return top
    return None


def is_rock(x):
    for x0, x1, _, rock in PROFILE:
        if x0 <= x <= x1:
            return rock
    return False


def main():
    ground = [0] * (W * H)
    deco = [0] * (W * H)
    collision = [0] * (W * H)

    def g(x, y, gid):
        ground[y * W + x] = gid

    def d(x, y, gid):
        deco[y * W + x] = gid

    def block(x, y):
        collision[y * W + x] = 1

    # 지형
    for x in range(W):
        top = ground_top(x)
        if top is None:
            continue
        rock = is_rock(x)
        g(x, top, ROCK_TOP if rock else MUD_TOP)
        block(x, top)
        for y in range(top + 1, H):
            g(x, y, ROCK_FILL if rock else MUD_FILL)
            block(x, y)

    # 낭떠러지 벽면 (절벽 어깨의 옆면이 비지 않게 안쪽 한 칸을 바위로)
    for y in range(BRIDGE_Y + 1, H):
        g(47, y, ROCK_FILL)
        g(64, y, ROCK_FILL)

    # 다리
    for x in range(48, 64):
        if x in BRIDGE_GAPS:
            continue
        g(x, BRIDGE_Y, PLANK_BROKEN if x in BRIDGE_BROKEN else PLANK)
        block(x, BRIDGE_Y)

    # 낮은 바위 턱 (늑대 숲)
    for x0, x1, top in LEDGES:
        for x in range(x0, x1 + 1):
            g(x, top, ROCK_TOP)
            block(x, top)
            for y in range(top + 1, ground_top(x)):
                g(x, y, ROCK_FILL)
                block(x, y)

    # 나무 (줄기 2~3칸 + 우듬지, 전부 장식 — 지나갈 수 있다)
    for x, kind in TREES:
        top = ground_top(x)
        tall = 3 if kind == "thick" else 2
        for i in range(1, tall + 1):
            d(x, top - i, TRUNK_THICK if kind == "thick" else TRUNK)
        d(x, top - tall - 1, CANOPY)

    # 풀과 소품
    for x, gid in SHRUBS:
        top = ground_top(x)
        if top is not None:
            d(x, top - 1, gid)

    # 다리 기둥
    for x in ROPE_POSTS:
        d(x, BRIDGE_Y - 1, ROPE_POST)

    # 부서진 레굴루스 석상 (2x2)
    d(STATUE_X, STATUE_TOP, STATUE_TL)
    d(STATUE_X + 1, STATUE_TOP, STATUE_TR)
    d(STATUE_X, STATUE_TOP + 1, STATUE_BL)
    d(STATUE_X + 1, STATUE_TOP + 1, STATUE_BR)

    data = {
        "version": 1, "name": "aldebaran_forest", "id": 100,
        "width": W, "height": H,
        "tileWidth": 16, "tileHeight": 16,
        "layers": [
            {"name": "ground", "data": ground},
            {"name": "deco", "data": deco},
        ],
        "collision": collision,
        "tilesets": [{"image": "resources/aldebaran/forest16.png",
                      "columns": 8, "firstGid": 1}],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    print("만듦:", os.path.relpath(OUT, REPO),
          f"{W}x{H}, 충돌 {sum(collision)}칸")


if __name__ == "__main__":
    main()
