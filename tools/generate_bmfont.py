#!/usr/bin/env python3
"""TTF에서 BMFont 규격의 비트맵 폰트(.fnt + .png)를 만든다.

엔진의 텍스트 경로는 비트맵 폰트 한 벌을 그대로 찍는다 — 그리는 쪽에 확대나
축소가 없다(TextureManagerSDL2::DrawText는 트랜스폼을 무시한다). 그래서 화면의
논리 해상도가 달라지면 글자 크기도 폰트 자체를 바꿔야 한다. 기존
resources/fonts/hangul.fnt는 32px이라 렌더 배율 2(논리 384x448)에서는 너무 크다.

기본 동작은 "기존 폰트와 같은 글자 집합을 더 작은 크기로 다시 굽기"다.
글자 목록을 기존 .fnt에서 읽으므로 커버리지가 줄지 않는다.

Usage:
    python3 tools/generate_bmfont.py                    # 16px, hangul.fnt와 같은 글자
    python3 tools/generate_bmfont.py --size 12 --out hangul12
Requires: Pillow, 그리고 시스템에 NanumGothic.ttf
"""

import argparse
import os
import re

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(REPO, "resources", "fonts")
SOURCE_FNT = os.path.join(FONTS, "hangul.fnt")

TTF_CANDIDATES = [
    os.path.expanduser("~/Library/Fonts/NanumGothic.ttf"),
    "/Library/Fonts/NanumGothic.ttf",
    "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
]


def find_ttf(explicit=None):
    for path in ([explicit] if explicit else []) + TTF_CANDIDATES:
        if path and os.path.exists(path):
            return path
    raise SystemExit("한글 TTF를 찾지 못했습니다. --ttf 로 경로를 지정하세요.")


def load_charset(path):
    """기존 .fnt에서 글자 id 목록을 읽는다 (커버리지를 그대로 유지하기 위해)."""
    text = open(path, encoding="utf-8").read()
    ids = [int(m) for m in re.findall(r'<char id="(\d+)"', text)]
    return sorted(set(ids))


def build(size, out_name, ttf_path, ids, padding=1):
    font = ImageFont.truetype(ttf_path, size)
    ascent, descent = font.getmetrics()
    line_height = ascent + descent

    # 글리프를 한 장씩 그려 두고 크기를 잰다
    glyphs = []
    probe = Image.new("L", (size * 3, size * 3))
    draw = ImageDraw.Draw(probe)
    for cid in ids:
        ch = chr(cid)
        try:
            bbox = draw.textbbox((0, 0), ch, font=font)
        except Exception:
            continue
        w = max(0, bbox[2] - bbox[0])
        h = max(0, bbox[3] - bbox[1])
        advance = int(round(font.getlength(ch)))
        glyphs.append({"id": cid, "ch": ch, "w": w, "h": h,
                       "ox": bbox[0], "oy": bbox[1], "advance": advance})

    # 아틀라스 크기: 2의 거듭제곱으로 키워 가며 줄 단위로 채운다
    for atlas in (256, 512, 1024, 2048):
        placed, x, y, row_h = [], padding, padding, 0
        ok = True
        for g in glyphs:
            gw, gh = g["w"] + padding, g["h"] + padding
            if x + gw >= atlas:
                x = padding
                y += row_h + padding
                row_h = 0
            if y + gh >= atlas:
                ok = False
                break
            placed.append((g, x, y))
            x += gw
            row_h = max(row_h, gh)
        if ok:
            break
    if not ok:
        raise SystemExit("글리프가 2048x2048 아틀라스에 들어가지 않습니다.")

    # 흰 글자 + 알파 (기존 hangul_0.png와 같은 방식)
    image = Image.new("RGBA", (atlas, atlas), (255, 255, 255, 0))
    canvas = ImageDraw.Draw(image)
    for g, gx, gy in placed:
        canvas.text((gx - g["ox"], gy - g["oy"]), g["ch"], font=font, fill=(255, 255, 255, 255))

    png_name = f"{out_name}_0.png"
    image.save(os.path.join(FONTS, png_name))

    lines = [
        '<?xml version="1.0"?>',
        "<font>",
        f'  <info face="NanumGothic" size="{size}" bold="0" italic="0" charset=""'
        ' unicode="1" stretchH="100" smooth="1" aa="1" padding="0,0,0,0"'
        ' spacing="1,1" outline="0"/>',
        f'  <common lineHeight="{line_height}" base="{ascent}" scaleW="{atlas}"'
        f' scaleH="{atlas}" pages="1" packed="0" alphaChnl="0" redChnl="0"'
        ' greenChnl="0" blueChnl="0"/>',
        "  <pages>",
        f'    <page id="0" file="{png_name}" />',
        "  </pages>",
        f'  <chars count="{len(placed)}">',
    ]
    for g, gx, gy in placed:
        lines.append(
            f'    <char id="{g["id"]}" x="{gx}" y="{gy}" width="{g["w"]}"'
            f' height="{g["h"]}" xoffset="{g["ox"]}" yoffset="{g["oy"]}"'
            f' xadvance="{g["advance"]}" page="0" chnl="15" />')
    lines += ["  </chars>", "</font>", ""]

    fnt_name = f"{out_name}.fnt"
    with open(os.path.join(FONTS, fnt_name), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"generated: resources/fonts/{fnt_name}, resources/fonts/{png_name}")
    print(f"  글자 {len(placed)}개, 아틀라스 {atlas}x{atlas}, lineHeight {line_height}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=16, help="글자 크기 (기본 16)")
    ap.add_argument("--out", default=None, help="출력 이름 (기본 hangul<크기>)")
    ap.add_argument("--ttf", default=None, help="TTF 경로")
    ap.add_argument("--from-fnt", default=SOURCE_FNT, help="글자 집합을 가져올 .fnt")
    args = ap.parse_args()

    out = args.out or f"hangul{args.size}"
    ids = load_charset(args.from_fnt)
    build(args.size, out, find_ttf(args.ttf), ids)


if __name__ == "__main__":
    main()
