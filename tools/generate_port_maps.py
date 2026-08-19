#!/usr/bin/env python3
"""데모 「떠나기 전에」의 맵 두 장을 만든다 (기획서 docs/design/port-town.md 4절).

  port_town.json  항구 마을 32x48 — 세로 화면(24x28 타일)에 맞춘 세로 배치
  inn.json        여관 1층 20x14

**난수를 쓰지 않는다.** 8단계의 마을 맵은 장식 90개를 난수로 뿌렸고, 이슈 24는
그런 배치를 "기술 데모용"이라고 지적했다. 여기서는 모든 타일이 기획서의 좌표에서
나오며, 같은 명령을 몇 번 돌려도 같은 파일이 나온다.

타일은 resources/tiles/port16.png (tools/generate_port_tileset.py).

Usage: python3 tools/generate_port_maps.py
"""

import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPS = os.path.join(REPO, "resources", "maps")
TILESET = {"image": "resources/tiles/port16.png", "columns": 8, "firstGid": 1}

# ---- gid (generate_port_tileset.py의 출력과 같은 번호) ----------------------

GRASS, PATH = 46, 45
FLOWER_W, FLOWER_B, BUSH = 56, 32, 40
ROCK = 21
TREE_TOP, TREE_BOT = 26, 34
ROOF = (105, 106, 107)
EAVE = (108, 109, 110)
WALL_L, WALL_R, DOOR = 111, 112, 113
FLOOR, WALL_TOP, WALL, VOID = 114, 115, 116, 117

SEA, SEA2, SHORE = 121, 122, 123
PLANK, PLANK_L, PLANK_R = 124, 125, 126
BOLLARD, CRATE = 127, 128
SAIL_L, SAIL_M, SAIL_R = 129, 130, 131
HULL_BOW, HULL_MID, HULL_STERN = 132, 133, 134
LH = {  # 등대 (2x3)
    (0, 0): 135, (0, 1): 136,
    (1, 0): 137, (1, 1): 138,
    (2, 0): 139, (2, 1): 140,
}
WELL_TOP, WELL_BOT = 141, 142
BOARD_TOP, BOARD_BOT = 143, 144
STALL_AW_L, STALL_AW_R, STALL_L, STALL_R = 145, 146, 147, 148
BENCH_L, BENCH_R = 149, 150
LAUNDRY_L, LAUNDRY_R = 151, 152
COBBLE, STEPS, WAREHOUSE_DOOR, INN_SIGN, GATE = 153, 154, 155, 156, 157
HEARTH, TABLE = 158, 159

VW, VH = 32, 48          # 항구 마을
IW, IH = 20, 14          # 여관 1층

ROAD_X = (15, 16)        # 남북으로 곧게 뻗은 큰길
PIER_X = (15, 16, 17)    # 부두 널
SHORE_Y = 41             # 물가 줄 (여기부터 아래가 바다)
PIER_BOTTOM = 45


class Grid:
    """땅(ground), 장식(deco), 통행(collision) 세 장을 함께 들고 있는 맵."""

    def __init__(self, w, h, fill):
        self.w, self.h = w, h
        self.ground = [fill] * (w * h)
        self.deco = [0] * (w * h)
        self.collision = [0] * (w * h)

    def g(self, x, y, gid):
        self.ground[y * self.w + x] = gid

    def d(self, x, y, gid, solid=True):
        self.deco[y * self.w + x] = gid
        if solid:
            self.collision[y * self.w + x] = 1

    def block(self, x, y, on=True):
        self.collision[y * self.w + x] = 1 if on else 0

    def rect_g(self, x0, y0, x1, y1, gid):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g(x, y, gid)

    def rect_block(self, x0, y0, x1, y1, on=True):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.block(x, y, on)

    def stamp(self, x, y, rows, solid=True, holes=()):
        """왼쪽 위를 (x, y)로 삼아 gid 표를 찍는다. holes는 통행 가능한 칸."""
        for dy, row in enumerate(rows):
            for dx, gid in enumerate(row):
                if gid == 0:
                    continue
                self.d(x + dx, y + dy, gid, solid=solid)
                if (dx, dy) in holes:
                    self.block(x + dx, y + dy, False)

    def to_map(self, name, map_id, events=None):
        """맵 포맷. events가 있으면 v2다 (없으면 v1 그대로 — 옛 파일도 열린다)."""
        data = {
            "version": 2 if events else 1, "name": name, "id": map_id,
            "width": self.w, "height": self.h,
            "tileWidth": 16, "tileHeight": 16,
            "layers": [
                {"name": "ground", "data": self.ground},
                {"name": "deco", "data": self.deco},
            ],
            "collision": self.collision,
            "tilesets": [dict(TILESET)],
        }
        if events:
            data["events"] = events
        return data


