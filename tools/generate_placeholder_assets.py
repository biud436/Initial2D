#!/usr/bin/env python3
"""Generate placeholder assets for the Flappy Bird demo (scripts/main.lua).

The original art assets referenced by the demo were never committed
(resources/*.* is gitignored). This script generates substitutes so the
demo runs on a fresh checkout. If you have the original assets, simply
keep them — running this script overwrites the generated files only.

Usage: python3 tools/generate_placeholder_assets.py
Requires: Pillow (pip install pillow)
"""

import math
import os
import random
import struct
import wave

from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(REPO, "resources")
AUDIO = os.path.join(RES, "audio")

W, H = 768, 896


def lerp(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def make_background():
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)

    # 하늘 그라데이션
    top, bottom = (96, 170, 255), (205, 235, 255)
    for y in range(H):
        d.line([(0, y), (W - 1, y)], fill=lerp(top, bottom, y / (H - 1)) + (255,))

    # 태양
    sun = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sun)
    ds.ellipse([40, 40, 180, 180], fill=(255, 245, 200, 255))
    sun = sun.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(sun, (540, 40))

    # 구름 (부드러운 타원 뭉치 — 배경 2장을 이어 스크롤하므로 가장자리를 넘지 않게 배치)
    random.seed(7)
    for cx, cy, s in [(120, 130, 1.0), (430, 210, 0.8), (560, 320, 0.65), (230, 380, 0.7)]:
        cloud = Image.new("RGBA", (300, 120), (0, 0, 0, 0))
        dc = ImageDraw.Draw(cloud)
        for _ in range(7):
            x = random.randint(20, 200)
            y = random.randint(30, 70)
            r = random.randint(28, 55)
            dc.ellipse([x, y, x + r * 2, y + r], fill=(255, 255, 255, 235))
        cloud = cloud.filter(ImageFilter.GaussianBlur(6))
        cloud = cloud.resize((int(300 * s), int(120 * s)))
        img.alpha_composite(cloud, (cx, cy))

    # 원경 언덕 2겹 (좌우가 이어지도록 폭의 정수배 주기 사인만 사용)
    for base, color, k1, k2 in [(700, (150, 205, 150, 255), 3, 7), (760, (110, 180, 110, 255), 2, 5)]:
        hills = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dh = ImageDraw.Draw(hills)
        pts = [(0, H)]
        for x in range(0, W + 1, 16):
            yy = base + int(26 * math.sin(2 * math.pi * k1 * x / W + base)) \
                      + int(13 * math.sin(2 * math.pi * k2 * x / W))
            pts.append((x, yy))
        pts.append((W, H))
        dh.polygon(pts, fill=color)
        img.alpha_composite(hills)

    img.convert("RGBA").save(os.path.join(RES, "background_768x896.png"))


def make_ground():
    g = Image.new("RGBA", (W, 64))
    d = ImageDraw.Draw(g)
    # 흙
    for y in range(64):
        d.line([(0, y), (W - 1, y)], fill=lerp((150, 105, 60), (120, 82, 45), y / 63) + (255,))
    # 잔디
    d.rectangle([0, 0, W - 1, 14], fill=(96, 180, 90, 255))
    d.rectangle([0, 14, W - 1, 17], fill=(70, 140, 66, 255))
    # 스크롤이 보이도록 주기적 사선 무늬 (48px 주기 — 768과 정합)
    for x in range(0, W, 48):
        d.polygon([(x, 26), (x + 16, 26), (x + 8, 50)], fill=(135, 92, 52, 255))
    g.save(os.path.join(RES, "ground_768x64.png"))


def draw_bird(d, ox, wing):
    # 몸통
    d.ellipse([ox + 12, 10, ox + 80, 58], fill=(255, 205, 55, 255), outline=(170, 120, 20, 255), width=3)
    d.ellipse([ox + 20, 20, ox + 62, 54], fill=(255, 226, 120, 255))
    # 날개 (wing: -1 아래 / 0 중간 / 1 위)
    wy = {1: 14, 0: 26, -1: 36}[wing]
    d.ellipse([ox + 22, wy, ox + 50, wy + 18], fill=(235, 165, 35, 255), outline=(170, 120, 20, 255), width=2)
    # 눈
    d.ellipse([ox + 58, 18, ox + 74, 34], fill=(255, 255, 255, 255), outline=(120, 90, 20, 255), width=2)
    d.ellipse([ox + 65, 24, ox + 71, 30], fill=(30, 30, 30, 255))
    # 부리
    d.polygon([(ox + 78, 32), (ox + 92, 37), (ox + 78, 44)], fill=(240, 120, 50, 255))
    d.polygon([(ox + 78, 37), (ox + 88, 39), (ox + 78, 42)], fill=(200, 90, 35, 255))


def make_bird():
    img = Image.new("RGBA", (276, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for f, wing in enumerate([1, 0, -1]):
        draw_bird(d, f * 92, wing)
    img.save(os.path.join(RES, "bird_276x64.png"))


def make_pipe():
    img = Image.new("RGBA", (52, 271), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 몸통 (수평 그라데이션으로 원통 느낌)
    left, mid, right = (60, 130, 52), (110, 200, 95), (45, 105, 42)
    for x in range(6, 46):
        t = (x - 6) / 39.0
        c = lerp(left, mid, t * 2) if t < 0.5 else lerp(mid, right, (t - 0.5) * 2)
        d.line([(x, 26), (x, 270)], fill=c + (255,))
    d.rectangle([6, 26, 45, 270], outline=(35, 80, 32, 255), width=2)
    # 캡 (간격 쪽 끝)
    for x in range(0, 52):
        t = x / 51.0
        c = lerp(left, mid, t * 2) if t < 0.5 else lerp(mid, right, (t - 0.5) * 2)
        d.line([(x, 0), (x, 26)], fill=c + (255,))
    d.rectangle([0, 0, 51, 26], outline=(35, 80, 32, 255), width=2)
    img.save(os.path.join(RES, "object_52x271.png"))


def write_wav(name, samples, rate=22050):
    path = os.path.join(AUDIO, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        w.writeframes(frames)


def env(i, n, attack=0.02):
    a = int(n * attack)
    if i < a:
        return i / max(1, a)
    return (1.0 - (i - a) / max(1, n - a)) ** 2


def make_sfx():
    rate = 22050
    # 참고: 엔진의 PlaySound(true)는 청크를 2회 연속 재생하므로 길이를 절반으로 설계한다.

    # flap: 하강 스윕 (55ms)
    n = int(rate * 0.055)
    write_wav("flap.wav", [0.5 * env(i, n) * math.sin(2 * math.pi * (520 - 340 * i / n) * i / rate) for i in range(n)])

    # point: 딩 (70ms, 880Hz + 배음)
    n = int(rate * 0.07)
    write_wav("point.wav", [
        0.4 * env(i, n) * (math.sin(2 * math.pi * 880 * i / rate) + 0.5 * math.sin(2 * math.pi * 1320 * i / rate))
        for i in range(n)])

    # hit: 노이즈 + 저음 (90ms)
    random.seed(3)
    n = int(rate * 0.09)
    write_wav("hit.wav", [
        env(i, n) * (0.35 * (random.random() * 2 - 1) + 0.35 * math.sin(2 * math.pi * 110 * i / rate))
        for i in range(n)])


def main():
    os.makedirs(AUDIO, exist_ok=True)
    make_background()
    make_ground()
    make_bird()
    make_pipe()
    make_sfx()
    print("generated: background, ground, bird, pipe, flap/point/hit wav")


if __name__ == "__main__":
    main()
