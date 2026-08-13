# Initial2D macOS 포팅 메타 프롬프트

> 이 문서는 AI 코딩 에이전트(Claude Code 등)에게 그대로 전달하여 Initial2D 엔진의 macOS 포팅을
> 단계별로 진행시키기 위한 메타 프롬프트입니다. 아래 "프롬프트 본문" 전체를 복사해서 사용하세요.
> 각 Phase는 독립적으로 실행 가능하므로, 한 세션에 한 Phase씩 진행하는 것을 권장합니다.

---

## 프롬프트 본문

당신은 Win32/GDI 기반 C++ 게임 엔진을 macOS로 포팅하는 크로스 플랫폼 엔지니어입니다.
대상 저장소는 Initial2D — 2018년경 작성된 개인 게임 엔진으로, 렌더링은 Windows GDI,
오디오는 SDL2_mixer, 스크립트는 Lua, 데이터는 JSON/SQLite를 사용합니다.

### 최우선 원칙: 기존 작업물을 교체하지 않는다

이 포팅은 **GDI 코드를 SDL2로 대체하는 작업이 아니다.** 기존 Win32/GDI 구현은 저자의 작업물로서
그대로 보존하며, **어댑터 패턴**으로 플랫폼 중립 인터페이스를 추출한 뒤 그 뒤에
기존 GDI 구현(Win32 어댑터)과 신규 SDL2 구현(macOS 어댑터)을 나란히 두는 것이 목표다.

- 기존 GDI 코드의 내부 로직은 수정하지 않는 것이 원칙. 허용되는 변경은
  "인터페이스를 상속받게 하는 껍데기 씌우기"와 "파일 이동/이름 변경"까지다.
- `#ifdef` 조건부 컴파일을 게임 로직에 흩뿌리지 않는다. 플랫폼 분기는 딱 두 곳에만 존재한다:
  1. **빌드 시스템** — CMake가 플랫폼별로 컴파일할 어댑터 소스 파일을 선택한다.
  2. **팩토리 함수 한 곳** — 어떤 어댑터 구현을 생성할지 결정하는 지점.
- 게임 로직(`GameState`, `Sprite`, `Tilemap`, `lua_*` 바인딩 등)은 중립 인터페이스만 참조한다.
  공개 헤더에서 `HBITMAP`, `HDC`, `XFORM`, `COLORREF`, `SDL_Texture*` 같은
  플랫폼 타입이 노출되지 않아야 한다.

**목표 디렉터리 구조 (제안 — 실제 코드 확인 후 조정 가능):**

```
src/
  platform/
    IRenderDevice.h    // 텍스처 생성·블리팅·변환의 순수 가상 인터페이스
    IWindow.h          // 창 생성·이벤트 펌프
    IInputDevice.h     // 키 상태 폴링 (키코드는 기존 VK_* 값을 중립 표준으로 유지)
    IGlyphRasterizer.h // TrueType 글리프 래스터화 (ExperimentalFont가 사용)
    IProcess.h         // 자식 프로세스 실행
    Affine2D.h         // XFORM을 대체하는 중립 2D 아핀 변환 타입
    win32/             // 기존 GDI/Win32 코드가 어댑터로 이동 (내부 무수정)
    sdl2/              // 신규 SDL2 어댑터 (macOS 기본, Windows에서도 선택 가능)
  ...                  // 게임 로직은 platform/ 인터페이스만 include
```

### 브랜치·버전 규칙

- 포팅 이전 원본은 `archive/windows-gdi` 브랜치와 `v1.1.0` 태그로 아카이빙되어 있다.
  이 브랜치와 태그는 절대 수정하지 않는다.
- 모든 포팅 작업은 `feature/macos-port` (또는 그 하위 브랜치)에서 진행한다.
  **master에 직접 커밋하지 않는다.**
- 동작이 실제로 확인된 후에만 PR을 올린다. PR 이전에 push하지 않는다.

### 전제가 되는 현재 상태 (조사 완료된 사실)

작업 전 아래 사실을 신뢰하되, 코드가 변경되었을 수 있으므로 각 Phase 시작 시 해당 파일을 다시 확인할 것.

**이미 포팅에 유리한 조건:**

- `SoundManager`는 이미 SDL2_mixer 기반 → 오디오는 어댑터 없이 그대로 크로스 플랫폼.
- `Window.h/.cpp`가 이미 `SDL_Window`/`SDL_Renderer`/`SDL_Texture` 래퍼로 작성되어 있음
  → SDL2 어댑터의 출발점으로 재사용.
- `Renderer.h`에 `RS_SDL_RENDERER` 매크로로 `<Windows.h>` ↔ `<SDL.h>`를 전환하는 미완성 분기가 존재.
  이 매크로 방식(조건부 컴파일)은 위의 어댑터 구조로 흡수하고 매크로 분기는 걷어낸다.
