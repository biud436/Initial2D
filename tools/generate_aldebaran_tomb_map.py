#!/usr/bin/env python3
"""알데바란 스테이지 1-2 「황제의 무덤」 맵 생성기
(docs/plans/aldebaran-7-tomb.md 3절).

320x30 타일, 가로 5120px. 지형과 장식은 **전부 손으로 정한 자리다. 난수로
뿌리지 않는다** (1-1과 같은 규칙).

무덤은 안이라 숲과 두 가지가 다르다.
  1. **천장이 있다.** 위가 트여 있지 않으므로 점프의 높이가 곧 제약이 된다.
  2. **방과 복도로 끊긴다.** 복도는 좁고 낮고, 방은 넓고 높다. 그 리듬이
     "무덤에 들어왔다"는 감각을 만든다.

방 다섯 (원안 표 19의 방 이름. x 타일):
    0~ 55  가슴부 입구와 첫 복도 — 무덤의 문법을 가르친다 (기후 없음)
   56~119  달의 방 — 눈. 바닥이 미끄럽다
  120~183  별들의 방 — 빛기둥. 그늘의 영혼은 베이지 않는다
  184~251  파괴의 방 — 우박. 머리 위를 본다
  252~319  태양의 방 — 홍수. 수위가 오르내린다. 아포피스

몬스터 배치는 scripts/games/aldebaran/stages/tomb.lua 에 있다.

Usage: python3 tools/generate_aldebaran_tomb_map.py
"""

import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "resources", "maps", "aldebaran_tomb.json")

W, H = 320, 30

# 타일 gid (tools/generate_aldebaran_tomb.py 의 tomb16.png, firstGid 1)
LIME_TOP, LIME_FILL, SAND_TOP, SAND_FILL = 1, 2, 3, 4
GOLD_BAND, CRACK_TOP, STEP, EDGE_L = 5, 6, 7, 8
WALL, WALL_HIERO, PILLAR_TOP, PILLAR_MID = 9, 10, 11, 12
PILLAR_BASE, BRAZIER, EDGE_R = 13, 14, 15
SARC_TL, SARC_TR, SARC_BL, SARC_BR = 17, 18, 19, 20
INLAY_STAR, INLAY_MOON, INLAY_SUN, WATER_TOP = 21, 22, 23, 24
WATER, RUBBLE, BONES, URN = 25, 26, 27, 28
LIME_TOP_B, LIME_TOP_C = 29, 30

FLOOR_TOPS = (LIME_TOP, LIME_TOP_B, LIME_TOP_C)

CEIL_BAND = 4       # 천장에서 아래로 그리는 벽의 줄 수 (위는 배경이 보인다)


def variant(seq, x, y):
    """좌표로 고르는 결정적 변형. 같은 맵은 늘 같은 그림이다."""
    return seq[(x * 7 + y * 13) % len(seq)]


# ---- 방과 복도 -------------------------------------------------------------
# (x0, x1, 이름). 씬의 구간(stages/tomb.lua의 SECTIONS)과 경계가 같아야 한다.
ROOMS = [
    (0, 55, "chest"),
    (56, 119, "moon"),
    (120, 183, "stars"),
    (184, 251, "ruin"),
    (252, 319, "sun"),
]

# 바닥 높이와 천장 높이 (타일 y). 복도는 좁고 방은 넓다.
#   (x0, x1, 바닥 윗면, 천장 아랫면)
PROFILE = [
    (0, 11, 24, 14),        # 가슴부 입구 (밖에서 들어온다. 조금 넓다)
    (12, 23, 24, 18),       # 첫 복도 — 낮다
    (24, 33, 22, 16),       # 계단 하나 올라
    (34, 43, 22, 18),       # 복도
    (44, 55, 24, 15),       # 방으로 트인다
    # 달의 방: 넓고, 바닥에 단이 셋
    (56, 71, 25, 10),
    (72, 83, 22, 10),
    (84, 95, 25, 10),
    (96, 107, 20, 10),
    (108, 119, 25, 11),
    # 복도로 이어지는 목 (별들의 방 앞)
    (120, 129, 25, 17),
    # 별들의 방: 천장이 높고 발판이 공중에 있다 (공중형의 무대)
    (130, 155, 26, 8),
    (156, 167, 26, 8),
    (168, 183, 24, 12),
    # 파괴의 방: 무너진 바닥. 구덩이 둘
    (184, 199, 24, 9),
    (200, 209, 26, 9),
    (210, 225, 23, 9),
    (226, 239, 26, 9),
    (240, 251, 24, 13),
    # 태양의 방: 넓고 평평하다 (보스가 도는 자리). 가장자리가 낮아 물이 찬다
    (252, 263, 26, 8),
    (264, 307, 25, 6),
    (308, 319, 26, 8),
]

