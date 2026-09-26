#!/usr/bin/env bash
# SDL2, SDL2_image, SDL2_mixer 소스를 external/sdl-src/ 에 받는다 (배포용 빌드, docs/plans/r4-dist-build.md).
# 판과 sha256 은 tools/sdl_versions.sh 에 있다. 같은 판이 이미 풀려 있으면 건너뛴다.
#
#   tools/fetch_sdl_src.sh            external/sdl-src/ 로
#   tools/fetch_sdl_src.sh <폴더>     다른 폴더로
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tools/sdl_versions.sh
. "$ROOT/tools/sdl_versions.sh"
DEST="${1:-$ROOT/external/sdl-src}"
mkdir -p "$DEST"

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

fetch() {
    local name=$1 ver=$2 url=$3 want=$4
    if [ -f "$DEST/$name/.version" ] && [ "$(cat "$DEST/$name/.version")" = "$ver" ]; then
        echo "[skip] $name $ver"
        return
    fi
    echo "[down] $name $ver"
    rm -rf "${DEST:?}/$name" "$DEST/$name-$ver"
    local tarball="$DEST/$name-$ver.tar.gz"
    curl -fsSL --retry 3 -o "$tarball" "$url"
    local got
    got="$(sha256_of "$tarball")"
    if [ "$got" != "$want" ]; then
        rm -f "$tarball"
        echo "sha256 가 다르다: $name $ver" >&2
        echo "  기대 $want" >&2
        echo "  받음 $got" >&2
        exit 1
    fi
    tar xzf "$tarball" -C "$DEST"
    rm "$tarball"
    mv "$DEST/$name-$ver" "$DEST/$name"
    echo "$ver" > "$DEST/$name/.version"
}

fetch SDL2       "$SDL2_VER" "$SDL2_URL" "$SDL2_SHA256"
fetch SDL2_image "$IMG_VER"  "$IMG_URL"  "$IMG_SHA256"
fetch SDL2_mixer "$MIX_VER"  "$MIX_URL"  "$MIX_SHA256"

echo "SDL 소스: $DEST"
