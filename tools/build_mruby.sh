#!/usr/bin/env bash
# mruby 를 소스에서 빌드한다 (배포용 빌드, docs/plans/r4-dist-build.md).
# 설정은 tests.yml 의 대체 경로와 같다: build_config/default.rb 에서 gembox 만 full-core 로 바꾼다.
# macOS 는 배포 대상 11.0 으로 컴파일한다 (rake 는 CMake 의 CMAKE_OSX_DEPLOYMENT_TARGET 을 물려받지 않는다).
#
#   tools/build_mruby.sh [출력 폴더]      기본 build-dist/mruby, 결과는 <출력 폴더>/host
#
# 엔진은 cmake -DMRUBY_ROOT=<출력 폴더>/host 로 이 빌드를 쓰고, mruby-config --cflags 의 -D 를 그대로 따른다.
# 소스는 external/mruby-src/ (gitignore) 에 받는다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MRUBY_VER=4.0.0
MRUBY_COMMIT=831da26b9021de0369d17b71b5667e2941a1a32d
SRC="$ROOT/external/mruby-src"
OUT="${1:-$ROOT/build-dist/mruby}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

if [ ! -d "$SRC/.git" ] || [ "$(git -C "$SRC" rev-parse HEAD)" != "$MRUBY_COMMIT" ]; then
    echo "[down] mruby $MRUBY_VER"
    rm -rf "$SRC"
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$MRUBY_VER" https://github.com/mruby/mruby.git "$SRC"
    got="$(git -C "$SRC" rev-parse HEAD)"
    if [ "$got" != "$MRUBY_COMMIT" ]; then
        echo "mruby $MRUBY_VER 태그의 커밋이 다르다: $got (기대 $MRUBY_COMMIT)" >&2
        exit 1
    fi
fi

if [ "$(uname -s)" = "Darwin" ]; then
    export MACOSX_DEPLOYMENT_TARGET=11.0
    # 시스템 ruby 2.6 으로 만든 빌드에는 presym 헤더가 빠질 수 있어 Homebrew 의 ruby 와 bison 을 앞에 둔다
    if command -v brew >/dev/null 2>&1; then
        for formula in bison ruby; do
            prefix="$(brew --prefix "$formula" 2>/dev/null || true)"
            if [ -n "$prefix" ] && [ -x "$prefix/bin/$formula" ]; then
                PATH="$prefix/bin:$PATH"
            fi
        done
        export PATH
    fi
    JOBS="$(sysctl -n hw.ncpu)"
else
    JOBS="$(nproc)"
fi

CONFIG="$OUT/build_config.rb"
sed "s/conf.gembox 'default'/conf.gembox 'full-core'/" "$SRC/build_config/default.rb" > "$CONFIG.new"
if ! grep -q "conf.gembox 'full-core'" "$CONFIG.new"; then
    echo "build_config/default.rb 의 gembox 줄을 찾지 못했다" >&2
    exit 1
fi
# 설정이 같으면 파일을 그대로 두어 rake 가 다시 빌드하지 않게 한다
if [ -f "$CONFIG" ] && cmp -s "$CONFIG" "$CONFIG.new"; then
    rm "$CONFIG.new"
else
    mv "$CONFIG.new" "$CONFIG"
fi

echo "ruby: $(ruby --version)"
echo "mruby $MRUBY_VER -> $OUT/host"
(cd "$SRC" && MRUBY_CONFIG="$CONFIG" MRUBY_BUILD_DIR="$OUT" rake -j "$JOBS" all)

for f in lib/libmruby.a bin/mruby-config include/mruby.h include/mruby/presym/id.h; do
    if [ ! -f "$OUT/host/$f" ]; then
        echo "빌드 결과에 없다: $OUT/host/$f" >&2
        exit 1
    fi
done
echo "mruby-config --cflags: $("$OUT/host/bin/mruby-config" --cflags)"
