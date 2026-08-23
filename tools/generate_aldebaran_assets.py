#!/usr/bin/env python3
"""알데바란 데모의 플레이스홀더 자산 생성기 (docs/design/aldebaran.md).

횡스크롤 시점이라 RTP의 톱다운 규격이 맞지 않아, 커밋 가능한 도트 그림을 여기서
만든다. 그리는 순서는 이미지 지침(2026-08-23) 그대로다:

  1. 실루엣을 단색으로 채운다 (스케치)
  2. 명암을 도트 방식(체커보드 디더)으로 덧칠한다
  3. 마지막에 어두운 테두리를 명확하게 두른다 (outline 후처리)

만드는 것:
  resources/aldebaran/karto.png      주인공 시트, 그리드 (12, 2), 프레임 48x48
  resources/aldebaran/spider.png     밀림 전갈거미, 그리드 (4, 2), 프레임 48x32
  resources/aldebaran/wolf.png       늑대 인간, 그리드 (5, 2), 프레임 48x48
  resources/aldebaran/monkey.png     가면 원숭이 짐도둑, 그리드 (4, 2), 프레임 48x48
  resources/aldebaran/stone.png      돌팔매 8x8
  resources/aldebaran/aura.png       버서커 기운, 가로 2프레임 48x48
  resources/aldebaran/bag.png        되찾을 배낭 16x16
  resources/aldebaran/forest16.png   타일셋 (8열, 16px)
  resources/aldebaran/forest_bg.png  원경 384x448
  resources/titles/aldebaran_title.png  타이틀 768x896 (글자를 굽는다)
  resources/aldebaran/hud.png        HUD 막대와 아이콘
  resources/audio/aldebaran_*.wav    효과음

아랫줄(왼쪽 보기)은 오른쪽 보기를 미러링해 굽는다 (엔진에 좌우 반전이 없다).

Usage: python3 tools/generate_aldebaran_assets.py
Requires: Pillow
"""

import math
import os
import struct
import wave

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "resources", "aldebaran")
TITLES = os.path.join(REPO, "resources", "titles")
AUDIO = os.path.join(REPO, "resources", "audio")

TTF_CANDIDATES = [
    "/Library/Fonts/NanumBarunGothicBold.ttf",
    os.path.expanduser("~/Library/Fonts/NanumGothicBold.ttf"),
    "/Library/Fonts/NanumGothic.ttf",
    "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
]

# ---- 팔레트 ---------------------------------------------------------------
# 검은 안개의 숲: 어둡고 채도 낮은 바탕 위에서 인물이 또렷해야 한다.

INK = (24, 18, 26)              # 공용 테두리 (거의 검정, 자줏빛)

COAT = (196, 164, 110)          # 카르토 외투 (밝은 황갈 — 어두운 숲에서 도드라진다)
COAT_SHADE = (150, 120, 76)
SCARF = (202, 70, 58)           # 붉은 목도리
SKIN = (232, 194, 156)
HAIR = (88, 58, 34)
PANTS = (84, 76, 96)
PANTS_SHADE = (60, 54, 72)
BOOT = (110, 74, 44)
BLADE = (222, 226, 236)
GLOW = (176, 106, 226)          # 단검의 보라색 검기

SPIDER = (94, 76, 104)          # 전갈거미 몸통 (암속성 보랏빛 회색)
SPIDER_SHADE = (66, 52, 76)
SPIDER_BELLY = (128, 108, 128)
SPIDER_EYE = (236, 90, 70)
STING = (206, 180, 90)          # 독침

WOLF = (96, 88, 84)             # 늑대 인간 털
WOLF_SHADE = (64, 58, 58)
WOLF_BELLY = (140, 130, 118)
WOLF_EYE = (240, 70, 54)
CLAW = (224, 220, 208)

MONKEY = (134, 96, 58)          # 가면 원숭이
MONKEY_SHADE = (98, 68, 42)
MASK = (230, 226, 210)          # 가면 (흰 나무 가면)
BAG = (172, 132, 78)            # 배낭
BAG_SHADE = (130, 96, 56)
STONE = (150, 146, 138)
STONE_SHADE = (104, 100, 96)

MUD = (72, 60, 52)              # 진흙 땅
MUD_SHADE = (52, 44, 40)
MOSS = (64, 84, 60)             # 땅 윗면의 검은 이끼
MOSS_SHADE = (44, 60, 44)
ROCK = (110, 106, 112)          # 기암과 바위 턱
ROCK_SHADE = (74, 72, 80)
ROCK_LIGHT = (142, 138, 144)
TREE = (52, 42, 54)             # 검은 늑대 인간의 나무
TREE_SHADE = (36, 28, 40)
TREE_LIGHT = (74, 60, 74)
PLANK = (128, 96, 60)           # 낡은 다리 널
PLANK_SHADE = (92, 68, 44)
ROPE = (170, 150, 104)
VINE = (96, 96, 58)             # 마른 넝쿨
BAMBOO = (150, 148, 96)         # 부서진 대나무
SHROOM = (172, 84, 74)          # 독버섯
WEED = (58, 74, 56)             # 잡초
SIGN = (146, 112, 68)           # 이정표
STATUE = (128, 122, 134)        # 레굴루스 석상
STATUE_SHADE = (88, 84, 98)

