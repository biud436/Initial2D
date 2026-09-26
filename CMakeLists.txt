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

# 배포용 빌드 (R4, docs/plans/r4-dist-build.md): SDL2, SDL2_image, SDL2_mixer 를 external/sdl-src/ 의 소스에서
# 정적으로 빌드해 다른 컴퓨터에 옮겨도 뜨는 실행 파일 하나를 만든다. tools/build_dist.sh 가 켠다.
# 배포 대상은 project() 전에 정해야 컴파일러 검사부터 적용된다.
option(INITIAL2D_VENDORED_SDL "Build SDL2, SDL2_image and SDL2_mixer statically from external/sdl-src" OFF)
if(INITIAL2D_VENDORED_SDL AND NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
  set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version of the distribution build")
endif()

project(Initial2D LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 소스는 UTF-8로 저장되어 있음. MSVC는 소스 문자셋만 지정하고
# 실행 문자셋은 기존(ANSI/CP949) 그대로 두어 런타임 동작을 보존한다.
if(MSVC)
  add_compile_options(/source-charset:utf-8)
endif()

# Emscripten 예외 방식 (R3, docs/plans/r3-emscripten.md): 모든 타깃을 wasm 네이티브 예외로
# 컴파일하고 링크한다. vendored Lua 는 C++ 로 컴파일되어 오류를 throw 로 던지고 pcall 이 catch 한다.
# 타깃마다 방식이 다르면 Lua 오류가 pcall 을 지나쳐 모듈 밖으로 빠진다. add_compile_options 는
# 그 뒤에 만든 타깃에만 붙으므로 어느 add_library 보다 먼저 둔다.
if(EMSCRIPTEN)
  add_compile_options(-fwasm-exceptions)
  add_link_options(-fwasm-exceptions)
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
# mruby (선택), S1, docs/plans/s1-mruby-binding.md
# Homebrew 의 mruby 를 찾는다 (brew install mruby). 없으면 Lua 만으로 빌드되고,
# INITIAL2D_SCRIPT=mruby 로 고르면 실행 파일이 그 사실을 알리고 끝난다.
# MRUBY_ROOT 를 주면 그 폴더만 본다 (tools/build_mruby.sh 의 결과). 배포용 빌드는 Homebrew 를 보지 않는다.
# ---------------------------------------------------------------------------
option(INITIAL2D_MRUBY "Build the mruby script backend when libmruby is found" ON)
set(MRUBY_ROOT "" CACHE PATH "mruby build to use (include/, lib/libmruby.a, bin/mruby-config); empty searches Homebrew")
set(INITIAL2D_HAS_MRUBY OFF)
if(INITIAL2D_MRUBY AND NOT WIN32 AND NOT EMSCRIPTEN)
  set(_mruby_find_opts "")
  if(MRUBY_ROOT)
    set(_mruby_hints "${MRUBY_ROOT}")
    set(_mruby_find_opts NO_DEFAULT_PATH)
  elseif(INITIAL2D_VENDORED_SDL)
    set(_mruby_hints "")
    message(STATUS "mruby: INITIAL2D_VENDORED_SDL without MRUBY_ROOT, Lua only (tools/build_mruby.sh builds one)")
  else()
    set(_mruby_hints /opt/homebrew/opt/mruby /usr/local/opt/mruby)
  endif()
  if(_mruby_hints)
    find_path(MRUBY_INCLUDE_DIR mruby.h HINTS ${_mruby_hints} PATH_SUFFIXES include ${_mruby_find_opts})
    find_library(MRUBY_LIBRARY mruby HINTS ${_mruby_hints} PATH_SUFFIXES lib ${_mruby_find_opts})
    find_program(MRUBY_CONFIG mruby-config HINTS ${_mruby_hints} PATH_SUFFIXES bin ${_mruby_find_opts})
  endif()
  if(MRUBY_INCLUDE_DIR AND MRUBY_LIBRARY)
    set(INITIAL2D_HAS_MRUBY ON)
    # libmruby 는 빌드 때의 -D 옵션(정수 폭, 박싱, 태스크 스케줄러 등)에 따라
    # 구조체 배치가 달라진다. 같은 정의로 컴파일해야 하므로 mruby-config --cflags 의
    # -D 항목을 그대로 가져온다.
    set(MRUBY_DEFINITIONS "")
    if(MRUBY_CONFIG)
      execute_process(COMMAND ${MRUBY_CONFIG} --cflags
        OUTPUT_VARIABLE _mruby_cflags OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
      separate_arguments(_mruby_cflags_list UNIX_COMMAND "${_mruby_cflags}")
      foreach(_flag IN LISTS _mruby_cflags_list)
        if(_flag MATCHES "^-D(.+)$")
          list(APPEND MRUBY_DEFINITIONS "${CMAKE_MATCH_1}")
        endif()
      endforeach()
    endif()
    message(STATUS "mruby found: ${MRUBY_LIBRARY}")
  else()
    message(STATUS "mruby not found, Lua only (brew install mruby to enable the mruby backend)")
  endif()
endif()

# 브라우저 빌드의 mruby (R3, docs/plans/r3-emscripten.md 9절). Homebrew 대신 tools/build_web.sh 가
# emcc 로 만든 libmruby 를 쓴다 (설정은 tools/web/mruby_build_config.rb). Emscripten 의 find_* 는
# sysroot 안만 보므로 경로를 직접 확인한다. 정의(-D)는 libmruby.flags.mak 의 MRUBY_CFLAGS 에서 가져온다.
if(INITIAL2D_MRUBY AND EMSCRIPTEN)
  set(INITIAL2D_MRUBY_WEB_DIR "${CMAKE_BINARY_DIR}/mruby/emscripten" CACHE PATH
    "mruby Emscripten build output (lib/libmruby.a, include/, lib/libmruby.flags.mak)")
  set(_mruby_web_flags "${INITIAL2D_MRUBY_WEB_DIR}/lib/libmruby.flags.mak")
  if(EXISTS "${INITIAL2D_MRUBY_WEB_DIR}/lib/libmruby.a"
      AND EXISTS "${INITIAL2D_MRUBY_WEB_DIR}/include/mruby.h"
      AND EXISTS "${_mruby_web_flags}")
    set(INITIAL2D_HAS_MRUBY ON)
    set(MRUBY_INCLUDE_DIR "${INITIAL2D_MRUBY_WEB_DIR}/include")
    set(MRUBY_LIBRARY "${INITIAL2D_MRUBY_WEB_DIR}/lib/libmruby.a")
    set(MRUBY_DEFINITIONS "")
    file(STRINGS "${_mruby_web_flags}" _mruby_cflags_line REGEX "^MRUBY_CFLAGS = ")
    string(REGEX REPLACE "^MRUBY_CFLAGS = " "" _mruby_cflags "${_mruby_cflags_line}")
    separate_arguments(_mruby_cflags_list UNIX_COMMAND "${_mruby_cflags}")
    foreach(_flag IN LISTS _mruby_cflags_list)
      if(_flag MATCHES "^-D(.+)$")
        list(APPEND MRUBY_DEFINITIONS "${CMAKE_MATCH_1}")
      endif()
    endforeach()
    # mruby 를 다시 빌드해 정의가 바뀌면 cmake 가 다시 돈다
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_mruby_web_flags}")
    message(STATUS "mruby (emscripten) found: ${MRUBY_LIBRARY}")
  else()
    message(STATUS "mruby (emscripten) not found in ${INITIAL2D_MRUBY_WEB_DIR}, Lua only (tools/build_web.sh builds it)")
  endif()
endif()

# ---------------------------------------------------------------------------
# SDL2 (Phase 2부터 필수 — Phase 0에서는 존재 여부만 보고)
#
# INITIAL2D_SDL2_AUDIO: SoundManager 를 코어에 넣는가 (SDL2_mixer 가 있을 때)
# INITIAL2D_SDL2_GAME:  게임 실행 파일을 만드는가 (SDL2, SDL2_image, SDL2_mixer 가 전부 있을 때)
# ---------------------------------------------------------------------------
set(INITIAL2D_SDL2_AUDIO OFF)
set(INITIAL2D_SDL2_GAME OFF)

if(EMSCRIPTEN)
  # R3 (docs/plans/r3-emscripten.md): 브라우저 빌드는 Homebrew 대신 Emscripten 포트를 쓴다.
  # -sUSE_* 플래그가 컴파일 때는 헤더 경로를, 링크 때는 라이브러리를 준다 (첫 빌드에서 포트를
  # 소스에서 컴파일한다). 이미지는 png 와 jpg, 오디오는 ogg 와 wav 만 넣는다 (리소스가 그 둘이다).
  set(INITIAL2D_EM_PORTS
    -sUSE_SDL=2
    -sUSE_SDL_IMAGE=2 "-sSDL2_IMAGE_FORMATS=png,jpg"
    -sUSE_SDL_MIXER=2 "-sSDL2_MIXER_FORMATS=ogg,wav"
    -sUSE_OGG=1 -sUSE_VORBIS=1)
  # 예외 방식(-fwasm-exceptions)은 파일 맨 위에서 모든 타깃에 준다.
  add_compile_options(${INITIAL2D_EM_PORTS})
  add_link_options(${INITIAL2D_EM_PORTS})
  # 아래 코드가 쓰는 이름을 그대로 채운다. 라이브러리 경로는 비워 둔다 (포트가 링크한다).
  add_library(SDL2::SDL2 INTERFACE IMPORTED)
  set(SDL2_FOUND ON)
  set(SDL2_MIXER_LIBRARY "")
  set(SDL2_MIXER_INCLUDE_DIR "")
  set(SDL2_IMAGE_LIBRARY "")
  set(SDL2_IMAGE_INCLUDE_DIR "")
  set(INITIAL2D_SDL2_AUDIO ON)
  set(INITIAL2D_SDL2_GAME ON)
  message(STATUS "Emscripten: SDL2, SDL2_image, SDL2_mixer, ogg, vorbis from emscripten ports")
elseif(INITIAL2D_VENDORED_SDL)
  # 배포용 빌드 (R4). 소스는 tools/fetch_sdl_src.sh 가 받고 판은 tools/sdl_versions.sh 에 있다.
  # 셋 다 정적 라이브러리로 만들어 실행 파일에 넣는다. Homebrew 는 찾지 않는다.
  set(INITIAL2D_SDL_SRC "${CMAKE_CURRENT_SOURCE_DIR}/external/sdl-src" CACHE PATH "SDL2, SDL2_image, SDL2_mixer sources")
  foreach(dep SDL2 SDL2_image SDL2_mixer)
    if(NOT EXISTS "${INITIAL2D_SDL_SRC}/${dep}/CMakeLists.txt")
      message(FATAL_ERROR "${dep} source not found in ${INITIAL2D_SDL_SRC} (run tools/fetch_sdl_src.sh)")
    endif()
  endforeach()
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  set(SDL_SHARED OFF CACHE BOOL "" FORCE)
  set(SDL_STATIC ON CACHE BOOL "" FORCE)
  set(SDL_TEST OFF CACHE BOOL "" FORCE)
  set(SDL2_DISABLE_SDL2MAIN ON CACHE BOOL "" FORCE)
  set(SDL2_DISABLE_INSTALL ON CACHE BOOL "" FORCE)
  set(SDL2_DISABLE_UNINSTALL ON CACHE BOOL "" FORCE)
  # Linux 의 X11, Wayland, ALSA, PulseAudio 는 SDL 기본값(*_SHARED ON)대로 실행 중에 dlopen 한다
  # PNG 와 JPG 는 stb_image 로 푼다. Apple 기본인 ImageIO 는 색 처리가 달라 골든을 움직일 수 있어 끈다
  set(SDL2IMAGE_BACKEND_IMAGEIO OFF CACHE BOOL "" FORCE)
  set(SDL2IMAGE_BACKEND_STB ON CACHE BOOL "" FORCE)
  set(SDL2IMAGE_DEPS_SHARED OFF CACHE BOOL "" FORCE)
  set(SDL2IMAGE_VENDORED OFF CACHE BOOL "" FORCE)
  set(SDL2IMAGE_SAMPLES OFF CACHE BOOL "" FORCE)
  set(SDL2IMAGE_INSTALL OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_DEPS_SHARED OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_VENDORED OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_VORBIS STB CACHE STRING "" FORCE)
  set(SDL2MIXER_SAMPLES OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_INSTALL OFF CACHE BOOL "" FORCE)
  # 포맷 스위치는 android/app/jni/CMakeLists.txt 와 같다 (디코더가 필요한 것 가운데 png, jpg, ogg, wav 만 남는다)
  set(SDL2IMAGE_AVIF OFF CACHE BOOL "" FORCE)
  set(SDL2IMAGE_JXL OFF CACHE BOOL "" FORCE)
  set(SDL2IMAGE_TIF OFF CACHE BOOL "" FORCE)
  set(SDL2IMAGE_WEBP OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_FLAC OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_MOD OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_MP3 OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_MIDI OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_OPUS OFF CACHE BOOL "" FORCE)
  set(SDL2MIXER_WAVPACK OFF CACHE BOOL "" FORCE)
  add_subdirectory("${INITIAL2D_SDL_SRC}/SDL2" "${CMAKE_BINARY_DIR}/sdl/SDL2" EXCLUDE_FROM_ALL)
  add_subdirectory("${INITIAL2D_SDL_SRC}/SDL2_image" "${CMAKE_BINARY_DIR}/sdl/SDL2_image" EXCLUDE_FROM_ALL)
  add_subdirectory("${INITIAL2D_SDL_SRC}/SDL2_mixer" "${CMAKE_BINARY_DIR}/sdl/SDL2_mixer" EXCLUDE_FROM_ALL)
  # SDL2 는 정적 빌드에서도 SDL2::SDL2 별칭을 만든다. 아래 코드가 쓰는 이름을 정적 대상으로 채운다
  set(SDL2_FOUND ON)
  set(SDL2_MIXER_LIBRARY SDL2_mixer::SDL2_mixer-static)
  set(SDL2_MIXER_INCLUDE_DIR "")
  set(SDL2_IMAGE_LIBRARY SDL2_image::SDL2_image-static)
  set(SDL2_IMAGE_INCLUDE_DIR "")
  set(INITIAL2D_SDL2_AUDIO ON)
  set(INITIAL2D_SDL2_GAME ON)
  message(STATUS "Vendored static SDL2, SDL2_image (stb), SDL2_mixer (stb_vorbis) from ${INITIAL2D_SDL_SRC}")
else()
  find_package(SDL2 QUIET CONFIG)
  if(SDL2_FOUND)
    message(STATUS "SDL2 found: ${SDL2_VERSION}")
  else()
    message(STATUS "SDL2 not found — Phase 2 이후 단계에서 필요합니다 (brew install sdl2 sdl2_image sdl2_mixer sdl2_ttf)")
  endif()
  if(SDL2_FOUND)
    find_library(SDL2_MIXER_LIBRARY SDL2_mixer)
    # Homebrew의 SDL2 CMake 타깃은 자기 keg의 include만 내보내므로
    # 다른 keg에 설치된 SDL_mixer.h / SDL_image.h는 별도로 찾아야 한다.
    find_path(SDL2_MIXER_INCLUDE_DIR SDL_mixer.h PATH_SUFFIXES SDL2)
    find_library(SDL2_IMAGE_LIBRARY SDL2_image)
    find_path(SDL2_IMAGE_INCLUDE_DIR SDL_image.h PATH_SUFFIXES SDL2)
    if(SDL2_MIXER_LIBRARY AND SDL2_MIXER_INCLUDE_DIR)
      set(INITIAL2D_SDL2_AUDIO ON)
    endif()
    if(NOT WIN32 AND SDL2_IMAGE_LIBRARY AND SDL2_MIXER_LIBRARY)
      set(INITIAL2D_SDL2_GAME ON)
    endif()
  endif()
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
  if(INITIAL2D_SDL2_AUDIO)
    target_sources(initial2d_core PRIVATE
      ${CMAKE_CURRENT_SOURCE_DIR}/src/SoundManager.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_audio.cpp
    )
    if(SDL2_MIXER_INCLUDE_DIR)
      target_include_directories(initial2d_core PUBLIC ${SDL2_MIXER_INCLUDE_DIR})
    endif()
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
if(INITIAL2D_SDL2_GAME)
  add_executable(Initial2D
    # 게임 로직 (플랫폼 중립 — Win32 부분은 RS_WINDOWS 가드로 제외됨)
    ${CMAKE_CURRENT_SOURCE_DIR}/src/App.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ScriptRuntime.cpp
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
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_json.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_texture.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_tilemap.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lua_font.cpp
    # SDL2 어댑터
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/AppSDL2.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/TextureManagerSDL2.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/InputSDL2.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/ScancodeMap.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/ExperimentalFontStub.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/sdl2Main.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/Utf8.cpp
  )
  if(EMSCRIPTEN)
    # 브라우저 어댑터 (R3): 소켓이 없으므로 핫 리로드 TCP 서버 대신 JS export 가 VM 을 재시작하고,
    # 환경 변수는 로더가 넘긴 Module.initial2dEnv 에서 읽는다.
    target_sources(Initial2D PRIVATE
      ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/emscripten/WebMain.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/emscripten/Env.cpp
    )
  else()
    # 개발용 Lua 핫 리로드 (INITIAL2D_HMR=1 옵트인)
    target_sources(Initial2D PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/HotReloadServer.cpp)
  endif()
  if(SDL2_IMAGE_INCLUDE_DIR)
    target_include_directories(Initial2D PRIVATE ${SDL2_IMAGE_INCLUDE_DIR})
  endif()
  target_link_libraries(Initial2D PRIVATE initial2d_core vendored_tinyxml ${SDL2_IMAGE_LIBRARY})
  message(STATUS "Initial2D game executable enabled (SDL2 backend)")

  # libstdc++ 의 <codecvt> 는 std::wstring_convert 를 선언한 <locale> 을 들이지 않는다.
  # lua_font.cpp 가 <locale> 을 직접 포함하기 전까지 Linux 에서는 컴파일러가 먼저 넣게 한다
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/src/lua_font.cpp" PROPERTIES COMPILE_OPTIONS "-include;locale")
  endif()

  # 판 헤더 (--version). 빌드마다 git describe 와 커밋을 다시 읽고, 바뀌었을 때만 헤더를 고친다
  find_package(Git QUIET)
  set(INITIAL2D_GENERATED_DIR "${CMAKE_BINARY_DIR}/generated")
  add_custom_target(initial2d_version
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      "-DOUTPUT=${INITIAL2D_GENERATED_DIR}/initial2d_version.h"
      "-DGIT_EXECUTABLE=${GIT_EXECUTABLE}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/initial2d_version.cmake"
    BYPRODUCTS "${INITIAL2D_GENERATED_DIR}/initial2d_version.h"
    VERBATIM)
  add_dependencies(Initial2D initial2d_version)
  target_include_directories(Initial2D PRIVATE "${INITIAL2D_GENERATED_DIR}")

  if(EMSCRIPTEN)
    # 산출물은 build-web/Initial2D.js 와 Initial2D.wasm. 페이지는 ES 모듈로 createInitial2D 를 import 한다.
    #   MODULARIZE + EXPORT_ES6: 전역을 더럽히지 않는 팩토리 함수 하나
    #   INVOKE_RUN=0:            로더가 파일을 MEMFS 에 올린 뒤 callMain 을 스스로 부른다
    #   EXIT_RUNTIME=0:          main 이 돌아와도 런타임과 requestAnimationFrame 루프가 산다
    #   FORCE_FILESYSTEM:        게임이 game.json, scripts/, resources/ 를 fopen 으로 읽는다 (MEMFS)
    #   ALLOW_MEMORY_GROWTH:     디코딩된 PNG 와 OGG 가 wasm 메모리에 산다
    #   ASYNCIFY 는 쓰지 않는다: 루프가 emscripten_set_main_loop 이라 블로킹 호출이 없다
    #   getExceptionMessage:     모듈 밖으로 나온 C++ 예외의 메시지를 로더의 errorText() 가 읽는다
    #   STACK_SIZE 8 MB:         C 를 거치는 mruby 재귀는 단계마다 wasm 스택을 최대 약 5.4 KB 쓴다. mruby 의 호출 깊이
    #                            한도(MRB_CALL_LEVEL_MAX 512, tools/web/mruby_build_config.rb)에서 약 2.8 MB 라 한도가 먼저
    #                            걸리고 SystemStackError 가 난다 (docs/plans/r3-emscripten.md 10절의 실측)
    set_target_properties(Initial2D PROPERTIES OUTPUT_NAME Initial2D SUFFIX ".js")
    target_link_options(Initial2D PRIVATE
      -sALLOW_MEMORY_GROWTH=1
      -sINITIAL_MEMORY=67108864
      -sSTACK_SIZE=8388608
      -sMODULARIZE=1
      -sEXPORT_ES6=1
      -sEXPORT_NAME=createInitial2D
      -sENVIRONMENT=web
      "-sEXPORTED_RUNTIME_METHODS=FS,ccall,cwrap,callMain,ENV,UTF8ToString,stringToNewUTF8,getExceptionMessage,decrementExceptionRefcount"
      "-sEXPORTED_FUNCTIONS=_main,_initial2d_reload,_initial2d_quit,_initial2d_features,_initial2d_frame_count,_initial2d_running,_malloc,_free"
      -sFORCE_FILESYSTEM=1
      -sEXIT_RUNTIME=0
      -sINVOKE_RUN=0
    )
  endif()

  # mruby 바인딩 (S1). 파일 하나에 모듈이나 클래스 하나, lua_*.cpp 와 같은 배치.
  if(INITIAL2D_HAS_MRUBY)
    target_sources(Initial2D PRIVATE
      ${CMAKE_CURRENT_SOURCE_DIR}/src/mrb_prot.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/mrb_input.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/mrb_audio.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/mrb_json.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/mrb_sprite.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/mrb_texture.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/mrb_tilemap.cpp
      ${CMAKE_CURRENT_SOURCE_DIR}/src/mrb_font.cpp
    )
    target_include_directories(Initial2D PRIVATE ${MRUBY_INCLUDE_DIR})
    target_compile_definitions(Initial2D PRIVATE INITIAL2D_HAS_MRUBY ${MRUBY_DEFINITIONS})
    target_link_libraries(Initial2D PRIVATE ${MRUBY_LIBRARY} m)
    if(EMSCRIPTEN)
      # libmruby 의 raise 는 setjmp/longjmp 다. -fwasm-exceptions 에서의 기본값(wasm)을 명시한다
      target_link_options(Initial2D PRIVATE -sSUPPORT_LONGJMP=wasm)
    endif()
    message(STATUS "mruby script backend enabled")
  endif()
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
  ${CMAKE_CURRENT_SOURCE_DIR}/tests/unit/rectangle_test.cpp
  # 코어 라이브러리에 없는 플랫폼 중립 소스는 여기서 직접 포함한다
  ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/Utf8.cpp
)
target_link_libraries(engine_unit_tests PRIVATE initial2d_core)

# 키 매핑(SDL 스캔코드 → VK)은 SDL 헤더만 필요한 순수 함수라 단위 테스트가 직접 부른다
if(SDL2_FOUND)
  target_sources(engine_unit_tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/tests/unit/scancode_map_test.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/platform/sdl2/ScancodeMap.cpp
  )
  target_link_libraries(engine_unit_tests PRIVATE SDL2::SDL2)
endif()
