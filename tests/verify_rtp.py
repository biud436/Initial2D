#!/usr/bin/env python3
"""RTP 변환 결과(resources/rtp/) 검증 — 4단계 자동 검수 (docs/plans/09-testing.md 7절).

무엇을 보는가:
  1. manifest.json이 있고 포맷 버전이 맞는가 (tools/rtp_import.py의 출력 계약)
  2. 매니페스트에 적힌 파일이 전부 실제로 있고, 크기와 투명 픽셀 수가 일치하는가
  3. 카테고리 규격 크기가 맞는가 (CharSet 288x256 등)
  4. 투명 카테고리는 투명 픽셀이 있고, 불투명 카테고리는 하나도 없는가
  5. 변환 결과물이 git 상태에 나타나지 않는가 (라이선스상 커밋 금지)

RTP는 정품 보유자의 로컬 자산이라 CI와 대부분의 개발 환경에는 없다. 그래서
resources/rtp/가 없으면 SKIP을 알리고 통과시킨다 — 없다는 사실 자체는 실패가 아니다.
다만 3번(gitignore)만은 폴더 없이도 확인한다.

사용법: python3 tests/verify_rtp.py
exit code: 0 = 통과 또는 건너뜀, 1 = 실패
"""

import json
import os
import subprocess
import sys
import zipfile

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTP_DIR = os.path.join(REPO, "resources", "rtp")
MANIFEST = os.path.join(RTP_DIR, "manifest.json")
MANIFEST_VERSION = 1

FAILS = []
CHECKED = 0


def check(cond, name, detail=""):
    global CHECKED
    CHECKED += 1
    if not cond:
        FAILS.append(name)
        print(f"  FAIL  {name}  {detail}")
    return cond


def verify_gitignore():
    """resources/rtp/ 와 RTP.zip 이 git에 잡히지 않는지 확인한다 (폴더가 없어도 검사)."""
    for path in ("resources/RTP.zip", "resources/rtp/CharSet/Actor1.png"):
        proc = subprocess.run(["git", "check-ignore", "-q", path], cwd=REPO)
        check(proc.returncode == 0, f"gitignore: {path}", "git이 추적 대상으로 본다")

    proc = subprocess.run(["git", "status", "--porcelain", "resources"],
                          cwd=REPO, capture_output=True, text=True)
    dirty = [line for line in proc.stdout.splitlines() if "resources/rtp" in line]
    check(not dirty, "git status에 변환 결과물이 없다", "; ".join(dirty[:3]))


def verify_category(category, bucket):
    expect = tuple(bucket["expectSize"]) if bucket["expectSize"] else None
    transparent = bucket["transparent"]
    for entry in bucket["files"]:
        path = os.path.join(RTP_DIR, category, entry["name"])
        rel = f"{category}/{entry['name']}"
        if bucket["kind"] == "audio":
            if not check(os.path.exists(path), f"{rel} 존재"):
                continue
            check(os.path.getsize(path) == entry["bytes"], f"{rel} 크기",
                  f"{os.path.getsize(path)} != {entry['bytes']}")
            continue

        if not check(os.path.exists(path), f"{rel} 존재"):
            continue
        with Image.open(path) as im:
            check(im.mode == "RGBA", f"{rel} 32비트 RGBA", f"mode={im.mode}")
            check(im.size == (entry["w"], entry["h"]), f"{rel} 크기",
                  f"{im.size} != {(entry['w'], entry['h'])}")
            if expect:
                check(im.size == expect, f"{rel} 규격 {expect}", f"실제 {im.size}")
            alpha0 = im.getchannel("A").histogram()[0]
        check(alpha0 == entry["alpha0"], f"{rel} 투명 픽셀 수",
              f"{alpha0} != {entry['alpha0']} (매니페스트)")
        if not transparent:
            # 배경 그림에 구멍이 뚫리지 않았는지 — tRNS가 있는 파일이 섞여 들어와도 잡힌다
            check(alpha0 == 0, f"{rel} 불투명하다", f"투명 픽셀 {alpha0}개")


def verify_against_source(zf, category, bucket, normalize):
    """원본 zip과 픽셀 단위로 대조한다 (카테고리마다 첫 파일 한 장).

    매니페스트 대조만으로는 "변환기가 만든 값과 변환기가 적은 값이 같다"는 동어반복이라,
    여기서는 팔레트를 직접 들여다보며 독립적으로 기대값을 만든다:
      팔레트 0번이면 (0,0,0,0), 아니면 팔레트 색 + 알파 255.
    """
    sources = {}
    for entry in zf.namelist():
        parts = entry.split("/")
        if len(parts) == 2 and parts[0] == category and parts[1].lower().endswith(".png"):
            name = parts[1].replace(" ", "_") if normalize else parts[1]
            sources[name] = entry

    for file_entry in bucket["files"][:1]:
        name = file_entry["name"]
        rel = f"{category}/{name}"
        if name not in sources:
            check(False, f"{rel} 원본 대조", "zip에서 원본을 찾지 못했다")
            continue
        with zf.open(sources[name]) as fp, Image.open(fp) as src:
            src.load()
            if src.mode != "P":
                continue
            palette = src.getpalette()
            indices = src.tobytes()
        with Image.open(os.path.join(RTP_DIR, category, name)) as out:
            got = out.convert("RGBA").tobytes()

        if not check(len(indices) * 4 == len(got), f"{rel} 픽셀 수 일치"):
            continue
        bad = 0
        for i, ix in enumerate(indices):
            if bucket["transparent"] and ix == 0:
                expect = (0, 0, 0, 0)
            else:
                expect = (palette[ix * 3], palette[ix * 3 + 1], palette[ix * 3 + 2], 255)
            if tuple(got[i * 4:i * 4 + 4]) != expect:
                bad += 1
        check(bad == 0, f"{rel} 원본 팔레트와 픽셀 단위 일치", f"어긋난 픽셀 {bad}개")


def main():
    verify_gitignore()

    if not os.path.exists(MANIFEST):
        print(f"  SKIP  resources/rtp/ 가 없습니다 — RTP 변환 검증을 건너뜁니다")
        print("        (정품 보유자만 python3 tools/rtp_import.py 로 생성한다)")
    else:
        with open(MANIFEST, encoding="utf-8") as fp:
            manifest = json.load(fp)
        check(manifest.get("formatVersion") == MANIFEST_VERSION, "매니페스트 포맷 버전",
              f"{manifest.get('formatVersion')} != {MANIFEST_VERSION}")
        categories = manifest.get("categories", {})
        check(bool(categories), "변환된 카테고리가 있다")
        for category in sorted(categories):
            verify_category(category, categories[category])

        source_zip = os.path.join(REPO, manifest["source"]["zip"])
        if os.path.exists(source_zip):
            normalize = manifest["options"]["normalizeNames"]
            with zipfile.ZipFile(source_zip) as zf:
                for category in sorted(categories):
                    if categories[category]["kind"] == "image":
                        verify_against_source(zf, category, categories[category], normalize)
        else:
            print(f"  SKIP  원본 대조 — {manifest['source']['zip']} 가 없습니다")

    print("")
    if FAILS:
        print(f"RTP 검증 실패: {len(FAILS)} / {CHECKED}")
        return 1
    print(f"RTP 검증 통과: {CHECKED}건")
    return 0


if __name__ == "__main__":
    sys.exit(main())
