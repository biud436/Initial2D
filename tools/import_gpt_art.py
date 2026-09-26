#!/usr/bin/env python3
"""GPT가 그린 그림을 알데바란 시트로 굽는다 (docs/prompts/aldebaran-art-meta-prompt.md 10절).

입력은 resources/aldebaran/src/gpt/<시트>__<부분>.png 이다. 그림의 약속은 메타 프롬프트 0절:
  - 배경은 단색 초록 #00FF00 (또는 투명)
  - 칸 사이에 게임 픽셀 1개 폭의 자홍 #FF00FF 세로 구분선
  - 게임 픽셀 하나가 같은 크기의 큰 블록으로 그려져 있다
하는 일:
  1. 초록을 투명으로, 자홍 구분선의 x 위치로 칸을 나눈다
  2. 블록 크기(pitch)를 구분선 폭과 색 런 길이에서 재고, 블록 가운데를 샘플링해 게임 픽셀로 되돌린다
  3. 규약 크기 캔버스에 가로 가운데, 발 기준선 맞춤으로 놓는다
  4. 팔레트로 양자화한다
  5. 오른쪽 보기 줄 아래에 미러링한 왼쪽 보기 줄을 붙여 resources/aldebaran/<시트>.png 로 저장한다

Usage:
  python3 tools/import_gpt_art.py inspect resources/aldebaran/src/gpt/karto__ref.png
      구분선, 칸, 블록 크기를 보고하고 6배 미리보기를 --out 에 쓴다 (기본: /tmp)
  python3 tools/import_gpt_art.py build karto
      SHEETS[karto] 의 원본을 전부 읽어 시트를 굽는다. 원본이 빠진 칸은 기존 시트의 칸을 유지한다
Requires: Pillow, numpy
"""
import argparse
import glob
import os
import shutil
import sys
import tempfile
import time
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "resources", "aldebaran", "src", "gpt")
OUT = os.path.join(REPO, "resources", "aldebaran")

KEY_BG = (0, 255, 0)
KEY_DIV = (255, 0, 255)
INK = "#18121A"
RIM = "#96AADC"
BG_W, BG_H = 384, 448
BG_NAMES = [
    "far_entrance", "near_entrance", "far_road", "near_road", "far_gorge", "near_gorge",
    "far_den", "near_den", "far_altar", "near_altar", "forest_bright",
    "far_chest", "near_chest", "far_moon", "near_moon", "far_stars", "near_stars",
    "far_ruin", "near_ruin", "far_sun", "near_sun",
]
FOREST_STAR = {
    "far_entrance": (300, 64, 4),
    "far_road": (300, 64, 4),
    "far_gorge": (300, 64, 4),
    "far_den": (300, 64, 4),
    "far_altar": (300, 80, 8),
}


def hexes(s):
    return [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in s.split()]


# 재질별 3톤 (메타 프롬프트 0절). 시트마다 쓰는 묶음을 고른다.
PAL = {
    "common": hexes(f"{INK} {RIM}"),
    "karto": hexes("#C4A46E #96784C #CA463A #E8C29C #C49A76 #583A22 #7C5634 #544C60 #3C3648 "
                   "#6E4A2C #4E3420 #DEE2EC #B06AE2"),
    "spider": hexes("#5E4C68 #42344C #806C80 #EC5A46 #CEB45A"),
    "wolf": hexes("#605854 #403A3A #8C8276 #F04636 #E0DCD0"),
    "monkey": hexes("#86603A #62442A #E6E2D2 #928A6A #68624A #96928A"),
    "forest": hexes("#483C34 #342C28 #40543C #2C3C2C #6E6A70 #4A4850 #8E8A90 #342A36 #241C28 "
                    "#4A3C4A #80603C #5C442C #AA9668 #60603A #969460 #AC544A #3A4A38 #927044 "
                    "#807A86 #585462 #E86042 #FCD684 #E8743A"),
    "tomb": hexes("#A69C82 #766E5C #C8BEA2 #4E483E #B09868 #806C48 #D6B054 #967630 #F4DC8C "
                  "#487680 #76ACB0 #E8743A #FCD684 #CEC6B0"),
    "soul": hexes("#92C6DC #E2F6FC #5C8AAE"),
    "sentinel": hexes("#98907A #686252 #92703E #604828 #D6B054 #967630 #F4DC8C"),
    "shard": hexes("#605660 #3E3842 #E8743A #FCD684"),
    "apophis": hexes("#2C3446 #1C2230 #4A5670 #D6B054 #967630 #F4DC8C #F04636 #E0DCD0"),
}

# 시트 규약 (scripts/games/aldebaran/data/monsters.lua, player.lua 의 값과 같아야 한다).
#   cell: 칸 크기, cols: 시트 열 수, anchor_y: 접지 행 (발의 마지막 픽셀은 그 한 줄 위)
#   parts: (원본 파일, 그 파일의 칸이 들어갈 시트 열 번호들)
#   scale: GPT 결과를 게임 픽셀로 되돌린 뒤 나누는 정수 배율. 프레임마다 키를 맞추면
#          웅크린 자세가 서 있는 자세와 같은 키로 늘어나므로 시트 전체에 하나를 쓴다.
#          GPT는 서 있는 카르토를 85픽셀 안팎으로 그린다 (칸 48에 키 40을 시켜도). 그래서 2.
SCALE = 2
# 기준 칸: 요청마다 칸 1에 카르토 걷기 A를 다시 그리게 한다. GPT는 같은 장 안에서는 배율을
# 지키지만 장마다는 캔버스 높이에 맞춰 크기를 바꾸므로(늑대 두 번째 장이 1.4배였다),
# 카르토 칸의 키로 그 장의 배율을 재서 보정한다. targets의 None이 그 칸이다.
REF_KARTO_H = 80     # GPT가 그리는 걷기 A 카르토의 게임 픽셀 키 (karto__walk.png에서 76~83, 서기는 85)
SHEETS = {
    "karto": dict(cell=(48, 48), cols=12, anchor_y=46, pal=["common", "karto"],
                  parts=[("karto__idle_hurt.png", [0, 1, 11]), ("karto__walk.png", [2, 3, 4, 5]),
                         ("karto__jump.png", [6, 7]), ("karto__slash.png", [8, 9, 10])]),
    "spider": dict(cell=(48, 32), cols=4, anchor_y=30, pal=["common", "spider"],
                   parts=[("spider__all.png", [0, 1, 2, 3])]),
    "wolf": dict(cell=(48, 48), cols=5, anchor_y=46, pal=["common", "wolf"],
                 parts=[("wolf__a.png", [0, 1, 2]), ("wolf__b.png", [None, 3, 4])]),
    "monkey": dict(cell=(48, 48), cols=4, anchor_y=46, pal=["common", "monkey"],
                   parts=[("monkey__all.png", [None, 0, 1, 2, 3])]),
    "soul": dict(cell=(32, 32), cols=4, anchor_y=26, pal=["common", "soul"],
                 parts=[("soul__all.png", [None, 0, 1, 2, 3])]),
    "sentinel": dict(cell=(48, 48), cols=5, anchor_y=46, pal=["common", "sentinel"],
                     parts=[("sentinel__a.png", [None, 0, 1, 2]), ("sentinel__b.png", [None, 3, 4])]),
    "shard": dict(cell=(32, 32), cols=4, anchor_y=30, pal=["common", "shard"],
                  parts=[("shard__all.png", [None, 0, 1, 2, 3])]),
    "apophis": dict(cell=(64, 64), cols=5, anchor_y=60, pal=["common", "apophis"],
                    parts=[("apophis__a.png", [None, 0, 1, 2]), ("apophis__b.png", [None, 3, 4])]),
}


