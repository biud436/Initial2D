#!/usr/bin/env python3
"""안드로이드 에셋 스테이징의 파일 목록 (android/prepare_assets.sh --project 가 부른다).

    python3 tools/stage_list.py --project <폴더> [--with-rtp]                 목록을 한 줄에 하나씩
    python3 tools/stage_list.py --project <폴더> [--with-rtp] --count         files=<n> bytes=<b> rtp=<yes|no>
    python3 tools/stage_list.py --project <폴더> [--with-rtp] --stage <폴더>  복사하고 스탬프를 쓴다.
                                                                               마지막 줄 files=<n> bytes=<b> rtp=<yes|no> stamp=<12자>

규칙은 tools/stage_rules.json 한 장이다: 프로젝트의 game.json, db.sqlite 와 scripts/, resources/ 아래 파일 가운데
exclude 표에 걸리지 않는 것. 경로는 늘 / 로 나눈다. warn 이 참인 규칙에 걸린 파일은 stderr 에 WARN 줄을 남긴다.
--stage 는 대상 폴더가 비어 있다고 보고(셸이 비운다) 파일을 복사한 뒤 assets_stamp/<스탬프>.txt 를 쓴다.
스탬프는 (경로, sha256) 을 경로 순으로 해시한 앞 12자라, 파일 목록이 같아도 내용이 바뀌면 달라진다.
종료 코드: 0 성공, 1 입출력 오류, 2 인자나 프로젝트 오류. 표준 라이브러리만 쓴다.
"""

import argparse
import hashlib
import json
import os
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_RULES = os.path.join(REPO, "tools", "stage_rules.json")
STAMP_DIR = "assets_stamp"


def aapt_patterns(value):
    """AAPT 의 ignoreAssetsPattern 문자열을 (종류, 모양) 목록으로. 종류는 any, dir, file"""
    out = []
    for token in value.split(":"):
        token = token.strip()
        if token.startswith("!"):
            token = token[1:]
        kind = "any"
        if token.startswith("<dir>"):
            kind, token = "dir", token[len("<dir>"):]
        elif token.startswith("<file>"):
            kind, token = "file", token[len("<file>"):]
        if token:
            out.append((kind, token.lower()))
    return out


def aapt_match(name, is_dir, patterns):
    """이름 하나가 AAPT 규칙에 걸리는가. 앞의 * 는 끝이 같음, 뒤의 * 는 앞이 같음, 그 밖은 같은 이름 (대소문자 무시)"""
    low = name.lower()
    for kind, pat in patterns:
        if kind == "dir" and not is_dir:
            continue
        if kind == "file" and is_dir:
            continue
        if pat.startswith("*"):
            if low.endswith(pat[1:]):
                return True
        elif pat.endswith("*"):
            if low.startswith(pat[:-1]):
                return True
        elif low == pat:
            return True
    return False


class Rules:
    def __init__(self, data, with_rtp):
        self.root_files = list(data["rootFiles"])
        self.root_dirs = list(data["rootDirs"])
        self.rules = []
        for rule in data["exclude"]:
            if rule.get("withRtp") and with_rtp:
                continue
            rule = dict(rule)
            if rule["kind"] == "aapt":
                rule["patterns"] = aapt_patterns(rule["value"])
            self.rules.append(rule)

    def excluded_by(self, rel):
        """rel 을 빼는 규칙 (없으면 None). rel 은 / 로 나눈 상대 경로이고 마지막 조각이 파일이다"""
        parts = rel.split("/")
        name = parts[-1]
        for rule in self.rules:
            kind, value = rule["kind"], rule["value"]
            if kind == "name-prefix":
                hit = any(p.startswith(value) for p in parts)
            elif kind == "dir":
                prefix = value.split("/")
                hit = len(parts) > len(prefix) and parts[:len(prefix)] == prefix
            elif kind == "suffix":
                hit = name.lower().endswith(value.lower())
            elif kind == "name":
                hit = name == value
            elif kind == "aapt":
                hit = aapt_match(name, False, rule["patterns"]) or any(aapt_match(p, True, rule["patterns"]) for p in parts[:-1])
            else:
                raise ValueError(f"모르는 규칙 종류: {kind}")
            if hit:
                return rule
        return None


