#!/usr/bin/env python3
"""항구 마을 데모용 타일셋을 만든다: 마을 타일셋 + 바다, 부두, 배, 등대, 마을 살림.

기획서(docs/design/port-town.md)의 배치를 그리려면 물과 부두와 배가 필요한데
village16.png 에는 잔디와 집뿐이다. 앞의 타일을 그대로 두고 뒤에만 이어 붙이므로
gid(=행*8+열+1)가 밀리지 않는다 — 먼저 만든 맵과 골든이 그대로 산다.

같은 규칙을 두 번째로 쓰는 것이라(첫 번째는 generate_village_tileset.py) 화풍도
맞춘다: 평면 색 두세 단, 가장자리만 어둡게, 채도 낮은 팔레트.

Usage: python3 tools/generate_port_tileset.py
Requires: Pillow
"""

import os

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(REPO, "resources", "tiles")
SOURCE = os.path.join(TILES, "village16.png")
OUTPUT = os.path.join(TILES, "port16.png")

TILE = 16
COLS = 8

# 바다와 나무, 돌 — 기존 잔디(64,176,128)와 모래(216,200,128) 옆에 놓아도 튀지 않는 채도
SEA = (46, 108, 156)
SEA_DARK = (34, 84, 126)
SEA_LIGHT = (72, 144, 188)
FOAM = (206, 232, 240)
SAND = (216, 200, 128)
SAND_DARK = (186, 168, 104)

WOOD = (150, 106, 68)
WOOD_DARK = (106, 72, 46)
WOOD_LIGHT = (184, 142, 98)

STONE = (172, 168, 160)
STONE_DARK = (124, 120, 114)
STONE_LIGHT = (206, 204, 196)

SAIL = (238, 232, 214)
SAIL_SHADE = (200, 192, 172)
ROPE = (198, 176, 128)
LAMP = (255, 214, 120)
LAMP_DARK = (196, 148, 60)
CLOTH = (226, 230, 236)
CLOTH_SHADE = (188, 194, 204)
AWNING = (196, 88, 76)
AWNING_DARK = (150, 62, 54)
FISH = (150, 178, 196)
FISH_DARK = (104, 132, 152)
INK = (52, 44, 40)


def tile(bg=None):
    return Image.new("RGBA", (TILE, TILE), bg or (0, 0, 0, 0))


# ---- 바다와 물가 -----------------------------------------------------------


def sea(variant=0):
    """바다. 물결 무늬 두 가지를 번갈아 깔아 넓은 면이 죽지 않게 한다."""
    im = tile(SEA)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, 1), fill=SEA_DARK)
    if variant == 0:
        d.line([(2, 5), (6, 5)], fill=SEA_LIGHT)
        d.line([(9, 10), (13, 10)], fill=SEA_LIGHT)
        d.point((7, 12), fill=SEA_LIGHT)
    else:
        d.line([(4, 3), (8, 3)], fill=SEA_LIGHT)
        d.line([(1, 11), (4, 11)], fill=SEA_LIGHT)
        d.line([(10, 7), (14, 7)], fill=SEA_LIGHT)
    return im


def shore():
    """땅에서 물로 내려가는 경계 — 위는 모래, 아래는 물, 사이에 포말."""
    im = tile(SEA)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, 6), fill=SAND)
    d.line([(0, 6), (TILE - 1, 6)], fill=SAND_DARK)
    d.rectangle((0, 7, TILE - 1, 8), fill=FOAM)
    for x in (1, 5, 9, 13):
        d.point((x, 9), fill=FOAM)
    d.line([(3, 12), (7, 12)], fill=SEA_LIGHT)
    return im


# ---- 부두 -----------------------------------------------------------------


def plank(edge=None):
    """부두 널. edge는 "left"/"right"면 그쪽에 굄목을 댄다."""
    im = tile(WOOD)
    d = ImageDraw.Draw(im)
    for y in (0, 5, 10, 15):
        d.line([(0, y), (TILE - 1, y)], fill=WOOD_DARK)
    for y in (1, 6, 11):
        d.line([(0, y), (TILE - 1, y)], fill=WOOD_LIGHT)
    if edge == "left":
        d.rectangle((0, 0, 1, TILE - 1), fill=WOOD_DARK)
    elif edge == "right":
        d.rectangle((TILE - 2, 0, TILE - 1, TILE - 1), fill=WOOD_DARK)
    return im