# ---- 1. 키 컬러와 구분선 --------------------------------------------------

def near(rgb, key, tol):
    d = np.abs(rgb.astype(np.int16) - np.array(key, dtype=np.int16))
    return d.max(axis=-1) <= tol


def load(path):
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    rgb, alpha = a[..., :3], a[..., 3]
    # 초록 키를 투명으로. 안티에일리어싱 된 가장자리는 초록기가 섞이므로 넉넉히 잡는다.
    bg = near(rgb, KEY_BG, 60) & (rgb[..., 1] > 150)
    alpha = np.where(bg, 0, alpha)
    return rgb, alpha


def divider_spans(rgb, alpha):
    """자홍 구분선이 차지하는 x 구간 목록 [(x0, x1)]. 세로로 절반 이상이 자홍이면 구분선이다."""
    mag = near(rgb, KEY_DIV, 70) & (alpha > 0)
    frac = mag.mean(axis=0)
    cols = frac > 0.5
    spans, x = [], 0
    while x < len(cols):
        if cols[x]:
            x0 = x
            while x < len(cols) and cols[x]:
                x += 1
            spans.append((x0, x))
        else:
            x += 1
    return spans


def content_bbox(alpha):
    ys, xs = np.nonzero(alpha > 127)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def split_cells(rgb, alpha, expect=None):
    """구분선으로 칸을 나눈다. 구분선이 없으면 한 칸이다. 자홍은 투명 처리한다."""
    spans = divider_spans(rgb, alpha)
    # 구분선의 안티에일리어싱 가장자리가 따로 잡혀 2~3조각으로 갈라진다. 가까운 조각은 합친다.
    merged = []
    for x0, x1 in spans:
        if merged and x0 - merged[-1][1] <= 8:
            merged[-1] = (merged[-1][0], x1)
        else:
            merged.append((x0, x1))
    spans = merged
    mag = near(rgb, KEY_DIV, 70)
    alpha = np.where(mag, 0, alpha)
    edges = [0] + [x for s in spans for x in s] + [rgb.shape[1]]
    cells = []
    for i in range(0, len(edges), 2):
        x0, x1 = edges[i], edges[i + 1]
        sub_a = alpha[:, x0:x1]
        bb = content_bbox(sub_a)
        if bb is None:
            continue
        bx0, by0, bx1, by1 = bb
        if bx1 - bx0 < 8 or by1 - by0 < 8:
            continue                                   # 구분선 부스러기 같은 얇은 칸
        cells.append((rgb[by0:by1, x0 + bx0:x0 + bx1], sub_a[by0:by1, bx0:bx1]))
    if expect is not None and len(cells) != expect:
        print(f"  경고: 칸 {len(cells)}개를 찾았는데 {expect}개를 기대했다", file=sys.stderr)
    return cells, spans


# ---- 2. 블록 격자 ----------------------------------------------------------
# AI가 그린 도트는 블록 크기가 고르지 않고 격자가 조금씩 어긋난다. 그래서 고정 pitch로
# 나누지 않고, 색이 바뀌는 자리(경계)를 축마다 모아 격자선을 만들고 그 사이의 가운데를
# 다수결로 샘플링한다. pitch는 경계 신호의 자기상관 주기로 잰다.

def edge_signal(rgb, alpha, axis):
    """axis=1이면 x방향 경계 신호 s[x]: x-1과 x 사이에서 색이 바뀐 줄의 비율."""
    a = alpha > 127
    q = rgb.astype(np.int16)
    if axis == 1:
        diff = np.abs(q[:, 1:] - q[:, :-1]).max(axis=-1)
        both = a[:, 1:] | a[:, :-1]
        s = ((diff > 40) & both).sum(axis=0) / max(1, a.shape[0])
    else:
        diff = np.abs(q[1:] - q[:-1]).max(axis=-1)
        both = a[1:] | a[:-1]
        s = ((diff > 40) & both).sum(axis=1) / max(1, a.shape[1])
    return np.concatenate([[0.0], s])


