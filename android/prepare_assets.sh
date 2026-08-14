#!/usr/bin/env bash
# 게임 에셋(scripts/, resources/, config.setting, db.sqlite)을
# android/app/src/main/assets/ 로 스테이징한다. (gitignore 대상)
#
# APK 안의 assets 는 파일 시스템이 아니므로, 런타임에는 최초 실행 시
# 내부 저장소로 추출한 뒤 chdir 하는 방식을 사용한다.
# 상세: docs/porting/android-plan.md (Phase A1)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/android/app/src/main/assets"

rm -rf "$ASSETS"
mkdir -p "$ASSETS"

cp -R "$ROOT/scripts"   "$ASSETS/scripts"
cp -R "$ROOT/resources" "$ASSETS/resources"
[ -f "$ROOT/config.setting" ] && cp "$ROOT/config.setting" "$ASSETS/"
[ -f "$ROOT/db.sqlite" ]      && cp "$ROOT/db.sqlite"      "$ASSETS/"

find "$ASSETS" -name .DS_Store -delete

# 런타임 추출용 파일 목록 — AndroidBootstrap이 읽는다 (AAssetManager는 디렉터리 열거 불가)
(cd "$ASSETS" && find . -type f ! -name assets_manifest.txt | sed 's|^\./||' | LC_ALL=C sort > assets_manifest.txt)

echo "완료: $ASSETS ($(wc -l < "$ASSETS/assets_manifest.txt" | tr -d ' ')개 파일)"
echo "주의: resources/ 의 일부 이미지 에셋은 저장소에 없음 —"
echo "      python3 tools/generate_placeholder_assets.py 로 생성 가능"