# 공중 발판 (x0, x1, y). 별들의 방과 파괴의 방의 세로 동선
LEDGES = [
    (136, 141, 20), (146, 151, 17), (158, 163, 20),   # 별들의 방
    (192, 196, 19), (216, 220, 18), (232, 236, 20),   # 파괴의 방
    (272, 277, 20), (288, 293, 19),                   # 태양의 방 (물 위의 섬)
]

# 구덩이 (x0, x1). 바닥이 없다 — 떨어지면 아래에서 다시 올라와야 한다
PITS = [(202, 207), (228, 234)]

# 물 (태양의 방). 수위는 씬이 흔들지만, 바닥의 웅덩이는 맵이 그린다
WATER_POOL = (264, 307, 24)

# 기둥 (x). 방마다 규칙적으로 선다
PILLARS = [60, 68, 88, 100, 112,          # 달의 방
           134, 150, 166, 178,            # 별들의 방
           188, 214, 244,                 # 파괴의 방
           258, 270, 286, 300, 314]       # 태양의 방

# 석관 2x2 (x, 윗줄 y)
SARCOPHAGI = [(78, 20), (104, 18), (170, 22), (296, 23)]

# 상감 바닥 (x, 종류). 방의 이름이 바닥에 박혀 있다
INLAYS = [(90, INLAY_MOON), (148, INLAY_STAR), (280, INLAY_SUN)]

# 화로 (x). 불빛이 있어야 방이 보인다
BRAZIERS = [18, 40, 64, 108, 132, 174, 190, 246, 262, 310]

# 잔해와 뼈와 항아리 (x, gid)
DEBRIS = [(28, BONES), (50, URN), (76, RUBBLE), (94, BONES), (118, URN),
          (140, RUBBLE), (162, BONES), (186, RUBBLE), (198, RUBBLE),
          (222, BONES), (250, URN), (266, RUBBLE), (304, BONES)]


def room_of(x):
    for x0, x1, name in ROOMS:
        if x0 <= x <= x1:
            return name
    return ROOMS[-1][2]


def profile_of(x):
    for x0, x1, floor, ceil in PROFILE:
        if x0 <= x <= x1:
            return floor, ceil
    return None, None


def in_pit(x):
    return any(x0 <= x <= x1 for x0, x1 in PITS)