def bollard():
    """밧줄 말뚝. 널 위에 선다."""
    im = plank()
    d = ImageDraw.Draw(im)
    d.rectangle((5, 3, 10, 13), fill=WOOD_DARK)
    d.rectangle((6, 4, 9, 12), fill=WOOD_LIGHT)
    d.rectangle((4, 2, 11, 4), fill=WOOD_DARK)
    d.arc((3, 7, 12, 13), 200, 340, fill=ROPE)
    d.arc((3, 8, 12, 14), 200, 340, fill=ROPE)
    return im


def crate():
    """나무 상자."""
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((2, 3, 13, 14), fill=WOOD)
    d.rectangle((2, 3, 13, 14), outline=WOOD_DARK)
    d.line([(2, 3), (13, 14)], fill=WOOD_DARK)
    d.line([(13, 3), (2, 14)], fill=WOOD_DARK)
    d.line([(3, 4), (12, 4)], fill=WOOD_LIGHT)
    return im


# ---- 배 (3x2) --------------------------------------------------------------


def ship_hull(part):
    """선체 아래 칸. part는 "bow"(왼쪽 뱃머리), "mid", "stern"(오른쪽 고물).

    뱃전을 밝게, 물에 닿는 아래를 어둡게 해서 갈색 덩어리로 뭉치지 않게 한다.
    """
    im = tile()
    d = ImageDraw.Draw(im)
    if part == "bow":
        d.polygon([(15, 2), (15, 13), (4, 12), (0, 6)], fill=WOOD)
        d.line([(0, 6), (15, 2)], fill=WOOD_LIGHT)          # 뱃전
        d.line([(0, 7), (15, 3)], fill=WOOD_LIGHT)
        d.line([(0, 6), (4, 12)], fill=WOOD_DARK)
        d.line([(4, 12), (15, 13)], fill=SEA_DARK)          # 물에 잠긴 선
        d.point((11, 8), fill=WOOD_DARK)                    # 현창
    elif part == "stern":
        d.polygon([(0, 2), (12, 4), (13, 10), (0, 13)], fill=WOOD)
        d.line([(0, 2), (12, 4)], fill=WOOD_LIGHT)
        d.line([(0, 3), (12, 5)], fill=WOOD_LIGHT)
        d.line([(12, 4), (13, 10)], fill=WOOD_DARK)
        d.line([(0, 13), (13, 10)], fill=SEA_DARK)
        d.rectangle((3, 6, 5, 8), fill=WOOD_DARK)           # 고물 창
    else:
        d.rectangle((0, 2, TILE - 1, 13), fill=WOOD)
        d.rectangle((0, 2, TILE - 1, 3), fill=WOOD_LIGHT)   # 뱃전
        d.line([(0, 5), (TILE - 1, 5)], fill=WOOD_DARK)     # 갑판 아래 이음
        d.rectangle((0, 12, TILE - 1, 13), fill=SEA_DARK)   # 흘수선
        for x in (3, 11):
            d.rectangle((x, 7, x + 1, 8), fill=WOOD_DARK)   # 현창
    return im


def ship_top(part):
    """돛 칸. 가운데에 돛대와 돛, 양옆은 물 위로 뻗은 밧줄."""
    im = tile()
    d = ImageDraw.Draw(im)
    if part == "mid":
        d.polygon([(9, 2), (15, 14), (9, 14)], fill=SAIL)        # 오른쪽 돛
        d.polygon([(6, 4), (1, 14), (6, 14)], fill=SAIL_SHADE)   # 왼쪽 돛
        d.line([(9, 2), (15, 14)], fill=SAIL_SHADE)
        d.line([(6, 4), (1, 14)], fill=SAIL)
        d.rectangle((7, 0, 8, TILE - 1), fill=WOOD_DARK)         # 돛대
        d.point((7, 1), fill=LAMP)                               # 꼭대기 등
    elif part == "left":
        d.line([(12, 14), (15, 3)], fill=ROPE)
        d.line([(13, 14), (15, 5)], fill=ROPE)
    else:
        d.line([(0, 3), (3, 14)], fill=ROPE)
        d.line([(0, 5), (2, 14)], fill=ROPE)
    return im


# ---- 등대 (2x3) ------------------------------------------------------------


