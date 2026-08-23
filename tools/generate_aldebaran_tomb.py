#!/usr/bin/env python3
"""알데바란 스테이지 1-2 「황제의 무덤」 자산 생성기
(docs/plans/aldebaran-7-tomb.md 7절 4항).

숲의 자산은 tools/generate_aldebaran_assets.py에 있다. 무덤은 안이고 하늘이
없고 색이 다르므로 파일을 나눴다. 도우미와 팔레트는 숲 쪽에서 가져다 쓴다 —
도트 지침(단색 실루엣 → 디더 명암 띠 → 테두리 → 역광)은 같아야 하기 때문이다.

원안 4.2.2절이 준 것:
  - 석회암 바위산을 깎아 만들었다. 벽돌을 쌓은 것이 아니다 (표 19).
  - 스핑크스 상을 닮았고 가슴부로 들어간다 (표 17).
  - 방 다섯과 복도 셋. 아포피스가 방마다 기후를 좌우한다 (표 19).
  - 별들의 방 벽면에 글귀가 새겨져 있다 (표 16).
  - 안개는 없다 (표 19). 숲의 안개 입자를 여기서는 쓰지 않는다.

Usage: python3 tools/generate_aldebaran_tomb.py
"""

import os

from PIL import Image, ImageDraw

from generate_aldebaran_assets import (
    RIM, blank, dither, lerp, outline, rim_light, save,
    shade_band, sheet, tint, OUT,
)

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---- 팔레트 ---------------------------------------------------------------
# 무덤은 석회암과 금이다. 숲의 보라색 밤빛과 섞이지 않게 따뜻한 쪽으로 민다.

LIME = (166, 156, 130)          # 석회암 (표 19: 벽돌이 아니라 깎아 만든 암반)
LIME_SHADE = (118, 110, 92)
LIME_LIGHT = (200, 190, 162)
LIME_DEEP = (78, 72, 62)        # 벽 안쪽 어둠

SAND = (176, 152, 104)          # 바닥에 쌓인 모래
SAND_SHADE = (128, 108, 72)

GOLD = (214, 176, 84)           # 금박 띠와 상형 문자
GOLD_SHADE = (150, 118, 48)
GOLD_LIGHT = (244, 220, 140)

WATER = (72, 118, 128)          # 홍수 (태양의 방)
WATER_LIGHT = (118, 172, 176)

EMBER = (232, 116, 58)          # 파괴의 방의 불씨
EMBER_HOT = (252, 214, 132)

SOUL = (146, 198, 220)          # 순장된 영혼 (차가운 영혼빛)
SOUL_CORE = (226, 246, 252)
SOUL_SHADE = (92, 138, 174)

SENT = (152, 144, 122)          # 무덤 번병 (석회암 갑주)
SENT_SHADE = (104, 98, 82)
# 방패는 청동이다. 두건과 같은 금색으로 두면 머리가 방패에 먹혀 실루엣이
# 통짜 사각형이 된다 (2배 배율에서 확인).
SHIELD = (146, 112, 62)         # 청동 방패
SHIELD_SHADE = (96, 72, 40)

SHARD = (96, 86, 96)            # 파괴의 조각 (검은 돌)
SHARD_SHADE = (62, 56, 66)

BONE = (206, 198, 176)

# 방마다 다른 빛. 배경과 타일의 색조가 여기서 갈린다.
ROOM_LIGHT = {
    "chest": (92, 84, 70),      # 입구: 등 뒤에서 들어오는 낮빛
    "moon": (86, 108, 140),     # 달의 방: 차고 푸르다 (눈)
    "stars": (74, 76, 118),     # 별들의 방: 어둡고 금빛 별이 박혀 있다
    "ruin": (118, 72, 56),      # 파괴의 방: 불씨와 우박
    "sun": (146, 116, 62),      # 태양의 방: 금빛과 물
}


# ---- 순장된 영혼 (공중형) ---------------------------------------------------
# 32x32, 몸 중심 x=15, 기준선 y=26. 발이 없다 — 아래가 흩어진다.

def soul_frame(pose):
    f = blank(32, 32)
    d = ImageDraw.Draw(f)
    cx = 15
    bob = pose.get("bob", 0)
    cy = 13 + bob
    stretch = pose.get("stretch", 0)      # 내려찍을 때 세로로 늘어난다

    # --- 아래로 흩어지는 자락: 세 갈래가 서로 다른 길이로 늘어진다 ----------
    for i, (ox, ln) in enumerate(((-5, 9), (0, 13), (5, 8))):
        tail = ln + stretch + (2 if (i + pose.get("wisp", 0)) % 2 else 0)
        d.polygon([(cx + ox - 3, cy + 2), (cx + ox + 3, cy + 2),
                   (cx + ox + 1, cy + tail), (cx + ox - 1, cy + tail)],
                  fill=SOUL_SHADE)

    # --- 몸통: 위가 둥글고 아래가 열린 종 모양 ------------------------------
    d.ellipse([cx - 8, cy - 10 - stretch, cx + 8, cy + 4], fill=SOUL)
    d.ellipse([cx - 5, cy - 8 - stretch, cx + 5, cy - 1], fill=SOUL_CORE)

    # --- 팔: 순장된 자들이 손을 뻗고 있다 -----------------------------------
    reach = pose.get("reach", 0)
    for sgn in (-1, 1):
        d.line([cx + sgn * 6, cy - 4, cx + sgn * (9 + reach), cy + 1 + reach],
               fill=SOUL, width=2)

    # --- 눈 둘: 빈 자리로 판다 (그려 넣지 않는다) ---------------------------
    for sgn in (-1, 1):
        d.ellipse([cx + sgn * 3 - 1, cy - 6 - stretch, cx + sgn * 3 + 1,
                   cy - 3 - stretch], fill=LIME_DEEP)

    shade_band(f, SOUL_SHADE, cx - 8, cy - 2, cx + 8, cy + 6, axis="y", gamma=1.3)
    if pose.get("hurt"):
        tint(f, SOUL_CORE, 0.5)
    outline(f)
    rim_light(f, RIM, side=0.8)
    return f