- `Constants.h`에 `__APPLE__`/`TargetConditionals.h` 기반 플랫폼 감지가 이미 있음 (`RS_WINDOWS` 등).
- Lua(vendored, `lua/`), SQLite(`src/sqlite3.c` amalgamation), JSON, BMFont(`Font.h`)는 플랫폼 독립적.

**포팅 대상 — `<Windows.h>`를 include하는 14개 파일:**
`App.h`, `win32Main.cpp`, `Renderer.h`, `TextureManager.h`, `Sprite.h`, `Input.h`,
`ExperimentalFont.h`, `Thread.h`, `Process.h`, `Matrix.h`, `Encrypt.h`, `StringUtils.h`,
`Utility.h`, `lua_prot.cpp`

**Win32 API 사용 인벤토리와 인터페이스 매핑 (src/ 전체, 근사치):**

| Win32/GDI API | 호출 수 | 소속될 인터페이스 | SDL2 어댑터에서의 구현 |
|---|---|---|---|
| `SelectObject` | 17 | `IRenderDevice` | SDL_Texture 직접 사용으로 소멸 |
| `CreateCompatibleDC` | 7 | `IRenderDevice` | `SDL_Texture` (target texture) |
| `SetWorldTransform` (XFORM) | 6 | `IRenderDevice` + `Affine2D` | 회전/스케일/플립이면 `SDL_RenderCopyEx`, 완전 아핀(기울임)이 필요하면 `SDL_RenderGeometry` (SDL ≥ 2.0.18) |
| `CreateDIBSection` | 3 | `IRenderDevice` | `SDL_CreateTexture(STREAMING)` + `SDL_LockTexture` |
| `GetAsyncKeyState` | 3 | `IInputDevice` | `SDL_GetKeyboardState` + scancode→VK 매핑 |
| `BitBlt`/`TransparentBlt`/`AlphaBlend` | 6 | `IRenderDevice` | `SDL_RenderCopy` + blend mode/alpha mod/`SDL_SetColorKey` |
| `QueryPerformanceCounter` | 2 | 공통 유틸 (어댑터 불필요) | `std::chrono::steady_clock`로 통일 |
| `GetGlyphOutline` (ExperimentalFont) | - | `IGlyphRasterizer` | `SDL_ttf` 또는 `stb_truetype` |
| `CreateWindow`/`WinMain`/`WndProc` | - | `IWindow` + 엔트리 포인트 | `int main()` + SDL 이벤트 루프 |
| `CreateProcess` (Process.h) | - | `IProcess` | `posix_spawn` |
| Win32 `HANDLE` 스레드/뮤텍스 (Thread.h) | - | 어댑터 불필요 — `std::thread`/`std::mutex`로 공통화 | (플랫폼 중립 std 사용) |
| `Shlwapi` 경로 함수 (main.cpp) | - | 공통 유틸 | `std::filesystem` + macOS `_NSGetExecutablePath` |
| `__declspec(dllexport)` (`RSLIB`, Constants.h) | - | 매크로 수정 | 비-Windows에서 `__attribute__((visibility("default")))` 또는 빈 매크로 |

`Thread`, 타이머, 경로 처리처럼 **C++ 표준만으로 해결되는 것은 어댑터를 만들지 않고
표준 라이브러리로 공통화**한다. 어댑터는 진짜 플랫폼 API가 필요한 곳
(렌더링, 창, 입력, 글리프, 프로세스)에만 둔다. 단, 이 경우에도 기존 Win32 구현 파일은
`platform/win32/`에 보존하고 Windows 빌드에서 계속 쓸지 여부를 사용자와 합의한다.

**코드베이스의 함정 (반드시 숙지):**

1. **소스 인코딩이 CP949(EUC-KR)** — 다수의 `.h/.cpp` 주석이 CP949로 저장되어 있어 macOS에서
   grep이 파일을 바이너리로 취급하고, clang이 처리하지 못할 수 있음. Phase 0에서 C++ 소스만
   UTF-8로 일괄 변환할 것. **`scripts/`(런타임 Lua)와 `resources/`는 변환하지 않는다** —
   엔진이 런타임에 CP949로 읽을 수 있으므로 소스 코드와 별개로 다뤄야 한다.
   MSVC 재빌드를 위해 CMake에 `/utf-8` 플래그를 명시해 둘 것.
2. **TCHAR/`_UNICODE` 혼용** — `tchar.h`, `std::wstring`, `MAX_PATH` 등이 흩어져 있음.
   중립 인터페이스의 문자열은 UTF-8 `std::string`으로 통일하고, 변환은 어댑터 내부에서만 한다.
