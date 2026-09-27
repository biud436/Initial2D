# SDL2, SDL2_image, SDL2_mixer 소스 판을 적는 한 곳. tools/fetch_sdl_src.sh 와 android/download_sdl.sh 가 source 한다.
# 판을 바꾸면 sha256 도 함께 바꾼다 (각 저장소 release 페이지의 tar.gz).
# 2.30.7 미만의 SDL2 는 NDK r27 에서 빌드되지 않는다 (ALooper_pollAll 제거).
# shellcheck shell=bash disable=SC2034

SDL2_VER=2.30.9
SDL2_SHA256=24b574f71c87a763f50704bbb630cbe38298d544a1f890f099a4696b1d6beba4
SDL2_URL="https://github.com/libsdl-org/SDL/releases/download/release-$SDL2_VER/SDL2-$SDL2_VER.tar.gz"

IMG_VER=2.8.2
IMG_SHA256=8f486bbfbcf8464dd58c9e5d93394ab0255ce68b51c5a966a918244820a76ddc
IMG_URL="https://github.com/libsdl-org/SDL_image/releases/download/release-$IMG_VER/SDL2_image-$IMG_VER.tar.gz"

MIX_VER=2.8.0
MIX_SHA256=1cfb34c87b26dbdbc7afd68c4f545c0116ab5f90bbfecc5aebe2a9cb4bb31549
MIX_URL="https://github.com/libsdl-org/SDL_mixer/releases/download/release-$MIX_VER/SDL2_mixer-$MIX_VER.tar.gz"
