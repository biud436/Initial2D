#!/usr/bin/env bash
# LuaLS 로 저장소의 Lua 스크립트를 검사한다. 규칙은 .luarc.json 이고(tools/gen_api_stubs.py 가 쓴다),
# 경고 이상의 진단이 하나라도 있으면 그 목록을 찍고 종료 코드 1 로 끝낸다. 힌트(쓰지 않는 지역 변수 등)는 세지 않는다.
#
#   tools/check_luals.sh                                   LuaLS 를 받아 build/luals/<판> 에 두고 쓴다
#   LUALS=/path/to/bin/lua-language-server tools/check_luals.sh   설치된 것을 쓴다
#
# 새 프로젝트 템플릿의 Lua 스크립트(RPG 레이어, 씬 로더, 플래피 컴포넌트)가 모두 scripts/lua 에 있으므로
# 이 검사가 통과하면 에디터의 기본 진단도 새 프로젝트에서 아무것도 표시하지 않는다.
set -euo pipefail

VERSION=3.19.1
REPO="$(cd "$(dirname "$0")/.." && pwd)"

asset_for_host() {
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) echo "darwin-arm64 0bc077f4447f076b4c92c14e9fd303f5b569eda2ec74b4dca2b55f75fae2e90c" ;;
    Darwin-x86_64) echo "darwin-x64 eb373c159cbe556711d7cd316315de2dce969bfd54b31edb7eb9cab2937f2cca" ;;
    Linux-x86_64) echo "linux-x64 e9235d2d72ef55bc41cf8c99cda2ed64777682024b4bb81f5dea425060c5cbb8" ;;
    Linux-aarch64) echo "linux-arm64 abd2572e8fc929dc838a81ffb8473c5bce0bf39bfe8edb4b120b3b623176ce83" ;;
    *) echo "" ;;
  esac
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

if [ -z "${LUALS:-}" ]; then
  read -r PLATFORM SHA <<<"$(asset_for_host)"
  if [ -z "${PLATFORM:-}" ]; then
    echo "이 기계($(uname -s) $(uname -m))용 LuaLS 판을 모른다. LUALS 로 실행 파일을 준다" >&2
    exit 2
  fi
  DIR="$REPO/build/luals/$VERSION-$PLATFORM"
  LUALS="$DIR/bin/lua-language-server"
  if [ ! -x "$LUALS" ]; then
    NAME="lua-language-server-$VERSION-$PLATFORM.tar.gz"
    URL="https://github.com/LuaLS/lua-language-server/releases/download/$VERSION/$NAME"
    mkdir -p "$DIR"
    echo "LuaLS $VERSION 받는 중: $URL"
    curl -fsSL -o "$DIR/$NAME" "$URL"
    GOT="$(sha256_of "$DIR/$NAME")"
    if [ "$GOT" != "$SHA" ]; then
      echo "sha256 이 다르다: $GOT (기대 $SHA)" >&2
      rm -f "$DIR/$NAME"
      exit 1
    fi
    tar xzf "$DIR/$NAME" -C "$DIR"
    rm -f "$DIR/$NAME"
  fi
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 진단이 있으면 LuaLS 자신도 0 이 아닌 값으로 끝나므로, 검사를 마쳤는지는 출력의 끝 줄로 본다
"$LUALS" --check="$REPO" --checklevel=Warning --check_format=json \
  --logpath="$WORK/log" --metapath="$WORK/meta" >"$WORK/out.txt" 2>&1 || true
if ! grep -q "Diagnosis complete" "$WORK/out.txt"; then
  cat "$WORK/out.txt" >&2
  echo "LuaLS 가 검사를 끝내지 못했다" >&2
  exit 1
fi

python3 - "$REPO" "$WORK/log/check.json" <<'EOF'
import json, os, sys
from urllib.parse import unquote, urlparse

repo, report = sys.argv[1], sys.argv[2]
try:
    with open(report, encoding="utf-8") as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
problems = []
for uri, diags in (data or {}).items():
    path = unquote(urlparse(uri).path) if uri.startswith("file:") else uri
    rel = os.path.relpath(path, repo)
    for d in diags:
        line = d["range"]["start"]["line"] + 1
        message = d["message"].splitlines()[0]
        problems.append(f"{rel}:{line}: [{d.get('code', '?')}] {message}")
if problems:
    print(f"LuaLS 진단 {len(problems)}건 (.luarc.json 의 규칙):", file=sys.stderr)
    for p in sorted(problems):
        print("  " + p, file=sys.stderr)
    sys.exit(1)
print("LuaLS 진단 0건 (.luarc.json 의 규칙, 경고 이상)")
EOF