3. **빌드가 Visual Studio 전용** — `.sln`/`.vcxproj`만 존재. 전처리기 정의(`TEST_MODE` 등)가
   vcxproj 안에 있으므로 CMake로 옮길 때 구성별 정의를 누락하지 말 것. vcxproj는 삭제하지 않는다.
4. **루트의 `*.dll`들** — SDL2, SDL2_image, SDL2_mixer 및 코덱 DLL은 Windows 배포용.
   macOS에서는 Homebrew(`brew install sdl2 sdl2_image sdl2_mixer sdl2_ttf`)로 대체.
5. **`Renderer.h` 내부에 `TextureManager.h`와 중복된 선언**(include guard도
   `__TEXTUREMANAGER_WIN32_IMPL_H_`로 복제됨)이 있음 — 인터페이스 추출 시 단일 소스로 정리하되,
   원본 파일은 win32 어댑터 디렉터리에 보존.
6. **Lua가 5.x vendored** — 시스템 Lua를 쓰지 말고 vendored 소스를 그대로 CMake 타깃으로 빌드.

### 작업 원칙

- 각 Phase가 끝날 때마다 **빌드가 통과하는 상태**를 유지한다. Windows 빌드(vcxproj)를
  깨뜨릴 수 있는 변경(파일 이동 등)은 vcxproj도 함께 갱신하거나, 불가능하면 사용자에게 보고한다.
- 동작 확인이 가능한 최소 데모(창 생성 → 스프라이트 표시 → 키 입력 → 사운드 재생)를
  Phase 3 종료 시점부터 항상 실행 가능하게 유지한다.
- 기존 클래스의 공개 인터페이스(`TextureManager`, `Input`, `SoundManager` 등)는 최대한 유지한다.
  Lua 바인딩(`lua_*.cpp`)이 이 인터페이스에 의존하기 때문이다. 특히 Lua에 노출되는
  키 코드 값(VK 계열)은 절대 바꾸지 않는다 — 스크립트 호환성이 우선이다.
- 커밋은 Phase 단위보다 잘게, 되돌릴 수 있는 단위로 한다.

### Phase 별 작업

**Phase 0 — 기반 정리 (로직 변경 없음)**
1. C++ 소스(`src/*.h`, `src/*.cpp`)의 인코딩을 CP949 → UTF-8로 일괄 변환한다
   (`iconv -f cp949 -t utf-8`). 변환 전 각 파일이 실제 CP949인지 확인하고(UTF-8 유효성 검사로 선별),
   변환 후 한글 주석이 올바른지 표본 검수한다. `scripts/`·`resources/`는 건드리지 않는다.
2. 최상위 `CMakeLists.txt`를 작성한다: 타깃은 `lua`(static), `sqlite3`(static), `Initial2D`(exe).
   SDL2 계열은 `find_package`로 찾되 Phase 0에서는 없어도 configure가 실패하지 않게 한다.
3. macOS에서 현재 컴파일 가능한 파일과 Windows 의존으로 실패하는 파일을 실측 분류하고
   (파일별 `-fsyntax-only` 시도), 실패 파일 목록과 실패 원인을 보고한다.
   이 목록이 이후 Phase의 작업 대상 목록이 된다.

**Phase 1 — 플랫폼 중립 인터페이스 정의 + 표준 라이브러리 공통화**
1. `src/platform/`에 인터페이스 헤더(`IRenderDevice`, `IWindow`, `IInputDevice`,
   `IGlyphRasterizer`, `IProcess`, `Affine2D`)를 작성한다. 이 시점에는 구현 없이 컴파일만 확인.
2. `Thread.h/.cpp` → `std::thread`/`std::mutex`/`std::condition_variable`로 공통화 (인터페이스 유지).
3. `StringUtils`, `Utility`, `Matrix`, `Encrypt`의 `<Windows.h>` 의존을 분석하고,
   표준 라이브러리로 대체 가능한 것만 공통화한다. `Matrix`가 XFORM을 감싸고 있다면
   `Affine2D`로 중립화하고 win32 어댑터에서 XFORM 변환 함수를 제공한다.
4. `main.cpp`의 `Shlwapi` 경로 획득 → `std::filesystem` + 플랫폼별 실행 경로 함수.
5. `Constants.h`의 `RSLIB` 매크로를 비-Windows에서 안전하게 정의.

**Phase 2 — 창·엔트리 포인트 어댑터**
1. `win32Main.cpp`(WinMain/WndProc)는 그대로 두고, SDL 엔트리 포인트
   `platform/sdl2/sdl2Main.cpp`를 추가한다: `SDL_Init` → 기존 `Window` 클래스 재사용 →
   `SDL_PollEvent` 루프 → `App::GetInstance()` 위임.
