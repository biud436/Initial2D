#!/usr/bin/env python3
"""RPG Maker 2003 RTP(resources/RTP.zip)를 엔진이 바로 쓰는 형태로 변환한다.

라이선스 주의:
    RTP 소재는 **RPG Maker 2003 정품 보유자의 로컬 개발용**으로만 쓴다. 소재 자체의
    재배포는 금지이므로 RTP.zip과 이 도구의 출력(resources/rtp/)은 git에 커밋하지
    않는다 (resources/.gitignore가 둘 다 제외한다).

무엇을 하는가:
    1. 팔레트 PNG(8비트)를 32비트 RGBA PNG로 변환한다. R2K3 관례대로 **팔레트 0번을
       투명으로 강제**한다 — tRNS 청크가 파일마다 들쭉날쭉하기 때문이다 (2026-08-16
       실측: ChipSet에만 tRNS가 있고 CharSet, System, Monster에는 없다).
       투명 처리 여부는 카테고리별 정책이며 CATEGORIES 표에 근거와 함께 적어 두었다.
    2. WAV는 그대로 복사한다 (SDL2_mixer가 바로 재생한다). --ogg 를 주면 OGG로 변환한다.
    3. MIDI는 기본적으로 건너뛴다. --soundfont 를 주면 fluidsynth로 OGG를 만든다
       (엔진에 MIDI 재생기를 넣지 않는다는 방침 — docs/plans/04-resources.md).
    4. 변환 결과의 명세를 resources/rtp/manifest.json에 남긴다. tests/verify_rtp.py가
       이 파일을 계약으로 삼아 출력물을 검증한다.

사용법:
    python3 tools/rtp_import.py                        # PNG 변환 + WAV 복사
    python3 tools/rtp_import.py --only CharSet,ChipSet # 일부 카테고리만
    python3 tools/rtp_import.py --ogg                  # WAV도 OGG로 (ffmpeg 필요)
    python3 tools/rtp_import.py --soundfont ~/sf/GM.sf2  # MIDI → OGG (fluidsynth 필요)
    python3 tools/rtp_import.py --normalize-names      # 공백을 언더스코어로

파일명의 공백("Mountain Road.png")은 기본적으로 그대로 둔다 — 엔진의 로더가 공백
경로를 문제없이 읽는 것을 실측으로 확인했다 (2026-08-16). --normalize-names 는
공백을 싫어하는 외부 도구와 엮을 때를 위한 선택지다.

필요 패키지: Pillow (pip install pillow)
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

try:
    from PIL import Image
except ImportError:  # pragma: no cover - 안내만 하고 종료
    sys.exit("Pillow가 필요합니다: pip install pillow")

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_ZIP = os.path.join(REPO, "resources", "RTP.zip")
DEFAULT_OUT = os.path.join(REPO, "resources", "rtp")

MANIFEST_NAME = "manifest.json"
MANIFEST_VERSION = 1


class Category:
    """카테고리 하나의 변환 정책.

    transparent: 팔레트 0번을 알파 0으로 만들지 여부 (이미지 카테고리에만 의미가 있다).
    size:        모든 파일이 가져야 할 크기 (None이면 파일마다 다름).
    note:        정책의 근거 (문서와 검증 메시지에 쓰인다).
    kind:        "image" 또는 "audio".
    """

    def __init__(self, transparent, size=None, note="", kind="image"):
        self.transparent = transparent
        self.size = size
        self.note = note
        self.kind = kind


# 투명 정책의 근거 (2026-08-16, RTP 2023년 재배포판 실측):
# 팔레트 0번의 사용 비율과 테두리 점유율을 재 보면 두 부류가 뚜렷하게 갈린다.
#   - 키 컬러 부류: CharSet(초록 32,156,0) 65%, ChipSet(마젠타) 12%, Monster(파랑) 46%,
#     Battle 계열(하늘색) 80~99%, System 20~35% — 전부 이미지 테두리를 100% 가깝게 두른다.
#   - 배경 그림 부류: Backdrop 0%, FaceSet 0%, Title 0.5%, Panorama는 파일에 따라 86%가
#     실제 하늘색이다. 여기서 0번을 뚫으면 그림에 구멍이 난다.
# 그래서 전자만 투명 처리한다. 모르는 카테고리는 안전한 쪽(불투명)으로 둔다.
CATEGORIES = {
    "Backdrop":      Category(False, (320, 240), "전투 배경 — 화면을 꽉 채우는 그림"),
    "Battle":        Category(True,  None,       "전투 애니메이션 — 키 컬러 배경"),
    "Battle2":       Category(True,  None,       "전투 애니메이션(2) — 키 컬러 배경"),
    "BattleCharSet": Category(True,  (144, 384), "전투용 캐릭터 — 키 컬러 배경"),
    "BattleWeapon":  Category(True,  (192, 512), "전투용 무기 — 키 컬러 배경"),
    "CharSet":       Category(True,  (288, 256), "맵 위 캐릭터 — 키 컬러 배경"),
    "ChipSet":       Category(True,  (480, 256), "타일셋 — 유일하게 tRNS가 들어 있다"),
    "FaceSet":       Category(True,  (192, 192), "얼굴 — RTP 5장은 0번을 한 픽셀도 쓰지 않는다"),
    "Frame":         Category(True,  None,       "화면 테두리 — 가운데가 뚫려야 한다"),
    "GameOver":      Category(False, (320, 240), "게임 오버 화면 — 배경 그림"),
    "Monster":       Category(True,  None,       "몬스터 — 키 컬러 배경, 크기 제각각"),
    "Panorama":      Category(False, None,       "원경 — 0번이 실제 하늘색인 파일이 있다"),
    "Picture":       Category(False, None,       "이벤트 그림 — 투명 여부는 이벤트가 정한다"),
    "System":        Category(True,  (160, 80),  "대화창 스킨 — 창 밖이 비어야 한다"),
    "System2":       Category(True,  (80, 96),   "전투 UI 스킨 — 키 컬러 배경"),
    "Title":         Category(False, (320, 240), "타이틀 화면 — 배경 그림"),
    "Music":         Category(False, None, "BGM — MIDI 141개와 WAV 10개", kind="audio"),
    "Sound":         Category(False, None, "효과음 — WAV", kind="audio"),
}
UNKNOWN_CATEGORY = Category(False, None, "정책 미지정 — 안전하게 불투명 처리")

AUDIO_EXTS = {".wav", ".mid", ".midi"}
IMAGE_EXTS = {".png"}

# 팔레트 인덱스 → 알파. 0번만 0, 나머지는 255.
ALPHA_LUT = bytes([0] + [255] * 255)


def log(msg):
    print(msg, flush=True)


def normalized(name, normalize):
    return name.replace(" ", "_") if normalize else name


def convert_image(raw, transparent):
    """팔레트 PNG 바이트 → (RGBA Image, 투명 픽셀 수).

    투명 픽셀의 RGB는 0으로 지운다. 키 컬러(형광 초록, 마젠타)를 남겨 두면 나중에
    선형 보간으로 확대할 때 가장자리에 그 색이 번진다.
    """
    with Image.open(raw) as src:
        src.load()
        if src.mode != "P":
            # 팔레트가 아닌 파일은 그대로 RGBA로 (RTP에는 없지만 방어적으로)
            return src.convert("RGBA"), 0
        if not transparent:
            return src.convert("RGBA"), 0

        alpha = Image.frombytes("L", src.size, src.tobytes().translate(ALPHA_LUT))
        # 마스크가 0/255뿐이라 composite 한 번으로 RGB와 알파가 동시에 정리된다:
        # 불투명한 곳은 원본 색, 투명한 곳은 (0,0,0,0).
        empty = Image.new("RGBA", src.size, (0, 0, 0, 0))
        rgba = Image.composite(src.convert("RGBA"), empty, alpha)
        return rgba, src.histogram()[0]


def run_tool(cmd, what):
    try:
        proc = subprocess.run(cmd, capture_output=True)
    except FileNotFoundError:
        sys.exit(f"{what}: '{cmd[0]}' 를 찾을 수 없습니다.")
    if proc.returncode != 0:
        tail = proc.stderr.decode("utf-8", "replace").strip().splitlines()[-3:]
        sys.exit(f"{what} 실패 (exit {proc.returncode}):\n  " + "\n  ".join(tail))


def wav_to_ogg(src_path, dst_path):
    run_tool(["ffmpeg", "-y", "-loglevel", "error", "-i", src_path,
              "-c:a", "libvorbis", "-q:a", "4", dst_path], "WAV → OGG 변환")


def midi_to_ogg(src_path, dst_path, soundfont):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "render.wav")
        run_tool(["fluidsynth", "-ni", "-g", "0.8", "-r", "44100", "-F", wav,
                  soundfont, src_path], "MIDI 렌더링(fluidsynth)")
        wav_to_ogg(wav, dst_path)


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as fp:
        for chunk in iter(lambda: fp.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def import_rtp(args):
    if not os.path.exists(args.zip):
        sys.exit(f"RTP 아카이브가 없습니다: {args.zip}\n"
                 "RPG Maker 2003 정품의 RTP를 resources/RTP.zip 으로 두고 다시 실행하세요.")

    only = set(x.strip() for x in args.only.split(",")) if args.only else None
    manifest = {
        "tool": "tools/rtp_import.py",
        "formatVersion": MANIFEST_VERSION,
        "source": {
            "zip": os.path.relpath(args.zip, REPO),
            "bytes": os.path.getsize(args.zip),
            "sha256": sha256_of(args.zip),
        },
        "options": {
            "normalizeNames": args.normalize_names,
            "ogg": args.ogg,
            "soundfont": os.path.basename(args.soundfont) if args.soundfont else None,
        },
        "categories": {},
    }

    skipped_midi = 0
    unknown = set()

    with zipfile.ZipFile(args.zip) as zf:
        entries = [e for e in zf.namelist() if not e.endswith("/")]
        for entry in sorted(entries):
            parts = entry.split("/")
            if len(parts) != 2:
                continue  # 루트의 icon.ico 등 카테고리 밖 파일은 다루지 않는다
            category, filename = parts
            if only is not None and category not in only:
                continue
            ext = os.path.splitext(filename)[1].lower()
            if ext not in IMAGE_EXTS and ext not in AUDIO_EXTS:
                continue
            if ext in (".mid", ".midi") and not args.soundfont:
                # 기본값은 "MIDI를 쓰지 않는다"다 (docs/plans/04-resources.md의 2안).
                skipped_midi += 1
                continue

            spec = CATEGORIES.get(category)
            if spec is None:
                spec = UNKNOWN_CATEGORY
                unknown.add(category)

            bucket = manifest["categories"].setdefault(category, {
                "kind": spec.kind,
                "transparent": spec.transparent,
                "expectSize": list(spec.size) if spec.size else None,
                "note": spec.note,
                "files": [],
            })

            out_dir = os.path.join(args.out, category)
            os.makedirs(out_dir, exist_ok=True)
            out_name = normalized(filename, args.normalize_names)

            if ext in IMAGE_EXTS:
                with zf.open(entry) as fp:
                    image, transparent_px = convert_image(fp, spec.transparent)
                out_path = os.path.join(out_dir, out_name)
                image.save(out_path, "PNG", optimize=True)
                if spec.size and image.size != spec.size:
                    log(f"  주의: {entry} 크기 {image.size} != 규격 {spec.size}")
                bucket["files"].append({
                    "name": out_name,
                    "w": image.size[0],
                    "h": image.size[1],
                    "alpha0": transparent_px,
                })
                image.close()
                continue

            # 오디오
            if ext in (".mid", ".midi"):
                out_name = os.path.splitext(out_name)[0] + ".ogg"
                with tempfile.TemporaryDirectory() as tmp:
                    mid = os.path.join(tmp, "in.mid")
                    with open(mid, "wb") as dst:
                        dst.write(zf.read(entry))
                    midi_to_ogg(mid, os.path.join(out_dir, out_name), args.soundfont)
            elif args.ogg:
                out_name = os.path.splitext(out_name)[0] + ".ogg"
                with tempfile.TemporaryDirectory() as tmp:
                    wav = os.path.join(tmp, "in.wav")
                    with open(wav, "wb") as dst:
                        dst.write(zf.read(entry))
                    wav_to_ogg(wav, os.path.join(out_dir, out_name))
            else:
                with zf.open(entry) as fp, open(os.path.join(out_dir, out_name), "wb") as dst:
                    shutil.copyfileobj(fp, dst)

            bucket["files"].append({
                "name": out_name,
                "bytes": os.path.getsize(os.path.join(out_dir, out_name)),
            })

    os.makedirs(args.out, exist_ok=True)
    manifest_path = os.path.join(args.out, MANIFEST_NAME)
    if only is not None and os.path.exists(manifest_path):
        # 일부만 다시 변환했다면 이번에 건드리지 않은 카테고리의 기록은 남겨 둔다.
        # (매니페스트는 검증의 계약이라 통째로 갈아치우면 나머지가 검증에서 빠진다)
        with open(manifest_path, encoding="utf-8") as fp:
            previous = json.load(fp)
        if previous.get("formatVersion") == MANIFEST_VERSION:
            merged = dict(previous["categories"])
            merged.update(manifest["categories"])
            manifest["categories"] = merged

    with open(manifest_path, "w", encoding="utf-8") as fp:
        json.dump(manifest, fp, ensure_ascii=False, indent=2, sort_keys=True)
        fp.write("\n")

    out_display = os.path.relpath(args.out, REPO)
    if out_display.startswith(".."):
        out_display = args.out
    log("")
    log(f"변환 완료 → {out_display}/")
    for category in sorted(manifest["categories"]):
        bucket = manifest["categories"][category]
        if bucket["kind"] == "audio":
            mark = "오디오"
        else:
            mark = "투명" if bucket["transparent"] else "불투명"
        log(f"  {category:<14} {len(bucket['files']):>4}개  {mark}")
    if skipped_midi:
        log(f"  (MIDI {skipped_midi}개는 건너뜀 — 변환하려면 --soundfont 경로.sf2)")
    if unknown:
        log(f"  (정책이 없는 카테고리를 불투명으로 처리함: {', '.join(sorted(unknown))})")
    log("")
    log("검증: python3 tests/verify_rtp.py")


def main():
    parser = argparse.ArgumentParser(
        description="RPG Maker 2003 RTP를 Initial2D가 쓰는 형태로 변환한다.")
    parser.add_argument("--zip", default=DEFAULT_ZIP, help="RTP 아카이브 (기본: resources/RTP.zip)")
    parser.add_argument("--out", default=DEFAULT_OUT, help="출력 폴더 (기본: resources/rtp)")
    parser.add_argument("--only", help="카테고리 일부만 변환 (쉼표 구분: CharSet,ChipSet)")
    parser.add_argument("--ogg", action="store_true", help="WAV를 OGG로 변환한다 (ffmpeg 필요)")
    parser.add_argument("--soundfont", help="MIDI를 OGG로 변환할 사운드폰트(.sf2) 경로 (fluidsynth 필요)")
    parser.add_argument("--normalize-names", action="store_true",
                        help="파일명의 공백을 언더스코어로 바꾼다")
    import_rtp(parser.parse_args())


if __name__ == "__main__":
    main()
