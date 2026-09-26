#!/usr/bin/env bash
# 배포용 엔진 실행 파일을 만든다 (R4, docs/plans/r4-dist-build.md).
# SDL2, SDL2_image, SDL2_mixer 와 mruby 를 소스에서 정적으로 빌드해, 다른 컴퓨터에 복사해도 뜨는 파일 하나를 낸다.
#
#   tools/build_dist.sh
#
# 결과:
#   dist/Initial2D-<타깃 트리플>   실행 파일 (strip 뒤 macOS 는 ad-hoc 서명)
#   dist/engine-dist.json          태그, 커밋, 타깃별 sha256 과 기능 (같은 커밋의 다른 타깃 항목은 이어받는다)
# 중간 산출물은 build-dist/ (SDL 소스는 external/sdl-src/, mruby 소스는 external/mruby-src/).
# 지원 타깃: aarch64-apple-darwin, x86_64-unknown-linux-gnu. 검사는 tools/check_dist.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)  TRIPLE=aarch64-apple-darwin ;;
    Linux-x86_64)  TRIPLE=x86_64-unknown-linux-gnu ;;
    *)
        echo "지원하지 않는 타깃: $(uname -s) $(uname -m) (aarch64-apple-darwin, x86_64-unknown-linux-gnu 만)" >&2
        exit 1
        ;;
esac
if [ "$(uname -s)" = "Darwin" ]; then
    JOBS="$(sysctl -n hw.ncpu)"
else
    JOBS="$(nproc)"
fi

BUILD="$ROOT/build-dist"
DIST="$ROOT/dist"
OUT="$DIST/Initial2D-$TRIPLE"

echo "== SDL 소스 =="
tools/fetch_sdl_src.sh

echo "== mruby =="
tools/build_mruby.sh "$BUILD/mruby"

echo "== 엔진 ($TRIPLE) =="
cmake -S "$ROOT" -B "$BUILD/engine" \
    -DCMAKE_BUILD_TYPE=Release \
    -DINITIAL2D_VENDORED_SDL=ON \
    -DMRUBY_ROOT="$BUILD/mruby/host"
cmake --build "$BUILD/engine" --target Initial2D --parallel "$JOBS"

mkdir -p "$DIST"
rm -f "$OUT"
cp "$BUILD/engine/Initial2D" "$OUT"
strip "$OUT"
if [ "$(uname -s)" = "Darwin" ]; then
    # strip 이 링커의 서명을 깨뜨릴 수 있어 ad-hoc 서명을 다시 붙인다 (arm64 는 서명 없는 실행 파일을 죽인다)
    codesign --force --sign - "$OUT"
fi

# 판과 기능은 만든 실행 파일에게 묻는다. 작업 폴더를 버리는 임시 폴더로, 시간 제한을 두고 돌린다
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ask() {
    (cd "$WORK" && perl -e 'alarm shift; exec @ARGV' 20 "$OUT" "$1")
}
FEATURES="$(ask --features)"
VERSION="$(ask --version)"

python3 tools/engine_dist_json.py add \
    --dist "$DIST" --target "$TRIPLE" --file "$OUT" \
    --version "$VERSION" --features "$FEATURES"

echo ""
echo "배포용 엔진: $OUT"
echo "  $VERSION"
echo "  features: $FEATURES"
echo "검사: tools/check_dist.sh $OUT"
