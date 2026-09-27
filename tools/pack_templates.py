#!/usr/bin/env python3
"""템플릿 묶음 dist/Initial2D-templates.zip 을 만든다 (R4, docs/plans/r4-dist-build.md).

    python3 tools/pack_templates.py [--list tools/templates_list.txt] [--out dist/Initial2D-templates.zip] [--allow-dirty]

목록(tools/templates_list.txt)의 엔진 경로를 그 경로 그대로 zip 에 넣고, 맨 앞에 MANIFEST.json 을 둔다:
    { "engineCommit": 커밋 40자, "describe": ..., "files": [ { "path", "size", "sha256", "generated" } ] }
generated 는 git ls-files 에 없는 파일(플래피 그림 넷처럼 도구가 만드는 생성물)이다.

실패 (종료 코드 1):
  - 목록의 파일이 하나라도 없다
  - 목록의 추적 파일이 HEAD 와 다르다 (--allow-dirty 면 MANIFEST 에 "dirty": true 로 적고 계속한다)
zip 안의 날짜와 권한은 고정이라 같은 파일이면 같은 바이트가 나온다. 표준 라이브러리만 쓴다.
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_LIST = os.path.join(REPO, "tools", "templates_list.txt")
DEFAULT_OUT = os.path.join(REPO, "dist", "Initial2D-templates.zip")
COMMENT = ("tools/pack_templates.py 가 만든다. path 는 엔진 저장소 안의 경로, "
           "generated 는 git 이 추적하지 않는 생성물 (tools/generate_placeholder_assets.py)")
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def git(*args):
    return subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True, check=True).stdout


def read_list(path):
    paths = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                paths.append(line)
    dup = sorted({p for p in paths if paths.count(p) > 1})
    if dup:
        raise SystemExit("목록에 두 번 나오는 경로: " + ", ".join(dup))
    return paths


def add(zf, name, data):
    info = zipfile.ZipInfo(name, date_time=FIXED_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    zf.writestr(info, data)


def main(argv):
    p = argparse.ArgumentParser(description="dist/Initial2D-templates.zip")
    p.add_argument("--list", default=DEFAULT_LIST)
    p.add_argument("--out", default=DEFAULT_OUT)
    p.add_argument("--allow-dirty", action="store_true")
    args = p.parse_args(argv)

    paths = read_list(args.list)
    missing = [rel for rel in paths if not os.path.isfile(os.path.join(REPO, rel))]
    if missing:
        for rel in missing:
            print("  없음  " + rel, file=sys.stderr)
        print("pack_templates: 목록의 파일 %d개가 없다 (생성물이면 python3 tools/generate_placeholder_assets.py)"
              % len(missing), file=sys.stderr)
        return 1

    tracked = set(git("ls-files", "-z", "--", *paths).split("\0")) - {""}
    changed = [line[3:] for line in git("status", "--porcelain", "--", *sorted(tracked)).splitlines()]
    if changed and not args.allow_dirty:
        for rel in changed:
            print("  바뀜  " + rel, file=sys.stderr)
        print("pack_templates: 목록의 추적 파일이 HEAD 와 다르다 (커밋하거나 --allow-dirty)", file=sys.stderr)
        return 1

    files = []
    blobs = []
    for rel in paths:
        with open(os.path.join(REPO, rel), "rb") as f:
            data = f.read()
        files.append({"path": rel, "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                      "generated": rel not in tracked})
        blobs.append((rel, data))

    manifest = {
        "comment": COMMENT,
        "engineCommit": git("rev-parse", "HEAD").strip(),
        "describe": git("describe", "--tags", "--always", "--dirty", "--match", "v[2-9]*").strip(),
        "files": files,
    }
    if changed:
        manifest["dirty"] = True

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    tmp = args.out + ".tmp"
    with zipfile.ZipFile(tmp, "w") as zf:
        add(zf, "MANIFEST.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        for rel, data in blobs:
            add(zf, rel, data)
    os.replace(tmp, args.out)

    generated = [f["path"] for f in files if f["generated"]]
    total = sum(f["size"] for f in files)
    print("%s: 파일 %d개, %d KB, 엔진 %s" % (os.path.relpath(args.out), len(files), total // 1024,
                                            manifest["engineCommit"]))
    for rel in generated:
        print("  생성물  " + rel)
    for rel in changed:
        print("  바뀜    " + rel)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
