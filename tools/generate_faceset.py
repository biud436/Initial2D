#!/usr/bin/env python3
"""R2K3 FaceSet 규격(192x192, 48x48 얼굴 16개)의 플레이스홀더를 만든다.

대화창의 얼굴 그래픽(7단계)도 RTP 없이 돌아가야 한다. 플레이스홀더 CharSet
(tools/generate_charset.py)과 같은 팔레트를 써서, 같은 인물의 전신과 얼굴이
같은 색으로 보이게 한다 — 팔레트 n번 얼굴은 CharSet n번 캐릭터다.

    얼굴 0..7   팔레트 8명의 평상시 표정
    얼굴 8..15  같은 8명의 웃는 표정 (선택지 분기에서 표정을 바꿔 볼 수 있다)

규격의 출처는 scripts/rpg/specs.lua의 M.faceset이다.
생성물은 저장소에 커밋된다 — 그림을 바꿀 때만 다시 실행한다.

Usage: python3 tools/generate_faceset.py
Requires: Pillow (pip install pillow)
"""

import os

from PIL import Image, ImageDraw

from generate_charset import PALETTES

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(REPO, "resources", "faces")

# specs.lua의 M.faceset과 같은 값이어야 한다
SHEET_W, SHEET_H = 192, 192
SIZE = 48
COLS, ROWS = 4, 4


def draw_face(pal, smiling):
    """48x48 얼굴 하나. 배경은 투명해서 대화창 바탕이 그대로 비친다."""
    skin, hair, shirt, pants, shoe, line = pal
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # 어깨와 옷 (아래쪽 1/4)
    d.rounded_rectangle((6, 36, 41, 47), radius=6, fill=shirt, outline=line)
    d.line([(24, 38), (24, 47)], fill=line)

    # 목
    d.rectangle((20, 32, 27, 38), fill=skin, outline=line)

    # 머리통
    d.ellipse((10, 6, 37, 37), fill=skin, outline=line)

    # 머리카락: 이마를 덮는 반원 + 옆머리
    d.pieslice((10, 4, 37, 30), start=180, end=360, fill=hair, outline=line)
    d.rectangle((10, 14, 13, 26), fill=hair)
    d.rectangle((34, 14, 37, 26), fill=hair)

    # 눈
    for ex in (17, 28):
        d.rectangle((ex, 20, ex + 2, 22), fill=line)

    # 입 (웃는 표정은 한 칸 넓고 아래로 휜다)
    if smiling:
        d.arc((18, 24, 29, 31), start=0, end=180, fill=line)
    else:
        d.line([(20, 28), (27, 28)], fill=line)

    # 볼 (살짝 붉게 — 단조로운 면을 깬다)
    blush = tuple(min(255, c + 20) for c in shirt)
    d.point((15, 25), fill=blush)
    d.point((32, 25), fill=blush)

    return im


def make_sheet(path):
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for index in range(COLS * ROWS):
        pal = PALETTES[index % len(PALETTES)]
        face = draw_face(pal, smiling=index >= len(PALETTES))
        sheet.paste(face, ((index % COLS) * SIZE, (index // COLS) * SIZE))
    sheet.save(path)
    print("generated:", os.path.relpath(path, REPO))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    make_sheet(os.path.join(OUT_DIR, "placeholder.png"))


if __name__ == "__main__":
    main()
