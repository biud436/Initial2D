#!/usr/bin/env bash
# SDL2/SDL2_image/SDL2_mixer 소스를 android/app/jni/ 아래에 다운로드한다.
# 다운로드된 소스는 gitignore 대상이며, Android 빌드 시 소스에서 함께 컴파일된다.
set -euo pipefail

cd "$(dirname "$0")/app/jni"

SDL2_VER=2.28.5
IMG_VER=2.8.2
MIX_VER=2.8.0

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

fetch SDL2       "$SDL2_VER" "https://github.com/libsdl-org/SDL/releases/download/release-$SDL2_VER/SDL2-$SDL2_VER.tar.gz"
fetch SDL2_image "$IMG_VER"  "https://github.com/libsdl-org/SDL_image/releases/download/release-$IMG_VER/SDL2_image-$IMG_VER.tar.gz"
fetch SDL2_mixer "$MIX_VER"  "https://github.com/libsdl-org/SDL_mixer/releases/download/release-$MIX_VER/SDL2_mixer-$MIX_VER.tar.gz"

echo "완료. 다음 단계: ./android/prepare_assets.sh 실행 후 android/ 에서 빌드"