MIST = (120, 116, 138)          # 검은 안개 (밝은 회보라 — 디더로 깐다)
SKY_TOP_C = (14, 12, 24)
SKY_LOW_C = (44, 36, 58)
STAR_RED = (232, 96, 66)        # 알데바란
STAR_DIM = (150, 140, 160)

HP_C, HP_D = (206, 74, 60), (140, 44, 40)
MP_C, MP_D = (86, 120, 214), (52, 74, 150)
XP_C, XP_D = (222, 182, 84), (160, 126, 52)
BAR_BG = (34, 30, 40)
STAR_GOLD = (238, 204, 96)
COIN_C = (222, 178, 70)


# ---- 그리기 도우미 --------------------------------------------------------

def blank(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def dither(d, x0, y0, x1, y1, color, phase=0):
    """체커보드 디더 — 두 색이 점점이 엇갈리며 중간 톤을 만든다 (경계 포함 안 함)."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x + y + phase) % 2 == 0:
                d.point((x, y), color)


def dither_over(img, x0, y0, x1, y1, color, phase=0):
    """이미 칠해진 픽셀 위에만 디더를 얹는다 (실루엣 밖으로 새지 않는다)."""
    px = img.load()
    for y in range(max(0, y0), min(img.height, y1)):
        for x in range(max(0, x0), min(img.width, x1)):
            if (x + y + phase) % 2 == 0 and px[x, y][3] > 40:
                px[x, y] = color + (255,)


def rect(d, x0, y0, x1, y1, fill):
    """자세 파라미터에 따라 좌표가 뒤집혀도 그려지는 사각형."""
    d.rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], fill=fill)


def outline(img, color=INK, thresh=40):
    """실루엣 가장자리 픽셀을 테두리 색으로 바꾼다 — 지침 3번 (명확한 테두리)."""
    px = img.load()
    w, h = img.size
    edges = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > thresh:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] <= thresh:
                        edges.append((x, y))
                        break
    for x, y in edges:
        px[x, y] = color + (255,)


def sheet(frames_right, fw, fh, mirror=True):
    """오른쪽 보기 프레임 목록을 시트로 조립한다. 아랫줄은 미러링한 왼쪽 보기."""
    cols = len(frames_right)
    rows = 2 if mirror else 1
    img = blank(cols * fw, rows * fh)
    for i, f in enumerate(frames_right):
        img.paste(f, (i * fw, 0), f)
        if mirror:
            img.paste(f.transpose(Image.FLIP_LEFT_RIGHT), (i * fw, fh))
    return img


def save(img, *path):
    full = os.path.join(*path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)
    print("만듦:", os.path.relpath(full, REPO), img.size)


# ---- 카르토 ---------------------------------------------------------------
# 프레임 48x48, 발 기준선 y=46, 몸통 가운데 x=24. 오른쪽 보기.
# 칸: 0 서기A, 1 서기B, 2~5 걷기, 6 점프, 7 낙하, 8 베기1, 9 베기2, 10 베기3, 11 피격

def karto_frame(pose):
    f = blank(48, 48)
    d = ImageDraw.Draw(f)
    cx, fy = 24, 46
    bob = pose.get("bob", 0)          # 몸 전체의 상하 (점프 자세 등)
    lean = pose.get("lean", 0)        # 앞뒤 기울기 (픽셀)

    # 다리 (스케치: 단색) — legs = (앞다리 dx, 뒷다리 dx, 들어올림)
    fdx, bdx, lift = pose.get("legs", (1, -2, 0))
    for dx, boot_dx, up in ((bdx, bdx, lift), (fdx, fdx, 0)):
        x0 = cx + dx - 1
        d.rectangle([x0, fy - 9 + bob - up, x0 + 2, fy - 3 + bob - up], fill=PANTS)
        d.rectangle([x0, fy - 3 + bob - up, x0 + 3, fy + bob - up], fill=BOOT)
    # 몸통 (외투)
    tx = cx + lean
    d.rectangle([tx - 5, fy - 20 + bob, tx + 5, fy - 9 + bob], fill=COAT)
    # 목도리
    d.rectangle([tx - 5, fy - 20 + bob, tx + 5, fy - 18 + bob], fill=SCARF)
    # 머리 (얼굴은 앞쪽, 머리칼은 위와 뒤)
    hx = tx + pose.get("head", 1)
    d.rectangle([hx - 5, fy - 29 + bob, hx + 5, fy - 20 + bob], fill=SKIN)
    d.rectangle([hx - 5, fy - 29 + bob, hx + 5, fy - 26 + bob], fill=HAIR)
    d.rectangle([hx - 5, fy - 26 + bob, hx - 2, fy - 20 + bob], fill=HAIR)
    if not pose.get("hurt"):
        d.point((hx + 3, fy - 24 + bob), fill=INK)      # 눈
    else:
        d.line([hx + 2, fy - 24 + bob, hx + 4, fy - 24 + bob], fill=INK)  # 감은 눈
    # 뒷팔
    bax, bay = pose.get("backarm", (-5, -16))
    rect(d, tx + bax - 1, fy + bay + bob, tx + bax + 1, fy + bay + 6 + bob, COAT_SHADE)
    # 앞팔과 단검 — arm = (손 dx, 손 dy), dagger = (dx, dy, 길이, 세로 여부)
    ax, ay = pose.get("arm", (6, -14))
    rect(d, tx + 3, fy - 17 + bob, tx + ax, fy + ay + 2 + bob, COAT)
    rect(d, tx + ax - 1, fy + ay + bob, tx + ax + 1, fy + ay + 2 + bob, SKIN)
    dg = pose.get("dagger")
    if dg:
        dgx, dgy, ln, vert = dg
        if vert:
            d.rectangle([tx + dgx, fy + dgy + bob, tx + dgx + 1, fy + dgy + ln + bob], fill=BLADE)
        else:
            d.rectangle([tx + dgx, fy + dgy + bob, tx + dgx + ln, fy + dgy + 1 + bob], fill=BLADE)

    # 명암 (디더 덧칠): 광원은 왼쪽 위 — 몸의 오른쪽 아래를 어둡게
    dither_over(f, tx, fy - 20 + bob, tx + 6, fy - 9 + bob, COAT_SHADE)
    dither_over(f, cx - 4, fy - 9 + bob, cx + 5, fy + bob, PANTS_SHADE)

    outline(f)

    # 검기 (테두리 뒤에 얹는다 — 빛이라 테두리가 없다)
    for arc in pose.get("slash", []):
        x0, y0, x1, y1, start, end = arc
        ImageDraw.Draw(f).arc([x0, y0 + bob, x1, y1 + bob], start, end, fill=GLOW, width=2)
    return f


def make_karto():
    frames = [
        karto_frame({}),                                                    # 0 서기A
        karto_frame({"bob": 1}),                                            # 1 서기B
        karto_frame({"legs": (4, -4, 0)}),                                  # 2 걷기1
        karto_frame({"legs": (2, -1, 1)}),                                  # 3 걷기2
        karto_frame({"legs": (-2, 3, 0)}),                                  # 4 걷기3
        karto_frame({"legs": (1, -1, 1)}),                                  # 5 걷기4
        karto_frame({"legs": (3, -4, 3), "bob": -2, "arm": (7, -20),        # 6 점프
                     "backarm": (-6, -20)}),
        karto_frame({"legs": (2, -3, 1), "arm": (7, -22),                   # 7 낙하
                     "backarm": (-6, -22)}),
        karto_frame({"legs": (4, -4, 0), "lean": 2, "arm": (10, -15),      # 8 베기1
                     "dagger": (10, -16, 8, False),
                     "slash": [(28, 20, 44, 40, 300, 60)]}),
        karto_frame({"legs": (4, -4, 0), "lean": 2, "arm": (10, -12),      # 9 베기2
                     "dagger": (10, -12, 8, False),
                     "slash": [(28, 18, 44, 38, 120, 210)]}),
        karto_frame({"legs": (5, -5, 0), "lean": 3, "arm": (11, -14),      # 10 베기3
                     "dagger": (11, -15, 9, False),
                     "slash": [(26, 16, 46, 40, 300, 60), (26, 16, 46, 40, 120, 210)]}),
        karto_frame({"legs": (3, -3, 0), "lean": -3, "head": -1,           # 11 피격
                     "hurt": True, "arm": (6, -20), "backarm": (-7, -19)}),
    ]
    save(sheet(frames, 48, 48), OUT, "karto.png")


# ---- 몬스터 ---------------------------------------------------------------

def spider_frame(pose):
    """전갈거미 48x32. 낮고 넓은 몸, 다리 여덟, 앞의 큰 턱, 위로 말린 독침 꼬리."""
    f = blank(48, 32)
    d = ImageDraw.Draw(f)
    cx, fy = 22, 30
    crouch = pose.get("crouch", 0)
    # 몸통 (스케치)
    d.ellipse([cx - 11, fy - 12 + crouch, cx + 9, fy - 2], fill=SPIDER)
    # 머리
    d.ellipse([cx + 6, fy - 9 + crouch, cx + 15, fy - 2], fill=SPIDER)
    # 다리 (걸음 위상에 따라 벌림)
    ph = pose.get("legs", 0)
    for i in range(4):
        sx = cx - 8 + i * 5
        spread = 3 if (i + ph) % 2 == 0 else 1
        d.line([sx, fy - 5, sx - spread, fy], fill=SPIDER_SHADE, width=2)
        d.line([sx + 2, fy - 5, sx + 2 + spread, fy], fill=SPIDER_SHADE, width=2)
    # 턱 (공격이면 크게 벌린다)
    jaw = pose.get("jaw", 2)
    d.line([cx + 14, fy - 6 + crouch, cx + 14 + jaw + 2, fy - 8 - jaw + crouch], fill=SPIDER_BELLY, width=2)
    d.line([cx + 14, fy - 4 + crouch, cx + 14 + jaw + 2, fy - 2 + jaw + crouch], fill=SPIDER_BELLY, width=2)
    # 독침 꼬리 (뒤에서 위로 말림)
    d.arc([cx - 18, fy - 20 + crouch, cx - 4, fy - 4 + crouch], 90, 250, fill=SPIDER, width=3)
    d.rectangle([cx - 18, fy - 14 + crouch, cx - 16, fy - 11 + crouch], fill=STING)
    # 눈
    d.point((cx + 10, fy - 7 + crouch), fill=SPIDER_EYE)
    d.point((cx + 12, fy - 6 + crouch), fill=SPIDER_EYE)
    # 명암: 등에 밝은 점, 배 쪽 어둡게
    dither_over(f, cx - 10, fy - 12 + crouch, cx + 8, fy - 8 + crouch, SPIDER_BELLY)
    dither_over(f, cx - 10, fy - 5, cx + 14, fy, SPIDER_SHADE)
    if pose.get("hurt"):
        dither_over(f, 0, 0, 48, 32, SPIDER_BELLY, phase=1)
    outline(f)
    return f


def make_spider():
    frames = [
        spider_frame({"legs": 0}),                       # 0 걷기A
        spider_frame({"legs": 1}),                       # 1 걷기B
        spider_frame({"jaw": 6, "crouch": 2}),           # 2 공격 (움츠려 턱 벌림)
        spider_frame({"hurt": True, "crouch": 1}),       # 3 피격
    ]
    save(sheet(frames, 48, 32), OUT, "spider.png")


def wolf_frame(pose):
    """늑대 인간 48x48. 곧추선 야수 — 굽은 등, 붉은 눈, 발톱."""
    f = blank(48, 48)
    d = ImageDraw.Draw(f)
    cx, fy = 22, 46
    lean = pose.get("lean", 0)          # 앞으로 기울기 (돌격)
    # 다리 (digitigrade — 무릎이 뒤로 꺾임)
    ph = pose.get("legs", 0)
    for dx in (-4 + ph, 3 - ph):
        d.line([cx + dx, fy - 14, cx + dx - 2, fy - 7], fill=WOLF, width=3)
        d.line([cx + dx - 2, fy - 7, cx + dx + 1, fy], fill=WOLF, width=3)
        d.rectangle([cx + dx - 1, fy - 2, cx + dx + 3, fy], fill=WOLF_SHADE)
    # 몸통 (굽은 등)
    d.ellipse([cx - 8 + lean, fy - 30, cx + 8 + lean, fy - 10], fill=WOLF)
    d.ellipse([cx - 4 + lean, fy - 26, cx + 7 + lean, fy - 14], fill=WOLF_BELLY)
    # 머리 (주둥이가 앞으로)
    hx = cx + 6 + lean * 2
    hy = fy - 34 + pose.get("headdown", 0)
    d.ellipse([hx - 5, hy, hx + 4, hy + 8], fill=WOLF)
    d.rectangle([hx + 3, hy + 3, hx + 9, hy + 6], fill=WOLF)          # 주둥이
    d.polygon([(hx - 4, hy + 1), (hx - 2, hy - 4), (hx, hy + 1)], fill=WOLF)   # 귀
    d.point((hx + 1, hy + 3), fill=WOLF_EYE)
    d.point((hx + 8, hy + 5), fill=INK)                                # 코
    # 팔 — attack이면 머리 위로 치켜든다
    if pose.get("raise"):
        d.line([cx + 5 + lean, fy - 26, cx + 12 + lean, fy - 38], fill=WOLF, width=3)
        for i in range(3):
            d.line([cx + 11 + lean + i * 2, fy - 38, cx + 13 + lean + i * 2, fy - 42], fill=CLAW, width=1)
    else:
        d.line([cx + 5 + lean, fy - 24, cx + 11 + lean * 2, fy - 16], fill=WOLF, width=3)
        for i in range(3):
            d.line([cx + 10 + lean * 2 + i, fy - 16, cx + 11 + lean * 2 + i, fy - 12], fill=CLAW, width=1)
    # 꼬리
    d.arc([cx - 18, fy - 22, cx - 4, fy - 8], 120, 260, fill=WOLF, width=3)
    # 명암
    dither_over(f, cx - 8 + lean, fy - 18, cx + 9 + lean, fy - 10, WOLF_SHADE)
    dither_over(f, cx - 8 + lean, fy - 30, cx + 2 + lean, fy - 24, WOLF_SHADE, phase=1)
    if pose.get("hurt"):
        dither_over(f, 0, 0, 48, 48, WOLF_BELLY, phase=1)
    outline(f)
    return f


def make_wolf():
    frames = [
        wolf_frame({"legs": 0}),                                  # 0 걷기A
        wolf_frame({"legs": 3}),                                  # 1 걷기B
        wolf_frame({"legs": 4, "lean": 4, "headdown": 4}),        # 2 돌격
        wolf_frame({"legs": 1, "raise": True}),                   # 3 내리찍기
        wolf_frame({"legs": 1, "lean": -2, "hurt": True}),        # 4 피격
    ]
    save(sheet(frames, 48, 48), OUT, "wolf.png")


def monkey_frame(pose):
    """가면 원숭이 짐도둑 48x48. 흰 가면, 등의 배낭."""
    f = blank(48, 48)
    d = ImageDraw.Draw(f)
    cx, fy = 24, 46
    # 다리 (달리기)
    ph = pose.get("legs", 0)
    for dx in (-3 + ph * 2, 2 - ph * 2):
        d.line([cx + dx, fy - 10, cx + dx + 1, fy], fill=MONKEY, width=3)
    # 배낭 (등 뒤 — 몸통보다 먼저 그린다)
    if pose.get("bag", True):
        d.rectangle([cx - 14, fy - 26, cx - 5, fy - 12], fill=BAG)
        d.line([cx - 13, fy - 22, cx - 6, fy - 22], fill=BAG_SHADE, width=1)
        dither_over(f, cx - 14, fy - 19, cx - 5, fy - 12, BAG_SHADE)
    # 몸통
    d.ellipse([cx - 7, fy - 24, cx + 6, fy - 8], fill=MONKEY)
    # 꼬리
    d.arc([cx - 16, fy - 18, cx - 2, fy - 4], 100, 250, fill=MONKEY, width=2)
    # 머리와 가면
    hy = fy - 32
    d.ellipse([cx - 5, hy, cx + 7, hy + 10], fill=MONKEY)
    d.ellipse([cx - 1, hy + 1, cx + 7, hy + 9], fill=MASK)          # 가면
    d.point((cx + 2, hy + 4), fill=INK)
    d.point((cx + 5, hy + 4), fill=INK)
    d.line([cx + 3, hy + 7, cx + 5, hy + 7], fill=SPIDER_EYE)       # 가면의 붉은 무늬
    # 팔 — 던지기면 앞으로 뻗고 돌을 쥔다
    if pose.get("throw"):
        d.line([cx + 3, fy - 20, cx + 13, fy - 26], fill=MONKEY, width=2)
        d.ellipse([cx + 12, fy - 30, cx + 17, fy - 25], fill=STONE)
    else:
        d.line([cx + 3, fy - 20, cx + 9, fy - 13], fill=MONKEY, width=2)
    # 명암
    dither_over(f, cx - 6, fy - 14, cx + 7, fy - 8, MONKEY_SHADE)
    if pose.get("hurt"):
        dither_over(f, 0, 0, 48, 48, MASK, phase=1)
    outline(f)
    return f


def make_monkey():
    frames = [
        monkey_frame({"legs": 0}),                    # 0 달리기A
        monkey_frame({"legs": 1}),                    # 1 달리기B
        monkey_frame({"legs": 0, "throw": True}),     # 2 던지기
        monkey_frame({"legs": 1, "hurt": True}),      # 3 피격
    ]
    save(sheet(frames, 48, 48), OUT, "monkey.png")


def make_stone():
    f = blank(8, 8)
    d = ImageDraw.Draw(f)
    d.ellipse([1, 1, 6, 6], fill=STONE)
    dither_over(f, 1, 4, 7, 7, STONE_SHADE)
    outline(f)
    save(f, OUT, "stone.png")


def make_bag():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.rectangle([2, 5, 13, 14], fill=BAG)
    d.rectangle([4, 2, 11, 5], fill=BAG_SHADE)       # 덮개
    d.line([2, 9, 13, 9], fill=BAG_SHADE)            # 끈
    dither_over(f, 2, 10, 14, 15, BAG_SHADE)
    outline(f)
    save(f, OUT, "bag.png")


def make_aura():
    """버서커의 붉은 기운 — 반투명이라 테두리를 두르지 않는다."""
    img = blank(96, 48)
    for i, phase in enumerate((0, 1)):
        f = blank(48, 48)
        d = ImageDraw.Draw(f)
        for r, a in ((20, 60), (16, 90), (13, 60)):
            d.ellipse([24 - r, 40 - 2 * r + phase * 2, 24 + r, 40 + 4], outline=STAR_RED + (a,), width=2)
        px = f.load()
        for y in range(48):
            for x in range(48):
                if (x + y + phase) % 2 == 0 and px[x, y][3] > 0:
                    px[x, y] = (0, 0, 0, 0)          # 기운 자체를 디더로 성기게
        img.paste(f, (i * 48, 0), f)
    save(img, OUT, "aura.png")


# ---- 타일셋 ---------------------------------------------------------------
# 8열. gid = 줄 * 8 + 칸 + 1 (firstGid 1).

def t_mud_top():
    f = Image.new("RGBA", (16, 16), MUD)
    d = ImageDraw.Draw(f)
    d.rectangle([0, 0, 15, 3], fill=MOSS)
    dither(d, 0, 3, 16, 5, MOSS)             # 이끼와 진흙의 디더 경계
    dither(d, 0, 5, 16, 7, MOSS_SHADE)
    dither(d, 0, 12, 16, 16, MUD_SHADE)
    return f


def t_mud_fill():
    f = Image.new("RGBA", (16, 16), MUD)
    d = ImageDraw.Draw(f)
    dither(d, 0, 0, 16, 16, MUD_SHADE, phase=1)
    d.point((4, 6), fill=MUD_SHADE)
    d.point((11, 12), fill=MOSS_SHADE)
    return f


def t_rock_top():
    f = Image.new("RGBA", (16, 16), ROCK)
    d = ImageDraw.Draw(f)
    d.rectangle([0, 0, 15, 1], fill=ROCK_LIGHT)
    dither(d, 0, 2, 16, 4, ROCK_LIGHT)
    dither(d, 0, 10, 16, 16, ROCK_SHADE)
    d.line([0, 15, 15, 15], fill=ROCK_SHADE)
    return f


def t_rock_fill():
    f = Image.new("RGBA", (16, 16), ROCK)
    d = ImageDraw.Draw(f)
    dither(d, 0, 0, 16, 16, ROCK_SHADE, phase=1)
    d.line([3, 5, 7, 5], fill=ROCK_SHADE)
    d.line([10, 11, 13, 11], fill=ROCK_SHADE)
    return f


def t_plank(broken=False):
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.rectangle([0, 6, 15, 11], fill=PLANK)
    d.line([0, 6, 15, 6], fill=ROPE)
    dither(d, 0, 9, 16, 12, PLANK_SHADE)
    for x in (3, 8, 13):
        d.point((x, 8), fill=PLANK_SHADE)
    if broken:
        d.rectangle([6, 6, 10, 11], fill=(0, 0, 0, 0))
        d.line([5, 6, 5, 11], fill=PLANK_SHADE)
        d.line([11, 6, 11, 11], fill=PLANK_SHADE)
    outline(f)
    return f


def t_rope_post():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.rectangle([6, 2, 9, 15], fill=PLANK)
    dither_over(f, 8, 2, 10, 16, PLANK_SHADE)
    d.line([0, 5, 15, 4], fill=ROPE)
    outline(f)
    return f


def t_sign():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.rectangle([7, 4, 9, 15], fill=SIGN)
    d.rectangle([2, 2, 14, 8], fill=SIGN)
    d.polygon([(14, 2), (15, 5), (14, 8)], fill=SIGN)
    d.line([4, 5, 11, 5], fill=INK)
    dither_over(f, 2, 6, 15, 9, BAG_SHADE)
    outline(f)
    return f


def t_trunk(thick=False):
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    if thick:
        d.rectangle([4, 0, 11, 15], fill=TREE)
        dither_over(f, 8, 0, 12, 16, TREE_SHADE)
        d.line([6, 2, 6, 13], fill=TREE_LIGHT)
    else:
        d.rectangle([6, 0, 10, 15], fill=TREE)
        dither_over(f, 8, 0, 11, 16, TREE_SHADE)
    outline(f)
    return f


def t_canopy():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.ellipse([0, 2, 15, 14], fill=TREE)
    d.ellipse([3, 0, 12, 9], fill=TREE)
    dither_over(f, 0, 8, 16, 15, TREE_SHADE)
    dither_over(f, 3, 1, 10, 5, TREE_LIGHT)
    outline(f)
    return f


def t_vine():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.arc([-6, -4, 10, 12], 270, 60, fill=VINE, width=2)
    d.arc([4, 2, 20, 18], 150, 290, fill=VINE, width=2)
    d.line([2, 12, 4, 15], fill=VINE)
    return f


def t_bamboo():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.line([3, 15, 6, 2], fill=BAMBOO, width=2)
    d.line([5, 2, 8, 0], fill=BAMBOO)                 # 부러진 끝
    d.line([10, 15, 11, 6], fill=BAMBOO, width=2)
    d.line([10, 6, 14, 4], fill=BAMBOO)
    d.point((4, 9), fill=MUD_SHADE)
    d.point((11, 11), fill=MUD_SHADE)
    return f


def t_shroom():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.rectangle([6, 9, 9, 15], fill=MASK)
    d.ellipse([3, 4, 12, 11], fill=SHROOM)
    d.point((6, 6), fill=MASK)
    d.point((9, 8), fill=MASK)
    dither_over(f, 3, 8, 13, 11, (120, 52, 48))
    outline(f)
    return f


def t_weed():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    for x, h in ((2, 5), (5, 8), (8, 4), (11, 7), (14, 5)):
        d.line([x, 15, x - 1, 15 - h], fill=WEED)
        d.line([x, 15, x + 1, 15 - h + 2], fill=MOSS)
    return f


def t_spire():
    """기암 — 뾰족한 바위."""
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.polygon([(2, 15), (7, 1), (13, 15)], fill=ROCK)
    dither_over(f, 7, 4, 14, 16, ROCK_SHADE)
    outline(f)
    return f


def t_statue(part):
    """부서진 레굴루스 석상 2x2. part = tl, tr, bl, br. 사자 머리 조각상의 잔해."""
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    if part == "tl":
        d.polygon([(4, 15), (6, 4), (15, 2), (15, 15)], fill=STATUE)
        d.arc([7, 4, 15, 12], 90, 270, fill=STATUE_SHADE, width=1)   # 갈기 무늬
        d.point((11, 7), fill=INK)                                    # 눈
    elif part == "tr":
        d.polygon([(0, 2), (9, 3), (11, 8), (7, 15), (0, 15)], fill=STATUE)
        d.line([2, 6, 5, 6], fill=STATUE_SHADE)
    elif part == "bl":
        d.rectangle([2, 0, 15, 15], fill=STATUE)
        d.line([2, 12, 15, 12], fill=STATUE_SHADE)                    # 받침
        d.line([5, 3, 5, 11], fill=STATUE_SHADE)                      # 금
    else:
        d.rectangle([0, 0, 12, 15], fill=STATUE)
        d.line([0, 12, 12, 12], fill=STATUE_SHADE)
        d.line([8, 0, 10, 8], fill=STATUE_SHADE)
    dither_over(f, 0, 9, 16, 16, STATUE_SHADE)
    outline(f)
    return f


def t_skull():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.ellipse([4, 7, 12, 14], fill=MASK)
    d.rectangle([5, 12, 11, 15], fill=MASK)
    d.point((6, 10), fill=INK)
    d.point((9, 10), fill=INK)
    dither_over(f, 4, 12, 13, 15, STONE_SHADE)
    outline(f)
    return f


def t_pebble():
    f = blank(16, 16)
    d = ImageDraw.Draw(f)
    d.ellipse([2, 10, 7, 15], fill=STONE)
    d.ellipse([9, 12, 13, 15], fill=STONE)
    dither_over(f, 2, 13, 14, 16, STONE_SHADE)
    outline(f)
    return f


def make_tileset():
    tiles = [
        # 줄 0 (gid 1~8): 땅과 다리
        t_mud_top(), t_mud_fill(), t_rock_top(), t_rock_fill(),
        t_plank(), t_plank(broken=True), t_rope_post(), t_sign(),
        # 줄 1 (gid 9~16): 나무와 풀
        t_trunk(), t_trunk(thick=True), t_canopy(), t_vine(),
        t_bamboo(), t_shroom(), t_weed(), t_spire(),
        # 줄 2 (gid 17~24): 석상과 잔해
        t_statue("tl"), t_statue("tr"), t_statue("bl"), t_statue("br"),
        t_skull(), t_pebble(), blank(16, 16), blank(16, 16),
    ]
    cols = 8
    rows = (len(tiles) + cols - 1) // cols
    img = blank(cols * 16, rows * 16)
    for i, t in enumerate(tiles):
        img.paste(t, ((i % cols) * 16, (i // cols) * 16), t)
    save(img, OUT, "forest16.png")


# ---- 원경과 타이틀 --------------------------------------------------------

def lerp(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def paint_forest(img, star_x, star_y, star_r, seed=7):
    """검은 안개의 숲 원경 — 그라데이션 하늘, 붉은 별, 나무 실루엣, 안개 디더."""
    w, h = img.size
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([0, y, w, y], fill=lerp(SKY_TOP_C, SKY_LOW_C, y / h))
    # 잔별 (결정적 의사 난수 — 실행마다 같은 그림)
    v = seed
    for i in range(60):
        v = (v * 1103515245 + 12345) % (2 ** 31)
        x, y = v % w, (v // w) % (h * 2 // 3)
        if (x - star_x) ** 2 + (y - star_y) ** 2 > (star_r * 4) ** 2:
            d.point((x, y), fill=STAR_DIM)
    # 알데바란 — 붉은 별과 디더 광륜
    for r, c in ((star_r * 3, lerp(SKY_TOP_C, STAR_RED, 0.25)),
                 (star_r * 2, lerp(SKY_TOP_C, STAR_RED, 0.5))):
        for yy in range(star_y - r, star_y + r):
            for xx in range(star_x - r, star_x + r):
                if 0 <= xx < w and 0 <= yy < h and (xx + yy) % 2 == 0 \
                        and (xx - star_x) ** 2 + (yy - star_y) ** 2 <= r * r:
                    d.point((xx, yy), fill=c)
    d.ellipse([star_x - star_r, star_y - star_r, star_x + star_r, star_y + star_r], fill=STAR_RED)
    d.line([star_x - star_r * 2, star_y, star_x + star_r * 2, star_y], fill=STAR_RED)
    d.line([star_x, star_y - star_r * 2, star_x, star_y + star_r * 2], fill=STAR_RED)
    # 나무 실루엣 두 겹
    v = seed * 3 + 1
    for layer, (color, top0, sway) in enumerate(
            (((30, 26, 42), int(h * 0.42), 5), ((20, 16, 30), int(h * 0.30), 8))):
        x = -10
        while x < w + 10:
            v = (v * 1103515245 + 12345) % (2 ** 31)
            tw = 6 + v % 8
            top = top0 + (v // 7) % 40
            d.rectangle([x, top, x + tw, h], fill=color)
            d.ellipse([x - tw, top - tw * 2, x + tw * 2, top + tw], fill=color)
            x += tw + 8 + v % 14
    # 검은 안개 (아래쪽 디더 띠 — 아래로 갈수록 짙어지되 단색이 되지는 않게)
    for band, alpha_step in ((int(h * 0.70), 4), (int(h * 0.80), 3), (int(h * 0.88), 2)):
        for y in range(band, h):
            for x in range(0, w):
                if (x + y) % alpha_step == 0:
                    d.point((x, y), fill=MIST)
    return img


def make_bg():
    img = Image.new("RGBA", (384, 448))
    paint_forest(img, 300, 64, 4)
    save(img.convert("RGB"), OUT, "forest_bg.png")


def find_ttf():
    for path in TTF_CANDIDATES:
        if os.path.exists(path):
            return path
    raise SystemExit("한글 TTF를 찾지 못했습니다 (NanumBarunGothicBold 등).")


def make_title():
    img = Image.new("RGBA", (768, 896))
    paint_forest(img, 600, 130, 8, seed=11)
    d = ImageDraw.Draw(img)
    ttf = find_ttf()
    big = ImageFont.truetype(ttf, 104)
    small = ImageFont.truetype(ttf, 30)
    # 글자 뒤에 붉은 글로우
    g = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.text((384, 250), "알데바란", font=big, fill=STAR_RED + (200,), anchor="mm")
    g = g.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(g)
    d.text((387, 253), "알데바란", font=big, fill=(40, 16, 20, 220), anchor="mm")
    d.text((384, 250), "알데바란", font=big, fill=(244, 234, 222, 255), anchor="mm")
    d.text((384, 340), "1-1 검은 안개의 숲", font=small,
           fill=(190, 178, 196, 255), anchor="mm")
    save(img.convert("RGB"), TITLES, "aldebaran_title.png")


# ---- HUD ------------------------------------------------------------------

def make_hud():
    """막대 채움 띠 3색 + 바탕 띠 + 별(목숨)과 동전 아이콘.

    막대는 hud.lua가 SetRect로 원하는 폭만큼 잘라 그린다 (창 스킨과 같은 방식).
    띠 좌표: hp (0,0,64,6), mp (0,8,64,6), exp (0,16,64,6), 바탕 (0,24,64,6)
    아이콘: 별 (66,0,10,10), 빈 별 (66,12,10,10), 동전 (66,24,10,10)
    """
    img = blank(80, 40)
    d = ImageDraw.Draw(img)
    for y0, (c, shade) in ((0, (HP_C, HP_D)), (8, (MP_C, MP_D)), (16, (XP_C, XP_D))):
        d.rectangle([0, y0, 63, y0 + 5], fill=c)
        d.line([0, y0, 63, y0], fill=lerp(c, (255, 255, 255), 0.4))
        dither(d, 0, y0 + 3, 64, y0 + 6, shade)
    d.rectangle([0, 24, 63, 29], fill=BAR_BG)
    star = [(5, 0), (6.5, 3.5), (10, 4), (7.5, 6.5), (8.5, 10), (5, 8), (1.5, 10),
            (2.5, 6.5), (0, 4), (3.5, 3.5)]
    d.polygon([(66 + x, y) for x, y in star], fill=STAR_GOLD)
    d.polygon([(66 + x, 12 + y) for x, y in star], outline=STONE_SHADE)
    d.ellipse([66, 24, 75, 33], fill=COIN_C)
    d.ellipse([68, 26, 73, 31], outline=BAG_SHADE)
    save(img, OUT, "hud.png")


# ---- 효과음 ---------------------------------------------------------------

RATE = 22050


def _write_wav(path, samples, volume):
    frames = bytearray()
    for s in samples:
        frames += struct.pack("<h", int(max(-1.0, min(1.0, s * volume)) * 32767))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print("만듦:", os.path.relpath(path, REPO))


def tone_sweep(f0, f1, dur, shape="sine"):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / RATE
        v = math.sin(phase)
        if shape == "square":
            v = 1.0 if v > 0 else -1.0
        env = min(1.0, i / (RATE * 0.004)) * (1.0 - t) ** 1.5
        out.append(v * env)
    return out


def noise_burst(dur, lp=0.3):
    n = int(RATE * dur)
    out, v, last = [], 12345, 0.0
    for i in range(n):
        v = (v * 1103515245 + 12345) % (2 ** 31)
        white = (v / 2 ** 30) - 1.0
        last = last + lp * (white - last)
        env = (1.0 - i / n) ** 2
        out.append(last * env)
    return out


def mix(*parts):
    out = []
    for p in parts:
        out += p
    return out


def make_sfx():
    _write_wav(os.path.join(AUDIO, "aldebaran_swing.wav"),
               noise_burst(0.09, lp=0.55), 0.30)                        # 휘두르기 (바람 소리)
    _write_wav(os.path.join(AUDIO, "aldebaran_jump.wav"),
               tone_sweep(300, 620, 0.10), 0.28)                        # 점프
    _write_wav(os.path.join(AUDIO, "aldebaran_hurt.wav"),
               mix(tone_sweep(220, 110, 0.16, "square")), 0.26)         # 피격
    _write_wav(os.path.join(AUDIO, "aldebaran_kill.wav"),
               mix(tone_sweep(520, 140, 0.22), noise_burst(0.08, 0.4)), 0.30)  # 소멸
    _write_wav(os.path.join(AUDIO, "aldebaran_level.wav"),
               mix(tone_sweep(440, 440, 0.07), tone_sweep(554, 554, 0.07),
                   tone_sweep(659, 659, 0.12)), 0.30)                   # 레벨 업
    _write_wav(os.path.join(AUDIO, "aldebaran_berserk.wav"),
               tone_sweep(140, 420, 0.30, "square"), 0.22)              # 버서커
    _write_wav(os.path.join(AUDIO, "aldebaran_pick.wav"),
               mix(tone_sweep(880, 880, 0.05), tone_sweep(1320, 1320, 0.09)), 0.26)  # 획득
    _write_wav(os.path.join(AUDIO, "aldebaran_throw.wav"),
               noise_burst(0.06, lp=0.7), 0.22)                         # 돌팔매


def main():
    make_karto()
    make_spider()
    make_wolf()
    make_monkey()
    make_stone()
    make_bag()
    make_aura()
    make_tileset()
    make_bg()
    make_title()
    make_hud()
    make_sfx()
    print("완료. 커밋 가능한 플레이스홀더 자산입니다 (RTP 불필요).")


if __name__ == "__main__":
    main()
