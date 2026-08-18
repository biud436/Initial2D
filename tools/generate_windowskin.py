#!/usr/bin/env python3
"""대화창 스킨(System 규격 160x80)의 플레이스홀더를 만든다.

RTP 리소스(resources/rtp/)는 정품 보유자의 로컬 자산이라 커밋할 수 없다
(docs/plans/04-resources.md). 그래서 대화창 데모와 골든 스크린샷이 신선한
체크아웃에서도 돌아가도록, RPG Maker 2003 System과 같은 배치의 대체 스킨을
생성한다. 배치의 출처는 scripts/rpg/specs.lua의 M.window다.

    (0,0)   32x32  창 바탕 (세로 그라데이션)
    (32,0)  32x32  테두리 (8픽셀 나인 슬라이스). 가운데 16x16에는 스크롤 화살표
                   두 개: 위 (40,8,16,8), 아래 (40,16,16,8)
    (64,0)  32x32  선택 커서 1 / (96,0) 커서 2 (깜빡임용, 조금 더 밝다)
    (0,48)  16x16씩 글자색 견본 20개 (엔진에 글자색 지정이 없어 지금은 장식)

생성물은 저장소에 커밋된다 — 그림을 바꿀 때만 다시 실행한다.

Usage: python3 tools/generate_windowskin.py
Requires: Pillow (pip install pillow)
"""

import os

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "resources", "ui", "window.png")

SKIN_W, SKIN_H = 160, 80
BLOCK = 32

# 바탕: 남색 그라데이션. 창을 늘일 때 32픽셀마다 반복되므로(window.lua의 띠 채우기)
# 위아래 차이를 작게 잡아 이음매가 눈에 띄지 않게 한다.
BG_TOP = (36, 52, 96)
BG_BOTTOM = (20, 30, 62)

FRAME_OUTER = (24, 34, 60)       # 테두리 바깥 진한 선
FRAME_LIGHT = (196, 214, 246)    # 밝은 중간 선 (창이 도드라지게)
FRAME_INNER = (86, 116, 176)     # 안쪽 선

ARROW = (232, 240, 255)
ARROW_EDGE = (40, 56, 96)

CURSOR_EDGE = (250, 252, 255)
CURSOR_FILL = (150, 200, 255, 90)
CURSOR2_FILL = (200, 228, 255, 130)

# 원본 System의 글자색 팔레트 자리를 채우는 20색 (10열 2행)
TEXT_COLORS = [
    (240, 244, 252), (128, 176, 248), (248, 216, 152), (192, 192, 196), (248, 240, 136),
    (240, 168, 168), (200, 176, 248), (248, 184, 232), (144, 224, 176), (248, 200, 120),
    (168, 208, 248), (248, 160, 160), (208, 232, 144), (216, 176, 248), (248, 208, 96),
    (152, 232, 216), (176, 184, 248), (232, 232, 232), (120, 176, 136), (200, 152, 104),
]


def lerp(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def draw_background(img):
    d = ImageDraw.Draw(img)
    for y in range(BLOCK):
        d.line([(0, y), (BLOCK - 1, y)],
               fill=lerp(BG_TOP, BG_BOTTOM, y / (BLOCK - 1)) + (255,))


def draw_frame(img):
    """테두리 블록. 바깥 3픽셀만 그리고 안쪽은 투명하게 둔다.

    변은 8픽셀 모서리를 뺀 가운데 16픽셀을 반복해 늘이므로, 변의 무늬는 세로
    (또는 가로) 방향으로 균일해야 이음매가 보이지 않는다.
    """
    d = ImageDraw.Draw(img)
    x0 = BLOCK
    for i, color in enumerate((FRAME_OUTER, FRAME_LIGHT, FRAME_INNER)):
        d.rectangle((x0 + i, i, x0 + BLOCK - 1 - i, BLOCK - 1 - i), outline=color + (255,))

    # 가운데 16x16의 스크롤 화살표 두 개 (specs.lua의 arrowUp / arrowDown)
    draw_arrow(d, x0 + 8, 8, up=True)
    draw_arrow(d, x0 + 8, 16, up=False)


def draw_arrow(d, x, y, up):
    """16x8 칸 안의 삼각형 화살표. up이면 꼭짓점이 위, 아니면 아래."""
    cx = x + 8
    for row in range(6):
        half = row + 1                       # 꼭짓점에서 멀어질수록 넓어진다
        yy = (y + 1 + row) if up else (y + 6 - row)
        d.line([(cx - half, yy), (cx + half - 1, yy)], fill=ARROW + (255,))
    # 밑변에 어두운 선을 한 줄 깔아 밝은 창 위에서도 형태가 보이게 한다
    base_y = y + 7 if up else y
    d.line([(cx - 6, base_y), (cx + 5, base_y)], fill=ARROW_EDGE + (255,))


def draw_cursor(img, x0, fill):
    """선택 커서: 반투명 면 + 밝은 테두리. 8픽셀 나인 슬라이스로 늘어난다."""
    d = ImageDraw.Draw(img)
    d.rectangle((x0 + 1, 1, x0 + BLOCK - 2, BLOCK - 2), fill=fill)
    d.rectangle((x0, 0, x0 + BLOCK - 1, BLOCK - 1), outline=CURSOR_EDGE + (220,))
    d.rectangle((x0 + 2, 2, x0 + BLOCK - 3, BLOCK - 3), outline=CURSOR_EDGE + (70,))


def draw_text_colors(img):
    d = ImageDraw.Draw(img)
    for i, color in enumerate(TEXT_COLORS):
        x = (i % 10) * 16
        y = 48 + (i // 10) * 16
        d.rectangle((x, y, x + 15, y + 15), fill=color + (255,))


def main():
    img = Image.new("RGBA", (SKIN_W, SKIN_H), (0, 0, 0, 0))
    draw_background(img)
    draw_frame(img)
    draw_cursor(img, 64, CURSOR_FILL)
    draw_cursor(img, 96, CURSOR2_FILL)
    draw_text_colors(img)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("generated:", os.path.relpath(OUT, REPO))


if __name__ == "__main__":
    main()
