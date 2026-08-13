# Phase 0 — macOS 컴파일 가능성 인벤토리

측정일: 2026-08-13 / 환경: macOS (arm64), Apple clang 17, `-std=c++17`
명령: `clang++ -fsyntax-only -Isrc -Ilua -Ijson/Json -I/opt/homebrew/include/SDL2 -D_THREAD_SAFE src/<file>.cpp`

이 문서는 `docs/prompts/macos-porting-meta-prompt.md`의 Phase 0 산출물이며,
이후 Phase의 작업 대상 목록이다. Phase가 진행되며 파일이 PASS로 이동하면 갱신할 것.

## PASS — macOS에서 컴파일되는 파일 (CMake `initial2d_core`에 포함됨)

| 파일 | 비고 |
|---|---|
| `File.cpp` | |
| `GameState.cpp` | |
| `GameStateMachine.cpp` | |
| `lua_tbl.cpp` | vendored Lua 헤더 직접 include (extern "C" 없음 — Lua를 C++로 컴파일하는 방식) |
| `Matrix.cpp` | 비-Windows 분기의 `sturct` 오타 수정 후 통과 (원저자가 준비해둔 크로스 플랫폼 분기) |

## FAIL — 실패 원인별 분류

### A. `<Windows.h>` 직접 include (어댑터 추출 대상)

| 파일 | 담당 Phase |
|---|---|
| `App.cpp` (App.h) | Phase 2 (창·이벤트) |
| `Thread.cpp` (Thread.h), `win32Main.cpp` | Phase 1 (std::thread 공통화) |
| `Encrypt.cpp`, `StringUtils.cpp`, `Utility.cpp` | Phase 1 (표준 라이브러리 공통화) |
| `Process.cpp` (Process.h) | Phase 1 (IProcess + posix_spawn) |
| `Input.cpp` (Input.h) | Phase 4 (IInputDevice) |
| `Renderer.cpp`, `TextureManager.cpp`, `Sprite.cpp` | Phase 3 (IRenderDevice) |
| `ExperimentalFont.cpp`, `lua_font.cpp` | Phase 5 (IGlyphRasterizer) |

### B. Windows.h 전이 포함 (직접 include 없음 — 상위 헤더가 중립화되면 통과 예상)

| 파일 | 전이 경로 |
|---|---|
| `Font.cpp`, `GameObject.cpp`, `Tile.cpp`, `Tilemap.cpp`, `lua_sprite.cpp` | → `Sprite.h` |
| `main.cpp`, `MapState.cpp`, `MenuState.cpp`, `lua_input.cpp`, `lua_texture.cpp`, `lua_prot.cpp` | → `App.h` |
| `Window.cpp` | → `App.h` (Window.h 자체는 SDL 기반) |

### C. FMOD 참조 (include 순서 의존 코드)

| 파일 | 원인 |
|---|---|
| `SoundManager.cpp`, `lua_audio.cpp`, `FMODSoundManager.cpp` | `SoundManager.h:44`의 `FSoundProxy`가 fmod 헤더 include 없이 `FMOD::System*` 참조. VS에서는 TU 내 include 순서로 우연히 컴파일됨. macOS용 FMOD 바이너리는 vendored되어 있지 않으므로 Phase 1에서 가드 처리 필요 |

## Phase 0에서 적용한 최소 수정 (기존 동작 무변경)

1. **인코딩**: `src/*.h`, `src/*.cpp` 37개 파일 CP949 → UTF-8 (라운드트립 검증으로 내용 무변경 확인).
   MSVC용으로 `Directory.Build.props`에 `/source-charset:utf-8` 추가 (실행 문자셋은 CP949 유지 —
   `MessageBoxA` 등에 전달되는 한글 리터럴의 Windows 런타임 동작 보존). vcxproj는 무수정.
2. **`Rectangle.h`**: 클래스 내부 정의의 `Rectangle::Rectangle`/`Rectangle::~Rectangle` 여분 한정자 제거
   (MSVC 확장, 표준 C++ 위반 — MSVC 동작 변화 없음).
3. **`Matrix.h:10`**: 비-Windows 분기의 `sturct` → `struct` 오타 수정 (Windows 빌드에서는 컴파일되지 않는 분기).

## 발견했으나 수정하지 않은 항목 (보고만)

- `Rectangle.h`의 `operator=`가 `return` 문 없음 — 호출 시 미정의 동작. Windows에서도 잠재 버그.
  기존 동작 보존 원칙에 따라 Phase 0에서는 수정하지 않음. 저자 확인 후 `return *this;` 추가 권장.
- README에는 Lua v5.0.3으로 기재되어 있으나 vendored Lua는 **5.3.5** (`LUA_RELEASE` 실측).
- 루트 `db.sqlite`는 SQLite 3.7.x 시절 파일, vendored `sqlite3.c`는 3.7.17 — 호환 문제 없음.

## Phase 0 검증 결과

```
$ cmake -B build && cmake --build build -j 8
-- SDL2 found: 2.30.9
[100%] Built target phase0_sanity
$ ./build/phase0_sanity
phase0 sanity OK — Lua 5.3.5 / sqlite 3.7.17 / jsoncpp
```