def make_soul():
    frames = [
        soul_frame({"bob": 0, "wisp": 0}),                    # 0 떠 있기 A
        soul_frame({"bob": 1, "wisp": 1}),                    # 1 떠 있기 B
        soul_frame({"stretch": 3, "reach": 2, "wisp": 0}),    # 2 내려찍기
        soul_frame({"hurt": True, "bob": 1}),                 # 3 피격
    ]
    save(sheet(frames, 32, 32), OUT, "soul.png")


# ---- 무덤 번병 (방패형) -----------------------------------------------------
# 48x48, 발 기준선 y=46, 몸 중심 x=23. 방패는 바라보는 쪽에 있다.

def sentinel_frame(pose):
    f = blank(48, 48)
    d = ImageDraw.Draw(f)
    cx, fy = 23, 46
    step = pose.get("step", 0)
    lean = pose.get("lean", 0)              # 창을 내지를 때 앞으로 기운다

    # --- 다리 둘: 굵게, 골반에 붙여서 (가는 선은 몸에서 떨어져 보인다) ------
    for sgn, ph in ((-1, 0), (1, 1)):
        sw = 2 if (ph + step) % 2 == 0 else -2
        hip = cx + sgn * 4
        d.polygon([(hip - 2, fy - 17), (hip + 3, fy - 17),
                   (hip + sw + 3, fy - 2), (hip + sw - 2, fy - 2)], fill=SENT_SHADE)
        d.rectangle([hip + sw - 3, fy - 3, hip + sw + 4, fy - 1], fill=SENT)

    # --- 몸통: 어깨가 좁고 허리가 넓은 석상 형태 ----------------------------
    d.polygon([(cx - 7 + lean, fy - 33), (cx + 7 + lean, fy - 33),
               (cx + 10, fy - 16), (cx - 10, fy - 16)], fill=SENT)
    d.rectangle([cx - 9, fy - 25, cx + 9, fy - 22], fill=GOLD)     # 허리 금박 띠
    d.line([cx - 9, fy - 25, cx + 9, fy - 25], fill=GOLD_LIGHT)
    # 앞쪽 모서리의 빛 한 줄 (면 전체를 체커로 덮지 않는다 — A4의 규칙)
    d.line([cx + 8, fy - 30, cx + 9, fy - 17], fill=lerp(SENT, LIME_LIGHT, 0.5))

    # --- 네메스 두건: 정수리에서 어깨로 흘러내리는 양 옆자락 -----------------
    hx = cx + lean
    d.polygon([(hx - 7, fy - 44), (hx + 7, fy - 44), (hx + 9, fy - 34),
               (hx - 9, fy - 34)], fill=GOLD)
    for sgn in (-1, 1):                     # 옆자락
        d.polygon([(hx + sgn * 7, fy - 40), (hx + sgn * 10, fy - 38),
                   (hx + sgn * 9, fy - 28), (hx + sgn * 6, fy - 31)], fill=GOLD_SHADE)
    for yy in range(-43, -35, 3):           # 두건의 줄무늬
        d.line([hx - 6, fy + yy, hx + 6, fy + yy], fill=GOLD_SHADE)
    d.rectangle([hx - 5, fy - 38, hx + 5, fy - 32], fill=SENT)     # 얼굴
    d.point((hx + 3, fy - 36), fill=EMBER)                         # 눈에 불씨
    d.point((hx + 1, fy - 36), fill=EMBER)

    # --- 창: 뒤쪽(왼쪽) 손에 든다. 찌를 때만 앞으로 나간다 -------------------
    thrust = pose.get("thrust", 0)
    if thrust:
        d.line([cx - 4, fy - 27, cx + 19, fy - 26], fill=BONE, width=3)
        d.polygon([(cx + 18, fy - 30), (cx + 28, fy - 26), (cx + 18, fy - 22)],
                  fill=GOLD_LIGHT)
        d.polygon([(cx + 20, fy - 28), (cx + 25, fy - 26), (cx + 20, fy - 24)],
                  fill=GOLD_SHADE)
    else:
        d.line([cx - 9, fy - 43, cx - 5, fy - 3], fill=BONE, width=3)
        d.polygon([(cx - 12, fy - 42), (cx - 8, fy - 48), (cx - 6, fy - 40)],
                  fill=GOLD_LIGHT)

    # --- 방패: 이 적의 전부다. 어느 프레임에도 사라지지 않는다 ---------------
    raise_ = pose.get("raise", 0)
    x0 = cx + (4 if thrust else 7)
    y0 = fy - 36 - raise_
    d.polygon([(x0, y0), (x0 + 11, y0 + 4), (x0 + 11, y0 + 20),
               (x0 + 5, y0 + 25), (x0, y0 + 21)], fill=SHIELD)
    d.polygon([(x0 + 2, y0 + 3), (x0 + 9, y0 + 6), (x0 + 9, y0 + 18),
               (x0 + 5, y0 + 22), (x0 + 2, y0 + 18)], fill=SHIELD_SHADE)
    d.ellipse([x0 + 4, y0 + 10, x0 + 8, y0 + 14], fill=GOLD_LIGHT)   # 태양 무늬
    d.line([x0, y0, x0 + 11, y0 + 4], fill=GOLD_LIGHT)               # 위 테두리 빛

    # 허리 아래의 그늘. 여섯 픽셀짜리 디더 띠도 이 크기에서는 체커로 보여서,
    # 밀도 대신 선 둘로 끊었다 (2배 배율에서 확인).
    d.line([cx - 10, fy - 17, cx + 10, fy - 17], fill=SENT_SHADE)
    d.line([cx - 10, fy - 16, cx + 10, fy - 16], fill=lerp(SENT_SHADE, LIME_DEEP, 0.4))
    if pose.get("hurt"):
        tint(f, LIME_LIGHT, 0.45)
    if pose.get("spark"):
        # 막은 순간: 방패 앞에서 불꽃이 튄다 (막혔다는 것이 보여야 한다)
        for i, (sx, sy) in enumerate(((13, -30), (16, -26), (14, -21), (17, -34))):
            d.point((cx + sx, fy + sy), fill=EMBER_HOT)
            if i % 2 == 0:
                d.point((cx + sx + 2, fy + sy - 1), fill=EMBER)
    outline(f)
    rim_light(f, RIM, side=0.78)
    return f


