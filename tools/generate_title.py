#!/usr/bin/env python3
"""데모 게임 "작은 마을"의 타이틀 배경을 만든다 (8단계, docs/plans/08-demo.md).

출력: resources/titles/village_title.png (768x896, 허브의 논리 해상도 그대로)

타이틀 글자는 그림에 구워 넣는다. 엔진의 텍스트 경로에는 확대와 글로우가 없어
비트맵 폰트로는 제목다운 크기가 나오지 않기 때문이다. 메뉴 항목은 반대로 런타임에
창(scripts/rpg/window.lua)으로 그린다 — 커서와 효과음이 붙어야 하는 부분이다.

Usage: python3 tools/generate_title.py
Requires: Pillow, 그리고 한글 TTF (NanumBarunGothicBold 등)
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "resources", "titles", "village_title.png")

W, H = 768, 896
HORIZON = 596                # 하늘과 땅의 경계

TTF_CANDIDATES = [
    "/Library/Fonts/NanumBarunGothicBold.ttf",
    os.path.expanduser("~/Library/Fonts/NanumGothicBold.ttf"),
    "/Library/Fonts/NanumGothic.ttf",
    "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
]

# 데모 맵의 팔레트(tools/generate_village_tileset.py)와 같은 계열로 맞춘다
SKY_TOP = (26, 30, 66)
SKY_MID = (78, 62, 110)
SKY_LOW = (226, 138, 92)
GROUND = (28, 62, 54)
HILL_FAR = (54, 60, 92)
HILL_NEAR = (34, 58, 62)
HOUSE = (26, 34, 44)
WINDOW_LIT = (255, 206, 122)
TITLE_INK = (255, 244, 222)
TITLE_GLOW = (255, 158, 78)


def find_ttf():
    for path in TTF_CANDIDATES:
        if os.path.exists(path):
            return path
    raise SystemExit("한글 TTF를 찾지 못했습니다 (NanumBarunGothicBold 등).")


def lerp(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def sky(img):
    d = ImageDraw.Draw(img)
    for y in range(HORIZON):
        t = y / HORIZON
        # 위쪽 2/3는 남색에서 보라로, 아래 1/3에서 노을로 물든다
        if t < 0.62:
            color = lerp(SKY_TOP, SKY_MID, t / 0.62)
        else:
            color = lerp(SKY_MID, SKY_LOW, ((t - 0.62) / 0.38) ** 1.6)
        d.line([(0, y), (W, y)], fill=color)


def stars(img, rnd):
    d = ImageDraw.Draw(img)
    for _ in range(140):
        x = rnd.randrange(0, W)
        y = rnd.randrange(0, int(HORIZON * 0.72))
        # 위로 갈수록 또렷하게 (아래는 노을에 묻힌다)
        fade = 1.0 - y / (HORIZON * 0.72)
        v = int(140 + 115 * fade * rnd.random())
        d.point((x, y), fill=(v, v, min(255, v + 20)))
        if rnd.random() < 0.12:
            d.point((x + 1, y), fill=(v // 2, v // 2, v // 2))
            d.point((x, y + 1), fill=(v // 2, v // 2, v // 2))


def moon(img):
    """초승달. 원 두 개의 차집합을 알파 마스크로 만든다.

    깎아 낼 쪽을 하늘색으로 덮으면 그라데이션 위에서 색이 어긋나 원반이
    비쳐 보인다. 마스크로 지우면 뒤의 하늘이 그대로 남는다.
    """
    cx, cy, r = 596, 138, 46

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [cx - r * 2.6, cy - r * 2.6, cx + r * 2.6, cy + r * 2.6],
        fill=(255, 236, 190, 46))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(30)))

    mask = Image.new("L", (W, H), 0)
    m = ImageDraw.Draw(mask)
    m.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    m.ellipse([cx - r + 24, cy - r - 14, cx + r + 24, cy + r - 14], fill=0)
    disc = Image.new("RGBA", (W, H), (252, 242, 214, 255))
    img.paste(disc, (0, 0), mask.filter(ImageFilter.GaussianBlur(0.6)))


def hills(img, rnd):
    """부드러운 능선 두 겹. 사인 몇 개를 겹쳐 만든다."""
    d = ImageDraw.Draw(img)
    for color, base, amp, phase in ((HILL_FAR, HORIZON - 42, 26, 0.0),
                                    (HILL_NEAR, HORIZON - 8, 18, 1.7)):
        pts = []
        for x in range(W + 1):
            u = x / W
            y = base - amp * (0.6 * math.sin(u * 5.0 + phase)
                              + 0.4 * math.sin(u * 11.0 + phase * 2.1))
            pts.append((x, y))
        d.polygon(pts + [(W, H), (0, H)], fill=color)


def ground(img):
    d = ImageDraw.Draw(img)
    for y in range(HORIZON, H):
        t = (y - HORIZON) / (H - HORIZON)
        d.line([(0, y), (W, y)], fill=lerp(HILL_NEAR, GROUND, t ** 0.7))


def house(d, spill, halo, x, y, w, h, roof_h, lit):
    """단순한 집 실루엣 하나. 창에만 불이 들어오고, 그 빛이 앞마당에 번진다."""
    d.polygon([(x - 10, y), (x + w + 10, y), (x + w // 2, y - roof_h)], fill=HOUSE)
    d.rectangle([x, y, x + w, y + h], fill=HOUSE)
    if not lit:
        return
    wx, wy = x + w // 2 - 9, y + h // 3
    d.rectangle([wx, wy, wx + 18, wy + 16], fill=WINDOW_LIT)
    # 마당으로 퍼지는 빛. 집 실루엣 아래에 깔아 집 몸통에는 묻히고 바닥에만 남는다.
    spill.polygon([(wx - 6, wy), (wx + 24, wy),
                   (wx + 62, y + h + 34), (wx - 44, y + h + 34)],
                  fill=(255, 196, 112, 70))
    # 창 언저리의 얇은 무리
    halo.rectangle([wx - 3, wy - 3, wx + 21, wy + 19], fill=(255, 212, 140, 120))


def village(img):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    spill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d, sp, ha = ImageDraw.Draw(layer), ImageDraw.Draw(spill), ImageDraw.Draw(halo)
    house(d, sp, ha, 96, 612, 92, 62, 40, True)
    house(d, sp, ha, 258, 634, 76, 52, 34, False)
    house(d, sp, ha, 402, 606, 108, 70, 46, True)
    house(d, sp, ha, 566, 640, 84, 56, 36, True)

    img.alpha_composite(spill.filter(ImageFilter.GaussianBlur(14)))
    img.alpha_composite(layer)
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(6)))


def fireflies(img, rnd):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(26):
        x = rnd.randrange(20, W - 20)
        y = rnd.randrange(HORIZON + 20, H - 40)
        r = rnd.choice((2, 2, 3))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(214, 240, 150, 190))
    layer = layer.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(layer)


def title_text(img, ttf):
    """제목과 부제. 글자 뒤에 따뜻한 글로우를 깐다."""
    big = ImageFont.truetype(ttf, 104)
    small = ImageFont.truetype(ttf, 30)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.text((W // 2, 232), "작은 마을", font=big, fill=TITLE_GLOW + (210,), anchor="mm")
    glow = glow.filter(ImageFilter.GaussianBlur(22))
    img.alpha_composite(glow)
    img.alpha_composite(glow)   # 두 번 겹쳐 밝기를 올린다

    d = ImageDraw.Draw(img)
    d.text((W // 2 + 3, 235), "작은 마을", font=big, fill=(60, 30, 20, 160), anchor="mm")
    d.text((W // 2, 232), "작은 마을", font=big, fill=TITLE_INK + (255,), anchor="mm")
    d.text((W // 2, 320), "Initial2D 데모", font=small,
           fill=(232, 214, 196, 220), anchor="mm")


def main():
    rnd = random.Random(20260819)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    sky(img)
    stars(img, rnd)
    moon(img)
    hills(img, rnd)
    ground(img)
    village(img)
    fireflies(img, rnd)
    title_text(img, find_ttf())

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("generated:", os.path.relpath(OUT, REPO))


if __name__ == "__main__":
    main()
