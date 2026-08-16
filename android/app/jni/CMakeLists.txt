# Initial2D — Android 네이티브 빌드 (SDL2 백엔드)
#
# Gradle(externalNativeBuild)이 이 파일을 진입점으로 사용한다.
# macOS 빌드(저장소 루트 CMakeLists.txt)와 동일한 소스 구성을 사용하되,
# SDL2/SDL2_image/SDL2_mixer 는 소스에서 함께 빌드한다 (android/download_sdl.sh 로 다운로드).
#
# 산출물: libmain.so — SDLActivity(getLibraries)가 로드한다.

cmake_minimum_required(VERSION 3.16)
project(Initial2DAndroid LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

get_filename_component(REPO_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../.. ABSOLUTE)

# ---------------------------------------------------------------------------
# SDL2 계열 — 소스 트리에서 빌드 (android/download_sdl.sh 실행 후 존재)
# ---------------------------------------------------------------------------
foreach(dep SDL2 SDL2_image SDL2_mixer)
  if(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${dep}/CMakeLists.txt)
    message(FATAL_ERROR
      "${dep} 소스가 없습니다. 저장소 루트에서 ./android/download_sdl.sh 를 먼저 실행하십시오.")
  endif()
endforeach()

# 사용하지 않는 포맷/샘플은 제외 — ogg(stb_vorbis), wav, png/jpg(stb_image)만으로 충분
set(SDL_TEST OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_SAMPLES OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_INSTALL OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_AVIF OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_JXL OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_TIF OFF CACHE BOOL "" FORCE)
set(SDL2IMAGE_WEBP OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_SAMPLES OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_INSTALL OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_FLAC OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_MOD OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_MP3 OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_MIDI OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_OPUS OFF CACHE BOOL "" FORCE)
set(SDL2MIXER_WAVPACK OFF CACHE BOOL "" FORCE)

add_subdirectory(SDL2)
add_subdirectory(SDL2_image)
add_subdirectory(SDL2_mixer)

# ---------------------------------------------------------------------------
# Vendored 서드파티 (루트 CMakeLists.txt 와 동일 구성)
# ---------------------------------------------------------------------------
file(GLOB LUA_SOURCES CONFIGURE_DEPENDS ${REPO_ROOT}/lua/*.cpp)
add_library(vendored_lua STATIC ${LUA_SOURCES})
target_include_directories(vendored_lua PUBLIC ${REPO_ROOT}/lua)

add_library(vendored_sqlite3 STATIC ${REPO_ROOT}/src/sqlite3.c)
target_include_directories(vendored_sqlite3 PUBLIC ${REPO_ROOT}/src)

add_library(vendored_jsoncpp STATIC ${REPO_ROOT}/json/Json/jsoncpp.cpp)
target_include_directories(vendored_jsoncpp PUBLIC ${REPO_ROOT}/json/Json)

add_library(vendored_tinyxml STATIC
  ${REPO_ROOT}/external/tinyxml/src/tinystr.cpp
  ${REPO_ROOT}/external/tinyxml/src/tinyxml.cpp
  ${REPO_ROOT}/external/tinyxml/src/tinyxmlerror.cpp
  ${REPO_ROOT}/external/tinyxml/src/tinyxmlparser.cpp
)
target_include_directories(vendored_tinyxml PUBLIC ${REPO_ROOT}/external/tinyxml/include)

# ---------------------------------------------------------------------------
# 게임 본체 — libmain.so (SDLActivity 가 로드)
# 소스 목록은 루트 CMakeLists.txt 의 initial2d_core + Initial2D 실행 파일과 동일
# ---------------------------------------------------------------------------
add_library(main SHARED
  # 엔진 코어
  ${REPO_ROOT}/src/File.cpp
  ${REPO_ROOT}/src/GameState.cpp
  ${REPO_ROOT}/src/GameStateMachine.cpp
  ${REPO_ROOT}/src/lua_tbl.cpp
  ${REPO_ROOT}/src/Matrix.cpp
  ${REPO_ROOT}/src/Thread.cpp
  ${REPO_ROOT}/src/StringUtils.cpp
  ${REPO_ROOT}/src/Utility.cpp
  ${REPO_ROOT}/src/SoundManager.cpp
  ${REPO_ROOT}/src/lua_audio.cpp
  # POSIX 어댑터
  ${REPO_ROOT}/src/platform/posix/SystemPath.cpp
  ${REPO_ROOT}/src/platform/posix/PosixProcess.cpp
  # 게임 로직 (플랫폼 중립 — Win32 부분은 RS_WINDOWS 가드로 제외됨)
  ${REPO_ROOT}/src/App.cpp
  ${REPO_ROOT}/src/main.cpp
  ${REPO_ROOT}/src/GameObject.cpp
  ${REPO_ROOT}/src/MenuState.cpp
  ${REPO_ROOT}/src/MapState.cpp
  ${REPO_ROOT}/src/Sprite.cpp
  ${REPO_ROOT}/src/Tile.cpp
  ${REPO_ROOT}/src/Tilemap.cpp
  ${REPO_ROOT}/src/Font.cpp
  ${REPO_ROOT}/src/Input.cpp
  ${REPO_ROOT}/src/Encrypt.cpp
  ${REPO_ROOT}/src/ExperimentalFont.cpp
  ${REPO_ROOT}/src/TextureManager.cpp
  # Lua 바인딩
  ${REPO_ROOT}/src/lua_prot.cpp
  ${REPO_ROOT}/src/lua_input.cpp
  ${REPO_ROOT}/src/lua_sprite.cpp
  ${REPO_ROOT}/src/lua_json.cpp
  ${REPO_ROOT}/src/lua_texture.cpp
  ${REPO_ROOT}/src/lua_tilemap.cpp
  ${REPO_ROOT}/src/lua_font.cpp
  # Android 어댑터 — assets 추출 + chdir (Phase A1)
  ${REPO_ROOT}/src/platform/android/AndroidBootstrap.cpp
  # 개발용 Lua 핫 리로드 (이슈 #16)
  ${REPO_ROOT}/src/platform/HotReloadServer.cpp
  # SDL2 어댑터
  ${REPO_ROOT}/src/platform/sdl2/AppSDL2.cpp
  ${REPO_ROOT}/src/platform/sdl2/TextureManagerSDL2.cpp
  ${REPO_ROOT}/src/platform/sdl2/InputSDL2.cpp
  ${REPO_ROOT}/src/platform/sdl2/ExperimentalFontStub.cpp
  ${REPO_ROOT}/src/platform/sdl2/sdl2Main.cpp
  ${REPO_ROOT}/src/platform/Utf8.cpp
)

target_include_directories(main PRIVATE ${REPO_ROOT}/src)
target_link_libraries(main PRIVATE
  SDL2::SDL2
  SDL2::SDL2main
  SDL2_image::SDL2_image
  SDL2_mixer::SDL2_mixer
  vendored_lua
  vendored_sqlite3
  vendored_jsoncpp
  vendored_tinyxml
  android
  log
)
