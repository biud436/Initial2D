#!/bin/sh
# 웹 빌드 검수 (R3, docs/plans/r3-emscripten.md 10.5). CI 의 engine-web 작업(.github/workflows/tests.yml)이
# 단계마다 이 스크립트를 부르고, 로컬에서도 같은 명령으로 돈다.
#
#   tools/web_ci.sh emsdk        # emsdk 를 $EMSDK(기본 ~/emsdk)에 두고 EMSDK_VERSION 을 설치, 활성화
#   tools/web_ci.sh playwright   # build-web/playwright 에 Playwright(PLAYWRIGHT_VERSION)와 크로미움
#   tools/web_ci.sh native       # 네이티브 엔진 build/Initial2D (web_smoke 의 네이티브 대조용)
#   tools/web_ci.sh build        # tools/build_web.sh (mruby 포함)
#   tools/web_ci.sh smoke        # tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png (뒤의 인수는 그대로 넘긴다)
#   tools/web_ci.sh all          # 위 다섯을 차례로
#
# 버전은 여기서 고정한다. EMSDK_VERSION 을 바꾸면 CI 의 emsdk 캐시 키(tests.yml)도 같이 바꾼다.
set -e
cd "$(dirname "$0")/.."

EMSDK_VERSION="${EMSDK_VERSION:-6.0.10}"
PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION:-1.63.0}"
EMSDK_DIR="${EMSDK:-$HOME/emsdk}"
PW_PREFIX="build-web/playwright"

step_emsdk() {
  if [ ! -x "$EMSDK_DIR/emsdk" ]; then
    git clone --depth 1 --branch "$EMSDK_VERSION" https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
  fi
  "$EMSDK_DIR/emsdk" install "$EMSDK_VERSION"
  "$EMSDK_DIR/emsdk" activate "$EMSDK_VERSION"
}

step_playwright() {
  mkdir -p "$PW_PREFIX"
  installed=""
  if [ -f "$PW_PREFIX/node_modules/playwright/package.json" ]; then
    installed="$(node -p "require('./$PW_PREFIX/node_modules/playwright/package.json').version")"
  fi
  if [ "$installed" != "$PLAYWRIGHT_VERSION" ]; then
    npm install --prefix "$PW_PREFIX" --no-save --no-package-lock "playwright@$PLAYWRIGHT_VERSION"
  fi
  "$PW_PREFIX/node_modules/.bin/playwright" install chromium
}

step_native() {
  cmake -B build -S .
  cmake --build build -j"${JOBS:-4}" --target Initial2D
}

step_build() {
  EMSDK="$EMSDK_DIR" tools/build_web.sh
}

step_smoke() {
  PLAYWRIGHT_DIR="${PLAYWRIGHT_DIR:-$PW_PREFIX/node_modules/playwright}" \
    SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-dummy}" SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}" \
    node tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png "$@"
}

case "${1:-}" in
  emsdk) step_emsdk ;;
  playwright) step_playwright ;;
  native) step_native ;;
  build) step_build ;;
  smoke) shift; step_smoke "$@" ;;
  all)
    step_emsdk
    step_playwright
    step_native
    step_build
    step_smoke
    ;;
  *)
    echo "사용법: tools/web_ci.sh emsdk|playwright|native|build|smoke|all" >&2
    exit 2
    ;;
esac
