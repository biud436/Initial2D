#!/usr/bin/env python3
"""배포용 엔진의 판 정보 dist/engine-dist.json 을 쓴다 (R4, docs/plans/r4-dist-build.md).

    python3 tools/engine_dist_json.py add --dist DIR --target TRIPLE --file EXE --version LINE --features WORDS
    python3 tools/engine_dist_json.py merge OUT IN...

add 는 tools/build_dist.sh 가 부른다. 같은 커밋의 engine-dist.json 이 이미 있으면 다른 타깃의 항목을 이어받고,
커밋이 다르면 새로 쓴다. merge 는 CI 가 타깃마다 만든 파일을 하나로 합친다 (커밋이 다르면 실패).

모양:
    {
      "comment": ...,
      "engineTag": "v2.0.0-alpha.1" 또는 null (HEAD 에 v2 이상의 태그가 없거나 빌드가 dirty 일 때),
      "describe": "git describe 결과",
      "engineCommit": "커밋 40자",
      "native": { "<트리플>": { "asset": "Initial2D-<트리플>", "size": 바이트, "sha256": ..., "features": [...] } }
    }
표준 라이브러리만 쓴다.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

NAME = "engine-dist.json"
COMMENT = "tools/build_dist.sh 가 쓴다. 손으로 고치지 않는다. describe 와 engineCommit 은 실행 파일의 --version 에서 온다"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_version(line):
    """'Initial2D <describe> <commit>' 을 (describe, commit) 으로."""
    m = re.fullmatch(r"Initial2D (\S+) ([0-9a-f]{40})", line.strip())
    if not m:
        raise SystemExit("--version 줄의 모양이 다르다: %r (Initial2D <describe> <커밋 40자>)" % line)
    return m.group(1), m.group(2)


def tag_at(commit, describe):
    """커밋을 가리키는 v2 이상의 태그. dirty 빌드거나 태그가 없으면 None."""
    if describe.endswith("-dirty"):
        return None
    try:
        out = subprocess.run(["git", "-C", REPO, "tag", "--points-at", commit, "--list", "v[2-9]*"],
                             capture_output=True, text=True, check=True).stdout.split()
    except (OSError, subprocess.CalledProcessError):
        return None
    if describe in out:
        return describe
    return sorted(out)[-1] if out else None


def write(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def cmd_add(args):
    describe, commit = parse_version(args.version)
    features = args.features.split()
    path = os.path.join(args.dist, NAME)
    data = None
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            old = json.load(f)
        if old.get("engineCommit") == commit and old.get("describe") == describe:
            data = old
    if data is None:
        data = {"comment": COMMENT, "engineTag": tag_at(commit, describe), "describe": describe,
                "engineCommit": commit, "native": {}}
    data["native"][args.target] = {
        "asset": os.path.basename(args.file),
        "size": os.path.getsize(args.file),
        "sha256": sha256_file(args.file),
        "features": features,
    }
    data["native"] = dict(sorted(data["native"].items()))
    write(path, data)
    print("%s: %s %s" % (path, args.target, data["native"][args.target]["sha256"]))
    return 0


def cmd_merge(args):
    merged = None
    for src in args.inputs:
        with open(src, encoding="utf-8") as f:
            data = json.load(f)
        if merged is None:
            merged = data
            continue
        for key in ("engineCommit", "describe", "engineTag"):
            if data.get(key) != merged.get(key):
                raise SystemExit("%s: %s 가 다르다 (%r, 앞의 파일은 %r)" % (src, key, data.get(key), merged.get(key)))
        for target, entry in data["native"].items():
            if target in merged["native"] and merged["native"][target] != entry:
                raise SystemExit("%s: 타깃 %s 가 두 번 나오고 내용이 다르다" % (src, target))
            merged["native"][target] = entry
    merged["native"] = dict(sorted(merged["native"].items()))
    write(args.out, merged)
    print("%s: %s" % (args.out, ", ".join(merged["native"])))
    return 0


def main(argv):
    p = argparse.ArgumentParser(description="dist/engine-dist.json")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add")
    a.add_argument("--dist", required=True)
    a.add_argument("--target", required=True)
    a.add_argument("--file", required=True)
    a.add_argument("--version", required=True)
    a.add_argument("--features", required=True)
    m = sub.add_parser("merge")
    m.add_argument("out")
    m.add_argument("inputs", nargs="+")
    args = p.parse_args(argv)
    return cmd_add(args) if args.cmd == "add" else cmd_merge(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
