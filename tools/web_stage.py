#!/usr/bin/env python3
"""웹 빌드용 프로젝트 파일 스테이징 (R3, docs/plans/r3-emscripten.md).

프로젝트의 game.json, scripts/lua/**, resources/** 를 사이트 폴더의 project/ 아래에 복사하고
목록을 project.json 으로 쓴다. 페이지(tools/web/index.html)는 이 목록을 fetch 해 MEMFS 에 올린다.

    python3 tools/web_stage.py --out build-web/site            # 이 저장소를 스테이징
    python3 tools/web_stage.py --project ~/mygame --out site   # 다른 프로젝트

빼는 것: resources/RTP.zip 과 resources/rtp/ (재배포 금지 소재), *.psd (원본), 닷파일,
resources/aldebaran/src/gpt/ (GPT 이미지 원본, 게임이 읽지 않는다). 표준 라이브러리만 쓴다.
"""
import argparse
import json
import os
import shutil
import sys

EXCLUDED_DIRS = {
    os.path.join("resources", "rtp"),
    os.path.join("resources", "aldebaran", "src", "gpt"),
}
EXCLUDED_FILES = {
    os.path.join("resources", "RTP.zip"),
}
EXCLUDED_SUFFIXES = (".psd",)


def wanted(rel):
    parts = rel.split(os.sep)
    if any(p.startswith(".") for p in parts):
        return False
    if rel in EXCLUDED_FILES or rel.lower().endswith(EXCLUDED_SUFFIXES):
        return False
    for d in EXCLUDED_DIRS:
        if rel == d or rel.startswith(d + os.sep):
            return False
    return True


def collect(project):
    files = []
    if os.path.isfile(os.path.join(project, "game.json")):
        files.append("game.json")
    for top in (os.path.join("scripts", "lua"), "resources"):
        base = os.path.join(project, top)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames.sort()
            for name in sorted(filenames):
                rel = os.path.relpath(os.path.join(dirpath, name), project)
                if wanted(rel):
                    files.append(rel)
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", default=os.path.join(os.path.dirname(__file__), ".."),
                        help="프로젝트 루트 (기본: 이 저장소)")
    parser.add_argument("--out", required=True, help="사이트 폴더 (project/ 와 project.json 을 여기에 만든다)")
    args = parser.parse_args()

    project = os.path.abspath(args.project)
    out = os.path.abspath(args.out)
    files = collect(project)
    if not files:
        print(f"web_stage: {project} 에 스테이징할 파일이 없습니다", file=sys.stderr)
        return 1

    target = os.path.join(out, "project")
    if os.path.isdir(target):
        shutil.rmtree(target)
    total = 0
    for rel in files:
        src = os.path.join(project, rel)
        dst = os.path.join(target, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        total += os.path.getsize(src)

    manifest = {
        "version": 1,
        "root": "project",
        "generatedBy": "tools/web_stage.py",
        "files": [rel.replace(os.sep, "/") for rel in files],
    }
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "project.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"web_stage: {len(files)} files, {total / 1024 / 1024:.1f} MB -> {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