def main():
    ground = [0] * (W * H)
    deco = [0] * (W * H)
    collision = [0] * (W * H)

    def g(x, y, gid):
        if 0 <= x < W and 0 <= y < H:
            ground[y * W + x] = gid

    def dc(x, y, gid):
        if 0 <= x < W and 0 <= y < H:
            deco[y * W + x] = gid

    def block(x, y):
        if 0 <= x < W and 0 <= y < H:
            collision[y * W + x] = 1

    # ---- 바닥과 천장 --------------------------------------------------------
    for x in range(W):
        floor, ceil = profile_of(x)
        if floor is None:
            continue

        if in_pit(x):
            # 구덩이: 바닥이 없다. 아주 아래에 받침만 둔다 (즉사가 아니다)
            for y in range(H - 2, H):
                g(x, y, LIME_FILL)
                block(x, y)
        else:
            top = floor
            room = room_of(x)
            if room == "ruin":
                g(x, top, CRACK_TOP)          # 파괴의 방은 갈라진 바닥
            elif room == "chest":
                g(x, top, SAND_TOP)           # 입구는 밖에서 들어온 모래
            else:
                g(x, top, variant(FLOOR_TOPS, x, top))
            block(x, top)
            for y in range(top + 1, H):
                g(x, y, SAND_FILL if room == "chest" else LIME_FILL)
                block(x, y)

        # 천장. 카메라는 세로로 움직이지 않으므로(y 고정) 천장 위를 전부 벽으로
        # 메우면 화면의 절반이 벽이 되고 배경이 하나도 보이지 않는다. 그래서
        # **벽은 천장 아래 네 줄만 그리고**, 그 위는 비워 배경(먼 방과 기둥)에
        # 맡긴다. 막는 것은 그대로 위까지 막는다.
        for y in range(0, ceil + 1):
            if y >= ceil - CEIL_BAND + 1:
                g(x, y, WALL_HIERO if (x % 9 == 4 and y == ceil - 1) else WALL)
            block(x, y)
        # 천장 아래 금박 띠 한 줄. 죽 이어야 띠로 보인다 (띄엄띄엄 두면 공중에
        # 뜬 벽돌로 보인다 — 실제로 그렇게 보여서 고쳤다)
        dc(x, ceil + 1, GOLD_BAND)

    # ---- 공중 발판 ----------------------------------------------------------
    for x0, x1, y in LEDGES:
        for x in range(x0, x1 + 1):
            g(x, y, STEP)
            block(x, y)

    # ---- 물웅덩이 (태양의 방) -----------------------------------------------
    wx0, wx1, wy = WATER_POOL
    for x in range(wx0, wx1 + 1):
        floor, _ = profile_of(x)
        if floor is None or in_pit(x):
            continue
        for y in range(wy, floor):
            dc(x, y, WATER_TOP if y == wy else WATER)

    # ---- 기둥 ---------------------------------------------------------------
    for x in PILLARS:
        floor, ceil = profile_of(x)
        if floor is None:
            continue
        dc(x, floor - 1, PILLAR_BASE)
        for y in range(ceil + 2, floor - 1):
            dc(x, y, PILLAR_MID)
        dc(x, ceil + 1, PILLAR_TOP)

    # ---- 석관 ---------------------------------------------------------------
    for x, y in SARCOPHAGI:
        dc(x, y, SARC_TL)
        dc(x + 1, y, SARC_TR)
        dc(x, y + 1, SARC_BL)
        dc(x + 1, y + 1, SARC_BR)

    # ---- 상감 바닥 ----------------------------------------------------------
    for x, gid in INLAYS:
        floor, _ = profile_of(x)
        if floor is not None:
            for dx in range(3):
                g(x + dx, floor, gid)

    # ---- 화로와 잔해 --------------------------------------------------------
    for x in BRAZIERS:
        floor, _ = profile_of(x)
        if floor is not None and not in_pit(x):
            dc(x, floor - 1, BRAZIER)

    for x, gid in DEBRIS:
        floor, _ = profile_of(x)
        if floor is not None and not in_pit(x):
            dc(x, floor - 1, gid)

    # ---- 방의 양 끝 바닥 가장자리 -------------------------------------------
    for x in range(1, W - 1):
        floor, _ = profile_of(x)
        if floor is None or in_pit(x):
            continue
        left, _ = profile_of(x - 1)
        right, _ = profile_of(x + 1)
        if left is None or left != floor or in_pit(x - 1):
            g(x, floor, EDGE_L)
        elif right is None or right != floor or in_pit(x + 1):
            g(x, floor, EDGE_R)

    data = {
        "version": 1, "name": "aldebaran_tomb", "id": 101,
        "width": W, "height": H,
        "tileWidth": 16, "tileHeight": 16,
        "layers": [
            {"name": "ground", "data": ground},
            {"name": "deco", "data": deco},
        ],
        "collision": collision,
        "tilesets": [{"image": "resources/aldebaran/tomb16.png",
                      "columns": 8, "firstGid": 1}],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    print("만듦:", os.path.relpath(OUT, REPO),
          f"{W}x{H}, 충돌 {sum(collision)}칸")


if __name__ == "__main__":
    main()