def lighthouse(row, side):
    """등대. row 0=등불, 1=몸통, 2=아래(문). side는 "left"/"right"."""
    im = tile()
    d = ImageDraw.Draw(im)
    left = side == "left"
    # 탑은 위로 갈수록 좁아진다
    inset = {0: 3, 1: 2, 2: 1}[row]
    x0 = inset if left else 0
    x1 = TILE - 1 if left else TILE - 1 - inset

    if row == 0:
        d.rectangle((x0, 6, x1, TILE - 1), fill=STONE_LIGHT)
        d.rectangle((x0, 3, x1, 6), fill=LAMP)                # 등불
        d.rectangle((x0, 3, x1, 3), fill=LAMP_DARK)
        d.rectangle((x0 - 1 if left else x0, 0, x1 if left else x1 + 1, 2), fill=INK)
        d.line([(x0, 4), (x1, 4)], fill=LAMP_DARK)            # 등불 위아래 테
        d.rectangle((x0 - 1 if left else x0, 7, x1 if left else x1 + 1, 8),
                    fill=STONE_DARK)                          # 난간 (탑보다 넓다)
        d.line([(x0, 9), (x1, 9)], fill=STONE_LIGHT)
    elif row == 1:
        d.rectangle((x0, 0, x1, TILE - 1), fill=STONE_LIGHT)
        d.rectangle((x0, 4, x1, 9), fill=AWNING)              # 붉은 띠
        d.line([(x0, 4), (x1, 4)], fill=AWNING_DARK)
        d.line([(x0, 9), (x1, 9)], fill=AWNING_DARK)
    else:
        d.rectangle((x0, 0, x1, TILE - 1), fill=STONE_LIGHT)
        d.rectangle((x0, TILE - 3, x1, TILE - 1), fill=STONE_DARK)   # 주춧돌
        if left:
            d.rectangle((9, 6, 14, TILE - 3), fill=WOOD_DARK)        # 문
            d.rectangle((10, 7, 13, TILE - 3), fill=WOOD)
    if left:
        d.line([(x0, 0), (x0, TILE - 1)], fill=STONE_DARK)
    else:
        d.line([(x1, 0), (x1, TILE - 1)], fill=STONE_DARK)
    return im


# ---- 마을 살림 -------------------------------------------------------------


def well(bottom=False):
    """우물 (1x2). 위는 지붕과 도르래, 아래는 돌 테두리와 물."""
    im = tile()
    d = ImageDraw.Draw(im)
    if not bottom:
        d.polygon([(1, 9), (8, 2), (15, 9)], fill=WOOD)       # 지붕
        d.line([(1, 9), (8, 2)], fill=WOOD_LIGHT)
        d.line([(8, 2), (15, 9)], fill=WOOD_DARK)
        d.rectangle((2, 10, 3, TILE - 1), fill=WOOD_DARK)     # 기둥
        d.rectangle((12, 10, 13, TILE - 1), fill=WOOD_DARK)
        d.line([(4, 11), (11, 11)], fill=ROPE)                # 도르래 축
    else:
        d.rectangle((1, 0, 14, 10), fill=STONE)
        d.rectangle((1, 0, 14, 10), outline=STONE_DARK)
        d.rectangle((4, 2, 11, 8), fill=SEA_DARK)             # 물
        d.line([(5, 4), (9, 4)], fill=SEA_LIGHT)
        d.rectangle((1, 11, 14, 13), fill=STONE_DARK)         # 아랫단
    return im


def board(bottom=False):
    """게시판 (1x2)."""
    im = tile()
    d = ImageDraw.Draw(im)
    if not bottom:
        d.rectangle((1, 3, 14, TILE - 1), fill=WOOD)
        d.rectangle((1, 3, 14, TILE - 1), outline=WOOD_DARK)
        d.rectangle((3, 5, 12, TILE - 2), fill=(238, 230, 208))   # 종이
        for y in (7, 9, 11, 13):
            d.line([(4, y), (11, y)], fill=STONE_DARK)             # 글줄
        d.rectangle((0, 1, 15, 2), fill=WOOD_DARK)                 # 차양
    else:
        d.rectangle((6, 0, 9, 11), fill=WOOD_DARK)                 # 기둥
        d.rectangle((7, 0, 8, 11), fill=WOOD)
    return im


def stall(row, side):
    """생선 좌판 (2x2). row 0=차양, 1=매대."""
    im = tile()
    d = ImageDraw.Draw(im)
    left = side == "left"
    if row == 0:
        d.rectangle((0, 2, TILE - 1, 9), fill=AWNING)
        for x in range(0 if left else 4, TILE, 8):
            d.rectangle((x, 2, x + 3, 9), fill=CLOTH)              # 줄무늬 차양
        d.line([(0, 2), (TILE - 1, 2)], fill=AWNING_DARK)
        d.line([(0, 9), (TILE - 1, 9)], fill=AWNING_DARK)
        post = 1 if left else TILE - 3
        d.rectangle((post, 10, post + 1, TILE - 1), fill=WOOD_DARK)
    else:
        d.rectangle((0, 3, TILE - 1, 9), fill=WOOD)                # 매대
        d.line([(0, 3), (TILE - 1, 3)], fill=WOOD_LIGHT)
        d.line([(0, 9), (TILE - 1, 9)], fill=WOOD_DARK)
        post = 1 if left else TILE - 3
        d.rectangle((post, 10, post + 1, TILE - 1), fill=WOOD_DARK)
        if left:
            for i in (0, 1):                                        # 생선 두 마리
                y = 5 + i * 2
                d.line([(3 + i, y), (10 + i, y)], fill=FISH)
                d.point((11 + i, y), fill=FISH_DARK)
        else:
            d.rectangle((3, 5, 9, 8), fill=FISH_DARK)               # 생선 궤짝
            d.line([(3, 5), (9, 5)], fill=FISH)
    return im


