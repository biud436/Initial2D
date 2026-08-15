# Initial2D — 크로스 플랫폼 빌드 (macOS 포팅 Phase 0)
#
# 기존 Visual Studio 빌드(Initial2D.sln/vcxproj)는 그대로 유지되며,
# 이 파일은 macOS(및 향후 다른 플랫폼) 빌드를 위한 별도 진입점입니다.
#
# Phase 0 범위:
#   - vendored 서드파티(lua, sqlite3, jsoncpp)를 정적 라이브러리로 빌드
#   - macOS에서 현재 컴파일 가능한 엔진 소스만 initial2d_core로 빌드
#     (실측 인벤토리: docs/porting/phase0-inventory.md)
#   - phase0_sanity 실행 파일로 lua/sqlite/json 동작 검증
#
# 사용법: cmake -B build && cmake --build build && ./build/phase0_sanity

cmake_minimum_required(VERSION 3.16)
project(Initial2D LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 소스는 UTF-8로 저장되어 있음. MSVC는 소스 문자셋만 지정하고
# 실행 문자셋은 기존(ANSI/CP949) 그대로 두어 런타임 동작을 보존한다.
if(MSVC)
  add_compile_options(/source-charset:utf-8)
endif()

# ---------------------------------------------------------------------------
# Vendored 서드파티
# ---------------------------------------------------------------------------
file(GLOB LUA_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/lua/*.cpp)
add_library(vendored_lua STATIC ${LUA_SOURCES})
target_include_directories(vendored_lua PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/lua)

add_library(vendored_sqlite3 STATIC ${CMAKE_CURRENT_SOURCE_DIR}/src/sqlite3.c)
target_include_directories(vendored_sqlite3 PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)

add_library(vendored_jsoncpp STATIC ${CMAKE_CURRENT_SOURCE_DIR}/json/Json/jsoncpp.cpp)
target_include_directories(vendored_jsoncpp PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/json/Json)

add_library(vendored_tinyxml STATIC
  ${CMAKE_CURRENT_SOURCE_DIR}/external/tinyxml/src/tinystr.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/external/tinyxml/src/tinyxml.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/external/tinyxml/src/tinyxmlerror.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/external/tinyxml/src/tinyxmlparser.cpp
)
target_include_directories(vendored_tinyxml PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/external/tinyxml/include)

# ---------------------------------------------------------------------------
# SDL2 (Phase 2부터 필수 — Phase 0에서는 존재 여부만 보고)
# ---------------------------------------------------------------------------
find_package(SDL2 QUIET CONFIG)
if(SDL2_FOUND)
  message(STATUS "SDL2 found: ${SDL2_VERSION}")
else()
  message(STATUS "SDL2 not found — Phase 2 이후 단계에서 필요합니다 (brew install sdl2 sdl2_image sdl2_mixer sdl2_ttf)")
endif()

# ---------------------------------------------------------------------------
# 엔진 코어 — macOS에서 컴파일 가능한 파일만 (실측 인벤토리 기준, Phase 진행에 따라 추가)
# ---------------------------------------------------------------------------
add_library(initial2d_core STATIC
  # Phase 0
  ${CMAKE_CURRENT_SOURCE_DIR}/src/File.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/GameState.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/GameStateMachine.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_tbl.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Matrix.cpp
  # Phase 1 — std 공통화
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Thread.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/StringUtils.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Utility.cpp
)
target_include_directories(initial2d_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(initial2d_core PUBLIC vendored_lua vendored_jsoncpp vendored_sqlite3)

if(NOT WIN32)
  # Phase 1 — POSIX 어댑터
  target_sources(initial2d_core PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/posix/SystemPath.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/posix/PosixProcess.cpp
  )
endif()

# 오디오(SoundManager)는 SDL2_mixer가 있을 때만 코어에 포함
if(SDL2_FOUND)
  find_library(SDL2_MIXER_LIBRARY SDL2_mixer)
  # Homebrew의 SDL2 CMake 타깃은 자기 keg의 include만 내보내므로
  # 다른 keg에 설치된 SDL_mixer.h / SDL_image.h는 별도로 찾아야 한다.
  find_path(SDL2_MIXER_INCLUDE_DIR SDL_mixer.h PATH_SUFFIXES SDL2)
  find_library(SDL2_IMAGE_LIBRARY SDL2_image)
  find_path(SDL2_IMAGE_INCLUDE_DIR SDL_image.h PATH_SUFFIXES SDL2)
  if(SDL2_MIXER_LIBRARY AND SDL2_MIXER_INCLUDE_DIR)
    target_sources(initial2d_core PRIVATE
      ${CMAKE_CURRENT_SOURCE_DIR}/src/SoundManager.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_audio.cpp
    )
    target_include_directories(initial2d_core PUBLIC ${SDL2_MIXER_INCLUDE_DIR})
    target_link_libraries(initial2d_core PUBLIC SDL2::SDL2 ${SDL2_MIXER_LIBRARY})
    message(STATUS "SoundManager enabled (SDL2_mixer: ${SDL2_MIXER_LIBRARY})")
  else()
    message(STATUS "SDL2_mixer not found — SoundManager excluded")
  endif()
endif()

# ---------------------------------------------------------------------------
# 게임 실행 파일 (SDL2 백엔드) — Phase 2~5
# Windows의 Initial2D.vcxproj(GDI 백엔드)에 대응하는 macOS 빌드.
# ---------------------------------------------------------------------------
if(NOT WIN32 AND SDL2_FOUND AND SDL2_IMAGE_LIBRARY AND SDL2_MIXER_LIBRARY)
  add_executable(Initial2D
    # 게임 로직 (플랫폼 중립 — Win32 부분은 RS_WINDOWS 가드로 제외됨)
    ${CMAKE_CURRENT_SOURCE_DIR}/src/App.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/GameObject.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/MenuState.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/MapState.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Sprite.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Tile.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Tilemap.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Font.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Input.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/Encrypt.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ExperimentalFont.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/TextureManager.cpp
    # Lua 바인딩
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_prot.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_input.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_sprite.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_texture.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_font.cpp
    # SDL2 어댑터
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/AppSDL2.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/TextureManagerSDL2.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/InputSDL2.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/ExperimentalFontStub.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/sdl2Main.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/Utf8.cpp
    # 개발용 Lua 핫 리로드 (INITIAL2D_HMR=1 옵트인)
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/HotReloadServer.cpp
  )
  target_include_directories(Initial2D PRIVATE ${SDL2_IMAGE_INCLUDE_DIR})
  target_link_libraries(Initial2D PRIVATE initial2d_core vendored_tinyxml ${SDL2_IMAGE_LIBRARY})
  message(STATUS "Initial2D game executable enabled (SDL2 backend)")
else()
  message(STATUS "Initial2D game executable disabled (SDL2/SDL2_image/SDL2_mixer required)")
endif()

# ---------------------------------------------------------------------------
# Phase 검증 실행 파일
# ---------------------------------------------------------------------------
add_executable(phase0_sanity ${CMAKE_CURRENT_SOURCE_DIR}/tests/phase0_sanity.cpp)
target_link_libraries(phase0_sanity PRIVATE vendored_lua vendored_sqlite3 vendored_jsoncpp)

add_executable(phase1_sanity ${CMAKE_CURRENT_SOURCE_DIR}/tests/phase1_sanity.cpp)
target_link_libraries(phase1_sanity PRIVATE initial2d_core)

# ---------------------------------------------------------------------------
# 단위 테스트 (검수 인프라 — docs/plans/09-testing.md 3.1절)
# 새 테스트 파일은 이 목록에 명시적으로 추가한다.
# (GLOB을 쓰지 않는 이유: 파일 삭제 시 스테일 오브젝트가 링크에 남아
#  삭제된 테스트가 계속 실행되는 문제를 실측으로 확인함)
# ---------------------------------------------------------------------------
add_executable(engine_unit_tests
  ${CMAKE_CURRENT_SOURCE_DIR}/tests/unit/main.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/tests/unit/utf8_test.cpp
  # 코어 라이브러리에 없는 플랫폼 중립 소스는 여기서 직접 포함한다
  ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/Utf8.cpp
)
target_link_libraries(engine_unit_tests PRIVATE initial2d_core)
