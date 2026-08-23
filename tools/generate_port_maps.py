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
FLOWER_W, FLOWER_B, BUSH = 56, 32, 42
RIDGE_L, RIDGE_M, RIDGE_R = 37, 38, 39      # 가로로 누운 바위 능선
RIDGE_V, RIDGE_V_END = 43, 51               # 세로 능선과 그 아래 끝
PEBBLE = 30                                 # 잔디 위의 작은 바위

# 마을을 두르는 바위 테두리 한 벌. 한 칸 두께의 링이며, 안쪽은 잔디 그대로다.
# (예전에는 ROCK=21을 두 줄로 채웠는데 21은 "바위 덩어리의 아랫면"이라 세로로
#  쌓으면 바위와 잔디가 번갈아 나오는 줄무늬가 됐다. 26/34를 나무로 쓴 것도
#  잘못이어서 — 34는 울타리 기둥이다 — 테두리가 통째로 어그러져 있었다.
#  이 타일셋에는 나무가 없다.)
EDGE_TL, EDGE_T, EDGE_TR = 5, 6, 7
EDGE_L, EDGE_R = 13, 15
EDGE_BL, EDGE_B, EDGE_BR = 9, 22, 10        # 아래쪽 — 이 맵에서는 바다가 대신한다

# 잔디와 모래가 만나는 가장자리. 타일셋에 이미 있었는데 쓰지 않고 있었다 —
# 그래서 길도 광장도 물가도 각진 사각형으로 잘려 있었다.
# 이름은 "모래가 어느 쪽에 있는가"로 읽는다 (SAND_S = 아래쪽이 모래).
SAND_S, SAND_N, SAND_E, SAND_W = 54, 70, 61, 63
SAND_NW, SAND_NE, SAND_SW, SAND_SE = 59, 60, 67, 68
SAND_NICK_SW = 55                           # 안쪽 모서리 (남서 대각선만 모래)

ROOF = (105, 106, 107)
EAVE = (108, 109, 110)
WALL_L, WALL_R, DOOR = 111, 112, 113
FLOOR, WALL_TOP, WALL, VOID = 114, 115, 116, 117

SHORE = 123
# 바다는 2x2 한 벌이다 (generate_port_tileset.py 참고). (y % 2, x % 2)로 고른다.
SEA_BLOCK = ((121, 122), (160, 161))
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
FENCE_L, FENCE_M, FENCE_R = 73, 74, 75      # 나무 울타리 (왼끝, 가운데, 오른끝)
HEARTH, TABLE = 158, 159

VW, VH = 32, 48          # 항구 마을
IW, IH = 20, 14          # 여관 1층

ROAD_X = (15, 16)        # 남북으로 곧게 뻗은 큰길
GATE_Y = 6               # 북쪽 울타리와 문 (여기부터 위는 갈 수 없다)
PIER_X = (15, 16, 17)    # 부두 널
SHORE_Y = 41             # 물가 줄 (여기부터 아래가 바다)
PIER_BOTTOM = 45


