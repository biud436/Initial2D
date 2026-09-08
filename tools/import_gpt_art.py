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
import os
import sys
from collections import Counter

import numpy as np
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "resources", "aldebaran", "src", "gpt")
OUT = os.path.join(REPO, "resources", "aldebaran")

KEY_BG = (0, 255, 0)
KEY_DIV = (255, 0, 255)
INK = "#18121A"
RIM = "#96AADC"


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
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
