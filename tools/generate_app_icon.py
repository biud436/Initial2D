#!/usr/bin/env python3
"""Initial2D 앱 아이콘을 그린다.

파란 둥근 사각형 안의 금색 머리글자 상자와 계단 그림자를 단 I. 도형만 쓰고 글꼴은 쓰지 않는다.
엔진은 시작할 때 resources/icons/icon.png 를 창 아이콘으로 쓰고, macOS 에서는 Dock 아이콘도 된다.

  python3 tools/generate_app_icon.py                      # resources/icons/icon.png (512px)
  python3 tools/generate_app_icon.py --size 1024 -o a.png # 다른 크기, 다른 경로
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "resources" / "icons" / "icon.png"

# 1024 기준 좌표로 그리고 SS 배로 키워 그린 뒤 줄여 가장자리를 매끄럽게 한다.
BASE = 1024
SS = 4

TOP = (52, 96, 156)
BOTTOM = (20, 36, 78)
GOLD = (236, 206, 104)
SHADOW = (11, 21, 48)
GRID = (255, 255, 255, 14)

BODY_MARGIN = 64
BODY_RADIUS = 200
FRAME = (150, 150, 874, 874)
FRAME_RADIUS = 110
FRAME_WIDTH = 14

# I 와 그림자 (그림자는 STEP px 씩 STEPS 번 오른쪽 아래로)
I_STEM_W = 150
I_SERIF_W = 404
I_SERIF_H = 92
I_HEIGHT = 500
STEP = 16
STEPS = 4


def s(v: float) -> int:
    return int(round(v * SS))


def gradient(size: int) -> Image.Image:
    column = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        column.putpixel((0, y), tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    return column.resize((size, size), Image.BILINEAR).convert("RGBA")


def slab_i(draw: ImageDraw.ImageDraw, cx: float, top: float, fill) -> None:
    bottom = top + I_HEIGHT
    draw.rectangle((s(cx - I_SERIF_W / 2), s(top), s(cx + I_SERIF_W / 2), s(top + I_SERIF_H)), fill=fill)
    draw.rectangle((s(cx - I_STEM_W / 2), s(top), s(cx + I_STEM_W / 2), s(bottom)), fill=fill)
    draw.rectangle((s(cx - I_SERIF_W / 2), s(bottom - I_SERIF_H), s(cx + I_SERIF_W / 2), s(bottom)), fill=fill)


def render(size: int) -> Image.Image:
    n = BASE * SS
    bg = gradient(n)

    grid = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    for k in range(64, BASE, 64):
        gd.line((s(k), 0, s(k), n), fill=GRID, width=s(2))
        gd.line((0, s(k), n, s(k)), fill=GRID, width=s(2))
    bg = Image.alpha_composite(bg, grid)

    d = ImageDraw.Draw(bg)
    d.rounded_rectangle(tuple(s(v) for v in FRAME), radius=s(FRAME_RADIUS), outline=GOLD + (255,), width=s(FRAME_WIDTH))

    # 글자와 그림자를 합친 덩어리가 가운데에 오도록 그림자 길이의 반만큼 왼쪽 위로 당긴다.
    shift = STEP * STEPS / 2
    cx = BASE / 2 - shift
    top = (BASE - I_HEIGHT) / 2 - shift
    for k in range(STEPS, 0, -1):
        slab_i(d, cx + STEP * k, top + STEP * k, SHADOW + (255,))
    slab_i(d, cx, top, GOLD + (255,))

    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (s(BODY_MARGIN), s(BODY_MARGIN), n - s(BODY_MARGIN), n - s(BODY_MARGIN)), radius=s(BODY_RADIUS), fill=255
    )
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def main() -> None:
    parser = argparse.ArgumentParser(description="Initial2D 앱 아이콘을 그린다")
    parser.add_argument("--size", type=int, default=512, help="한 변의 픽셀 수 (기본 512)")
    parser.add_argument("-o", "--out", type=Path, default=DEFAULT_OUT, help="저장할 PNG 경로")
    args = parser.parse_args()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    render(args.size).save(args.out, "PNG", optimize=True)
    print(f"wrote {args.out} ({args.size}x{args.size})")


if __name__ == "__main__":
    main()
