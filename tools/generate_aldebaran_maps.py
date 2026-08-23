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

W, H = 256, 28

# 타일 gid (tools/generate_aldebaran_assets.py 의 forest16.png, firstGid 1)
MUD_TOP, MUD_FILL, ROCK_TOP, ROCK_FILL = 1, 2, 3, 4
PLANK, PLANK_BROKEN, ROPE_POST, SIGN = 5, 6, 7, 8
TRUNK, TRUNK_THICK, CANOPY, VINE = 9, 10, 11, 12
BAMBOO, SHROOM, WEED, SPIRE = 13, 14, 15, 16
STATUE_TL, STATUE_TR, STATUE_BL, STATUE_BR = 17, 18, 19, 20
SKULL, PEBBLE = 21, 22
MUD_TOP_B, MUD_TOP_C, ROCK_TOP_B = 25, 26, 27
ROCK_EDGE_L, ROCK_EDGE_R, CANOPY_BARE = 28, 29, 30
# 5단계에서 더한 것 (gid 33~40)
PAVING, PILLAR_TOP, PILLAR_BOT, HUT_WALL = 33, 34, 35, 36
HUT_ROOF, CAGE, FIREPIT, ALTAR_TILE = 37, 38, 39, 40

MUD_TOPS = (MUD_TOP, MUD_TOP_B, MUD_TOP_C)
ROCK_TOPS = (ROCK_TOP, ROCK_TOP_B)


def variant(seq, x, y):
    """좌표로 고르는 결정적 변형. 난수가 아니라 같은 맵은 늘 같은 그림이다."""
    return seq[(x * 7 + y * 13) % len(seq)]


# ---- 구간 (기획서 4.3절) ---------------------------------------------------
# 구간마다 지형의 성격이 다르다. 경계는 문이 아니라 지형으로 표시한다.
SECTIONS = [
    (0, 47, "entrance"),     # 숲 입구: 평탄한 진흙 길, 얕은 턱 둘
    (48, 99, "road"),        # 옛 길: 포석이 깔린 오르막, 바위 턱 계단
    (100, 147, "gorge"),     # 기암 절벽: 낭떠러지와 다리 둘
    (148, 203, "den"),       # 늑대 마을: 오두막과 우리, 잦은 높낮이
    (204, 255, "altar"),     # 제단 앞: 트인 공터
]


def section_of(x):
    for x0, x1, name in SECTIONS:
        if x0 <= x <= x1:
            return name
    return "altar"


# 지면 높이 (윗면 타일의 y). None 이면 낭떠러지.
# 앞의 숫자가 구간 경계와 맞물리게 짜 두었다.
# 지면 높이 (윗면 타일의 y). None 이면 낭떠러지.
# 레벨 디자인(계획 3.5절): 새 위험은 안전한 자리에서 먼저 보여 주고, 그 다음에 시험한다.
PROFILE = [
    # 1구간 숲 입구: 평지에서 배우고, 1타일 턱으로 점프를 소개하고, 2타일 턱으로 시험
    (0, 19, 24, False),      # 평지 (첫 거미가 여기. 혼자, 안전하다)
    (20, 27, 23, True),      # 1타일 턱 (실패해도 다치지 않는다)
    (28, 37, 24, False),     # 다시 평지 (쉬는 박자)
    (38, 47, 22, True),      # 2타일 턱 (그 위에 거미. 점프하고 싸운다)
    # 2구간 옛 길: 포석 계단 넷. 오를수록 좁아진다
    (48, 61, 22, False),
    (62, 73, 21, True),
    (74, 85, 20, True),
    (86, 99, 19, True),      # 끝에 석주와 체크포인트 (다리 앞)
    # 3구간 기암 절벽: 구멍 둘 셋 다섯으로 늘어난다
    (100, 111, 19, True),    # 어깨
    (112, 119, None, False), # 첫 다리 (구멍 2칸)
    (120, 127, 19, True),    # 중간 바위섬 (쉬는 자리)
    (128, 139, None, False), # 둘째 다리 (구멍 3칸)
    (140, 147, 20, True),    # 건너편 어깨
    # 4구간 늑대 마을: 높낮이가 잦고 좁다
    (148, 159, 22, False),   # 마을 초입 (우리와 체크포인트)
    (160, 167, 20, True),
    (168, 181, 23, False),   # 오두막 앞 마당 (늑대 둘)
    (182, 189, 21, True),
    (190, 203, 23, False),   # 안쪽 (검은 늑대)
    # 5구간 제단 앞: 트인 공터
    (204, 255, 24, False),
]

# 다리. 가르치고 나서 시험한다 (계획 3.5절).
#   첫째는 **얕은 도랑** 위다. 빠져도 두 칸이라 뛰어서 나온다. 벌이 없는 연습.
#   둘째는 진짜 낭떠러지다. 구멍 셋을 못 넘으면 목숨을 잃는다.
BRIDGES = [
    (112, 119, 19, {115, 116}, {113}),
    (128, 139, 19, {132, 133, 134}, {130, 137}),
]
TRENCH = (112, 119, 21)     # 첫 다리 아래의 도랑 바닥 (다리보다 두 칸 아래)

# 마을의 낮은 턱 (지면 위에 얹힌다). 늑대를 상대할 발판이 된다.
LEDGES = [(152, 157, 20), (196, 201, 21)]

