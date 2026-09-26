#!/bin/sh
# Initial2D 웹 빌드 (Emscripten, R3, docs/plans/r3-emscripten.md)
#
#   tools/build_web.sh                         # build-web/ 에 Initial2D.js 와 .wasm, build-web/site/ 에 데모 페이지
#   JOBS=4 tools/build_web.sh                  # 병렬 수 (기본 8)
#   INITIAL2D_WEB_MRUBY=0 tools/build_web.sh   # mruby 없이 Lua 만 (mruby 소스를 받지 않는다)
#   MRUBY_SRC=~/src/mruby tools/build_web.sh   # 이미 받아 둔 mruby 4.0.0 소스를 쓴다
#
# emsdk 가 PATH 에 없으면 ~/emsdk (또는 $EMSDK) 의 emsdk_env.sh 를 읽는다.
# 첫 빌드는 SDL2, SDL2_image, SDL2_mixer, ogg, vorbis 포트를 소스에서 컴파일하므로 몇 분 걸린다.
# mruby 는 4.0.0 태그를 build-web/mruby-src 에 받아(git clone) emcc 로 libmruby 를 만든다
# (설정 tools/web/mruby_build_config.rb, 산출물 build-web/mruby/emscripten). rake 가 필요하다.
set -e
cd "$(dirname "$0")/.."
REPO="$(pwd)"

JOBS="${JOBS:-8}"
MRUBY_VERSION=4.0.0
WITH_MRUBY="${INITIAL2D_WEB_MRUBY:-1}"
MRUBY_SRC="${MRUBY_SRC:-build-web/mruby-src}"
MRUBY_OUT="$REPO/build-web/mruby"

if ! command -v emcmake >/dev/null 2>&1; then
  EMSDK_DIR="${EMSDK:-$HOME/emsdk}"
  if [ -f "$EMSDK_DIR/emsdk_env.sh" ]; then
    # shellcheck disable=SC1090
    . "$EMSDK_DIR/emsdk_env.sh" >/dev/null 2>&1
  fi
fi
if ! command -v emcmake >/dev/null 2>&1; then
  echo "emsdk 가 없습니다. 설치:" >&2
  echo "  git clone https://github.com/emscripten-core/emsdk.git ~/emsdk && cd ~/emsdk && ./emsdk install latest && ./emsdk activate latest" >&2
  exit 1
fi

mkdir -p build-web
if [ "$WITH_MRUBY" != "0" ]; then
  echo "== [1/4] mruby $MRUBY_VERSION (emcc, libmruby) =="
  if [ ! -f "$MRUBY_SRC/Rakefile" ]; then
    git clone --depth 1 --branch "$MRUBY_VERSION" https://github.com/mruby/mruby.git "$MRUBY_SRC"
  fi
  # 네이티브 CI(.github/workflows/tests.yml)와 같은 버전만 쓴다
  found="$(awk '/^#define MRUBY_RELEASE_(MAJOR|MINOR|TEENY) /{printf "%s%s", sep, $3; sep="."}' "$MRUBY_SRC/include/mruby/version.h")"
  if [ "$found" != "$MRUBY_VERSION" ]; then
    echo "mruby 소스($MRUBY_SRC)가 ${found:-알 수 없는 버전} 입니다. $MRUBY_VERSION 이 필요합니다" >&2
    exit 1
  fi
  # 시스템 ruby 보다 Homebrew ruby 를 앞에 둔다 (CI 의 소스 빌드와 같다)
  if command -v brew >/dev/null 2>&1; then
    BREW_RUBY="$(brew --prefix ruby 2>/dev/null || true)"
    if [ -n "$BREW_RUBY" ] && [ -x "$BREW_RUBY/bin/rake" ]; then
      PATH="$BREW_RUBY/bin:$PATH"
      export PATH
    fi
  fi
  if ! command -v rake >/dev/null 2>&1; then
    echo "rake 가 없습니다 (brew install ruby). mruby 없이 빌드하려면 INITIAL2D_WEB_MRUBY=0" >&2
    exit 1
  fi
  if ! (
    cd "$MRUBY_SRC"
    # mruby 의 emscripten 툴체인은 CFLAGS, CXXFLAGS, LDFLAGS 가 있으면 -fwasm-exceptions 를 넣지 않는다.
    # 셸에 남은 값이 예외 방식을 바꾸지 않게 비운다
    unset CFLAGS CXXFLAGS LDFLAGS
    MRUBY_CONFIG="$REPO/tools/web/mruby_build_config.rb" MRUBY_BUILD_DIR="$MRUBY_OUT" rake -m -j"$JOBS" all
  ) > build-web/mruby-build.log 2>&1; then
    tail -40 build-web/mruby-build.log >&2
    echo "mruby 빌드 실패 (전체 로그: build-web/mruby-build.log)" >&2
    exit 1
  fi
  printf '%10s bytes  %s\n' "$(wc -c < "$MRUBY_OUT/emscripten/lib/libmruby.a" | tr -d ' ')" "build-web/mruby/emscripten/lib/libmruby.a"
  CMAKE_MRUBY="-DINITIAL2D_MRUBY=ON -DINITIAL2D_MRUBY_WEB_DIR=$MRUBY_OUT/emscripten"
else
  echo "== [1/4] mruby 건너뜀 (INITIAL2D_WEB_MRUBY=0, Lua 만) =="
  CMAKE_MRUBY="-DINITIAL2D_MRUBY=OFF"
fi

echo ""
echo "== [2/4] Emscripten 빌드 (Release) =="
# shellcheck disable=SC2086
emcmake cmake -S . -B build-web -DCMAKE_BUILD_TYPE=Release $CMAKE_MRUBY
cmake --build build-web -j"$JOBS" --target Initial2D

echo ""
echo "== [3/4] 정적 사이트 (build-web/site) =="
mkdir -p build-web/site
cp build-web/Initial2D.js build-web/Initial2D.wasm build-web/site/
cp tools/web/index.html tools/web/initial2d-loader.js build-web/site/
python3 tools/web_stage.py --out build-web/site

echo ""
echo "== [4/4] 산출물 크기 =="
for f in build-web/site/Initial2D.js build-web/site/Initial2D.wasm; do
  size=$(wc -c < "$f" | tr -d ' ')
  printf '%10s bytes  %s\n' "$size" "$f"
done
echo ""
echo "보기:  python3 -m http.server -d build-web/site 8080   # http://localhost:8080 (Ruby 판은 ?env=INITIAL2D_SCRIPT=mruby)"
echo "검수:  node tools/web_smoke.mjs                        # 헤드리스 크로미움, build-web/smoke.png"