def make_sentinel():
    frames = [
        sentinel_frame({"step": 0}),                       # 0 걷기A
        sentinel_frame({"step": 1}),                       # 1 걷기B
        sentinel_frame({"thrust": 1, "lean": 2}),          # 2 창 찌르기
        sentinel_frame({"hurt": True, "step": 1}),         # 3 피격
        sentinel_frame({"raise": 3, "spark": True}),       # 4 막기
    ]
    save(sheet(frames, 48, 48), OUT, "sentinel.png")


# ---- 파괴의 조각 (자폭형) ---------------------------------------------------
# 32x32, 기준선 y=30, 중심 x=15. 돌덩이의 금에서 불씨가 새어 나온다.

def shard_frame(pose):
    f = blank(32, 32)
    d = ImageDraw.Draw(f)
    cx, fy = 15, 30
    heat = pose.get("heat", 0)          # 0 평소, 1 심지가 탄다, 2 터진다
    swell = pose.get("swell", 0)

    if heat >= 2:
        # 터지는 순간. 돌은 이미 없다 — 빛과 파편이다.
        # (면 전체를 체커로 덮던 옛 방식은 쓰지 않는다. A4에서 버린 것이다.)
        for r, c in ((13, EMBER), (9, EMBER_HOT), (5, (255, 250, 236))):
            d.ellipse([cx - r, fy - 12 - r, cx + r, fy - 12 + r], fill=c)
        for dx, dy in ((-13, -4), (13, -4), (-9, -14), (9, -14),
                       (0, -20), (-6, 4), (6, 4)):
            d.line([cx, fy - 12, cx + dx, fy - 12 + dy], fill=EMBER_HOT, width=2)
        for dx, dy, r in ((-11, -9, 2), (10, -13, 2), (-7, 2, 1), (8, 1, 2)):
            d.rectangle([cx + dx, fy - 12 + dy, cx + dx + r, fy - 12 + dy + r],
                        fill=SHARD_SHADE)          # 흩어지는 파편
        shade_band(f, EMBER, cx - 14, fy - 6, cx + 14, fy + 2, axis="y", gamma=1.5)
        outline(f)
        return f

    # --- 각진 돌덩이 (둥글게 그리지 않는다 — 부서진 조각이다) ---------------
    body = [(cx - 8 - swell, fy - 6), (cx - 5 - swell, fy - 15 - swell),
            (cx + 2, fy - 18 - swell), (cx + 8 + swell, fy - 12),
            (cx + 7 + swell, fy - 4), (cx - 2, fy - 1)]
    d.polygon(body, fill=SHARD)
    d.polygon([(cx - 4, fy - 13), (cx + 1, fy - 15), (cx + 4, fy - 9),
               (cx - 1, fy - 7)], fill=SHARD_SHADE)

    # --- 짧은 돌다리 둘로 기어 온다 (떠 있지 않다) ---------------------------
    for sgn in (-1, 1):
        d.polygon([(cx + sgn * 3, fy - 4), (cx + sgn * 7, fy - 3),
                   (cx + sgn * 7, fy - 1), (cx + sgn * 3, fy - 1)],
                  fill=SHARD_SHADE)

    # --- 금: 심지가 타면 넓고 밝아진다 --------------------------------------
    glow = EMBER_HOT if heat else EMBER
    d.line([(cx - 6, fy - 8), (cx - 2, fy - 11), (cx + 1, fy - 7),
            (cx + 5, fy - 10)], fill=glow, width=1 + heat)
    if heat:
        d.line([(cx - 3, fy - 4), (cx, fy - 8), (cx + 4, fy - 5)],
               fill=glow, width=1)
        d.line([(cx - 1, fy - 15), (cx + 2, fy - 11)], fill=glow, width=1)
        # 심지가 탄다는 신호: 위로 오르는 불티 (멈춰 선 것과 함께 예고가 된다)
        for i, (ox, oy) in enumerate(((-3, -20), (2, -23), (0, -26))):
            d.point((cx + ox, fy + oy), fill=EMBER_HOT if i else EMBER)

    shade_band(f, SHARD_SHADE, cx - 8, fy - 7, cx + 8, fy - 1, axis="y", gamma=1.5)
    if pose.get("hurt"):
        tint(f, LIME_LIGHT, 0.5)
    outline(f)
    rim_light(f, EMBER, side=0.8)
    return f


