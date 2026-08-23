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
HAIR_LIGHT = (124, 86, 52)
RIM = (150, 170, 220)      # 역광 (숲의 푸른 밤빛)
PANTS = (84, 76, 96)
PANTS_SHADE = (60, 54, 72)
BOOT = (110, 74, 44)
BOOT_SHADE = (78, 52, 32)
SKIN_SHADE = (196, 154, 118)
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
BAG = (146, 138, 106)           # 배낭 (거친 천. 원숭이 털과 색이 겹치지 않게)
BAG_SHADE = (104, 98, 74)
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


# 순서 있는 디더 (Bayer 4x4). 문턱값이 0..15 로 흩어져 있어, 밀도 t 를 0에서 1로
# 옮기면 두 색이 **점점 엇갈리며** 섞인다. 면 전체를 50% 체커로 덮는 것과 다르다.
BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def bayer(x, y):
    """(x, y) 자리의 문턱값 (0.0 ~ 1.0)."""
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def dither(d, x0, y0, x1, y1, color, phase=0):
    """체커보드 디더. 무늬가 필요한 자리(작은 소품)에만 쓴다."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x + y + phase) % 2 == 0:
                d.point((x, y), color)


def shade_band(img, color, x0, y0, x1, y1, axis="y", invert=False, gamma=1.0):
    """그늘(또는 빛)을 **밀도가 변하는 띠**로 얹는다.

    띠의 시작에서는 한 픽셀도 찍지 않고, 끝으로 갈수록 촘촘해진다. 이미 칠해진
    픽셀 위에만 얹으므로 실루엣 밖으로 새지 않는다.

    axis  "y" 면 위에서 아래로, "x" 면 왼쪽에서 오른쪽으로 짙어진다.
    invert 반대 방향으로 짙어지게 한다.
    gamma  1보다 크면 늦게 짙어진다 (띠가 얇게 느껴진다).
    """
    px = img.load()
    x0, y0 = max(0, int(x0)), max(0, int(y0))
    x1, y1 = min(img.width, int(x1)), min(img.height, int(y1))
    span = (y1 - y0) if axis == "y" else (x1 - x0)
    if span <= 0:
        return
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[x, y][3] <= 40:
                continue
            pos = (y - y0) if axis == "y" else (x - x0)
            t = pos / (span - 1) if span > 1 else 1.0
            if invert:
                t = 1.0 - t
            t = t ** gamma
            # 디더가 눈에 띄는 것은 밀도가 0.5 언저리일 때다. 그 구간을 띠의
            # 가운데 절반으로 좁히고, 바깥은 아예 비우고 안쪽은 꽉 채운다.
            t = (t - 0.25) / 0.5
            if t <= 0:
                continue
            if t >= 1 or t > bayer(x, y):
                px[x, y] = color + (255,)


def tint(img, color, amount=0.5, box=None):
    """영역을 한 색 쪽으로 섞는다 (피격 번쩍임처럼 무늬가 아니라 색이 변해야 하는 곳)."""
    px = img.load()
    x0, y0, x1, y1 = box or (0, 0, img.width, img.height)
    for y in range(max(0, y0), min(img.height, y1)):
        for x in range(max(0, x0), min(img.width, x1)):
            r, g, b, a = px[x, y]
            if a <= 40:
                continue
            px[x, y] = (
                int(r + (color[0] - r) * amount),
                int(g + (color[1] - g) * amount),
                int(b + (color[2] - b) * amount),
                255,
            )


def dither_over(img, x0, y0, x1, y1, color, phase=0):
    """예전 방식(면 전체 50% 체커). 남은 호출부가 없어질 때까지만 둔다."""
    px = img.load()
    for y in range(max(0, int(y0)), min(img.height, int(y1))):
        for x in range(max(0, int(x0)), min(img.width, int(x1))):
            if (x + y + phase) % 2 == 0 and px[x, y][3] > 40:
                px[x, y] = color + (255,)


def rect(d, x0, y0, x1, y1, fill):
    """자세 파라미터에 따라 좌표가 뒤집혀도 그려지는 사각형."""
    d.rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], fill=fill)


def darker(color, k=0.45):
    return tuple(max(0, int(c * k)) for c in color)


def outline(img, thresh=40, ink=None):
    """실루엣 가장자리를 두른다 (지침 3번: 테두리가 명확할 것).

    잉크 한 색으로 두르면 스티커처럼 보이므로, 기본은 **그 자리 색을 어둡게 한 것**을
    쓴다. ink 를 주면 예전처럼 단색으로 두른다.
    """
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
        if ink is not None:
            px[x, y] = ink + (255,)
        else:
            r, g, b, _ = px[x, y]
            px[x, y] = darker((r, g, b)) + (255,)


def rim_light(img, color, thresh=40, side=0.55):
    """실루엣의 **바깥 오른쪽** 가장자리에만 1px 역광을 넣는다.

    어두운 숲에서 인물이 배경에 묻히지 않게 하는 장치다. 안쪽 가장자리(다리
    사이 같은 곳)까지 넣으면 전부 파랗게 테두리가 지므로, 채워진 영역의
    오른쪽 side 비율 안에 드는 픽셀만 고른다.
    """
    px = img.load()
    w, h = img.size
    xs = [x for y in range(h) for x in range(w) if px[x, y][3] > thresh]
    if not xs:
        return
    x0, x1 = min(xs), max(xs)
    limit = x0 + (x1 - x0) * side
    hits = []
    for y in range(1, h):
        for x in range(w - 1):
            if x < limit:
                continue
            if px[x, y][3] > thresh and px[x + 1, y][3] <= thresh:
                if px[x, y - 1][3] > thresh:
                    hits.append((x, y))
    for x, y in hits:
        r, g, b, _ = px[x, y]
        px[x, y] = (
            min(255, int(r + (color[0] - r) * 0.45)),
            min(255, int(g + (color[1] - g) * 0.45)),
            min(255, int(b + (color[2] - b) * 0.45)),
            255,
        )


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
# 프레임 48x48, 발 기준선 y=46, 몸 중심 x=24. 오른쪽 보기 (왼쪽은 시트가 미러링).
#
# 사각형을 쌓지 않고 **실루엣 다각형**으로 그린다. 어깨는 머리보다 넓고, 외투는
# 허리에서 좁아졌다가 자락에서 퍼지며, 부츠는 발목보다 넓다. 그래야 형태만으로
# 무엇을 입은 사람인지 읽힌다 (docs/plans/aldebaran-4-pixelart.md 4절).
#
# 칸: 0 서기A, 1 서기B, 2~5 걷기, 6 점프, 7 낙하, 8 베기1, 9 베기2, 10 베기3, 11 피격

FOOT_Y = 46          # 발 기준선
HEAD_TOP = 8         # 머리 꼭대기 (bob=0일 때)


def limb(d, p0, p1, w0, w1, color):
    """(x0,y0)에서 (x1,y1)로 가는, 굵기가 변하는 팔다리 하나."""
    (x0, y0), (x1, y1) = p0, p1
    d.polygon([(x0 - w0 / 2, y0), (x0 + w0 / 2, y0),
               (x1 + w1 / 2, y1), (x1 - w1 / 2, y1)], fill=color)


def karto_frame(pose):
    f = blank(48, 48)
    d = ImageDraw.Draw(f)
    cx, fy = 24, FOOT_Y
    bob = pose.get("bob", 0)          # 몸 전체의 상하 (걸음의 흔들림, 점프)
    lean = pose.get("lean", 0)        # 앞으로 기울기 (베기, 돌진)

    tx = cx + lean                    # 몸통 중심
    hip_y = fy - 14 + bob
    waist_y = fy - 20 + bob
    sh_y = fy - 27 + bob              # 어깨
    head_b = fy - 29 + bob
    head_t = fy - 38 + bob
    hx = tx + pose.get("head", 1)     # 머리는 진행 방향으로 조금 나간다

    # --- 다리와 부츠 (몸통보다 먼저: 외투 자락이 위를 덮는다) ---------------
    # leg = (발 dx, 들어올림). 뒷다리는 그늘색으로 칠해 앞뒤가 구분되게 한다.
    for leg, shade in ((pose.get("back_leg", (-2, 0)), True),
                       (pose.get("front_leg", (2, 0)), False)):
        dx, lift = leg
        pants = PANTS_SHADE if shade else PANTS
        boot = BOOT_SHADE if shade else BOOT
        knee = (tx + dx * 0.4, hip_y + 6 - lift * 0.6)
        ankle = (tx + dx, fy - 4 - lift)
        limb(d, (tx + dx * 0.2, hip_y - 1), knee, 5, 4, pants)
        limb(d, knee, ankle, 4, 4, pants)
        # 부츠: 발목보다 넓고 앞쪽으로 코가 나온다
        by = fy - lift
        d.polygon([(ankle[0] - 2.5, ankle[1]), (ankle[0] + 2.5, ankle[1]),
                   (ankle[0] + 4, by), (ankle[0] - 3, by)], fill=boot)

    # --- 뒷팔 (몸통 뒤) ------------------------------------------------------
    bax, bay = pose.get("backarm", (-5, -16))
    limb(d, (tx - 4, sh_y + 2), (tx + bax, fy + bay + bob), 4, 3, COAT_SHADE)

    # --- 몸통: 어깨에서 허리로 좁아졌다 자락에서 퍼지는 외투 ----------------
    d.polygon([
        (tx - 7, sh_y), (tx + 7, sh_y),              # 어깨 (머리보다 넓다)
        (tx + 5, waist_y), (tx + 6, hip_y + 1),      # 허리 → 자락 (앞)
        (tx - 6, hip_y + 1), (tx - 5, waist_y),      # 자락 → 허리 (뒤)
    ], fill=COAT)

    # --- 목과 머리 ----------------------------------------------------------
    d.rectangle([tx - 2, sh_y - 2, tx + 2, sh_y], fill=SKIN_SHADE)   # 목 (2px)
    d.ellipse([hx - 4, head_t, hx + 4, head_b], fill=SKIN)
    # 머리칼이 정수리와 뒤통수와 옆을 덮고, 앞쪽에 얼굴 만큼만 남긴다
    d.chord([hx - 4, head_t, hx + 4, head_b], 140, 375, fill=HAIR)
    d.rectangle([hx - 4, head_t + 3, hx - 1, head_t + 8], fill=HAIR)  # 뒷머리
    d.polygon([(hx - 1, head_t + 2), (hx + 4, head_t + 3),
               (hx + 4, head_t + 4), (hx - 1, head_t + 4)], fill=HAIR)  # 앞머리
    if pose.get("hurt"):
        d.line([hx + 1, head_t + 6, hx + 3, head_t + 6], fill=INK)   # 감은 눈
    else:
        d.rectangle([hx + 2, head_t + 5, hx + 2, head_t + 6], fill=INK)   # 눈
    d.point((hx + 3, head_b - 1), fill=SKIN_SHADE)                   # 턱 그늘

    # 목도리: 외투의 목선 위에 얹고 뒤로 한 자락 날린다
    d.rectangle([tx - 5, sh_y, tx + 5, sh_y + 1], fill=SCARF)
    d.polygon([(tx - 4, sh_y), (tx - 8 - lean, sh_y + 3),
               (tx - 7 - lean, sh_y + 5), (tx - 3, sh_y + 2)], fill=SCARF)

    # --- 앞팔과 단검 --------------------------------------------------------
    # arm = (손 dx, 손 dy). 팔꿈치는 어깨와 손의 가운데에서 조금 바깥으로 나간다.
    ax, ay = pose.get("arm", (6, -14))
    hand = (tx + ax, fy + ay + bob)
    elbow = ((tx + 4 + hand[0]) / 2 + 1, (sh_y + 3 + hand[1]) / 2)
    limb(d, (tx + 4, sh_y + 3), elbow, 5, 4, COAT)
    limb(d, elbow, hand, 4, 3, COAT)
    d.ellipse([hand[0] - 1.5, hand[1] - 1.5, hand[0] + 1.5, hand[1] + 1.5], fill=SKIN)

    dg = pose.get("dagger")
    if dg:
        dgx, dgy, ln, vert = dg
        if vert:
            d.polygon([(hand[0] + dgx - 1, hand[1] + dgy),
                       (hand[0] + dgx + 1, hand[1] + dgy),
                       (hand[0] + dgx, hand[1] + dgy + ln)], fill=BLADE)
        else:
            d.polygon([(hand[0] + dgx, hand[1] + dgy - 1),
                       (hand[0] + dgx + ln, hand[1] + dgy),
                       (hand[0] + dgx, hand[1] + dgy + 1)], fill=BLADE)

    # --- 명암: 광원은 왼쪽 위. 오른쪽 아래로 갈수록 그늘이 촘촘해진다 -------
    shade_band(f, COAT_SHADE, tx - 2, sh_y + 3, tx + 8, hip_y + 2, axis="x", gamma=1.4)
    shade_band(f, COAT_SHADE, tx - 7, waist_y, tx + 8, hip_y + 2, axis="y", gamma=1.6)
    shade_band(f, PANTS_SHADE, tx - 6, hip_y + 2, tx + 7, fy, axis="y", gamma=1.5)
    shade_band(f, HAIR_LIGHT, hx - 4, head_t, hx + 5, head_t + 4, axis="y",
               invert=True, gamma=1.2)
    if pose.get("hurt"):
        tint(f, SKIN, 0.35)

    outline(f)
    rim_light(f, RIM)

    # 검기 (테두리 뒤에 얹는다. 빛이라 테두리가 없다)
    for arc in pose.get("slash", []):
        x0, y0, x1, y1, start, end = arc
        ImageDraw.Draw(f).arc([x0, y0 + bob, x1, y1 + bob], start, end, fill=GLOW, width=2)
    return f


# 걷기 4프레임: 접지 → 최저점 → 반대 접지 → 최저점. 몸이 1px 위아래로 흔들리고
# 팔은 다리와 반대로 흔들린다. (다리 = (발 dx, 들어올림))
WALK = [
    {"front_leg": (4, 0), "back_leg": (-4, 0), "bob": 0, "arm": (4, -15), "backarm": (-6, -15)},
    {"front_leg": (2, 0), "back_leg": (-1, 3), "bob": 1, "arm": (6, -14), "backarm": (-4, -16)},
    {"front_leg": (-4, 0), "back_leg": (4, 0), "bob": 0, "arm": (7, -14), "backarm": (-3, -16)},
    {"front_leg": (-1, 3), "back_leg": (2, 0), "bob": 1, "arm": (5, -15), "backarm": (-5, -15)},
]


def make_karto():
    frames = [
        karto_frame({}),                                                    # 0 서기A
        karto_frame({"bob": 1, "arm": (6, -13)}),                           # 1 서기B (숨)
    ]
    frames += [karto_frame(p) for p in WALK]                                # 2~5 걷기
    frames += [
        karto_frame({"front_leg": (3, 4), "back_leg": (-3, 1), "bob": -2,   # 6 점프
                     "arm": (7, -20), "backarm": (-6, -20)}),
        karto_frame({"front_leg": (2, 1), "back_leg": (-3, 0), "bob": 1,    # 7 낙하
                     "arm": (7, -22), "backarm": (-6, -21)}),
        karto_frame({"front_leg": (4, 0), "back_leg": (-4, 0), "lean": 2,   # 8 베기1
                     "arm": (11, -16), "dagger": (1, -1, 8, False),
                     "slash": [(28, 20, 44, 40, 300, 60)]}),
        karto_frame({"front_leg": (4, 0), "back_leg": (-4, 0), "lean": 2,   # 9 베기2
                     "arm": (11, -12), "dagger": (1, 0, 8, False),
                     "slash": [(28, 18, 44, 38, 120, 210)]}),
        karto_frame({"front_leg": (5, 0), "back_leg": (-5, 0), "lean": 3,   # 10 베기3
                     "arm": (12, -14), "dagger": (1, -1, 9, False),
                     "slash": [(26, 16, 46, 40, 300, 60), (26, 16, 46, 40, 120, 210)]}),
        karto_frame({"front_leg": (3, 0), "back_leg": (-3, 0), "lean": -3,  # 11 피격
                     "head": -1, "hurt": True, "arm": (5, -21),
                     "backarm": (-7, -20)}),
    ]
    save(sheet(frames, 48, 48), OUT, "karto.png")


# ---- 몬스터 ---------------------------------------------------------------
# 셋은 실루엣만으로 구분되어야 한다 (docs/plans/aldebaran-4-pixelart.md 4.3절).
#   전갈거미  낮고 넓다. 마디가 셋이고 다리가 꺾여 있으며 꼬리가 위로 말린다.
#   늑대 인간 곧추서서 굽은 등. 어깨의 갈기가 실루엣을 키운다.
#   가면 원숭이 작고 둥글다. 흰 가면이 먼저 보이고 등에 배낭이 있다.


def spider_frame(pose):
    """밀림 전갈거미 48x32. 발 기준선 y=30, 몸 중심 x=22. 오른쪽 보기."""
    f = blank(48, 32)
    d = ImageDraw.Draw(f)
    cx, fy = 22, 30
    crouch = pose.get("crouch", 0)      # 움츠림 (공격 선딜레이)
    by = fy - 8 + crouch                # 몸통 중심선

    # --- 다리 여덟: 무릎이 몸보다 높이 솟았다가 발끝이 땅으로 내려온다 -------
    ph = pose.get("legs", 0)
    for i in range(4):
        base = cx - 6 + i * 4
        up = 8 if (i + ph) % 2 == 0 else 10     # 무릎이 몸통 위로 솟는다 (걸음 위상)
        for side, spread in ((1, 5), (-1, 3)):  # 앞다리 쪽이 더 멀리 짚는다
            knee = (base + side * 4, by - up)
            foot = (base + side * (spread + 6), fy)
            d.line([base, by - 1, knee[0], knee[1]], fill=SPIDER, width=2)
            d.line([knee[0], knee[1], foot[0], foot[1]], fill=SPIDER, width=1)

    # --- 꼬리: 마디 셋이 뒤에서 위로 말리고 끝에 독침 ----------------------
    tail = [(cx - 10, by - 1), (cx - 14, by - 4), (cx - 16, by - 9), (cx - 15, by - 13)]
    for i, (px, py) in enumerate(tail):
        r = 3 - i * 0.5
        d.ellipse([px - r, py - r, px + r, py + r], fill=SPIDER_SHADE if i else SPIDER)
    d.polygon([(tail[-1][0] - 1, tail[-1][1] - 1), (tail[-1][0] + 2, tail[-1][1] - 2),
               (tail[-1][0] + 1, tail[-1][1] + 2)], fill=STING)

    # --- 몸통 마디 셋: 배, 가슴, 머리 ---------------------------------------
    d.ellipse([cx - 11, by - 5, cx - 1, by + 4], fill=SPIDER)          # 배
    d.ellipse([cx - 3, by - 4, cx + 7, by + 4], fill=SPIDER)           # 가슴
    d.ellipse([cx + 5, by - 3, cx + 13, by + 3], fill=SPIDER)          # 머리
    d.line([cx - 2, by - 4, cx - 2, by + 3], fill=SPIDER_SHADE)        # 마디 경계
    d.line([cx + 5, by - 3, cx + 5, by + 2], fill=SPIDER_SHADE)
    d.point((cx - 7, by - 3), fill=SPIDER_BELLY)                       # 등의 무늬
    d.point((cx - 5, by - 1), fill=SPIDER_BELLY)

    # --- 큰 턱: 공격 프레임에서 벌어진다 ------------------------------------
    jaw = pose.get("jaw", 2)
    for sgn in (-1, 1):
        tip = (cx + 15 + jaw, by + sgn * (2 + jaw))
        d.polygon([(cx + 11, by + sgn), (cx + 13, by + sgn * 3),
                   (tip[0], tip[1]), (tip[0], tip[1] - sgn * 2)], fill=SPIDER_BELLY)
    d.point((cx + 9, by - 1), fill=SPIDER_EYE)
    d.point((cx + 11, by), fill=SPIDER_EYE)

    shade_band(f, SPIDER_SHADE, cx - 12, by - 1, cx + 14, by + 5, axis="y", gamma=1.4)
    shade_band(f, SPIDER_BELLY, cx - 11, by - 6, cx + 12, by - 4, axis="y",
               invert=True, gamma=1.1)
    if pose.get("hurt"):
        tint(f, SPIDER_BELLY, 0.45)
    outline(f)
    rim_light(f, RIM, side=0.82)     # 다리마다 걸리지 않게 앞쪽 끝에만
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
    """늑대 인간 48x48. 발 기준선 y=46, 몸 중심 x=22. 곧추선 야수."""
    f = blank(48, 48)
    d = ImageDraw.Draw(f)
    cx, fy = 22, 46
    lean = pose.get("lean", 0)          # 앞으로 기울기 (돌격)
    ph = pose.get("legs", 0)

    hip_y = fy - 20
    sh_y = fy - 34 + pose.get("crouch", 0)

    # --- 뒷다리 둘: 무릎이 앞, 뒤꿈치가 뒤로 꺾이는 야수의 다리 -------------
    for dx, shade in ((-4 + ph, True), (3 - ph, False)):
        col = WOLF_SHADE if shade else WOLF
        knee = (cx + dx + 3, hip_y + 7)
        hock = (cx + dx - 2, hip_y + 15)
        limb(d, (cx + dx, hip_y), knee, 7, 5, col)
        limb(d, knee, hock, 5, 4, col)
        d.polygon([(hock[0] - 2, hock[1]), (hock[0] + 2, hock[1]),
                   (hock[0] + 5, fy), (hock[0] - 2, fy)], fill=WOLF_SHADE)

    # --- 꼬리 ---------------------------------------------------------------
    d.line([cx - 7, hip_y - 2, cx - 13, hip_y - 8], fill=WOLF, width=3)
    d.line([cx - 13, hip_y - 8, cx - 15, hip_y - 15], fill=WOLF_SHADE, width=2)

    # --- 몸통: 엉덩이에서 어깨로 굽어 오르는 등 -----------------------------
    d.polygon([
        (cx - 7, hip_y + 2), (cx + 6, hip_y + 1),            # 엉덩이
        (cx + 8 + lean, sh_y + 8), (cx + 7 + lean, sh_y + 1),  # 가슴
        (cx - 4 + lean, sh_y - 1), (cx - 8, hip_y - 6),        # 굽은 등
    ], fill=WOLF)
    d.ellipse([cx - 2 + lean, sh_y + 4, cx + 8 + lean, hip_y + 2], fill=WOLF_BELLY)

    # --- 갈기: 어깨를 키워 실루엣을 늑대로 만든다 ---------------------------
    for i in range(5):
        x = cx - 5 + i * 3 + lean
        d.polygon([(x, sh_y + 1), (x + 3, sh_y + 3), (x - 1, sh_y + 7)], fill=WOLF_SHADE)

    # --- 머리: 주둥이가 앞으로, 귀가 뒤로 ------------------------------------
    hx = cx + 6 + lean * 2
    hy = sh_y - 6 + pose.get("headdown", 0)
    d.ellipse([hx - 5, hy, hx + 4, hy + 8], fill=WOLF)
    d.polygon([(hx + 2, hy + 2), (hx + 11, hy + 4), (hx + 11, hy + 7),
               (hx + 2, hy + 7)], fill=WOLF)                     # 주둥이
    d.polygon([(hx - 4, hy + 1), (hx - 2, hy - 5), (hx + 1, hy + 1)], fill=WOLF)  # 귀
    d.polygon([(hx - 1, hy), (hx + 1, hy - 4), (hx + 3, hy + 1)], fill=WOLF_SHADE)
    d.point((hx + 2, hy + 3), fill=WOLF_EYE)
    d.rectangle([hx + 10, hy + 4, hx + 11, hy + 5], fill=INK)     # 코
    if pose.get("raise"):                                          # 이빨 (공격)
        for i in range(3):
            d.point((hx + 5 + i * 2, hy + 7), fill=CLAW)

    # --- 팔: 내리찍기면 머리 위로, 아니면 앞으로 ----------------------------
    if pose.get("raise"):
        wrist = (cx + 12 + lean, sh_y - 8)
        limb(d, (cx + 5 + lean, sh_y + 4), wrist, 6, 4, WOLF)
        for i in range(3):
            d.line([wrist[0] + i * 2 - 1, wrist[1], wrist[0] + i * 2, wrist[1] - 4], fill=CLAW)
    else:
        wrist = (cx + 10 + lean * 2, sh_y + 14)
        limb(d, (cx + 5 + lean, sh_y + 5), wrist, 6, 4, WOLF)
        for i in range(3):
            d.line([wrist[0] + i - 1, wrist[1], wrist[0] + i + 1, wrist[1] + 3], fill=CLAW)

    shade_band(f, WOLF_SHADE, cx - 9, hip_y - 6, cx + 10 + lean, hip_y + 4,
               axis="y", gamma=1.4)
    shade_band(f, WOLF_BELLY, cx - 6, sh_y - 2, cx + 10 + lean, sh_y + 6,
               axis="y", invert=True, gamma=1.5)
    if pose.get("hurt"):
        tint(f, WOLF_BELLY, 0.45)
    outline(f)
    rim_light(f, RIM)
    return f


def make_wolf():
    frames = [
        wolf_frame({"legs": 0}),                                  # 0 걷기A
        wolf_frame({"legs": 3}),                                  # 1 걷기B
        wolf_frame({"legs": 4, "lean": 3, "headdown": 2, "crouch": 1}),  # 2 돌격
        wolf_frame({"legs": 1, "raise": True}),                   # 3 내리찍기
        wolf_frame({"legs": 1, "lean": -2, "hurt": True}),        # 4 피격
    ]
    save(sheet(frames, 48, 48), OUT, "wolf.png")


def monkey_frame(pose):
    """가면 원숭이 짐도둑 48x48. 발 기준선 y=46, 몸 중심 x=24."""
    f = blank(48, 48)
    d = ImageDraw.Draw(f)
    cx, fy = 24, 46
    ph = pose.get("legs", 0)
    hip_y = fy - 12
    sh_y = fy - 24

    # --- 다리 (짧고 굽었다) --------------------------------------------------
    for dx, shade in ((-3 + ph * 2, True), (2 - ph * 2, False)):
        col = MONKEY_SHADE if shade else MONKEY
        knee = (cx + dx + 1, hip_y + 5)
        limb(d, (cx + dx, hip_y), knee, 5, 4, col)
        limb(d, knee, (cx + dx - 1, fy - 1), 4, 3, col)
        d.polygon([(cx + dx - 3, fy - 2), (cx + dx + 3, fy - 2),
                   (cx + dx + 3, fy), (cx + dx - 4, fy)], fill=col)

    # --- 배낭 (등 뒤: 몸통보다 먼저 그린다) ---------------------------------
    if pose.get("bag", True):
        d.polygon([(cx - 14, sh_y + 3), (cx - 5, sh_y + 1),
                   (cx - 4, hip_y - 1), (cx - 13, hip_y + 1)], fill=BAG)
        d.line([cx - 13, sh_y + 8, cx - 5, sh_y + 7], fill=BAG_SHADE)
        shade_band(f, BAG_SHADE, cx - 14, sh_y + 8, cx - 4, hip_y + 1, axis="y", gamma=1.3)

    # --- 몸통 ---------------------------------------------------------------
    d.ellipse([cx - 7, sh_y + 2, cx + 6, hip_y + 2], fill=MONKEY)
    d.ellipse([cx - 3, sh_y + 6, cx + 5, hip_y], fill=MONKEY_SHADE)
    # 배낭 끈이 어깨를 지나간다
    if pose.get("bag", True):
        d.line([cx - 5, sh_y + 3, cx + 2, sh_y + 5], fill=BAG_SHADE, width=1)

    # --- 꼬리 (길게 말린다) --------------------------------------------------
    d.arc([cx - 18, hip_y - 8, cx - 2, hip_y + 6], 100, 250, fill=MONKEY, width=2)
    d.arc([cx - 20, hip_y - 14, cx - 10, hip_y - 4], 60, 220, fill=MONKEY_SHADE, width=2)

    # --- 머리: 가면이 얼굴보다 커서 먼저 보인다 -----------------------------
    hy = fy - 34
    d.ellipse([cx - 6, hy, cx + 6, hy + 11], fill=MONKEY)        # 머리통
    d.polygon([(cx - 6, hy + 2), (cx - 4, hy - 2), (cx - 2, hy + 2)], fill=MONKEY_SHADE)  # 귀
    d.polygon([(cx + 3, hy + 1), (cx + 6, hy - 2), (cx + 7, hy + 3)], fill=MONKEY_SHADE)
    d.ellipse([cx - 2, hy + 1, cx + 8, hy + 10], fill=MASK)      # 흰 가면
    d.point((cx + 1, hy + 4), fill=INK)
    d.point((cx + 5, hy + 4), fill=INK)
    d.line([cx + 1, hy + 2, cx + 7, hy + 3], fill=SPIDER_EYE)    # 이마를 가로지르는 표식
    d.line([cx + 2, hy + 8, cx + 5, hy + 8], fill=MONKEY_SHADE)  # 가면의 입 자국

    # --- 팔: 던지기면 돌을 쥐고 뒤로 젖힌다 ---------------------------------
    if pose.get("throw"):
        wrist = (cx + 12, sh_y - 4)
        limb(d, (cx + 3, sh_y + 5), wrist, 5, 3, MONKEY)
        d.ellipse([wrist[0] - 1, wrist[1] - 4, wrist[0] + 4, wrist[1] + 1], fill=STONE)
    else:
        limb(d, (cx + 3, sh_y + 5), (cx + 9, hip_y - 1), 5, 3, MONKEY)

    shade_band(f, MONKEY_SHADE, cx - 8, sh_y + 6, cx + 7, fy, axis="y", gamma=1.5)
    if pose.get("hurt"):
        tint(f, MASK, 0.45)
    outline(f)
    rim_light(f, RIM)
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