class Grid:
    """땅(ground), 장식(deco), 머리 위(over), 통행(collision)을 함께 들고 있는 맵.

    deco와 over를 나누는 까닭은 그리는 순서다. 캐릭터 프레임(24x32)은 타일(16x16)보다
    커서 머리가 윗 칸으로 올라가므로, 그 칸의 타일을 캐릭터보다 **뒤**에 그릴지
    **앞**에 그릴지가 정해져 있어야 한다.

      deco  캐릭터보다 아래. 집 벽, 울타리, 우물, 게시판처럼 **앞에 서는** 것
      over  캐릭터보다 위. 빨래줄처럼 **밑을 지나가는** 것

    한 장뿐이면 집 벽 앞에 섰을 때 벽이 머리를 덮는다 (2026-08-20 사용자 보고).
    """

    def __init__(self, w, h, fill):
        self.w, self.h = w, h
        self.ground = [fill] * (w * h)
        self.deco = [0] * (w * h)
        self.over = [0] * (w * h)
        self.collision = [0] * (w * h)
        self.sandy = set()      # blend_sand가 볼 "모래로 치는 칸"

    def g(self, x, y, gid):
        self.ground[y * self.w + x] = gid

    def d(self, x, y, gid, solid=True):
        self.deco[y * self.w + x] = gid
        if solid:
            self.collision[y * self.w + x] = 1

    def o(self, x, y, gid, solid=False):
        """머리 위로 지나가는 것. 기본은 통행 가능하다 (밑을 지나가라고 있는 층이다)."""
        self.over[y * self.w + x] = gid
        if solid:
            self.collision[y * self.w + x] = 1

    def block(self, x, y, on=True):
        self.collision[y * self.w + x] = 1 if on else 0

    def rect_g(self, x0, y0, x1, y1, gid):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g(x, y, gid)

    def sand(self, x, y, gid):
        """모래로 치는 칸. 잔디와 맞닿는 자리는 blend_sand가 가장자리 타일로 바꾼다."""
        self.g(x, y, gid)
        self.sandy.add((x, y))

    def rect_sand(self, x0, y0, x1, y1, gid):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.sand(x, y, gid)

    def blend_sand(self, grass):
        """잔디 칸 가운데 모래와 맞닿은 것을 가장자리 타일로 바꾼다.

        오토타일이 아니라 한 번 도는 후처리다. 맵이 다 그려진 뒤에 부르며,
        바꾸는 것은 잔디 칸뿐이라 길과 광장과 물가의 폭은 그대로 남는다.
        모서리 타일은 네 방향 가운데 둘이 모래일 때 고른다 — 이 타일셋에 안쪽
        모서리는 남서쪽 한 장(SAND_NICK_SW)뿐이라 나머지는 잔디로 둔다.
        """
        def sandy(x, y):
            return (x, y) in self.sandy

        straight = {
            (0, 1, 0, 0): SAND_S, (0, 0, 0, 1): SAND_N,
            (0, 0, 1, 0): SAND_E, (1, 0, 0, 0): SAND_W,
        }
        corner = {
            (0, 0, 1, 1): SAND_NE, (1, 0, 0, 1): SAND_NW,
            (0, 1, 1, 0): SAND_SE, (1, 1, 0, 0): SAND_SW,
        }

        out = list(self.ground)
        for y in range(self.h):
            for x in range(self.w):
                if self.ground[y * self.w + x] != grass:
                    continue
                key = (int(sandy(x - 1, y)), int(sandy(x, y + 1)),
                       int(sandy(x + 1, y)), int(sandy(x, y - 1)))
                gid = straight.get(key) or corner.get(key)
                if gid is None and key == (0, 0, 0, 0) and sandy(x - 1, y + 1):
                    gid = SAND_NICK_SW
                if gid is not None:
                    out[y * self.w + x] = gid
        self.ground = out

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
        """맵 포맷. events가 있으면 v2다 (없으면 v1 그대로 — 옛 파일도 열린다).

        over 층은 비어 있으면 내보내지 않는다. 그래야 실내처럼 머리 위에 아무것도
        없는 맵이 쓸데없이 빈 배열을 싣지 않는다.
        """
        layers = [
            {"name": "ground", "data": self.ground},
            {"name": "deco", "data": self.deco},
        ]
        if any(self.over):
            layers.append({"name": "over", "data": self.over})

        data = {
            "version": 2 if events else 1, "name": name, "id": map_id,
            "width": self.w, "height": self.h,
            "tileWidth": 16, "tileHeight": 16,
            "layers": layers,
            "collision": self.collision,
            "tilesets": [dict(TILESET)],
        }
        if events:
            data["events"] = events
        return data


# ---- 항구 마을 -------------------------------------------------------------