def make_shard():
    frames = [
        shard_frame({}),                                   # 0 기기A
        shard_frame({"swell": 1}),                         # 1 기기B
        shard_frame({"heat": 1, "swell": 1}),              # 2 심지가 탄다
        shard_frame({"heat": 2}),                          # 3 터진다
        shard_frame({"hurt": True, "heat": 1}),            # 4 피격
    ]
    save(sheet(frames, 32, 32), OUT, "shard.png")


# ---- 아포피스 (보스) --------------------------------------------------------
# 64x64, 발 기준선 y=60, 몸 중심 x=31.
# 이집트의 파괴의 신은 거대한 뱀이다. 다만 횡스크롤에서 뱀은 실루엣이 약하므로,
# 원안의 "수호자"라는 말을 살려 **뱀 머리를 한 선 자세**로 그린다.

def apophis_frame(pose):
    f = blank(64, 64)
    d = ImageDraw.Draw(f)
    cx, fy = 31, 60
    lean = pose.get("lean", 0)
    coil = pose.get("coil", 0)          # 휘두르기 전에 몸을 낮춘다

    # --- 아래로 감긴 꼬리: 다리 대신 몸을 받친다 ----------------------------
    tail = pose.get("tail", 0)
    d.polygon([(cx - 18 - tail, fy), (cx + 18 + tail, fy),
               (cx + 10, fy - 12), (cx - 10, fy - 12)], fill=SHARD)
    for i in range(-3, 4):              # 비늘 결
        d.line([cx + i * 5, fy - 11, cx + i * 5 + 2, fy - 1], fill=SHARD_SHADE)

    # --- 몸통: 위로 솟은 코브라의 몸 ----------------------------------------
    top = fy - 44 + coil
    d.polygon([(cx - 8 + lean, top + 6), (cx + 8 + lean, top + 6),
               (cx + 12, fy - 12), (cx - 12, fy - 12)], fill=SHARD)
    d.rectangle([cx - 10, fy - 26, cx + 10, fy - 22], fill=GOLD)     # 금박 띠
    d.line([cx + 10, top + 8, cx + 12, fy - 14],
           fill=lerp(SHARD, EMBER, 0.35))                            # 앞모서리 빛

    # --- 목덜미: 코브라의 후드. 이 적의 실루엣이다 --------------------------
    hood = pose.get("hood", 8)
    d.polygon([(cx - 8 - hood + lean, top + 8), (cx - 4 + lean, top - 4),
               (cx + 4 + lean, top - 4), (cx + 8 + hood + lean, top + 8),
               (cx + 6 + lean, top + 12), (cx - 6 + lean, top + 12)],
              fill=SHARD_SHADE)
    d.polygon([(cx - 4 - hood // 2 + lean, top + 6), (cx + 4 + hood // 2 + lean,
               top + 6), (cx, top + 11)], fill=GOLD_SHADE)           # 후드의 무늬

    # --- 머리: 앞으로 내민 뱀 대가리 ----------------------------------------
    hx = cx + 4 + lean + pose.get("strike", 0)
    d.polygon([(hx - 6, top - 6), (hx + 10, top - 4), (hx + 12, top + 2),
               (hx - 6, top + 3)], fill=SHARD)
    d.point((hx + 6, top - 1), fill=EMBER_HOT)                       # 눈
    d.point((hx + 7, top - 1), fill=EMBER)
    if pose.get("open"):                                             # 벌린 입
        d.polygon([(hx + 8, top + 1), (hx + 16, top + 5), (hx + 8, top + 4)],
                  fill=EMBER)
        d.point((hx + 11, top + 3), fill=EMBER_HOT)

    # --- 팔 둘: 우박을 부를 때 위로 든다 ------------------------------------
    raise_ = pose.get("raise", 0)
    for sgn in (-1, 1):
        ex = cx + sgn * (13 + raise_)
        ey = fy - 30 - raise_ * 2
        d.line([cx + sgn * 8, fy - 30, ex, ey], fill=SHARD, width=3)
        d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=GOLD_SHADE)
        if raise_:
            d.point((ex, ey - 4), fill=EMBER_HOT)

    shade_band(f, SHARD_SHADE, cx - 13, fy - 20, cx + 13, fy - 12,
               axis="y", gamma=1.6)
    if pose.get("hurt"):
        tint(f, LIME_LIGHT, 0.45)
    outline(f)
    rim_light(f, EMBER, side=0.8)
    return f


