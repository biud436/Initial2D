# Android 포팅 계획 (SDL2)

작성: 2026-08-14 · 기반 브랜치: `feature/android-port` (dev에서 파생)

macOS 포팅(Phase 0~5, `docs/porting/phase0-inventory.md`)으로 엔진은 이미 SDL2 위에서 돌아간다.
Android 포팅은 **새 렌더러 작업이 아니라** 같은 SDL2 어댑터(`src/platform/sdl2/`)를
Android 실행 환경(APK 에셋, 터치, 수명주기)에 연결하는 작업이다.

원칙은 macOS 포팅과 동일하다:

- **게임 로직·Lua 스크립트 무수정** — 플랫폼 차이는 어댑터에서 흡수한다
- Win32/GDI 원형 보존 (`RS_WINDOWS` 가드, `archive/windows-gdi` 브랜치)
- 콘텐츠·씬은 `scripts/*.lua`, C++은 엔진/어댑터만

## Phase A0 — 빌드 스캐폴딩 (이 브랜치에서 완료)

- `android/` Gradle 프로젝트: `app/jni/CMakeLists.txt`가 SDL2/SDL2_image/SDL2_mixer를
  소스에서 함께 빌드하고 엔진 전체를 `libmain.so`로 링크
- `Initial2DActivity extends SDLActivity` + `AndroidManifest.xml` (가로 고정, 풀스크린)
- `android/download_sdl.sh` — SDL 소스 다운로드 (SDL2 2.28.5 / image 2.8.2 / mixer 2.8.0,
  ogg는 stb_vorbis, png/jpg는 stb_image로 처리해 외부 라이브러리 의존 없음)
- `android/prepare_assets.sh` — `scripts/`, `resources/`, `config.setting`, `db.sqlite`를
  `assets/`로 스테이징
- `sdl2Main.cpp`에 `SDL_main.h` 연결 (`__ANDROID__` 가드) — SDLActivity가 JNI로 main 호출

## Phase A1 — 파일 I/O (최우선 차단 요소)

엔진은 `fopen`/`std::ifstream` + 상대 경로(`./scripts/...`, `./resources/...`)로 파일을 읽는다.
APK의 assets는 파일 시스템이 아니므로 이대로는 아무것도 로드되지 않는다.

**처방: 최초 실행 시 assets를 내부 저장소로 추출한 뒤 `chdir`** — 게임 로직 무수정 원칙에 부합하는
가장 값싼 방법이다.

1. 앱 시작 시(SDL_main 진입 직후, App::Run 이전) `SDL_AndroidGetInternalStoragePath()` 확보
2. 버전 마커 파일로 최초 실행/업데이트 판단 → `SDL_RWFromFile`(assets 읽기 가능)로
   `scripts/`, `resources/`, `config.setting`, `db.sqlite`를 내부 저장소로 복사
   (assets 디렉터리 열거는 JNI로 `AAssetManager_openDir` 필요 — 또는 스테이징 시
   파일 목록 매니페스트를 생성해 열거를 대체)
3. `chdir(내부 저장소 경로)` → 이후 기존 상대 경로 `fopen` 그대로 동작
4. 쓰기 파일(`db.sqlite`, `config.setting`)은 내부 저장소에 있으므로 그대로 쓰기 가능

구현 위치: `src/platform/android/` (새 어댑터 디렉터리), `sdl2Main.cpp`에서 호출.

## Phase A2 — 입력

- 터치 → 마우스: `SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "1")` — 기존 `Input.GetMouseX/Y`,
  `IsMouseDown` Lua API가 무수정으로 동작
- Android 백 버튼(`SDLK_AC_BACK`) → 종료 확인 또는 VK 매핑 결정
- 하드웨어 키보드 없는 환경이 기본이므로 `Input.IsKeyDown` 의존 씬은 터치 UI 대응 필요
  (콘텐츠 영역 — `scripts/*.lua`에서 처리)

## Phase A3 — 화면

- 논리 해상도 고정: `SDL_RenderSetLogicalSize(640, 480)` — 레터박스로 종횡비 유지,
  `WindowWidth()`/`WindowHeight()` Lua API 반환값 보존
- 고 DPI: SDL이 처리하나 텍스트 가독성 실기 확인 필요
- 화면 회전은 매니페스트에서 가로 고정으로 차단 (완료)

## Phase A4 — 수명주기·오디오

- 백그라운드 전환: SDL이 `SDL_APP_WILLENTERBACKGROUND` 이벤트 발생 — BGM 일시정지/재개
  (`Mix_PauseMusic`/`Mix_ResumeMusic`)를 어댑터에서 처리
- GLES 컨텍스트 유실 시 텍스처 복구: SDL_Renderer가 `SDL_RENDER_DEVICE_RESET` 이벤트를
  보고하므로 TextureManagerSDL2에서 재로드 경로 필요 여부 검증
- `Process`/`MessageBox` 등 데스크톱 전용 API: Android에서는 no-op 스텁
  (`IProcess` 인터페이스 뒤로 — PosixProcess의 fork/exec는 Android에서 사용하지 않음)

## Phase A5 — 검증

- 데스크톱 테스트 스위트(`tests/run_engine_tests.py`)는 로컬 프로세스 실행 전제라 그대로는 불가
- 기존 `INITIAL2D_SCREENSHOT` 프레임 덤프 경로를 재사용해 기기/에뮬레이터에서
  픽셀 검증 스크린샷을 내부 저장소로 출력 → `adb pull`로 수거해 비교
- 실기 확인 항목: 터치 입력, BGM(ogg)+SE(wav), BMFont 한글 렌더링, 60fps 유지 여부

## 리스크 메모

- `lua/*.cpp`(Lua 5.0.3 C++ 빌드), `sqlite3.c`, jsoncpp, tinyxml은 모두 NDK에서 컴파일 무리 없음
- `Encrypt.cpp`·`ExperimentalFontStub` 등 macOS에서 이미 검증된 파일은 그대로 재사용
- 성능: GDI 시절 소프트웨어 렌더링과 달리 SDL_Renderer(GLES2)는 하드웨어 가속 —
  프레임 상한이 없는 메인 루프라 모바일에서 배터리 소모 큼 → 프레임 제한(vsync) 검토
