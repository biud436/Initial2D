#!/usr/bin/env python3
"""R2K3 CharSet 규격의 플레이스홀더 캐릭터 시트를 만든다.

RTP 리소스(resources/rtp/)는 정품 보유자의 로컬 자산이라 커밋할 수 없다
(docs/plans/04-resources.md). 그래서 캐릭터 데모와 골든 스크린샷이 신선한
체크아웃에서도 돌아가도록, 같은 규격(288x256, 8명, 24x32 x 3프레임 x 4방향)의
대체 시트를 생성한다. 규격 값의 출처는 scripts/rpg/specs.lua다.

generate_ui_assets.py와 마찬가지로 이 출력물은 저장소에 커밋된다 —
그림을 바꿀 때만 다시 실행한다.

Usage: python3 tools/generate_charset.py
Requires: Pillow (pip install pillow)
"""

import os

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(REPO, "resources", "charsets")

# specs.lua의 M.charset과 같은 값이어야 한다
SHEET_W, SHEET_H = 288, 256
FRAME_W, FRAME_H = 24, 32
BLOCK_W, BLOCK_H = 72, 128
SHEET_COLS, SHEET_ROWS = 4, 2
DIR_ROWS = ["up", "right", "down", "left"]   # 블록 안의 행 순서

# 캐릭터 8명. (피부, 머리, 옷, 바지, 신발, 윤곽선)
PALETTES = [
    ((247, 214, 178), (96, 56, 32), (206, 62, 62), (56, 72, 140), (60, 44, 40), (36, 28, 32)),
    ((247, 214, 178), (232, 200, 96), (72, 128, 208), (72, 76, 88), (48, 44, 56), (28, 30, 40)),
    ((228, 186, 148), (48, 40, 44), (86, 168, 84), (120, 88, 56), (60, 44, 36), (28, 32, 28)),
    ((247, 214, 178), (168, 96, 200), (236, 236, 240), (88, 76, 112), (56, 48, 60), (36, 32, 44)),
    ((214, 166, 124), (72, 52, 40), (232, 176, 64), (72, 116, 72), (56, 48, 36), (32, 30, 24)),
    ((247, 224, 200), (200, 208, 216), (96, 200, 200), (44, 60, 108), (44, 44, 56), (28, 32, 40)),
    ((208, 156, 116), (140, 72, 40), (232, 128, 56), (96, 72, 56), (52, 40, 32), (32, 26, 24)),
    ((250, 222, 202), (240, 208, 128), (240, 152, 192), (112, 72, 128), (60, 44, 56), (40, 28, 40)),
]


def draw_frame(pal, direction, pattern):
    """24x32 한 프레임. pattern 0=왼발, 1=서기, 2=오른발."""
    skin, hair, shirt, pants, shoe, line = pal
    im = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    side = direction in ("left", "right")
    # 걷는 프레임에서는 몸이 1px 내려앉는다 (제자리 미끄러짐을 줄이는 최소한의 상하 운동)
    bob = 1 if pattern != 1 else 0
    swing = {0: -3, 1: 0, 2: 3}[pattern]

    # ---- 다리와 신발 -------------------------------------------------------
    # 팔다리는 윤곽선 없이 면으로만 그린다. 24x32 안에서 3px 굵기에 윤곽선까지
    # 두르면 속이 1px만 남아 검은 막대로 보인다.
    if side:
        # 옆모습: 두 다리가 앞뒤로 엇갈린다
        for x0, sw in ((9, swing), (12, -swing)):
            d.rectangle((x0 + sw, 24, x0 + 2 + sw, 28), fill=pants)
            d.rectangle((x0 + sw - 1, 29, x0 + 3 + sw, 31), fill=shoe)
    else:
        # 정면·뒷모습: 한쪽 다리를 들어 올린다
        lift_left = 3 if pattern == 0 else 0
        lift_right = 3 if pattern == 2 else 0
        d.rectangle((7, 24, 10, 29 - lift_left), fill=pants)
        d.rectangle((7, 30 - lift_left, 10, 31 - lift_left), fill=shoe)
        d.rectangle((13, 24, 16, 29 - lift_right), fill=pants)
        d.rectangle((13, 30 - lift_right, 16, 31 - lift_right), fill=shoe)

    # ---- 몸통과 팔 ---------------------------------------------------------
    d.rectangle((8, 15 + bob, 15, 25 + bob), fill=shirt, outline=line)
    if side:
        # 옆모습은 한 팔만 보이고, 다리와 반대로 흔든다
        ax = 12 - swing
        d.rectangle((ax, 16 + bob, ax + 2, 21 + bob), fill=shirt)
        d.rectangle((ax, 22 + bob, ax + 2, 24 + bob), fill=skin)
    else:
        for ax in (5, 16):
            d.rectangle((ax, 16 + bob, ax + 2, 21 + bob), fill=shirt)
            d.rectangle((ax, 22 + bob, ax + 2, 24 + bob), fill=skin)

    # ---- 머리 --------------------------------------------------------------
    head = (6, 3 + bob, 17, 15 + bob)
    d.ellipse(head, fill=skin, outline=line)
    # 머리카락에는 윤곽선을 두르지 않는다 — 이마 자리에 가로줄이 생겨 눈과 붙는다
    if direction == "up":
        d.ellipse(head, fill=hair, outline=line)          # 뒤통수는 머리카락뿐
    elif direction == "down":
        d.pieslice(head, 180, 360, fill=hair)
        d.rectangle((9, 11 + bob, 10, 12 + bob), fill=line)   # 눈
        d.rectangle((13, 11 + bob, 14, 12 + bob), fill=line)
    else:
        # 옆모습: 뒤통수(왼쪽)와 정수리를 덮고 눈은 하나
        d.pieslice(head, 135, 360, fill=hair)
        d.rectangle((13, 11 + bob, 14, 12 + bob), fill=line)

    if direction == "left":
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im


def make_sheet(path):
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for index, pal in enumerate(PALETTES):
        bx = (index % SHEET_COLS) * BLOCK_W
        by = (index // SHEET_COLS) * BLOCK_H
        for row, direction in enumerate(DIR_ROWS):
            for pattern in range(3):
                frame = draw_frame(pal, direction, pattern)
                sheet.paste(frame, (bx + pattern * FRAME_W, by + row * FRAME_H))
    sheet.save(path)
    print("generated:", os.path.relpath(path, REPO))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    make_sheet(os.path.join(OUT_DIR, "placeholder.png"))


if __name__ == "__main__":
    main()
