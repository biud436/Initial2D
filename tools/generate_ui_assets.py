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


def make_dpad(path, size=160):
    """터치용 가상 D-패드 스프라이트 시트 (scripts/ui/vpad.lua).

    가로 5프레임: 0=기본, 1=위, 2=오른쪽, 3=아래, 4=왼쪽 눌림.
    반투명 어두운 원판 위에 4개 화살표. 눌린 방향은 버튼 팔레트의
    초록으로 채워 손가락 아래에서 무엇이 눌렸는지 보이게 한다.
    """
    frames = 5
    sheet = Image.new("RGBA", (size * frames, size), (0, 0, 0, 0))
    c = size / 2.0
    r_disc = size * 0.48
    r_out, r_in = size * 0.40, size * 0.17   # 화살표 밖·안 반경
    half = size * 0.13                       # 화살표 밑변 절반

    def arrow(d, dr, ang_deg, fill, outline):
        import math
        a = math.radians(ang_deg)
        ux, uy = math.cos(a), math.sin(a)          # 바깥 방향 단위 벡터
        px, py = -uy, ux                           # 수직 벡터
        tip = (c + ux * r_out, c + uy * r_out)
        bl = (c + ux * r_in + px * half, c + uy * r_in + py * half)
        br = (c + ux * r_in - px * half, c + uy * r_in - py * half)
        dr.polygon([tip, bl, br], fill=fill, outline=outline)

    # 각 프레임: 위(-90), 오른쪽(0), 아래(90), 왼쪽(180)
    angles = [-90, 0, 90, 180]
    for f in range(frames):
        frame = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(frame)
        d.ellipse((c - r_disc, c - r_disc, c + r_disc, c + r_disc),
                  fill=(20, 40, 30, 120), outline=(230, 240, 230, 150), width=3)
        for i, ang in enumerate(angles):
            pressed = (f == i + 1)
            fill = (110, 178, 92, 235) if pressed else (235, 240, 235, 170)
            outline = (46, 104, 52, 255) if pressed else (30, 50, 40, 200)
            arrow(i, d, ang, fill, outline)
        sheet.paste(frame, (f * size, 0))

    sheet.save(path)
    print("generated:", os.path.relpath(path, REPO))


def main():
    os.makedirs(UI, exist_ok=True)
    make_button(os.path.join(UI, "button.png"))
    make_dpad(os.path.join(UI, "dpad.png"))


if __name__ == "__main__":
    main()