# ---- 항구 마을 -------------------------------------------------------------


def build_town():
    m = Grid(VW, VH, GRASS)

    # 큰길: 북쪽 문(y=4)에서 부두 입구(y=40)까지 곧게. 언덕 구간은 돌계단이다.
    for y in range(4, SHORE_Y):
        for x in ROAD_X:
            m.g(x, y, STEPS if 14 <= y <= 17 else PATH)

    # 광장: 큰길을 감싸는 돌바닥
    m.rect_g(10, 34, 21, 39, COBBLE)

    # 바다와 물가
    for x in range(VW):
        m.g(x, SHORE_Y, SHORE)
        m.block(x, SHORE_Y)
    for y in range(SHORE_Y + 1, VH):
        for x in range(VW):
            m.g(x, y, SEA if (x + y) % 2 == 0 else SEA2)
            m.block(x, y)

    # 부두: 물가를 가로질러 바다로 뻗는다
    for y in range(SHORE_Y, PIER_BOTTOM + 1):
        m.g(PIER_X[0], y, PLANK_L)
        m.g(PIER_X[1], y, PLANK)
        m.g(PIER_X[2], y, PLANK_R)
        for x in PIER_X:
            m.block(x, y, False)

    # 저녁 배: 부두 오른쪽에 댄다 (돛 한 줄, 선체 한 줄)
    m.stamp(18, 43, [
        [SAIL_L, SAIL_M, SAIL_R],
        [HULL_BOW, HULL_MID, HULL_STERN],
    ])

    # 부두의 살림
    m.d(PIER_X[2], 42, BOLLARD)          # 밧줄 말뚝
    m.d(13, 40, CRATE)                   # 짐 상자 둘
    m.d(14, 40, CRATE)

    # 광장의 살림
    m.stamp(13, 36, [[BOARD_TOP], [BOARD_BOT]])            # 게시판
    m.stamp(18, 35, [[WELL_TOP], [WELL_BOT]])              # 우물
    m.stamp(11, 34, [[STALL_AW_L, STALL_AW_R],             # 생선 좌판 (광장 안에)
                     [STALL_L, STALL_R]])
    m.d(19, 34, BENCH_L)                                   # 벤치
    m.d(20, 34, BENCH_R)

    # 큰길가: 여관과 창고 (문 칸만 통행 가능)
    m.stamp(12, 27, [
        list(ROOF), list(EAVE), [WALL_L, DOOR, INN_SIGN],
    ], holes={(1, 2)})
    m.stamp(18, 27, [
        list(ROOF), list(EAVE), [WALL_L, WAREHOUSE_DOOR, WALL_R],
    ])

    # 주택가: 빨래줄과 살림집 둘 (이야기는 없고 마을을 채우는 몫)
    m.d(12, 21, LAUNDRY_L)
    m.d(13, 21, LAUNDRY_R)
    m.stamp(10, 22, [list(ROOF), list(EAVE), [WALL_L, DOOR, WALL_R]])
    m.stamp(19, 19, [list(ROOF), list(EAVE), [WALL_L, WALL_R, DOOR]])

    # 언덕의 등대 (2x3). 문 칸은 이벤트가 잠겨 있다고 말한다.
    m.stamp(17, 10, [[LH[(0, 0)], LH[(0, 1)]],
                     [LH[(1, 0)], LH[(1, 1)]],
                     [LH[(2, 0)], LH[(2, 1)]]])

    # 북쪽 문: 숲으로 가는 길을 막아 두었다
    for x in ROAD_X:
        m.d(x, 6, GATE)

    # 마을을 두르는 나무와 바위 (좌우 끝과 위쪽). 좌표는 규칙에서 나오며 난수가 아니다.
    for y in range(2, SHORE_Y):
        for x in (0, 1, VW - 2, VW - 1):
            if (x + y) % 3 == 0:
                m.stamp(x, y - 1 if y > 2 else y, [[TREE_TOP], [TREE_BOT]])
            else:
                m.d(x, y, ROCK)
    for x in range(VW):
        for y in (0, 1):
            m.d(x, y, ROCK)
    m.rect_block(0, 0, VW - 1, 3)
    for x in ROAD_X:                      # 북쪽 문 위로는 길만 남긴다 (막혀 있다)
        m.block(x, 3, False)
        m.g(x, 3, PATH)
        m.g(x, 2, PATH)

    # 잔디의 장식: 정해진 자리에만
    for x, y, gid in (
        (8, 30, BUSH), (23, 31, BUSH), (7, 24, FLOWER_W), (24, 25, FLOWER_B),
        (9, 18, BUSH), (22, 16, BUSH), (11, 12, FLOWER_W), (21, 13, FLOWER_B),
        (6, 36, BUSH), (25, 37, BUSH), (8, 9, BUSH), (23, 8, BUSH),
    ):
        m.d(x, y, gid, solid=False)

    # 맵 파일이 실어 나르는 이벤트 (포맷 v2). 좌표와 커맨드가 전부 데이터라
    # 맵 에디터가 이 자리에서 만들 수 있다 — 나머지 이벤트는 아직 Lua 정의
    # 파일에 있다 (배회 설정처럼 데이터로만 적기 어려운 것이 섞여 있다).
    events = [{
        "id": "crates",
        "x": 14, "y": 40,
        "trigger": "action",
        "commands": [{
            "code": "message",
            "text": "누군가의 짐이다. 남쪽으로 간다는 표가 붙어 있다.",
        }],
    }]
    return m.to_map("항구 마을", 10, events)


