# macOS 컴파일 가능성 인벤토리 (Phase 진행에 따라 갱신)

최초 측정: 2026-08-13 (Phase 0) / 최근 갱신: 2026-08-13 (**Phase 2~5 완료 — 게임 실행 파일 macOS 구동 확인**)

## 최종 상태 요약 (Phase 2~5)

- **PASS: 28 / 33** — `cmake --build build` 로 `Initial2D` 게임 실행 파일이 macOS에서 빌드·실행됨
- 남은 FAIL 5개는 모두 의도적 제외: `win32Main.cpp`(Windows 엔트리), `Process.cpp`(Win32 전용,
  `platform/posix/PosixProcess`로 대체), `Renderer.cpp`(빈 파일 — 실 렌더러는 TextureManager),
  `Window.cpp`(미사용 실험 코드, `std::exception(msg)` MSVC 확장 포함), `FMODSoundManager.cpp`(Windows에서도 깨진 WIP)
- 아키텍처: Win32/GDI 구현은 `RS_WINDOWS` 가드로 원형 보존, SDL2 어댑터는 `src/platform/sdl2/`,
  공개 API 시그니처는 `platform/WinTypes.h` 심(RECT/BYTE/COLORREF/VK_* 등)으로 무변경 유지
- 검증: 정적 테스트 씬에서 배경 + 반투명 스프라이트(opacity) + 45° 회전(XFORM→RenderCopyEx) +
  2배 스케일 + BMFont 텍스트 렌더링을 프레임 덤프로 확인 (`INITIAL2D_SCREENSHOT` env)
- 오디오: `Audio.PlayMusic`으로 `resources/audio/bless.ogg` 재생 확인 (SDL2_mixer, macOS)
- 미검증 항목: 키보드 입력 실기 검증 (스캔코드→VK 매핑 테이블은 구현됨 — 실제 키 입력은
  사용자 플레이로 확인 필요), Tilemap 경로 (MapState의 Tilemap 생성이 원본에서 주석 처리 상태)
- 발견: `scripts/main.lua`가 참조하는 에셋 3종(background/object/bird PNG)은 저장소에 없음
  (`resources/*.*`가 gitignore) — 검증은 로컬 생성 플레이스홀더로 수행, 커밋하지 않음
- BMFont 텍스트는 fontSize(32) ≠ lineHeight(16)일 때 원본 GDI 알고리즘 그대로 아틀라스를
  2배 영역으로 샘플링해 글자가 겹침 — SDL2 어댑터는 이를 충실히 재현 (동작 보존 원칙)
환경: macOS (arm64), Apple clang 17, `-std=c++17`
명령: `clang++ -fsyntax-only -Isrc -Ilua -Ijson/Json -I/opt/homebrew/include/SDL2 -D_THREAD_SAFE src/<file>.cpp`

이 문서는 `docs/prompts/macos-porting-meta-prompt.md`의 Phase 0 산출물이며,
이후 Phase의 작업 대상 목록이다.

## PASS — macOS에서 컴파일되는 파일 (10 / 33)

| 파일 | 통과 시점 | 비고 |
|---|---|---|
| `File.cpp` | Phase 0 | |
| `GameState.cpp` | Phase 0 | |
| `GameStateMachine.cpp` | Phase 0 | |
| `lua_tbl.cpp` | Phase 0 | vendored Lua 헤더 직접 include (extern "C" 없음) |
| `Matrix.cpp` | Phase 0 | 비-Windows 분기의 `sturct` 오타 수정 후 통과 |
| `Thread.cpp` | Phase 1 | `std::thread`/`std::mutex`로 공통화 (원본: `platform/win32/legacy/`) |
| `StringUtils.cpp` | Phase 1 | Win32 문자셋 변환 함수만 `_WIN32` 가드로 격리 (호출처 없음) |
| `Utility.cpp` | Phase 1 | `GetWorkingDirectory`(호출처 없음)를 Win32 가드로 격리 |
| `SoundManager.cpp` | Phase 1 | `FMOD::System` 전방 선언 추가 후 통과, SDL2_mixer 링크 |
| `lua_audio.cpp` | Phase 1 | SoundManager 통과에 따라 연쇄 통과 |

## FAIL — 실패 원인별 분류 (23 / 33)

### A. `<Windows.h>` 직접 include (어댑터 추출 대상)

| 파일 | 담당 Phase |
|---|---|
| `App.cpp` (App.h) | Phase 2 (창·이벤트) |
| `win32Main.cpp` | Phase 2 (Windows 전용 엔트리로 유지 — mac 빌드 제외 대상) |
| `Encrypt.cpp` | Phase 2+ (`App.h` 의존 제거 후 `FindFirstFile` → `std::filesystem`) |
| `Process.cpp` | 보류 (실사용 호출처 없음 — 중립 대체는 `platform/posix/PosixProcess`) |
| `Input.cpp` (Input.h) | Phase 4 (IInputDevice) |
| `Renderer.cpp`, `TextureManager.cpp`, `Sprite.cpp` | Phase 3 (IRenderDevice) |
| `ExperimentalFont.cpp`, `lua_font.cpp` | Phase 5 (IGlyphRasterizer) |

