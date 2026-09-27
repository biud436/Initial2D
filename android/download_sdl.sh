#!/usr/bin/env bash
# SDL2/SDL2_image/SDL2_mixer 소스를 android/app/jni/ 아래에 다운로드한다.
# 다운로드된 소스는 gitignore 대상이며, Android 빌드 시 소스에서 함께 컴파일된다.
# 판 번호는 tools/sdl_versions.sh 한 곳에 있다 (배포용 데스크톱 빌드와 같은 판).
set -euo pipefail

# shellcheck source=tools/sdl_versions.sh
. "$(dirname "$0")/../tools/sdl_versions.sh"

cd "$(dirname "$0")/app/jni"

fetch() {
    local name=$1 ver=$2 url=$3
    if [ -d "$name" ]; then
        echo "[skip] $name 이미 존재함"
        return
    fi
    echo "[down] $name $ver"
    curl -fL -o "$name.tar.gz" "$url"
    tar xzf "$name.tar.gz"
    mv "$name-$ver" "$name"
    rm "$name.tar.gz"
}

fetch SDL2       "$SDL2_VER" "$SDL2_URL"
fetch SDL2_image "$IMG_VER"  "$IMG_URL"
fetch SDL2_mixer "$MIX_VER"  "$MIX_URL"

echo "완료. 다음 단계: ./android/prepare_assets.sh 실행 후 android/ 에서 빌드"