def bench(side):
    im = tile()
    d = ImageDraw.Draw(im)
    left = side == "left"
    d.rectangle((0, 6, TILE - 1, 9), fill=WOOD)                    # 앉는 판
    d.line([(0, 6), (TILE - 1, 6)], fill=WOOD_LIGHT)
    d.line([(0, 9), (TILE - 1, 9)], fill=WOOD_DARK)
    d.rectangle((0, 2, TILE - 1, 4), fill=WOOD)                    # 등받이
    d.line([(0, 2), (TILE - 1, 2)], fill=WOOD_LIGHT)
    leg = 2 if left else TILE - 4
    d.rectangle((leg, 10, leg + 1, 13), fill=WOOD_DARK)
    return im


def laundry(side):
    """빨래줄 (2x1)."""
    im = tile()
    d = ImageDraw.Draw(im)
    d.line([(0, 3), (TILE - 1, 3)], fill=ROPE)
    if side == "left":
        d.rectangle((2, 4, 7, 12), fill=CLOTH)
        d.line([(2, 12), (7, 12)], fill=CLOTH_SHADE)
        d.rectangle((10, 4, 14, 10), fill=CLOTH_SHADE)
    else:
        d.rectangle((1, 4, 5, 9), fill=CLOTH_SHADE)
        d.rectangle((8, 4, 13, 13), fill=CLOTH)
        d.line([(8, 13), (13, 13)], fill=CLOTH_SHADE)
    return im


def cobble():
    """광장 돌바닥."""
    im = tile(STONE)
    d = ImageDraw.Draw(im)
    for y in (0, 8):
        d.line([(0, y), (TILE - 1, y)], fill=STONE_DARK)
    for y, xs in ((4, (0, 8)), (12, (4, 12))):
        for x in xs:
            d.line([(x, y - 4), (x, y + 3)], fill=STONE_DARK)
    d.point((3, 2), fill=STONE_LIGHT)
    d.point((11, 10), fill=STONE_LIGHT)
    return im


def steps():
    """언덕으로 오르는 돌계단."""
    im = tile(STONE)
    d = ImageDraw.Draw(im)
    for y in (0, 5, 10, 15):
        d.line([(0, y), (TILE - 1, y)], fill=STONE_DARK)
        d.line([(0, y + 1), (TILE - 1, y + 1)], fill=STONE_LIGHT)
    return im


def warehouse_door():
    """창고의 큰 두 짝 문."""
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, TILE - 1), fill=(214, 188, 150))   # 벽 (집 타일과 같은 색)
    d.rectangle((1, 1, 14, TILE - 1), fill=WOOD_DARK)
    d.rectangle((2, 2, 13, TILE - 1), fill=WOOD)
    d.line([(8, 2), (8, TILE - 1)], fill=WOOD_DARK)                 # 가운데 이음매
    d.line([(2, 6), (13, 6)], fill=WOOD_DARK)                       # 가로대
    d.line([(2, 11), (13, 11)], fill=WOOD_DARK)
    d.rectangle((6, 8, 7, 9), fill=(120, 116, 110))                 # 자물쇠
    d.rectangle((9, 8, 10, 9), fill=(120, 116, 110))
    return im


def inn_sign():
    """여관 간판 (벽에 매다는 칸)."""
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, TILE - 1), fill=(214, 188, 150))
    d.rectangle((2, 1, 13, 2), fill=WOOD_DARK)                      # 걸이
    d.rectangle((3, 3, 12, 11), fill=WOOD)
    d.rectangle((3, 3, 12, 11), outline=WOOD_DARK)
    d.rectangle((5, 5, 10, 6), fill=LAMP)                           # 등불 그림
    d.line([(5, 8), (10, 8)], fill=(238, 230, 208))
    return im