def make_apophis():
    frames = [
        apophis_frame({"tail": 0}),                              # 0 서기A
        apophis_frame({"tail": 1, "hood": 9}),                   # 1 서기B
        apophis_frame({"lean": 4, "coil": 4, "strike": 4,
                       "open": True, "hood": 6}),                # 2 돌진
        apophis_frame({"raise": 5, "open": True, "hood": 10}),   # 3 우박 부르기
        apophis_frame({"hurt": True, "coil": 3}),                # 4 피격
    ]
    save(sheet(frames, 64, 64), OUT, "apophis.png")


# ---- 타일셋 ---------------------------------------------------------------
# 16x16. gid는 forest16.png와 별개다 (맵마다 자기 타일셋을 가리킨다).

def t_lime_top(variant=0):
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], fill=LIME)
    d.rectangle([0, 0, 15, 2], fill=LIME_LIGHT)      # 닳아 밝아진 윗면
    # 정으로 쪼아 낸 자국. 변형마다 자리가 다르다
    for i, (x, y) in enumerate(((3, 6), (9, 5), (12, 9), (6, 11))):
        if (i + variant) % 3 != 2:
            d.point((x, y), fill=LIME_SHADE)
    shade_band(t, LIME_SHADE, 0, 3, 15, 15, axis="y", gamma=1.2)
    return t


def t_lime_fill():
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], fill=LIME_SHADE)
    dither(d, 0, 0, 15, 15, LIME_DEEP, phase=1)
    return t


def t_sand_top():
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], fill=SAND)
    d.rectangle([0, 0, 15, 1], fill=lerp(SAND, LIME_LIGHT, 0.4))
    dither(d, 0, 4, 15, 15, SAND_SHADE, phase=0)
    return t


def t_sand_fill():
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], fill=SAND_SHADE)
    dither(d, 0, 0, 15, 15, LIME_DEEP, phase=1)
    return t


def t_crack_top():
    """파괴의 방의 갈라진 바닥. 틈에서 불씨가 보인다."""
    t = t_lime_top(1)
    d = ImageDraw.Draw(t)
    d.line([(2, 0), (5, 6), (3, 11), (7, 15)], fill=LIME_DEEP)
    d.line([(11, 0), (9, 5), (13, 10)], fill=LIME_DEEP)
    d.point((5, 6), fill=EMBER)
    d.point((9, 5), fill=EMBER)
    return t


def t_gold_band():
    """금박 띠. 벽과 바닥의 경계에 두른다."""
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], fill=LIME)
    d.rectangle([0, 5, 15, 10], fill=GOLD)
    d.line([0, 5, 15, 5], fill=GOLD_LIGHT)
    d.line([0, 10, 15, 10], fill=GOLD_SHADE)
    for x in range(1, 15, 4):
        d.point((x, 8), fill=GOLD_SHADE)
    return t


def t_step():
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 8, 15, 15], fill=LIME)
    d.rectangle([0, 8, 15, 9], fill=LIME_LIGHT)
    shade_band(t, LIME_SHADE, 0, 10, 15, 15, axis="y", gamma=1.2)
    return t


def t_wall(hiero=False):
    """벽. 표 19대로 벽돌을 쌓은 것이 아니라 깎아 낸 암반이다."""
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], fill=lerp(LIME_DEEP, LIME_SHADE, 0.35))
    # 면 전체 체커는 이 크기에서 그물로 보인다. 정으로 쪼아 낸 자국 몇 개로 끝낸다.
    for x, y in ((2, 3), (7, 6), (12, 2), (5, 11), (11, 13), (14, 8)):
        d.point((x, y), fill=LIME_DEEP)
    d.line([0, 15, 15, 15], fill=LIME_DEEP)
    if hiero:
        # 상형 문자 한 칸 (읽히는 글자가 아니라 새김의 결이다)
        d.rectangle([4, 2, 11, 13], fill=lerp(LIME_DEEP, GOLD, 0.30))
        d.line([6, 4, 6, 11], fill=GOLD_SHADE)
        d.line([9, 4, 9, 7], fill=GOLD_SHADE)
        d.line([6, 7, 9, 7], fill=GOLD_SHADE)
        d.point((9, 10), fill=GOLD)
    return t


def t_pillar(part):
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    if part == "top":
        d.rectangle([1, 0, 14, 4], fill=LIME_LIGHT)     # 주두
        d.rectangle([3, 4, 12, 15], fill=LIME)
        d.rectangle([1, 3, 14, 4], fill=GOLD)
    elif part == "base":
        d.rectangle([3, 0, 12, 11], fill=LIME)
        d.rectangle([1, 11, 14, 15], fill=LIME_LIGHT)
    else:
        d.rectangle([3, 0, 12, 15], fill=LIME)
    d.line([4, 0, 4, 15], fill=LIME_LIGHT)              # 세로 홈
    d.line([11, 0, 11, 15], fill=LIME_SHADE)
    return t