# ---- 여관 1층 --------------------------------------------------------------


def build_inn():
    m = Grid(IW, IH, VOID)

    # 방: 벽으로 두르고 안쪽은 나무 바닥
    m.rect_g(0, 0, IW - 1, IH - 1, FLOOR)
    m.rect_block(0, 0, IW - 1, IH - 1)
    for x in range(IW):
        m.d(x, 0, WALL_TOP)
        m.d(x, 1, WALL)
        m.d(x, IH - 1, WALL)
    for y in range(2, IH - 1):
        m.d(0, y, WALL)
        m.d(IW - 1, y, WALL)
    for y in range(2, IH - 1):
        for x in range(1, IW - 1):
            m.block(x, y, False)

    # 카운터: 주인이 설 자리(10, 3)만 비워 둔다
    for x in (7, 8, 9, 11, 12):
        m.d(x, 3, TABLE)
    m.d(14, 3, TABLE)              # 방명록을 올려 둔 탁자
    m.d(2, 3, HEARTH)              # 난로

    # 손님 자리 둘 — 탁자와 의자
    for x in (5, 6, 13, 14):
        m.d(x, 7, TABLE)
    m.d(5, 8, BENCH_L)
    m.d(6, 8, BENCH_R)
    m.d(13, 8, BENCH_L)
    m.d(14, 8, BENCH_R)

    # 2층 계단 (오르면 이벤트가 막는다)
    m.d(17, 3, STEPS)
    m.d(17, 4, STEPS)

    # 아래 출입구
    door = (10, IH - 1)
    m.d(door[0], door[1], DOOR)
    m.block(door[0], door[1], False)

    return m.to_map("항구 여관", 11)


def write(name, data):
    path = os.path.join(MAPS, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("generated:", os.path.relpath(path, REPO),
          f"({data['width']}x{data['height']})")


def main():
    os.makedirs(MAPS, exist_ok=True)
    write("port_town.json", build_town())
    write("inn.json", build_inn())


if __name__ == "__main__":
    main()