2. `App`의 이벤트 처리를 중립화한다: 기존 `HandleEvent(hWnd, uMsg, wParam, lParam)`는 유지하고,
   내부 공통 로직을 추출해 `HandleEvent(const SDL_Event&)`(sdl2 어댑터)와 공유한다.
3. `QueryPerformanceCounter` 사용부를 `std::chrono::steady_clock`로 공통화.

**Phase 3 — 렌더 디바이스 어댑터 (핵심 작업)**
1. `TextureManager`/`Renderer`에서 순수 가상 `IRenderDevice`/텍스처 핸들 개념을 추출한다.
   게임 로직이 보는 텍스처는 불투명 핸들(ID 또는 인터페이스 포인터)로 바꾸고,
   `HBITMAP`은 win32 어댑터 내부로 숨긴다.
2. 기존 GDI 구현(`Renderer.cpp`, `TextureManager.cpp`의 GDI 경로)을 `platform/win32/`로 이동해
   `IRenderDevice`의 Win32 어댑터로 만든다. **내부 로직은 수정하지 않는다.**
3. `platform/sdl2/`에 SDL2 어댑터를 구현한다: 텍스처 로딩은 SDL2_image(`IMG_LoadTexture`),
   블리팅은 `SDL_RenderCopy` + blend/alpha/color key.
4. `SetWorldTransform`(XFORM) 사용부 6곳을 분석해 실제 필요한 변환을 판별:
   회전/스케일/플립뿐이면 `SDL_RenderCopyEx`, 기울임이 있으면 `SDL_RenderGeometry`.
   판별 결과를 보고에 포함할 것.
5. `Sprite`, `Tilemap`, `Tile`, `Font`(BMFont) 렌더 호출부를 `IRenderDevice` 경유로 전환.
   `RS_SDL_RENDERER` 매크로 분기는 이 시점에 제거한다.

**Phase 4 — 입력 어댑터**
1. `Input`의 공개 인터페이스(4-상태 `KEY_STATE` 머신, VK 계열 키 코드)는 그대로 두고,
   키 폴링 부분만 `IInputDevice`로 추출한다.
2. win32 어댑터는 기존 `GetAsyncKeyState` 코드 보존, sdl2 어댑터는
   `SDL_GetKeyboardState` + scancode→VK 매핑 테이블로 구현한다.
   `lua_input.cpp`가 노출하는 키 코드 값은 변하지 않아야 한다.

**Phase 5 — 폰트 어댑터**
1. `Font.h/.cpp`(BMFont)는 Phase 3에서 이미 중립화됨 — 확인만 한다.
2. `ExperimentalFont`(GetGlyphOutline)의 글리프 래스터화를 `IGlyphRasterizer`로 추출:
   win32 어댑터는 기존 코드 보존, sdl2 어댑터는 `SDL_ttf` 또는 `stb_truetype`로 구현.
   안티앨리어싱 옵션(`USE_ANTIALIASING`)은 blended 렌더링으로 대응.
   사용처가 없으면 macOS에서 스텁 처리하고 그 사실을 보고한다.

**Phase 6 — 통합 검증**
1. `resources/` + `db.sqlite` + `config.setting`을 사용하는 실제 게임 루프
   (`MenuState` → `MapState`)를 macOS에서 실행하고 스크린샷/로그로 검증한다.
2. Lua 스크립트 로딩, JSON 게임 데이터 로딩, SQLite 접근, BGM/SE 재생을 각각 확인한다.
   런타임 파일(CP949 가능성)의 인코딩 문제가 있으면 로더 계층에서 변환한다.
3. `TEST_MODE` 구성(sqlite/thread 테스트 코드)도 CMake 옵션으로 재현한다.
4. 남은 Windows 전용 잔재와 미해결 항목을 최종 보고서로 정리하고,
   **이 시점에 비로소 PR을 올린다** (그 전에는 push하지 않는다).

### 완료 기준

- macOS에서 `cmake -B build && cmake --build build`만으로 빌드된다.
- 창이 뜨고, 타일맵과 스프라이트가 렌더링되며, 키보드 입력과 BGM/SE가 동작한다.
- Lua 스크립트가 수정 없이 동일하게 동작한다 (키 코드 포함).
- 기존 GDI 구현이 `platform/win32/`에 원형대로 보존되어 있고, Windows 빌드 경로가 유지된다.
- 게임 로직 소스에서 `#ifdef` 플랫폼 분기와 플랫폼 타입 노출이 없다
  (빌드 시스템과 팩토리 한 곳 제외).

### 보고 형식

각 Phase 종료 시: 변경 파일 목록, 인터페이스 변경 여부, 새로 발견한 Windows 의존성,
직접 실행한 검증 명령과 그 실제 출력 결과를 보고한다. 빌드/테스트가 실패하면 실패한 상태 그대로
출력과 함께 보고하고, 성공을 가정한 서술을 하지 않는다.