### B. Windows.h 전이 포함 (상위 헤더가 중립화되면 통과 예상)

| 파일 | 전이 경로 |
|---|---|
| `Font.cpp`, `GameObject.cpp`, `Tile.cpp`, `Tilemap.cpp`, `lua_sprite.cpp` | → `Sprite.h` (Phase 3) |
| `main.cpp`, `MapState.cpp`, `MenuState.cpp`, `lua_input.cpp`, `lua_texture.cpp`, `lua_prot.cpp` | → `App.h` (Phase 2) |
| `Window.cpp` | → `App.h` (Window.h 자체는 SDL 기반) |

### C. FMOD (Windows에서도 깨져 있는 WIP 파일)

| 파일 | 원인 |
|---|---|
| `FMODSoundManager.cpp` | `FMODSoundManager.h`가 `SoundManager.h`를 include한 뒤 `sound_type`/`BGM`/`SE`를 **재정의** — MSVC에서도 컴파일 불가(C2011). vcxproj에 포함되어 있으므로 아카이브된 Windows 빌드도 이 파일에서 실패하는 상태로 방치된 WIP로 판단됨. macOS용 FMOD 바이너리도 없으므로 포팅 대상에서 제외. Windows 측 수정 여부는 저자 결정 필요 |

## Phase 1에서 적용한 변경 (2026-08-13)

1. **플랫폼 중립 인터페이스 초안** (`src/platform/`): `IWindow`, `IInputDevice`, `IRenderDevice`,
   `IGlyphRasterizer`, `IProcess`, `SystemPath`. 각 인터페이스는 담당 Phase에서 실제 호출 패턴
   기준으로 확정한다. 아핀 변환 중립 타입은 별도 `Affine2D.h` 대신 **원저자가 이미 만들어 둔
   `Matrix.h`의 비-Windows `TransformData` 분기를 그대로 사용**하기로 결정.
2. **POSIX 어댑터**: `platform/posix/SystemPath.cpp`(`_NSGetExecutablePath` 기반),
   `platform/posix/PosixProcess.cpp`(`posix_spawn` 기반, 원본과 동일하게 자식을 기다리지 않음).
3. **Thread std 공통화**: 공개 인터페이스 유지(`start/join/lock/unlock/run/isWaiting`).
   원본 파일은 `platform/win32/legacy/`에 보존. `OutputDebugString` 트레이스는 stderr로 변경
   (디버그 빌드 한정). `Callback` 시그니처는 `UINT WINAPI` → `unsigned int`(외부 호출처 없음).
4. **StringUtils/Utility**: Win32 전용 부분(모두 호출처 없는 죽은 코드)만 `_WIN32` 가드로 격리,
   원본 코드 자체는 무수정. 게임 로직이 아닌 leaf 유틸리티이므로 어댑터 대신 가드를 허용.
5. **호환 수정**: `SoundManager.h`에 `FMOD::System` 전방 선언(include 순서 우연에 의존하던 코드),
   `Constants.h`의 `RSLIB`를 비-Windows에서 visibility 어트리뷰트로 정의,
   `win32Main.cpp`의 TEST_MODE 분기에 `<Windows.h>` 직접 include 추가
   (Thread.h의 전이 include가 사라졌기 때문 — **Windows Test 구성 유지용**).

## 발견했으나 수정하지 않은 항목 (보고만)

- `Rectangle.h`의 `operator=`가 `return` 문 없음 — 호출 시 미정의 동작. Windows에서도 잠재 버그.
  저자 확인 후 `return *this;` 추가 권장.
- `FMODSoundManager.h`의 타입 재정의 — 위 C절 참조. Windows 빌드도 깨뜨리는 상태.
- `StrSplit`(StringUtils.cpp)은 토큰이 아니라 **구분자 문자열 자체를 반환**한다 — 주석의 예제
  출력과는 일치하므로 의도일 수 있으나 이름과 동작이 다름. 동작 보존 원칙에 따라 무수정.
- README에는 Lua v5.0.3으로 기재되어 있으나 vendored Lua는 **5.3.5** (`LUA_RELEASE` 실측).

## 검증 결과

```
$ cmake -B build && cmake --build build -j 8
-- SDL2 found: 2.30.9
-- SoundManager enabled (SDL2_mixer: /opt/homebrew/lib/libSDL2_mixer.dylib)
[100%] Built target phase1_sanity

$ ./build/phase0_sanity
phase0 sanity OK — Lua 5.3.5 / sqlite 3.7.17 / jsoncpp

$ ./build/phase1_sanity
new Thread();
Callback();
~Thread();
phase1 sanity OK — thread/std, string utils, platform headers, exe dir: /Users/u/Initial2D/build
```
