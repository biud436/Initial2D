#!/usr/bin/env python3
"""데모 게임 「떠나기 전에」의 타이틀 배경을 만든다 (기획서 docs/design/port-town.md).

출력: resources/titles/port_title.png (768x896, 허브의 논리 해상도 그대로)

그림은 게임의 첫 장면과 같은 곳이다 — 저녁 물때의 항구, 부두에 댄 배, 언덕의
등대. 8단계의 마을 타이틀(village_title.png)을 항구로 다시 그린 것이다.

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
OUT = os.path.join(REPO, "resources", "titles", "port_title.png")

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
SEA_NEAR = (36, 62, 92)
SEA_FAR = (22, 38, 62)
SAIL = (238, 232, 214)
SAIL_SHADE = (196, 190, 172)
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
    """물가와 바다. 위쪽은 부두가 선 땅, 아래는 노을이 비치는 물이다."""
    d = ImageDraw.Draw(img)
    water_top = 700
    for y in range(HORIZON, water_top):
        t = (y - HORIZON) / (water_top - HORIZON)
        d.line([(0, y), (W, y)], fill=lerp(HILL_NEAR, GROUND, t ** 0.7))
    for y in range(water_top, H):
        t = (y - water_top) / (H - water_top)
        d.line([(0, y), (W, y)], fill=lerp(SEA_NEAR, SEA_FAR, t))
    # 물 위에 남은 노을. 한 줄로 곧게 세우면 사다리처럼 보이므로, 조각을 좌우로
    # 흔들고 아래로 갈수록 어둡게 섞어 끊어진 반사로 만든다.
    for i, y in enumerate(range(water_top + 6, H, 11)):
        t = (y - water_top) / (H - water_top)
        if i % 3 == 2:
            continue
        w = int(90 * (1.0 - t) + 14)
        cx = 384 + int(math.sin(i * 1.7) * 46)
        color = lerp((236, 168, 122), lerp(SEA_NEAR, SEA_FAR, t), min(1.0, t * 1.5))
        d.line([(cx - w // 2, y), (cx + w // 2, y)], fill=color)


def house(d, spill, halo, x, y, w, h, roof_h, lit):
    """마을 집 실루엣. 창에만 불이 들어오고 그 빛이 앞마당에 번진다."""
    d.polygon([(x - 10, y), (x + w + 10, y), (x + w // 2, y - roof_h)], fill=HOUSE)
    d.rectangle([x, y, x + w, y + h], fill=HOUSE)
    if not lit:
        return
    wx, wy = x + w // 2 - 9, y + h // 3
    d.rectangle([wx, wy, wx + 18, wy + 16], fill=WINDOW_LIT)
    spill.polygon([(wx - 6, wy), (wx + 24, wy),
                   (wx + 62, y + h + 34), (wx - 44, y + h + 34)],
                  fill=(255, 196, 112, 70))
    halo.rectangle([wx - 3, wy - 3, wx + 21, wy + 19], fill=(255, 212, 140, 120))


def lighthouse(d, spill, halo, x, base_y, h):
    """언덕의 등대. 불빛이 바다 쪽으로 퍼진다."""
    top = base_y - h
    d.polygon([(x - 16, base_y), (x - 11, top + 26), (x + 11, top + 26),
               (x + 16, base_y)], fill=HOUSE)          # 탑
    d.rectangle([x - 13, top + 10, x + 13, top + 26], fill=HOUSE)
    d.rectangle([x - 10, top + 8, x + 10, top + 20], fill=WINDOW_LIT)   # 등실
    d.polygon([(x - 15, top + 4), (x + 15, top + 4), (x + 10, top + 8),
               (x - 10, top + 8)], fill=HOUSE)         # 지붕
    halo.ellipse([x - 30, top - 4, x + 30, top + 32], fill=(255, 214, 140, 150))
    spill.polygon([(x - 12, top + 12), (x + 12, top + 12),
                   (x + 150, top + 70), (x - 150, top + 70)],
                  fill=(255, 206, 130, 46))            # 바다로 뻗는 빛


def pier_and_ship(d, spill, halo, x0, x1, y):
    """옆에서 본 부두와 그 끝에 댄 배. 게임의 첫 장면과 같은 배치다."""
    d.rectangle([x0, y, x1, y + 7], fill=HOUSE)              # 데크
    d.rectangle([x0, y - 3, x1, y], fill=(46, 58, 70))       # 널의 윗면
    for px in range(x0 + 10, x1 - 6, 52):                    # 기둥
        d.rectangle([px, y + 7, px + 6, y + 46], fill=HOUSE)

    sx, sy = x1 + 96, y + 16                                 # 배
    d.polygon([(sx - 58, sy - 12), (sx + 58, sy - 12), (sx + 40, sy + 12),
               (sx - 40, sy + 12)], fill=HOUSE)              # 선체
    d.rectangle([sx - 2, sy - 84, sx + 2, sy - 12], fill=HOUSE)   # 돛대
    d.polygon([(sx + 5, sy - 76), (sx + 40, sy - 16), (sx + 5, sy - 16)], fill=SAIL)
    d.polygon([(sx - 5, sy - 60), (sx - 34, sy - 16), (sx - 5, sy - 16)],
              fill=SAIL_SHADE)
    d.line([(x1, y + 2), (sx - 52, sy - 12)], fill=(120, 104, 88))   # 매어 둔 밧줄
    halo.ellipse([sx - 7, sy - 92, sx + 7, sy - 78], fill=(255, 214, 140, 130))
    spill.ellipse([sx - 70, sy + 6, sx + 70, sy + 26], fill=(255, 196, 112, 40))


def village(img):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    spill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d, sp, ha = ImageDraw.Draw(layer), ImageDraw.Draw(spill), ImageDraw.Draw(halo)

    lighthouse(d, sp, ha, 636, 612, 118)                # 언덕의 등대
    house(d, sp, ha, 96, 636, 84, 54, 36, True)         # 마을 집 셋
    house(d, sp, ha, 226, 654, 70, 46, 30, False)
    house(d, sp, ha, 344, 640, 92, 58, 38, True)
    pier_and_ship(d, sp, ha, 168, 396, 726)             # 부두와 배

    img.alpha_composite(spill.filter(ImageFilter.GaussianBlur(16)))
    img.alpha_composite(layer)
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(7)))


def fireflies(img, rnd):
    """물 위의 잔물결과 뭍의 반딧불 몇 마리."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(40):
        x = rnd.randrange(10, W - 10)
        y = rnd.randrange(716, H - 10)
        w = rnd.randrange(6, 22)
        d.line([(x, y), (x + w, y)], fill=(120, 150, 186, 150))
    for _ in range(10):
        x = rnd.randrange(20, W - 20)
        y = rnd.randrange(HORIZON + 30, 690)
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(214, 240, 150, 170))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(2)))


def title_text(img, ttf):
    """제목과 부제. 글자 뒤에 따뜻한 글로우를 깐다."""
    big = ImageFont.truetype(ttf, 92)
    small = ImageFont.truetype(ttf, 30)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.text((W // 2, 232), "떠나기 전에", font=big, fill=TITLE_GLOW + (210,), anchor="mm")
    glow = glow.filter(ImageFilter.GaussianBlur(22))
    img.alpha_composite(glow)
    img.alpha_composite(glow)   # 두 번 겹쳐 밝기를 올린다

    d = ImageDraw.Draw(img)
    d.text((W // 2 + 3, 235), "떠나기 전에", font=big, fill=(60, 30, 20, 160), anchor="mm")
    d.text((W // 2, 232), "떠나기 전에", font=big, fill=TITLE_INK + (255,), anchor="mm")
    d.text((W // 2, 320), "항구 마을의 반나절 — Initial2D 데모", font=small,
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
