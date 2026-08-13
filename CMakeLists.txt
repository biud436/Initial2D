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
# 엔진 코어 — Phase 0 시점에 macOS에서 컴파일 가능한 파일만 (실측 결과)
# 이후 Phase가 진행되며 파일이 추가된다.
# ---------------------------------------------------------------------------
add_library(initial2d_core STATIC
  ${CMAKE_CURRENT_SOURCE_DIR}/src/File.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/GameState.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/GameStateMachine.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_tbl.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/Matrix.cpp
)
target_include_directories(initial2d_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(initial2d_core PUBLIC vendored_lua vendored_jsoncpp vendored_sqlite3)

# ---------------------------------------------------------------------------
# Phase 0 검증 실행 파일
# ---------------------------------------------------------------------------
add_executable(phase0_sanity ${CMAKE_CURRENT_SOURCE_DIR}/tests/phase0_sanity.cpp)
target_link_libraries(phase0_sanity PRIVATE vendored_lua vendored_sqlite3 vendored_jsoncpp)
