#!/usr/bin/env python3
"""마을 데모용 타일셋을 만든다: 기존 타일셋 + 집(지붕, 벽, 문, 실내) 타일.

resources/tiles/tileset16-8x13.png 에는 잔디, 울타리, 꽃, 바위, 연못뿐이라 집을
표현할 수 없다. 울타리로 사각형을 그려 놓고 오두막이라고 부를 수는 없으므로,
기존 타일 뒤에 집 타일을 이어 붙인 별도 타일셋을 만든다.

기존 타일을 앞에 그대로 두므로 gid(=행*8+열+1)가 바뀌지 않는다. 즉 이미 만든
맵 데이터가 그대로 살아 있고, sample.json과 2단계 골든은 원래 타일셋을 계속 쓴다.

정품 RTP를 가진 사람이라면 resources/rtp/ChipSet/*.png 가 훨씬 좋지만, R2K3
칩셋은 왼쪽 절반이 오토타일이라 맵 포맷 v1으로는 그대로 쓸 수 없다 (v2 과제).

Usage: python3 tools/generate_village_tileset.py
Requires: Pillow
"""

import os

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(REPO, "resources", "tiles")
SOURCE = os.path.join(TILES, "tileset16-8x13.png")
OUTPUT = os.path.join(TILES, "village16.png")

TILE = 16
COLS = 8
EXTRA_ROWS = 2

# 기존 타일셋의 차분한 색조에 맞춘 팔레트
ROOF = (156, 76, 64)
ROOF_DARK = (112, 52, 46)
ROOF_LIGHT = (190, 104, 88)
EAVE = (86, 58, 50)
WALL = (214, 188, 150)
WALL_DARK = (172, 146, 116)
BEAM = (120, 86, 60)
DOOR = (108, 74, 50)
DOOR_DARK = (78, 52, 36)
KNOB = (226, 200, 120)
GLASS = (120, 176, 206)
GLASS_LIGHT = (168, 212, 230)
FLOOR = (166, 126, 84)
FLOOR_DARK = (138, 102, 66)
INWALL = (206, 196, 178)
INWALL_DARK = (168, 158, 142)
BASE = (112, 86, 64)


def tile():
    return Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))


def roof(edge=None, bottom=False):
    """지붕. edge는 "left"/"right"면 그쪽 모서리를 어둡게, bottom이면 처마를 단다."""
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, TILE - 1), fill=ROOF)

    # 기와 줄무늬 (4px 간격, 아래쪽이 어둡다)
    for y in range(0, TILE, 4):
        d.line([(0, y), (TILE - 1, y)], fill=ROOF_DARK)
        d.line([(0, y + 1), (TILE - 1, y + 1)], fill=ROOF_LIGHT)

    if not bottom:
        # 용마루
        d.rectangle((0, 0, TILE - 1, 2), fill=ROOF_LIGHT)
        d.line([(0, 0), (TILE - 1, 0)], fill=EAVE)
    else:
        # 처마: 아래 세 줄을 어둡게 해 그림자를 만든다
        d.rectangle((0, TILE - 3, TILE - 1, TILE - 1), fill=EAVE)
        d.line([(0, TILE - 4), (TILE - 1, TILE - 4)], fill=ROOF_DARK)

    if edge == "left":
        d.line([(0, 0), (0, TILE - 1)], fill=EAVE)
        d.line([(1, 0), (1, TILE - 1)], fill=ROOF_DARK)
    elif edge == "right":
        d.line([(TILE - 1, 0), (TILE - 1, TILE - 1)], fill=EAVE)
        d.line([(TILE - 2, 0), (TILE - 2, TILE - 1)], fill=ROOF_DARK)
    return im


def wall_base(d):
    d.rectangle((0, 0, TILE - 1, TILE - 1), fill=WALL)
    d.line([(0, 0), (TILE - 1, 0)], fill=BEAM)              # 처마 아래 보
    d.line([(0, TILE - 1), (TILE - 1, TILE - 1)], fill=BEAM)  # 바닥 경계
    d.line([(0, TILE - 2), (TILE - 1, TILE - 2)], fill=WALL_DARK)