def t_brazier():
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.polygon([(4, 15), (11, 15), (10, 9), (5, 9)], fill=GOLD_SHADE)
    d.rectangle([3, 7, 12, 9], fill=GOLD)
    d.polygon([(6, 7), (8, 1), (10, 7)], fill=EMBER)
    d.polygon([(7, 6), (8, 3), (9, 6)], fill=EMBER_HOT)
    return t


def t_inlay(kind):
    """바닥에 박힌 상감. 방마다 다른 무늬가 그 방의 이름이다."""
    t = t_lime_top(2)
    d = ImageDraw.Draw(t)
    if kind == "star":
        d.line([8, 2, 8, 13], fill=GOLD)
        d.line([2, 8, 13, 8], fill=GOLD)
        d.point((8, 8), fill=GOLD_LIGHT)
        for dx, dy in ((-3, -3), (3, -3), (-3, 3), (3, 3)):
            d.point((8 + dx, 8 + dy), fill=GOLD_SHADE)
    elif kind == "moon":
        d.ellipse([3, 3, 12, 12], fill=lerp(LIME, SOUL, 0.55))
        d.ellipse([6, 2, 14, 11], fill=LIME)
    else:                                   # sun
        d.ellipse([4, 4, 11, 11], fill=GOLD)
        d.ellipse([6, 6, 9, 9], fill=GOLD_LIGHT)
        for dx, dy in ((0, -6), (0, 6), (-6, 0), (6, 0)):
            d.point((8 + dx, 8 + dy), fill=GOLD_SHADE)
    return t


def t_water(top=False):
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], fill=WATER)
    dither(d, 0, 0, 15, 15, lerp(WATER, LIME_DEEP, 0.4), phase=1)
    if top:
        d.line([0, 0, 15, 0], fill=WATER_LIGHT)
        for x in range(0, 16, 4):
            d.point((x, 2), fill=WATER_LIGHT)
    return t


def t_sarcophagus(part):
    """석관 2x2. 황제의 것이 아니라 순장된 자들의 것이다 (원안 표 16)."""
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    left = part in ("tl", "bl")
    top = part in ("tl", "tr")
    d.rectangle([0 if not left else 2, 0, 15 if left else 13, 15], fill=LIME)
    if top:
        d.rectangle([0 if not left else 2, 0, 15 if left else 13, 3],
                    fill=LIME_LIGHT)
        if left:
            d.ellipse([6, 5, 13, 12], fill=GOLD_SHADE)      # 얼굴 조각
            d.ellipse([7, 6, 12, 11], fill=GOLD)
    else:
        for y in range(2, 15, 4):
            d.line([3 if left else 0, y, 13 if left else 15, y], fill=LIME_SHADE)
    shade_band(t, LIME_SHADE, 0, 8, 15, 15, axis="y", gamma=1.1)
    return t


def t_rubble():
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    for x0, y0, w in ((2, 11, 5), (8, 12, 4), (5, 8, 3), (11, 9, 3)):
        d.rectangle([x0, y0, x0 + w, y0 + w - 1], fill=LIME_SHADE)
        d.point((x0, y0), fill=LIME)
    return t


def t_bones():
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.ellipse([3, 9, 9, 14], fill=BONE)                 # 두개골
    d.point((5, 11), fill=LIME_DEEP)
    d.point((7, 11), fill=LIME_DEEP)
    d.line([10, 13, 14, 11], fill=BONE, width=2)        # 뼈 한 짝
    return t


def t_urn():
    t = blank(16, 16)
    d = ImageDraw.Draw(t)
    d.polygon([(5, 15), (10, 15), (12, 8), (10, 4), (5, 4), (3, 8)], fill=SAND)
    d.rectangle([5, 2, 10, 4], fill=SAND_SHADE)
    d.line([4, 9, 11, 9], fill=GOLD_SHADE)
    shade_band(t, SAND_SHADE, 3, 8, 12, 15, axis="y", gamma=1.2)
    return t


def t_edge(side):
    """바닥의 양 끝. 깎다 만 암반의 결."""
    t = t_lime_top(0)
    d = ImageDraw.Draw(t)
    if side == "left":
        d.polygon([(0, 0), (3, 0), (1, 15), (0, 15)], fill=LIME_SHADE)
    else:
        d.polygon([(15, 0), (12, 0), (14, 15), (15, 15)], fill=LIME_SHADE)
    return t


