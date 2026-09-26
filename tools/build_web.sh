#!/bin/sh
# Initial2D 웹 빌드 (Emscripten, R3, docs/plans/r3-emscripten.md)
#
#   tools/build_web.sh            # build-web/ 에 Initial2D.js 와 .wasm, build-web/site/ 에 데모 페이지
#   JOBS=4 tools/build_web.sh     # 병렬 수 (기본 8)
#
# emsdk 가 PATH 에 없으면 ~/emsdk (또는 $EMSDK) 의 emsdk_env.sh 를 읽는다.
# 첫 빌드는 SDL2, SDL2_image, SDL2_mixer, ogg, vorbis 포트를 소스에서 컴파일하므로 몇 분 걸린다.
set -e
cd "$(dirname "$0")/.."

JOBS="${JOBS:-8}"

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

echo "== [1/3] Emscripten 빌드 (Release) =="
emcmake cmake -S . -B build-web -DCMAKE_BUILD_TYPE=Release
cmake --build build-web -j"$JOBS" --target Initial2D

echo ""
echo "== [2/3] 정적 사이트 (build-web/site) =="
mkdir -p build-web/site
cp build-web/Initial2D.js build-web/Initial2D.wasm build-web/site/
cp tools/web/index.html tools/web/initial2d-loader.js build-web/site/
python3 tools/web_stage.py --out build-web/site

echo ""
echo "== [3/3] 산출물 크기 =="
for f in build-web/site/Initial2D.js build-web/site/Initial2D.wasm; do
  size=$(wc -c < "$f" | tr -d ' ')
  printf '%10s bytes  %s\n' "$size" "$f"
done
echo ""
echo "보기:  python3 -m http.server -d build-web/site 8080   # http://localhost:8080"
echo "검수:  node tools/web_smoke.mjs                        # 헤드리스 크로미움, build-web/smoke.png"