def period_of(s, lo=4, hi=80):
    """자기상관이 가장 큰 주기. 배음(2배)보다 기본 주기를 고른다."""
    z = s - s.mean()
    scores = {}
    for lag in range(lo, min(hi, len(z) // 3)):
        scores[lag] = float((z[:-lag] * z[lag:]).sum())
    if not scores:
        return None
    best_lag = max(scores, key=scores.get)
    best = scores[best_lag]
    for lag in sorted(scores):
        if lag < best_lag and abs(best_lag - 2 * lag) <= 1 and scores[lag] > 0.6 * best:
            return lag
    return best_lag


def peaks(s):
    return [i for i in range(1, len(s) - 1) if s[i] >= s[i - 1] and s[i] > s[i + 1] and s[i] > 0]


def grid_lines(s, pitch, length):
    """경계 신호에서 격자선 좌표 목록. 경계가 없는 구간은 pitch 간격으로 채운다."""
    pk = peaks(s)
    strong = [i for i in pk if s[i] >= max(0.03, 0.15 * s.max())] if pk else []
    if not strong:
        return list(range(0, length + 1, max(1, pitch)))
    kept = []
    for i in strong:
        if kept and i - kept[-1] < 0.6 * pitch:
            if s[i] > s[kept[-1]]:
                kept[-1] = i
            continue
        kept.append(i)
    lines = [float(kept[0])]
    for i in kept[1:]:
        a = lines[-1]
        n = max(1, int(round((i - a) / pitch)))
        for k in range(1, n):
            lines.append(a + (i - a) * k / n)
        lines.append(float(i))
    while lines[0] - pitch >= -0.5 * pitch:
        lines.insert(0, lines[0] - pitch)
    while lines[-1] + pitch <= length + 0.5 * pitch:
        lines.append(lines[-1] + pitch)
    lines[0] = max(0.0, lines[0])
    lines[-1] = min(float(length), lines[-1])
    out = [int(round(v)) for v in lines]
    return [x for i, x in enumerate(out) if i == 0 or x > out[i - 1]]


def sample_cell(rgb, alpha, x0, x1, y0, y1):
    """격자 칸 안쪽 절반의 다수결 색. 불투명이 절반 미만이면 투명."""
    mx, my = (x1 - x0) // 4, (y1 - y0) // 4
    sub = rgb[y0 + my:max(y0 + my + 1, y1 - my), x0 + mx:max(x0 + mx + 1, x1 - mx)]
    suba = alpha[y0 + my:max(y0 + my + 1, y1 - my), x0 + mx:max(x0 + mx + 1, x1 - mx)]
    opaque = suba > 127
    if opaque.size == 0 or opaque.mean() < 0.5:
        return (0, 0, 0), 0
    px = sub[opaque].reshape(-1, 3).astype(np.int32)
    q = px // 8
    keys = q[:, 0] * 4096 + q[:, 1] * 64 + q[:, 2]
    vals, counts = np.unique(keys, return_counts=True)
    sel = px[keys == vals[counts.argmax()]]
    return tuple(int(v) for v in sel.mean(axis=0)), 255


def estimate_pitch(rgb, alpha, spans, hint=None):
    """게임 픽셀 하나의 화면 픽셀 수. 구분선 폭이 가장 믿을 만하고, 없으면 경계 신호의 주기."""
    if spans:
        widths = sorted(x1 - x0 for x0, x1 in spans)
        return max(1, widths[len(widths) // 2])
    p = period_of(edge_signal(rgb, alpha, 1))
    return p or hint or 8


def downsample(rgb, alpha, pitch=None):
    """격자를 따라 게임 픽셀로 되돌린다. pitch를 주면 두 축 모두 그 값으로 강제한다."""
    sx, sy = edge_signal(rgb, alpha, 1), edge_signal(rgb, alpha, 0)
    px = pitch or period_of(sx) or 8
    py = pitch or period_of(sy) or px
    xl = grid_lines(sx, px, rgb.shape[1])
    yl = grid_lines(sy, py, rgb.shape[0])
    gw, gh = len(xl) - 1, len(yl) - 1
    out = np.zeros((gh, gw, 3), dtype=np.uint8)
    oa = np.zeros((gh, gw), dtype=np.uint8)
    for j in range(gh):
        for i in range(gw):
            c, a = sample_cell(rgb, alpha, xl[i], xl[i + 1], yl[j], yl[j + 1])
            out[j, i] = c
            oa[j, i] = a
    # 빈 테두리 줄은 잘라 낸다
    ys, xs = np.nonzero(oa)
    if len(xs) == 0:
        return out, oa, (px, py)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1], \
        oa[ys.min():ys.max() + 1, xs.min():xs.max() + 1], (px, py)


# ---- 2.5 크기 맞춤 ----------------------------------------------------------
# GPT는 요청한 칸보다 약 2배 크게 그린다 (48칸에 키 40을 시켰더니 54x87이 나왔다).
# 그래서 게임 픽셀로 되돌린 뒤 목표 키에 맞춰 한 번 더 줄인다. 면적 평균으로 줄이면
# 테두리가 반 픽셀이 되어 흐려지므로, 줄인 뒤 팔레트로 양자화하고 테두리와 역광을
# 생성기의 함수로 다시 두른다.

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_aldebaran_assets as G  # noqa: E402  (outline, rim_light 재사용)


def shrink_majority(rgb, alpha, factor):
    """정수 배율 축소. 블록마다 다수결 색을 고른다 (섞지 않으므로 또렷하다).
    동률이면 블록 평균에 가장 가까운 색. 불투명이 절반 미만이면 투명.
    위쪽과 좌우로 채워 넣어 발 줄이 그대로 남게 한다."""
    h, w = alpha.shape
    H, W = -(-h // factor), -(-w // factor)
    ph, pw = H * factor - h, W * factor - w
    rp = np.zeros((H * factor, W * factor, 3), dtype=np.uint8)
    ap = np.zeros((H * factor, W * factor), dtype=np.uint8)
    rp[ph:, pw // 2:pw // 2 + w] = rgb
    ap[ph:, pw // 2:pw // 2 + w] = alpha
    out = np.zeros((H, W, 3), dtype=np.uint8)
    oa = np.zeros((H, W), dtype=np.uint8)
    for j in range(H):
        for i in range(W):
            blk = rp[j * factor:(j + 1) * factor, i * factor:(i + 1) * factor].reshape(-1, 3)
            ba = ap[j * factor:(j + 1) * factor, i * factor:(i + 1) * factor].reshape(-1)
            op = ba > 127
            if op.sum() * 2 < len(ba):
                continue
            px = blk[op].astype(np.int32)
            q = px // 16
            keys = q[:, 0] * 4096 + q[:, 1] * 64 + q[:, 2]
            vals, counts = np.unique(keys, return_counts=True)
            cands = vals[counts == counts.max()]
            if len(cands) > 1:
                mean = px.mean(axis=0)
                best = min(cands, key=lambda kk: float(((px[keys == kk].mean(axis=0) - mean) ** 2).sum()))
            else:
                best = cands[0]
            out[j, i] = px[keys == best].mean(axis=0)
            oa[j, i] = 255
    return out, oa


def shrink_box(rgb, alpha, target_h):
    """비정수 배율 축소. 알파 가중 면적 평균 (흐려지므로 정수 배율이 안 될 때만)."""
    h, w = alpha.shape
    s = target_h / h
    nw = max(1, int(round(w * s)))
    a = (alpha > 127).astype(np.float32)
    prem = rgb.astype(np.float32) * a[..., None]
    im_c = Image.fromarray(prem.astype(np.uint8)).resize((nw, target_h), Image.BOX)
    im_a = Image.fromarray((a * 255).astype(np.uint8)).resize((nw, target_h), Image.BOX)
    aa = np.array(im_a).astype(np.float32) / 255.0
    cc = np.array(im_c).astype(np.float32)
    with np.errstate(divide="ignore", invalid="ignore"):
        cc = np.where(aa[..., None] > 0.02, cc / np.maximum(aa[..., None], 1e-3), 0)
    out_a = np.where(aa >= 0.5, 255, 0).astype(np.uint8)
    return np.clip(cc, 0, 255).astype(np.uint8), out_a


def fit_height(rgb, alpha, target_h):
    """키가 target_h를 넘으면 줄인다. 배율이 정수에 가까우면 다수결, 아니면 면적 평균."""
    h, w = alpha.shape
    if h <= target_h:
        return rgb, alpha
    ratio = h / target_h
    factor = int(round(ratio))
    if factor >= 2 and abs(ratio - factor) <= 0.12:
        return shrink_majority(rgb, alpha, factor)
    return shrink_box(rgb, alpha, target_h)


def redraw_edges(rgba):
    """생성기와 같은 규칙으로 테두리를 어둡게, 오른쪽 가장자리에 역광 1px."""
    im = Image.fromarray(np.ascontiguousarray(rgba)).copy()
    G.outline(im)
    G.rim_light(im, G.RIM)
    return np.array(im)


# ---- 2.6 배경 크기와 이음매 -------------------------------------------------

def is_near_bg(name):
    return os.path.basename(name).startswith("near_")


def bg_name_from_path(path):
    return os.path.splitext(os.path.basename(path))[0]


def green_residue(rgb, alpha):
    r = rgb[..., 0].astype(np.int16)
    g = rgb[..., 1].astype(np.int16)
    b = rgb[..., 2].astype(np.int16)
    return int((((alpha > 0) & (g > r + 40) & (g > b + 40))).sum())


def clean_green_for_near(rgb, alpha):
    """초록 키와 초록 안티에일리어싱 잔여를 투명하게 만든다."""
    r = rgb[..., 0].astype(np.int16)
    g = rgb[..., 1].astype(np.int16)
    b = rgb[..., 2].astype(np.int16)
    key = near(rgb, KEY_BG, 80) & (g > 120)
    spill = (g > r + 40) & (g > b + 40)
    alpha = np.where(key | spill, 0, alpha).astype(np.uint8)
    rgb = rgb.copy()
    rgb[alpha == 0] = 0
    return rgb, alpha


def load_bg_source(path, transparent):
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    rgb, alpha = a[..., :3].copy(), a[..., 3].copy()
    if transparent:
        return clean_green_for_near(rgb, alpha)
    return rgb, np.full(alpha.shape, 255, dtype=np.uint8)


def resize_box_width(rgb, alpha, target_w, transparent):
    h, w = alpha.shape
    target_h = max(1, int(round(h * (target_w / w))))
    if transparent:
        af = alpha.astype(np.float32) / 255.0
        prem = rgb.astype(np.float32) * af[..., None]
        im_c = Image.fromarray(np.clip(prem, 0, 255).astype(np.uint8)).resize((target_w, target_h), Image.BOX)
        im_a = Image.fromarray(alpha).resize((target_w, target_h), Image.BOX)
        aa = np.array(im_a).astype(np.float32) / 255.0
        cc = np.array(im_c).astype(np.float32)
        with np.errstate(divide="ignore", invalid="ignore"):
            cc = np.where(aa[..., None] > 0.02, cc / np.maximum(aa[..., None], 1e-3), 0)
        out_a = np.where(aa >= 0.5, 255, 0).astype(np.uint8)
        out = np.clip(cc, 0, 255).astype(np.uint8)
        out[out_a == 0] = 0
        return out, out_a
    out = np.array(Image.fromarray(rgb).resize((target_w, target_h), Image.BOX))
    return out, np.full((target_h, target_w), 255, dtype=np.uint8)


def resize_nearest_width(rgb, alpha, target_w):
    h, w = alpha.shape
    target_h = max(1, int(round(h * (target_w / w))))
    rgba = np.dstack([rgb, alpha])
    out = np.array(Image.fromarray(rgba).resize((target_w, target_h), Image.NEAREST))
    return out[..., :3], out[..., 3]


def fit_bg_size(rgb, alpha, crop_y, transparent):
    h, w = alpha.shape
    if w != BG_W:
        rgb, alpha = resize_nearest_width(rgb, alpha, BG_W)
        h, w = alpha.shape
    if h >= BG_H:
        y0 = max(0, min(crop_y, h - BG_H))
        return rgb[y0:y0 + BG_H].copy(), alpha[y0:y0 + BG_H].copy()
    out_rgb = np.zeros((BG_H, BG_W, 3), dtype=np.uint8)
    out_a = np.zeros((BG_H, BG_W), dtype=np.uint8)
    out_rgb[:h] = rgb
    out_a[:h] = alpha
    if transparent:
        return out_rgb, out_a
    out_rgb[h:] = rgb[-1:]
    out_a[h:] = 255
    return out_rgb, out_a


def build_bg_pixels(rgb, alpha, name, crop_y=0, method="grid"):
    transparent = is_near_bg(name)
    used = method
    pitch = None
    if method == "grid":
        g_rgb, g_a, pitch = downsample(rgb, alpha)
        if g_a.shape[1] < 300 or g_a.shape[1] > 600:
            print(f"  grid 실패: 복원 폭 {g_a.shape[1]}이라 box로 대체")
            used = "box"
        else:
            if g_a.shape[1] > BG_W:
                ratio = g_a.shape[1] / BG_W
                factor = int(round(ratio))
                if factor >= 2 and abs(ratio - factor) <= 0.12:
                    g_rgb, g_a = shrink_majority(g_rgb, g_a, factor)
                else:
                    g_rgb, g_a = resize_box_width(g_rgb, g_a, BG_W, transparent)
            elif g_a.shape[1] < BG_W:
                g_rgb, g_a = resize_nearest_width(g_rgb, g_a, BG_W)
            rgb, alpha = g_rgb, g_a
    if used == "box":
        rgb, alpha = resize_box_width(rgb, alpha, BG_W, transparent)
    rgb, alpha = fit_bg_size(rgb, alpha, crop_y, transparent)
    if transparent:
        rgb, alpha = clean_green_for_near(rgb, alpha)
    return rgb, alpha, used, pitch


def seam_score(rgb, alpha=None):
    a = rgb[:, 0].astype(np.int16)
    b = rgb[:, -1].astype(np.int16)
    diff = np.abs(a - b).mean()
    if alpha is not None:
        diff += np.abs(alpha[:, 0].astype(np.int16) - alpha[:, -1].astype(np.int16)).mean() / 3.0
    return float(diff)


def roll_column(rgb, alpha, transparent):
    if transparent:
        return int(alpha.sum(axis=0).argmin())
    q = rgb.astype(np.int16)
    diff = np.abs(q - np.roll(q, 1, axis=1)).mean(axis=(0, 2))
    return int(diff.argmin())


def wrap_crossfade(rgb, alpha, width, transparent):
    width = max(0, min(width, rgb.shape[1] // 2))
    if width == 0:
        return rgb, alpha
    out_rgb = rgb.astype(np.float32).copy()
    out_a = alpha.astype(np.float32).copy()
    src_rgb = out_rgb.copy()
    src_a = out_a.copy()
    denom = max(1, width - 1)
    for i in range(width):
        t = i / denom
        li, ri = i, rgb.shape[1] - 1 - i
        mixed_rgb = (src_rgb[:, li] + src_rgb[:, ri]) * 0.5
        mixed_a = (src_a[:, li] + src_a[:, ri]) * 0.5
        out_rgb[:, li] = mixed_rgb * (1.0 - t) + src_rgb[:, li] * t
        out_rgb[:, ri] = mixed_rgb * (1.0 - t) + src_rgb[:, ri] * t
        if transparent:
            out_a[:, li] = mixed_a * (1.0 - t) + src_a[:, li] * t
            out_a[:, ri] = mixed_a * (1.0 - t) + src_a[:, ri] * t
    if not transparent:
        out_a[:] = 255
    return np.clip(out_rgb, 0, 255).astype(np.uint8), np.clip(out_a, 0, 255).astype(np.uint8)


def paint_required_star(rgb, name):
    if name not in FOREST_STAR:
        return rgb
    img = Image.fromarray(np.ascontiguousarray(rgb)).convert("RGB")
    x, y, r = FOREST_STAR[name]
    G.aldebaran_star(ImageDraw.Draw(img), x, y, r, BG_W, BG_H)
    return np.array(img)


def process_bg(path, name, crop_y=0, method="grid", seam=24):
    transparent = is_near_bg(name)
    rgb, alpha = load_bg_source(path, transparent)
    rgb, alpha, used, pitch = build_bg_pixels(rgb, alpha, name, crop_y, method)
    cut = roll_column(rgb, alpha, transparent)
    rgb = np.roll(rgb, -cut, axis=1)
    alpha = np.roll(alpha, -cut, axis=1)
    before = seam_score(rgb, alpha if transparent else None)
    rgb, alpha = wrap_crossfade(rgb, alpha, seam, transparent)
    if transparent:
        rgb, alpha = clean_green_for_near(rgb, alpha)
    else:
        rgb = paint_required_star(rgb, name)
        alpha[:] = 255
    after = seam_score(rgb, alpha if transparent else None)
    return rgb, alpha, dict(method=used, pitch=pitch, cut=cut, seam_before=before, seam_after=after)


def save_bg_preview(rgb, alpha, path):
    if alpha is None:
        img = Image.fromarray(rgb, "RGB")
    else:
        img = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
    preview = Image.new(img.mode, (BG_W * 2, BG_H))
    preview.paste(img, (0, 0), img if img.mode == "RGBA" else None)
    preview.paste(img, (BG_W, 0), img if img.mode == "RGBA" else None)
    preview.resize((preview.width * 2, preview.height * 2), Image.NEAREST).save(path)


def write_bg_output(rgb, alpha, transparent, path):
    if transparent:
        Image.fromarray(np.dstack([rgb, alpha]), "RGBA").save(path)
    else:
        Image.fromarray(rgb, "RGB").save(path)


# ---- 3, 4. 캔버스와 팔레트 ------------------------------------------------

def quantize(rgb, alpha, palette):
    pal = np.array(palette, dtype=np.int32)
    flat = rgb.reshape(-1, 3).astype(np.int32)
    # 사람 눈의 가중치 (초록 > 빨강 > 파랑)
    wgt = np.array([2, 4, 3])
    d = ((flat[:, None, :] - pal[None, :, :]) ** 2 * wgt).sum(axis=-1)
    idx = d.argmin(axis=1)
    out = pal[idx].reshape(rgb.shape).astype(np.uint8)
    return np.where(alpha[..., None] > 0, out, 0)


def place(rgb, alpha, cell, anchor_y):
    """규약 칸에 놓는다. 가로 가운데, 발은 anchor_y - 1 행.
    칸보다 크면 줄이지 않고 **잘라 낸다**. 검기 호 같은 효과가 칸을 넘칠 때 몸까지 작아지면
    다른 프레임과 배율이 어긋나므로, 가운데를 남기고 양옆을, 위를 잘라 낸다."""
    cw, ch = cell
    h, w = alpha.shape
    if w > cw:
        x_off = (w - cw) // 2
        rgb, alpha = rgb[:, x_off:x_off + cw], alpha[:, x_off:x_off + cw]
        print(f"  경고: 폭 {w}가 칸 {cw}를 넘쳐 양옆을 잘랐다", file=sys.stderr)
    if h > anchor_y:
        rgb, alpha = rgb[h - anchor_y:], alpha[h - anchor_y:]
        print(f"  경고: 키 {h}가 접지 행 {anchor_y}를 넘쳐 위를 잘랐다", file=sys.stderr)
    h, w = alpha.shape
    canvas = np.zeros((ch, cw, 4), dtype=np.uint8)
    x0 = (cw - w) // 2
    y0 = anchor_y - h
    canvas[y0:y0 + h, x0:x0 + w, :3] = rgb
    canvas[y0:y0 + h, x0:x0 + w, 3] = alpha
    return canvas


def sheet_from_cells(cells, cell, cols):
    cw, ch = cell
    img = Image.new("RGBA", (cols * cw, 2 * ch))
    for i, c in enumerate(cells):
        if c is None:
            continue
        f = Image.fromarray(c)
        img.paste(f, (i * cw, 0), f)
        m = f.transpose(Image.FLIP_LEFT_RIGHT)
        img.paste(m, (i * cw, ch), m)
    return img


# ---- 명령 -----------------------------------------------------------------

def cmd_inspect(args):
    rgb, alpha = load(args.path)
    cells, spans = split_cells(rgb, alpha)
    pitch = estimate_pitch(rgb, alpha, spans, hint=args.pitch)
    if args.pitch:
        pitch = args.pitch
    print(f"{os.path.basename(args.path)}: {rgb.shape[1]}x{rgb.shape[0]}, 구분선 {len(spans)}개 "
          f"{[x1 - x0 for x0, x1 in spans]}, 칸 {len(cells)}개, 블록 {pitch}px")
    previews = []
    for i, (crgb, ca) in enumerate(cells):
        g_rgb, g_a, (px, py) = downsample(crgb, ca, args.pitch)
        print(f"  칸 {i}: 원본 {ca.shape[1]}x{ca.shape[0]} → 게임 픽셀 {g_a.shape[1]}x{g_a.shape[0]} (블록 x {px}, y {py})")
        previews.append(Image.fromarray(np.dstack([g_rgb, g_a])))
    if previews:
        gap = 4
        w = sum(p.width for p in previews) + gap * (len(previews) - 1)
        h = max(p.height for p in previews)
        strip = Image.new("RGBA", (w, h), (40, 40, 40, 255))
        x = 0
        for p in previews:
            strip.paste(p, (x, h - p.height), p)
            x += p.width + gap
        out = args.out or os.path.join("/tmp", os.path.basename(args.path).replace(".png", "_x6.png"))
        strip.resize((strip.width * 6, strip.height * 6), Image.NEAREST).save(out)
        print(f"  미리보기: {out}")


def cmd_build(args):
    spec = SHEETS[args.sheet]
    cw, ch = spec["cell"]
    palette = [c for k in spec["pal"] for c in PAL[k]]
    cells = [None] * spec["cols"]
    # 원본이 없는 칸은 기존 시트를 유지한다
    old_path = os.path.join(OUT, args.sheet + ".png")
    if os.path.exists(old_path):
        old = Image.open(old_path).convert("RGBA")
        for i in range(spec["cols"]):
            cells[i] = np.array(old.crop((i * cw, 0, (i + 1) * cw, ch)))
    for fname, targets in spec["parts"]:
        path = os.path.join(SRC, fname)
        if not os.path.exists(path):
            print(f"  없음: {fname} (칸 {targets}는 기존 것을 유지)")
            continue
        rgb, alpha = load(path)
        found, spans = split_cells(rgb, alpha, expect=len(targets))
        if len(found) != len(targets):
            print(f"  건너뜀: {fname} (칸 수가 맞지 않는다)", file=sys.stderr)
            continue
        pitch = args.pitch or estimate_pitch(rgb, alpha, spans)
        print(f"{fname}: 칸 {len(found)}개, 블록 {pitch}px → 열 {targets}")
        sampled = [downsample(crgb, ca, args.pitch) for crgb, ca in found]
        factor = 1.0
        if None in targets:
            ref = sampled[targets.index(None)]
            factor = ref[1].shape[0] / REF_KARTO_H
            print(f"  기준 칸 키 {ref[1].shape[0]} → 배율 보정 {factor:.2f}")
        scale = args.scale or spec.get("scale", SCALE)
        s_img = scale * factor                       # 이 장의 축소 배율
        heights = [g_a.shape[0] for (_, g_a, _), t in zip(sampled, targets) if t is not None]
        limit = spec["anchor_y"] - 1                 # 접지 행 위로 들어가야 하는 최대 키
        if heights and max(heights) / s_img > limit:
            # 팔을 든 자세 등이 칸을 넘치면 장 전체를 같은 비율로 조금 더 줄인다 (자세끼리 비율 유지)
            s_img = max(heights) / limit
            print(f"  칸 넘침: 가장 큰 칸 {max(heights)} → 장 배율을 {s_img:.2f}로 올린다")
        for (g_rgb, g_a, _), t in zip(sampled, targets):
            if t is None:
                continue
            if args.height:
                g_rgb, g_a = fit_height(g_rgb, g_a, args.height)
            elif abs(s_img - round(s_img)) <= 0.12 and round(s_img) >= 2:
                g_rgb, g_a = shrink_majority(g_rgb, g_a, int(round(s_img)))
            else:
                g_rgb, g_a = shrink_box(g_rgb, g_a, max(1, int(round(g_a.shape[0] / s_img))))
            if not args.no_quant:
                g_rgb = quantize(g_rgb, g_a, palette)
            cell_img = place(g_rgb, g_a, (cw, ch), spec["anchor_y"])
            cells[t] = cell_img if args.no_edges else redraw_edges(cell_img)
    img = sheet_from_cells(cells, (cw, ch), spec["cols"])
    out = args.out or old_path
    img.save(out)
    print(f"만듦: {os.path.relpath(out, REPO)} ({img.width}x{img.height})")
    if args.preview:
        img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(args.preview)
        print(f"미리보기: {args.preview}")


def cmd_derive(args):
    """검은 늑대를 늑대 시트에서 파생한다. 몸은 어둡게, 붉은 눈(빨강이 두드러진 픽셀)은 그대로."""
    src_path = os.path.join(OUT, "wolf.png")
    a = np.array(Image.open(src_path).convert("RGBA")).astype(np.int32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    eye = (r > 120) & (r > g * 1.8) & (r > b * 1.8)
    body = (al > 40) & ~eye
    out = a.copy()
    out[..., 0] = np.where(body, r * 0.55, r)
    out[..., 1] = np.where(body, g * 0.55, g)
    out[..., 2] = np.where(body, b * 0.62, b)
    dst = args.out or os.path.join(OUT, "blackwolf.png")
    Image.fromarray(out.astype(np.uint8)).save(dst)
    print(f"만듦: {os.path.relpath(dst, REPO)} (눈 픽셀 {int(eye.sum())}개 유지)")


def build_bg_one(name, src_dir=SRC, out_dir=OUT, crop_y=0, method="grid", seam=24, preview=None, out_path=None):
    path = os.path.join(src_dir, name + ".png")
    if not os.path.exists(path):
        print(f"없음: {name}")
        return None
    transparent = is_near_bg(name)
    rgb, alpha, info = process_bg(path, name, crop_y=crop_y, method=method, seam=seam)
    dst = out_path or os.path.join(out_dir, name + ".png")
    write_bg_output(rgb, alpha, transparent, dst)
    mode = "RGBA" if transparent else "RGB"
    print(f"만듦: {os.path.relpath(dst, REPO)} ({BG_W}x{BG_H}, {mode}, method {info['method']}, "
          f"cut {info['cut']}, 이음매 점수 {info['seam_after']:.2f})")
    if preview:
        save_bg_preview(rgb, alpha if transparent else None, preview)
        print(f"미리보기: {preview}")
    return rgb, alpha, info


def cmd_build_bg(args):
    if args.name == "all":
        if args.out:
            raise SystemExit("all에는 --out을 쓸 수 없습니다")
        for name in BG_NAMES:
            build_bg_one(name, crop_y=args.crop_y, method=args.method, seam=args.seam)
        return
    if args.name not in BG_NAMES:
        raise SystemExit(f"알 수 없는 배경: {args.name}")
    build_bg_one(args.name, crop_y=args.crop_y, method=args.method, seam=args.seam,
                 preview=args.preview, out_path=args.out)


def cmd_inspect_bg(args):
    name = bg_name_from_path(args.path)
    transparent = is_near_bg(name)
    rgb, alpha = load_bg_source(args.path, transparent)
    pitch = estimate_pitch(rgb, alpha, [], hint=None)
    ratio = 1.0 - float((alpha > 0).mean())
    residue = green_residue(rgb, alpha)
    out_rgb, out_a, info = process_bg(args.path, name, crop_y=0, method="grid", seam=24)
    preview = args.preview or os.path.join("/tmp", name + "_bg_preview.png")
    save_bg_preview(out_rgb, out_a if transparent else None, preview)
    print(f"{os.path.basename(args.path)}: {rgb.shape[1]}x{rgb.shape[0]}, 블록 {pitch}px, "
          f"투명 {ratio * 100:.1f}%, 초록 잔여 {residue}개")
    print(f"  384x448 이음매 점수: {info['seam_after']:.2f} (method {info['method']}, cut {info['cut']})")
    print(f"  미리보기: {preview}")


def pull_files(names, downloads, src_dir=SRC, force=False):
    files = sorted(glob.glob(os.path.join(downloads, "ChatGPT Image *.png")), key=lambda p: (os.path.getmtime(p), p))
    count = min(len(files), len(names))
    if count < len(names):
        print(f"파일 {len(files)}개만 있어 {count}개만 옮깁니다")
    for name in names[:count]:
        dst = os.path.join(src_dir, name + ".png")
        if os.path.exists(dst) and not force:
            raise SystemExit(f"대상이 이미 있습니다: {dst} (--force 필요)")
    os.makedirs(src_dir, exist_ok=True)
    moved = []
    for src, name in zip(files[:count], names[:count]):
        dst = os.path.join(src_dir, name + ".png")
        if os.path.exists(dst) and force:
            os.remove(dst)
        shutil.move(src, dst)
        moved.append((src, dst))
        print(f"옮김: {os.path.basename(src)} -> {os.path.relpath(dst, REPO)}")
    return moved


def cmd_pull(args):
    pull_files(args.names, os.path.expanduser(args.downloads), force=args.force)


def assert_true(ok, msg):
    if not ok:
        raise AssertionError(msg)


def make_synthetic_far(path, size=(1024, 1536), block=8):
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    for y in range(0, h, block):
        t = y / h
        c = (int(14 + 40 * t), int(12 + 30 * t), int(24 + 52 * t))
        d.rectangle([0, y, w - 1, min(h - 1, y + block - 1)], fill=c)
    for x, tw in ((90, 42), (360, 58), (740, 50)):
        d.rectangle([x, 560, x + tw, h], fill=(18, 16, 28))
        d.line([x + tw // 2, 760, x - 80, 610], fill=(18, 16, 28), width=18)
        d.line([x + tw // 2, 700, x + 120, 560], fill=(18, 16, 28), width=14)
    d.rectangle([0, 0, 80, h - 1], fill=(82, 26, 34))
    d.rectangle([w - 80, 0, w - 1, h - 1], fill=(12, 60, 88))
    img.save(path)


def make_synthetic_near(path, size=(1024, 1536)):
    img = Image.new("RGB", size, KEY_BG)
    d = ImageDraw.Draw(img)
    for x0, x1 in ((260, 350), (930, 1040)):
        d.rectangle([x0, 0, x1, size[1] - 1], fill=(24, 20, 28))
        d.rectangle([x0 - 12, 0, x0 - 1, size[1] - 1], fill=(26, 180, 28))
        d.rectangle([x1 + 1, 0, x1 + 12, size[1] - 1], fill=(28, 170, 26))
    img.save(path)


def selftest_far(tmp):
    src = os.path.join(tmp, "src")
    out = os.path.join(tmp, "out")
    os.makedirs(src)
    os.makedirs(out)
    path = os.path.join(src, "far_entrance.png")
    make_synthetic_far(path)
    raw_rgb, raw_a = load_bg_source(path, False)
    base_rgb, base_a = resize_box_width(raw_rgb, raw_a, BG_W, False)
    base_rgb, base_a = fit_bg_size(base_rgb, base_a, 0, False)
    before = seam_score(base_rgb)
    rgb, alpha, info = build_bg_one("far_entrance", src, out, method="box", seam=24)
    after = seam_score(rgb)
    star = rgb[52:77, 288:313].astype(np.int16)
    near_star = (np.abs(star - np.array((232, 96, 66))).max(axis=-1) <= 40).sum()
    im = Image.open(os.path.join(out, "far_entrance.png"))
    assert_true(im.size == (BG_W, BG_H) and im.mode == "RGB", "far 출력 형식이 틀립니다")
    assert_true(after <= before * 0.5, f"far 이음매 개선 부족: {before:.2f} -> {after:.2f}")
    assert_true(near_star >= 5, f"알데바란 별 픽셀이 부족합니다: {near_star}")
    return before, after, info


def selftest_near(tmp):
    src = os.path.join(tmp, "near_src")
    out = os.path.join(tmp, "near_out")
    os.makedirs(src)
    os.makedirs(out)
    path = os.path.join(src, "near_entrance.png")
    make_synthetic_near(path)
    rgb, alpha, info = build_bg_one("near_entrance", src, out, method="box", seam=24)
    im = Image.open(os.path.join(out, "near_entrance.png"))
    assert_true(im.size == (BG_W, BG_H) and im.mode == "RGBA", "near 출력 형식이 틀립니다")
    assert_true((alpha == 0).mean() >= 0.60, "near 투명 비율이 60% 미만입니다")
    assert_true(green_residue(rgb, alpha) == 0, "near 초록 잔여가 남았습니다")
    assert_true(np.abs(alpha[:, 0].astype(np.int16) - alpha[:, -1].astype(np.int16)).mean() < 3,
                "near 이음매 알파가 이어지지 않습니다")
    return info


def selftest_square(tmp):
    src = os.path.join(tmp, "square_src")
    out = os.path.join(tmp, "square_out")
    os.makedirs(src)
    os.makedirs(out)
    path = os.path.join(src, "forest_bright.png")
    make_synthetic_far(path, size=(1024, 1024))
    rgb, alpha, _ = build_bg_one("forest_bright", src, out, method="box", seam=24)
    assert_true(alpha[-1].min() == 255, "forest_bright 아래 채움 알파가 틀립니다")
    assert_true(np.abs(rgb[-1].astype(np.int16) - rgb[-2].astype(np.int16)).max() == 0,
                "forest_bright 아래 채움이 마지막 줄 색이 아닙니다")


def selftest_pull(tmp):
    downloads = os.path.join(tmp, "downloads")
    dst = os.path.join(tmp, "pulled")
    os.makedirs(downloads)
    os.makedirs(dst)
    for i in range(3):
        p = os.path.join(downloads, f"ChatGPT Image {i}.png")
        Image.new("RGB", (8, 8), (i, i, i)).save(p)
        ts = time.time() - 30 + i
        os.utime(p, (ts, ts))
    moved = pull_files(["far_road", "near_road"], downloads, src_dir=dst)
    assert_true([os.path.basename(d) for _, d in moved] == ["far_road.png", "near_road.png"], "pull 이름 순서가 틀립니다")
    try:
        pull_files(["far_road"], downloads, src_dir=dst)
    except SystemExit:
        return
    raise AssertionError("pull이 기존 대상 파일을 거부하지 않았습니다")


def cmd_selftest(args):
    try:
        with tempfile.TemporaryDirectory() as tmp:
            far_before, far_after, _ = selftest_far(tmp)
            selftest_near(tmp)
            selftest_square(tmp)
            selftest_pull(tmp)
        print(f"selftest 통과: far 이음매 {far_before:.2f} -> {far_after:.2f}, near 초록 잔여 0, pull 순서 확인")
    except Exception as e:
        print(f"selftest 실패: {e}", file=sys.stderr)
        raise SystemExit(1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("inspect", help="원본 하나를 분석하고 미리보기를 만든다")
    a.add_argument("path")
    a.add_argument("--pitch", type=int, help="블록 크기를 직접 지정")
    a.add_argument("--out", help="미리보기 경로")
    a.set_defaults(fn=cmd_inspect)
    b = sub.add_parser("build", help="시트 하나를 굽는다")
    b.add_argument("sheet", choices=sorted(SHEETS))
    b.add_argument("--pitch", type=int)
    b.add_argument("--no-quant", action="store_true", help="팔레트 양자화를 건너뛴다")
    b.add_argument("--no-edges", action="store_true", help="테두리와 역광을 다시 두르지 않는다")
    b.add_argument("--height", type=int, help="고정 배율 대신 이 키에 맞춘다 (프레임마다 비율이 달라진다)")
    b.add_argument("--scale", type=int, help="고정 배율 (기본: 시트의 scale 또는 2)")
    b.add_argument("--out", help="시트를 다른 경로에 쓴다")
    b.add_argument("--preview", help="4배 미리보기 경로")
    b.set_defaults(fn=cmd_build)
    c = sub.add_parser("derive-blackwolf", help="wolf.png에서 blackwolf.png를 파생한다")
    c.add_argument("--out")
    c.set_defaults(fn=cmd_derive)
    d = sub.add_parser("build-bg", help="GPT 배경 원본을 384x448 게임 배경으로 굽는다")
    d.add_argument("name", choices=sorted(BG_NAMES + ["all"]))
    d.add_argument("--crop-y", type=int, default=0, help="세로 자르기 시작 줄 (기본: 0)")
    d.add_argument("--method", choices=("grid", "box"), default="grid")
    d.add_argument("--seam", type=int, default=24, help="좌우 이음매를 섞는 폭")
    d.add_argument("--preview", help="가로 두 장을 붙인 2배 미리보기 경로")
    d.add_argument("--out", help="출력 경로 (단일 이름에서만)")
    d.set_defaults(fn=cmd_build_bg)
    e = sub.add_parser("inspect-bg", help="배경 원본 하나를 분석하고 반복 미리보기를 만든다")
    e.add_argument("path")
    e.add_argument("--preview", help="미리보기 경로 (기본: /tmp/<이름>_bg_preview.png)")
    e.set_defaults(fn=cmd_inspect_bg)
    f = sub.add_parser("pull", help="Downloads의 ChatGPT Image PNG를 GPT 원본 위치로 옮긴다")
    f.add_argument("names", nargs="+")
    f.add_argument("--downloads", default="~/Downloads")
    f.add_argument("--force", action="store_true")
    f.set_defaults(fn=cmd_pull)
    g = sub.add_parser("selftest", help="배경 처리와 pull 명령을 외부 파일 없이 검증한다")
    g.set_defaults(fn=cmd_selftest)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