TREES = [(4, "thin"), (10, "thick"), (20, "thin"), (31, "thin"), (43, "thick"),
         (52, "thin"), (66, "thin"), (78, "thick"), (92, "thin"),
         (150, "thick"), (156, "thin"), (163, "thick"), (172, "thin"),
         (176, "thick"), (183, "thin"), (190, "thick"), (196, "thin"), (201, "thick"),
         (208, "thin"), (214, "thick")]

SHRUBS = [(3, WEED), (8, SHROOM), (14, BAMBOO), (24, WEED), (30, VINE), (36, PEBBLE),
          (45, WEED),
          (55, PEBBLE), (69, WEED), (81, SHROOM), (95, PEBBLE),
          (104, SKULL), (128, WEED), (146, SKULL),
          (152, SHROOM), (166, WEED), (170, SKULL), (186, SHROOM), (200, WEED),
          (210, SKULL), (222, WEED), (240, SPIRE), (248, SPIRE)]

# 옛 길의 부서진 석주 (2칸 높이). 구간 2의 표식이다.
PILLARS = [56, 64, 72, 80, 88, 96]
# 마을의 오두막 (x, 지면). 벽 2칸에 지붕 1칸.
HUTS = [(158, 22), (174, 23), (194, 23)]
# 매달린 우리 (4구간의 흔적 자리)
CAGES = [(168, 20), (169, 20)]
FIREPITS = [(162, 23), (198, 23)]

# 마름모 제단 (5구간). 네 화두는 꼭짓점에 있다.
ALTAR_X, ALTAR_Y = 232, 22
STATUE_X, STATUE_TOP = 244, 22
ROPE_POSTS = [111, 124, 131, 144]


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
        if rock:
            left = ground_top(x - 1) != top or not is_rock(x - 1)
            right = ground_top(x + 1) != top or not is_rock(x + 1)
            if left:
                g(x, top, ROCK_EDGE_L)
            elif right:
                g(x, top, ROCK_EDGE_R)
            else:
                g(x, top, variant(ROCK_TOPS, x, top))
        else:
            g(x, top, variant(MUD_TOPS, x, top))
        block(x, top)
        for y in range(top + 1, H):
            g(x, y, ROCK_FILL if rock else MUD_FILL)
            block(x, y)

    # 첫 다리 아래의 얕은 도랑 (빠져도 뛰어서 나온다)
    tx0, tx1, ty = TRENCH
    for x in range(tx0, tx1 + 1):
        g(x, ty, variant(ROCK_TOPS, x, ty))
        block(x, ty)
        for y in range(ty + 1, H):
            g(x, y, ROCK_FILL)
            block(x, y)

    # 낭떠러지 벽면 (어깨의 옆면이 비지 않게 안쪽 한 칸을 바위로)
    for x0, x1, by, gaps, broken in BRIDGES:
        for y in range(by + 1, H):
            g(x0 - 1, y, ROCK_FILL)
            g(x1 + 1, y, ROCK_FILL)
        for x in range(x0, x1 + 1):
            if x in gaps:
                continue
            g(x, by, PLANK_BROKEN if x in broken else PLANK)
            block(x, by)

    # 마을의 낮은 턱
    for x0, x1, top in LEDGES:
        for x in range(x0, x1 + 1):
            if x == x0:
                g(x, top, ROCK_EDGE_L)
            elif x == x1:
                g(x, top, ROCK_EDGE_R)
            else:
                g(x, top, variant(ROCK_TOPS, x, top))
            block(x, top)
            below = ground_top(x)
            if below is not None:
                for y in range(top + 1, below):
                    g(x, y, ROCK_FILL)
                    block(x, y)

    # 옛 길의 포석 (2구간의 지면을 덮는다)
    for x in range(48, 100):
        top = ground_top(x)
        if top is not None and not is_rock(x):
            g(x, top, PAVING)

    # 부서진 석주 (2구간)
    for x in PILLARS:
        top = ground_top(x)
        if top is None:
            continue
        d(x, top - 1, PILLAR_BOT)
        d(x, top - 2, PILLAR_TOP)

    # 나무
    for x, kind in TREES:
        top = ground_top(x)
        if top is None:
            continue
        tall = 3 if kind == "thick" else 2
        for i in range(1, tall + 1):
            d(x, top - i, TRUNK_THICK if kind == "thick" else TRUNK)
        d(x, top - tall - 1, CANOPY_BARE)

    # 풀과 소품
    for x, gid in SHRUBS:
        top = ground_top(x)
        if top is not None:
            d(x, top - 1, gid)

    # 늑대 인간의 오두막 (벽 둘에 지붕 하나). 짐승이 아니라 살림을 꾸린 자들이다
    for x, base in HUTS:
        for dx in range(3):
            d(x + dx, base - 1, HUT_WALL)
            d(x + dx, base - 2, HUT_WALL)
            d(x + dx, base - 3, HUT_ROOF)
            block(x + dx, base - 1)
            block(x + dx, base - 2)

    # 매달린 우리와 모닥불
    for x, base in CAGES:
        d(x, base - 3, CAGE)
    for x, base in FIREPITS:
        d(x, base - 1, FIREPIT)

    # 다리 기둥
    for x in ROPE_POSTS:
        top = ground_top(x)
        if top is not None:
            d(x, top - 1, ROPE_POST)

    # 마름모 제단 (5구간). 바닥 타일과 네 꼭짓점의 화두
    for dy in range(3):
        for dx in range(7):
            if abs(dx - 3) + abs(dy - 1) <= 3:
                g(ALTAR_X + dx, ALTAR_Y + dy, ALTAR_TILE)

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