def wall_plain():
    im = tile()
    d = ImageDraw.Draw(im)
    wall_base(d)
    return im


def wall_window():
    im = tile()
    d = ImageDraw.Draw(im)
    wall_base(d)
    d.rectangle((3, 4, 12, 10), fill=BEAM)
    d.rectangle((4, 5, 11, 9), fill=GLASS)
    d.rectangle((4, 5, 7, 7), fill=GLASS_LIGHT)     # 유리 반사
    d.line([(8, 5), (8, 9)], fill=BEAM)             # 창틀 세로
    return im


def wall_door():
    im = tile()
    d = ImageDraw.Draw(im)
    wall_base(d)
    d.rectangle((3, 3, 12, TILE - 2), fill=DOOR_DARK)
    d.rectangle((4, 4, 11, TILE - 2), fill=DOOR)
    d.line([(8, 4), (8, TILE - 2)], fill=DOOR_DARK)  # 문짝 가운데 선
    d.rectangle((9, 9, 10, 10), fill=KNOB)           # 손잡이
    return im


def wood_floor():
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, TILE - 1), fill=FLOOR)
    # 널은 길게 간다. 이음매를 촘촘히 넣으면 마루가 아니라 벽돌로 보인다.
    for y in (5, 11):
        d.line([(0, y), (TILE - 1, y)], fill=FLOOR_DARK)
    d.line([(9, 0), (9, 5)], fill=FLOOR_DARK)
    d.line([(4, 12), (4, TILE - 1)], fill=FLOOR_DARK)
    return im


def interior_wall(lower=False):
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, TILE - 1), fill=INWALL)
    d.line([(0, 0), (TILE - 1, 0)], fill=INWALL_DARK)
    if lower:
        d.rectangle((0, TILE - 4, TILE - 1, TILE - 1), fill=BASE)   # 걸레받이
        d.line([(0, TILE - 5), (TILE - 1, TILE - 5)], fill=INWALL_DARK)
    else:
        for x in range(2, TILE, 6):
            d.line([(x, 3), (x, TILE - 1)], fill=INWALL_DARK)       # 널빤지 결
    return im


def void():
    """맵 바깥을 채우는 어두운 타일.

    화면보다 작은 실내 맵은 카메라가 가운데 정렬하고 나머지가 배경색(흰색)으로
    남는다. 그 자리를 이 타일로 덮으면 방이 어둠 속에 떠 있는 것처럼 보인다.
    """
    im = tile()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, TILE - 1, TILE - 1), fill=(24, 22, 28))
    return im


def main():
    source = Image.open(SOURCE).convert("RGBA")
    cols = source.width // TILE
    rows = source.height // TILE
    if cols != COLS:
        raise SystemExit(f"열 수가 {COLS}가 아닙니다: {cols}")

    out = Image.new("RGBA", (source.width, source.height + EXTRA_ROWS * TILE),
                    (0, 0, 0, 0))
    out.paste(source, (0, 0))

    # 이어 붙일 타일 (앞 타일의 gid를 건드리지 않으려고 뒤에만 더한다)
    added = [
        roof(edge="left"), roof(), roof(edge="right"),
        roof(edge="left", bottom=True), roof(bottom=True), roof(edge="right", bottom=True),
        wall_plain(), wall_window(),
        wall_door(), wood_floor(), interior_wall(), interior_wall(lower=True),
        void(),
    ]

    first_gid = rows * COLS + 1
    for i, img in enumerate(added):
        out.paste(img, ((i % COLS) * TILE, (rows + i // COLS) * TILE))

    out.save(OUTPUT)
    print("generated:", os.path.relpath(OUTPUT, REPO))
    names = ["지붕 좌", "지붕 중", "지붕 우", "처마 좌", "처마 중", "처마 우",
             "벽", "창문 벽", "문", "나무 바닥", "실내벽 위", "실내벽 아래", "바깥 어둠"]
    for i, name in enumerate(names):
        print(f"  gid {first_gid + i}: {name}")


if __name__ == "__main__":
    main()
