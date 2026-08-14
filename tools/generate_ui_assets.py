#!/usr/bin/env python3
"""Generate UI assets under resources/ui/.

플레이스홀더 아트(tools/generate_placeholder_assets.py)와 달리 이 출력물은
저장소에 커밋된다 — 디자인을 바꿀 때만 다시 실행한다.

Usage: python3 tools/generate_ui_assets.py
Requires: Pillow (pip install pillow)
"""

import os

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(REPO, "resources", "ui")


def lerp(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def make_button(path, w=440, h=96):
    """게임 팔레트(잔디 초록)에 맞춘 라운드 버튼 패널.

    흰색 비트맵 폰트 라벨이 올라가므로 면은 중간 명도의 초록 그라데이션,
    테두리는 진한 초록, 아래에는 그림자 밴드를 둔 묵직한 게임 버튼 스타일.
    """
    shadow_h = 8          # 바닥 그림자 두께
    border = 5            # 테두리 두께
    radius = 24

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # 바닥 그림자 (버튼이 떠 있는 느낌)
    d.rounded_rectangle((3, shadow_h, w - 1, h - 1), radius=radius, fill=(40, 70, 35, 110))

    # 본체 테두리 (진한 초록)
    body = (0, 0, w - 4, h - shadow_h)
    d.rounded_rectangle(body, radius=radius, fill=(46, 104, 52, 255))

    # 면: 초록 그라데이션 (위가 밝고 아래가 어두움)
    top, bottom = (110, 178, 92), (66, 132, 66)
    face = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fd = ImageDraw.Draw(face)
    for y in range(h):
        t = y / (h - 1)
        fd.line([(0, y), (w, y)], fill=lerp(top, bottom, t) + (255,))

    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle(
        (border, border, w - 4 - border, h - shadow_h - border),
        radius=radius - 4, fill=255)
    img.paste(face, (0, 0), mask)

    # 상단 하이라이트 (유광 느낌)
    hl_mask = Image.new("L", (w, h), 0)
    hd = ImageDraw.Draw(hl_mask)
    hd.rounded_rectangle(
        (border + 8, border + 6, w - 4 - border - 8, h // 3),
        radius=radius - 8, fill=56)
    img.paste(Image.new("RGBA", (w, h), (255, 255, 255, 255)), (0, 0), hl_mask)

    img.save(path)
    print("generated:", os.path.relpath(path, REPO))


def main():
    os.makedirs(UI, exist_ok=True)
    make_button(os.path.join(UI, "button.png"))


if __name__ == "__main__":
    main()