def build_town():
    m = Grid(VW, VH, GRASS)

    # 큰길: 북쪽 끝에서 부두 입구까지 곧게. 언덕 구간(y 14~17)은 돌계단이다.
    # 모래로 쳐 두면 blend_sand가 길 양옆의 잔디를 가장자리 타일로 바꿔 준다.
    for y in range(1, SHORE_Y):
        for x in ROAD_X:
            m.sand(x, y, STEPS if 14 <= y <= 17 else PATH)

    # 광장: 큰길이 바다로 내려오는 자리를 넓힌 모래밭과, 그 안의 돌바닥.
    # 돌바닥과 잔디가 바로 맞닿으면 각진 사각형이 되므로 모래 한 칸을 두른다.
    m.rect_sand(9, 33, 22, SHORE_Y - 1, PATH)
    m.rect_sand(10, 34, 21, 39, COBBLE)

    # 물가와 바다. 물가도 모래로 쳐서 위쪽 잔디가 자연스럽게 내려앉게 한다.
    for x in range(VW):
        m.sand(x, SHORE_Y, SHORE)
        m.block(x, SHORE_Y)
    for y in range(SHORE_Y + 1, VH):
        for x in range(VW):
            m.g(x, y, SEA_BLOCK[y % 2][x % 2])
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

    # 주택가: 빨래줄과 살림집 둘 (이야기는 없고 마을을 채우는 몫).
    # 빨래줄은 이 맵에서 유일하게 **머리 위로** 지나가는 것이라 over 층에 둔다.
    m.o(12, 21, LAUNDRY_L)
    m.o(13, 21, LAUNDRY_R)
    m.stamp(10, 22, [list(ROOF), list(EAVE), [WALL_L, DOOR, WALL_R]])
    m.stamp(19, 19, [list(ROOF), list(EAVE), [WALL_L, WALL_R, DOOR]])

    # 언덕의 등대 (2x3). 문 칸은 이벤트가 잠겨 있다고 말한다.
    m.stamp(17, 10, [[LH[(0, 0)], LH[(0, 1)]],
                     [LH[(1, 0)], LH[(1, 1)]],
                     [LH[(2, 0)], LH[(2, 1)]]])

    # 북쪽 문: 숲으로 가는 길을 막아 두었다. 문만 세우면 옆으로 걸어서 지나갈 수
    # 있으므로 울타리를 가로로 잇는다 — 문 너머는 보이되 갈 수 없는 자리가 된다.
    for x in range(1, VW - 1):
        if x in ROAD_X:
            m.d(x, GATE_Y, GATE)
        else:
            m.d(x, GATE_Y, FENCE_L if x == 1 else (FENCE_R if x == VW - 2 else FENCE_M))

    # 마을을 두르는 바위. 한 칸 두께의 링이며 안쪽은 잔디 그대로다 — 타일셋의
    # 바위는 "잔디를 두르는 테두리" 한 벌이라, 면으로 채우면 줄무늬가 된다.
    m.g(0, 0, EDGE_TL)
    m.g(VW - 1, 0, EDGE_TR)
    for x in range(1, VW - 1):
        m.g(x, 0, EDGE_T)
    for y in range(1, SHORE_Y):
        m.g(0, y, EDGE_L)
        m.g(VW - 1, y, EDGE_R)
    for y in range(VH):
        m.block(0, y)
        m.block(VW - 1, y)
    for x in range(VW):
        m.block(x, 0)

    # 테두리 안쪽의 바위 능선. 링 한 줄만으로는 마을의 끝이 얇아 보인다.
    for y0 in (8, 20, 31):
        for x in range(1, 4):
            m.d(x, y0, RIDGE_L if x == 1 else (RIDGE_R if x == 3 else RIDGE_M))
    for y0 in (12, 25, 36):
        for x in range(VW - 4, VW - 1):
            m.d(x, y0, RIDGE_L if x == VW - 4 else (RIDGE_R if x == VW - 2 else RIDGE_M))
    for y in range(15, 18):                       # 언덕 옆의 세로 능선
        m.d(21, y, RIDGE_V if y < 17 else RIDGE_V_END)

    # 잔디의 장식: 정해진 자리에만
    for x, y, gid in (
        (8, 30, BUSH), (23, 31, BUSH), (7, 24, FLOWER_W), (24, 25, FLOWER_B),
        (9, 18, BUSH), (22, 16, BUSH), (11, 12, FLOWER_W), (21, 13, FLOWER_B),
        (6, 36, BUSH), (25, 37, BUSH), (8, 9, BUSH), (23, 8, BUSH),
        (5, 14, PEBBLE), (26, 21, PEBBLE), (7, 33, PEBBLE), (24, 11, PEBBLE),
    ):
        m.d(x, y, gid, solid=False)

    # 다 그린 뒤에 잔디와 모래가 만나는 자리를 가장자리 타일로 바꾼다
    m.blend_sand(GRASS)

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