def load_rules(path, with_rtp):
    with open(path, encoding="utf-8") as f:
        return Rules(json.load(f), with_rtp)


def collect(project, rules):
    """(목록, 경고 [(경로, 규칙)]). 목록은 경로 순"""
    files, warned = [], []

    def consider(rel):
        rule = rules.excluded_by(rel)
        if rule is None:
            files.append(rel)
        elif rule.get("warn"):
            warned.append((rel, rule))

    for name in rules.root_files:
        if os.path.isfile(os.path.join(project, name)):
            consider(name)
    for top in rules.root_dirs:
        base = os.path.join(project, top)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames.sort()
            for name in sorted(filenames):
                full = os.path.join(dirpath, name)
                if not os.path.isfile(full):
                    continue
                consider(os.path.relpath(full, project).replace(os.sep, "/"))
    files.sort()
    return files, warned


def file_sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def stamp_of(root, files):
    """(경로, sha256) 을 경로 순으로 해시한 값 (64자). 복사한 쪽을 읽는다"""
    h = hashlib.sha256()
    for rel in sorted(files):
        h.update(rel.encode("utf-8") + b"\0" + file_sha256(os.path.join(root, *rel.split("/"))).encode("ascii") + b"\n")
    return h.hexdigest()


def is_rtp(rel):
    return rel.startswith("resources/rtp/")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", required=True, help="프로젝트 폴더 (game.json 이 있어야 한다)")
    parser.add_argument("--with-rtp", action="store_true", help="resources/rtp/ 를 넣는다 (개인 기기 시험)")
    parser.add_argument("--rules", default=DEFAULT_RULES, help="규칙 파일 (기본 tools/stage_rules.json)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--count", action="store_true", help="파일 수와 크기만 한 줄로")
    mode.add_argument("--stage", metavar="DEST", help="이 폴더로 복사하고 스탬프를 쓴다")
    args = parser.parse_args(argv)

    project = os.path.abspath(args.project)
    if not os.path.isfile(os.path.join(project, "game.json")):
        print(f"stage_list: game.json 이 없다: {project}", file=sys.stderr)
        return 2
    try:
        rules = load_rules(args.rules, args.with_rtp)
    except (OSError, ValueError, KeyError) as e:
        print(f"stage_list: 규칙 파일을 읽지 못했다 ({args.rules}): {e}", file=sys.stderr)
        return 2

    try:
        files, warned = collect(project, rules)
        for rel, rule in warned:
            print(f"WARN {rule['id']}: {rel} 는 APK 에 들어가지 않는 이름이라 뺐다", file=sys.stderr)
        rtp = "yes" if any(is_rtp(rel) for rel in files) else "no"
        if not args.count and not args.stage:
            for rel in files:
                print(rel)
            return 0
        total = sum(os.path.getsize(os.path.join(project, rel)) for rel in files)
        summary = f"files={len(files)} bytes={total} rtp={rtp}"
        if args.count:
            print(summary)
            return 0
        dest = os.path.abspath(args.stage)
        for rel in files:
            target = os.path.join(dest, *rel.split("/"))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.copyfile(os.path.join(project, rel), target)
        digest = stamp_of(dest, files)
        stamp = digest[:12]
        os.makedirs(os.path.join(dest, STAMP_DIR), exist_ok=True)
        with open(os.path.join(dest, STAMP_DIR, f"{stamp}.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write(f"{digest}\n")
        print(f"{summary} stamp={stamp}")
        return 0
    except OSError as e:
        print(f"stage_list: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