def gate_closed():
    """숲으로 가는 북쪽 문 — 널 두 장을 가로질러 막아 두었다."""
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 2, TILE - 1, 5), fill=WOOD)
    d.rectangle((0, 9, TILE - 1, 12), fill=WOOD)
    d.line([(0, 2), (TILE - 1, 2)], fill=WOOD_LIGHT)
    d.line([(0, 12), (TILE - 1, 12)], fill=WOOD_DARK)
    d.rectangle((2, 0, 4, TILE - 1), fill=WOOD_DARK)                # 기둥
    d.rectangle((11, 0, 13, TILE - 1), fill=WOOD_DARK)
    return im


def hearth():
    """여관 난로. 실내 벽에 붙여 놓는다."""
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, TILE - 1), fill=STONE)
    d.rectangle((0, 0, TILE - 1, 1), fill=STONE_DARK)
    d.rectangle((3, 4, 12, TILE - 1), fill=INK)                 # 아궁이
    d.polygon([(7, 7), (10, 12), (5, 12)], fill=(226, 120, 48))  # 불
    d.polygon([(7, 9), (9, 12), (6, 12)], fill=LAMP)
    d.rectangle((2, 2, 13, 3), fill=STONE_DARK)                 # 상인방
    return im


def table():
    """여관 탁자."""
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((1, 4, 14, 9), fill=WOOD_LIGHT)
    d.line([(1, 4), (14, 4)], fill=(214, 180, 140))
    d.line([(1, 9), (14, 9)], fill=WOOD_DARK)
    d.rectangle((3, 10, 4, 13), fill=WOOD_DARK)
    d.rectangle((11, 10, 12, 13), fill=WOOD_DARK)
    d.rectangle((6, 5, 9, 7), fill=CLOTH)                       # 접시
    return im


TILESET = [
    ("바다", lambda: sea(0)),
    ("바다 물결", lambda: sea(1)),
    ("물가", shore),
    ("부두 널", lambda: plank()),
    ("부두 널 좌", lambda: plank("left")),
    ("부두 널 우", lambda: plank("right")),
    ("밧줄 말뚝", bollard),
    ("나무 상자", crate),

    ("배 돛 좌", lambda: ship_top("left")),
    ("배 돛 중", lambda: ship_top("mid")),
    ("배 돛 우", lambda: ship_top("right")),
    ("배 뱃머리", lambda: ship_hull("bow")),
    ("배 선체", lambda: ship_hull("mid")),
    ("배 고물", lambda: ship_hull("stern")),
    ("등대 등불 좌", lambda: lighthouse(0, "left")),
    ("등대 등불 우", lambda: lighthouse(0, "right")),

    ("등대 몸통 좌", lambda: lighthouse(1, "left")),
    ("등대 몸통 우", lambda: lighthouse(1, "right")),
    ("등대 아래 좌", lambda: lighthouse(2, "left")),
    ("등대 아래 우", lambda: lighthouse(2, "right")),
    ("우물 위", lambda: well()),
    ("우물 아래", lambda: well(bottom=True)),
    ("게시판 위", lambda: board()),
    ("게시판 아래", lambda: board(bottom=True)),

    ("좌판 차양 좌", lambda: stall(0, "left")),
    ("좌판 차양 우", lambda: stall(0, "right")),
    ("좌판 매대 좌", lambda: stall(1, "left")),
    ("좌판 매대 우", lambda: stall(1, "right")),
    ("벤치 좌", lambda: bench("left")),
    ("벤치 우", lambda: bench("right")),
    ("빨래줄 좌", lambda: laundry("left")),
    ("빨래줄 우", lambda: laundry("right")),

    ("돌바닥", cobble),
    ("돌계단", steps),
    ("창고 문", warehouse_door),
    ("여관 간판", inn_sign),
    ("막힌 문", gate_closed),
    ("난로", hearth),
    ("탁자", table),
]


def main():
    source = Image.open(SOURCE).convert("RGBA")
    cols = source.width // TILE
    rows = source.height // TILE
    if cols != COLS:
        raise SystemExit(f"열 수가 {COLS}가 아닙니다: {cols}")

    extra_rows = (len(TILESET) + COLS - 1) // COLS
    out = Image.new("RGBA", (source.width, source.height + extra_rows * TILE),
                    (0, 0, 0, 0))
    out.paste(source, (0, 0))

    first_gid = rows * COLS + 1
    for i, (name, make) in enumerate(TILESET):
        out.paste(make(), ((i % COLS) * TILE, (rows + i // COLS) * TILE))

    out.save(OUTPUT)
    print("generated:", os.path.relpath(OUTPUT, REPO),
          f"({out.width // TILE}x{out.height // TILE} 타일)")
    for i, (name, _) in enumerate(TILESET):
        print(f"  gid {first_gid + i}: {name}")


if __name__ == "__main__":
    main()