def make_tileset():
    tiles = [
        # 줄 0 (gid 1~8): 바닥
        t_lime_top(0), t_lime_fill(), t_sand_top(), t_sand_fill(),
        t_gold_band(), t_crack_top(), t_step(), t_edge("left"),
        # 줄 1 (gid 9~16): 벽과 기둥
        t_wall(), t_wall(hiero=True), t_pillar("top"), t_pillar("mid"),
        t_pillar("base"), t_brazier(), t_edge("right"), blank(16, 16),
        # 줄 2 (gid 17~24): 석관과 상감
        t_sarcophagus("tl"), t_sarcophagus("tr"), t_sarcophagus("bl"),
        t_sarcophagus("br"), t_inlay("star"), t_inlay("moon"), t_inlay("sun"),
        t_water(top=True),
        # 줄 3 (gid 25~32): 물과 잔해와 바닥 변형
        t_water(), t_rubble(), t_bones(), t_urn(),
        t_lime_top(1), t_lime_top(2), blank(16, 16), blank(16, 16),
    ]
    cols = 8
    rows = (len(tiles) + cols - 1) // cols
    img = blank(cols * 16, rows * 16)
    for i, t in enumerate(tiles):
        img.paste(t, ((i % cols) * 16, (i // cols) * 16), t)
    save(img, OUT, "tomb16.png")


# ---- 기후 조각 --------------------------------------------------------------
# 엔진에 도형 프리미티브가 없어서(README의 렌더링 표) 기후도 스프라이트다.
# 64x16 한 장에 다섯 조각을 담고, 씬이 setRect로 잘라 쓴다.
#   x  0.. 7  우박 한 알 (8x8)
#   x  8..23  낙하 예고 그림자 (16x8)
#   x 56..63  눈송이 (8x8)
# 빛기둥(beam.png)과 물(water.png)은 화면만큼 커서 따로 굽는다.

def make_climate():
    img = blank(64, 16)
    d = ImageDraw.Draw(img)

    # 우박: 모서리가 선 얼음 조각
    d.polygon([(4, 0), (7, 3), (5, 7), (1, 5), (0, 2)], fill=(214, 232, 244))
    d.polygon([(4, 1), (6, 3), (4, 5), (2, 3)], fill=(255, 255, 255))
    d.point((2, 5), fill=(140, 180, 210))

    # 예고 표시: 떨어질 자리. 어두운 바닥에 어두운 그림자를 두면 보이지 않는다
    # (파괴의 방에서 실제로 묻혔다). 밝은 고리로 그린다.
    d.ellipse([9, 1, 22, 6], fill=EMBER_HOT)
    d.ellipse([11, 2, 20, 5], fill=(120, 46, 30))
    d.ellipse([13, 3, 18, 4], fill=EMBER)
    for x in (9, 15, 22):
        d.point((x, 0), fill=(255, 255, 255))

    # 눈송이
    d.point((59, 2), fill=(236, 244, 252))
    d.line([58, 3, 61, 3], fill=(236, 244, 252))
    d.line([59, 2, 59, 5], fill=(236, 244, 252))

    save(img, OUT, "climate.png")


# 빛기둥과 물은 화면만큼 크다. 엔진의 setScale은 균등 배율뿐이라 16x16을 늘여
# 쓸 수 없어서(scripts/image.lua), 쓸 크기 그대로 굽는다.

BEAM_W, BEAM_H = 88, 448
WATER_W, WATER_H = 384, 128


def make_beam():
    img = blank(BEAM_W, BEAM_H)
    d = ImageDraw.Draw(img)
    for y in range(BEAM_H):
        c = lerp(GOLD_LIGHT, GOLD_SHADE, min(1.0, y / (BEAM_H * 0.9)))
        d.line([0, y, BEAM_W - 1, y], fill=c)
    # 가장자리를 어둡게 해 기둥의 폭이 눈에 들어오게
    for x in (0, 1, BEAM_W - 2, BEAM_W - 1):
        d.line([x, 0, x, BEAM_H - 1], fill=GOLD_SHADE)
    for x in range(6, BEAM_W - 6, 14):      # 세로 결
        for y in range(0, BEAM_H, 3):
            d.point((x, y), fill=(255, 255, 255))
    save(img, OUT, "beam.png")


def make_water():
    img = blank(WATER_W, WATER_H)
    d = ImageDraw.Draw(img)
    for y in range(WATER_H):
        d.line([0, y, WATER_W - 1, y],
               fill=lerp(WATER_LIGHT, WATER, min(1.0, y / 40)))
    for x in range(0, WATER_W, 6):          # 수면의 잔물결
        d.point((x, 0), fill=(210, 240, 244))
        d.point((x + 3, 1), fill=(180, 220, 228))
    d.line([0, 0, WATER_W - 1, 0], fill=(200, 236, 240))
    save(img, OUT, "water.png")


# ---- 배경 -----------------------------------------------------------------
# 무덤은 안이다. 하늘이 없으므로 먼 층은 깊은 방, 가까운 층은 앞의 기둥이다.

W, H = 384, 448


def _rnd(seed):
    v = seed

    def nxt(n):
        nonlocal v
        v = (v * 1103515245 + 12345) % (2 ** 31)
        return v % n
    return nxt


def make_bg_far(name):
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    light = ROOM_LIGHT[name]

    # 벽: 위가 어둡고 아래가 방의 빛을 받는다
    for y in range(H):
        d.line([0, y, W, y], fill=lerp(LIME_DEEP, light, (y / H) ** 1.4))

    # 깎아 낸 결 (벽돌 줄눈이 아니다 — 표 19)
    nxt = _rnd(31 + len(name) * 5)
    for _ in range(90):
        x, y = nxt(W), nxt(H)
        ln = 8 + nxt(26)
        d.line([x, y, x + ln, y + nxt(3) - 1], fill=lerp(light, LIME_DEEP, 0.5))

    # 안쪽으로 물러나는 아치 셋. 단마다 뚜렷하게 어두워야 "깊다"로 읽힌다 —
    # 색이 가까우면 그냥 벽에 붙은 널판으로 보인다 (실제로 그렇게 보여서 고쳤다).
    for i in range(3):
        w = int(W * (0.62 - i * 0.13))
        top = int(H * (0.20 + i * 0.06))
        bot = int(H * 0.88)
        x0 = (W - w) // 2
        col = lerp(light, LIME_DEEP, 0.45 + i * 0.22)
        d.rectangle([x0, top, x0 + w, bot], fill=col)
        d.arc([x0, top - w // 3, x0 + w, top + w // 3], 180, 360,
              fill=lerp(col, GOLD_SHADE, 0.55), width=2)
        # 단의 바닥선. 발이 닿는 자리가 보여야 안쪽으로 물러나 보인다
        d.line([x0, bot, x0 + w, bot], fill=lerp(col, LIME, 0.30))

    # 방마다의 표식
    if name == "chest":
        # 등 뒤에서 들어오는 낮빛 한 줄기 (문은 항상 열려 있다 — 표 17)
        for i in range(70):
            a = 1.0 - i / 70
            d.line([int(W * 0.06) + i, 0, int(W * 0.16) + i, H],
                   fill=lerp(light, (222, 206, 168), 0.35 * a))
    elif name == "moon":
        d.ellipse([W // 2 - 46, 70, W // 2 + 46, 162], fill=lerp(light, SOUL, 0.55))
        d.ellipse([W // 2 - 22, 62, W // 2 + 66, 150], fill=lerp(LIME_DEEP, light, 0.5))
        for _ in range(120):                     # 눈
            x, y = nxt(W), nxt(H)
            d.point((x, y), fill=(226, 236, 246))
    elif name == "stars":
        # 별들의 방: 금별이 벽 가득 박혀 있다 (원안 표 16의 글귀)
        for _ in range(150):
            x, y = nxt(W), nxt(int(H * 0.8))
            r = nxt(3)
            c = GOLD_LIGHT if r == 2 else GOLD
            d.point((x, y), fill=c)
            if r == 2:
                d.point((x + 1, y), fill=GOLD_SHADE)
                d.point((x, y + 1), fill=GOLD_SHADE)
    elif name == "ruin":
        # 무너진 천장과 불씨
        pts = [(0, 0)]
        x = 0
        while x <= W:
            pts.append((x, 40 + nxt(70)))
            x += 32
        pts += [(W, 0)]
        d.polygon(pts, fill=LIME_DEEP)
        for _ in range(40):
            d.point((nxt(W), nxt(H)), fill=EMBER)
    else:                                        # sun
        d.ellipse([W // 2 - 60, 40, W // 2 + 60, 160], fill=lerp(light, GOLD, 0.6))
        d.ellipse([W // 2 - 34, 66, W // 2 + 34, 134], fill=GOLD_LIGHT)
        for i in range(16):                      # 빛살
            a = i * 22.5
            d.pieslice([W // 2 - 150, 100 - 150, W // 2 + 150, 100 + 150],
                       a, a + 6, fill=lerp(light, GOLD, 0.22))

    return img


def make_bg_near(name):
    """가까운 층: 앞을 지나가는 기둥. 대부분 비어 있어야 먼 층이 보인다."""
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    light = ROOM_LIGHT[name]
    col = lerp(light, LIME_DEEP, 0.62)

    # 기둥은 둘이면 족하다. 셋에 폭 34이면 화면의 4분의 1을 앞이 가린다
    # (2배 배율의 실제 화면에서 확인).
    col = lerp(col, LIME_DEEP, 0.35)
    xs = (52, 268)
    for x0 in xs:
        d.rectangle([x0, 0, x0 + 22, H], fill=col)
        d.rectangle([x0 - 4, 0, x0 + 26, 22], fill=lerp(col, LIME, 0.30))
        d.rectangle([x0 - 4, 22, x0 + 26, 25], fill=lerp(col, GOLD_SHADE, 0.45))
        d.rectangle([x0 - 5, H - 28, x0 + 27, H], fill=lerp(col, LIME, 0.26))
        d.line([x0 + 4, 25, x0 + 4, H - 28], fill=lerp(col, LIME, 0.40))
        d.line([x0 + 17, 25, x0 + 17, H - 28], fill=lerp(col, LIME_DEEP, 0.5))

    if name == "ruin":
        for x0 in xs:                            # 금이 간 기둥
            d.line([x0 + 8, 60, x0 + 14, 180, x0 + 6, 300], fill=LIME_DEEP)
    if name == "sun":
        for x0 in xs:                            # 물에 잠긴 밑동
            d.rectangle([x0 - 5, H - 54, x0 + 27, H], fill=lerp(col, WATER, 0.5))
    return img


def make_backgrounds():
    for name in ROOM_LIGHT:
        save(make_bg_far(name), OUT, "far_" + name + ".png")
        save(make_bg_near(name), OUT, "near_" + name + ".png")


def main():
    make_soul()
    make_apophis()
    make_sentinel()
    make_shard()
    make_tileset()
    make_climate()
    make_beam()
    make_water()
    make_backgrounds()
    print("완료. 1-2 황제의 무덤의 자산입니다.")


if __name__ == "__main__":
    main()
