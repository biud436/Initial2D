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
- `android/download_sdl.sh` — SDL 소스 다운로드 (SDL2 2.30.9 / image 2.8.2 / mixer 2.8.0,
  ogg는 stb_vorbis, png/jpg는 stb_image로 처리해 외부 라이브러리 의존 없음.
  SDL2 2.30.7 미만은 NDK r27에서 ALooper_pollAll 제거로 빌드 불가)
- 16KB 페이지 크기 호환 (Android 15+ 기기 경고 대응): NDK r27 +
  `ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON` + `c++_static` + AGP 8.7.3(16KB zip 정렬)
- `android/prepare_assets.sh` — `scripts/`, `resources/`, `config.setting`, `db.sqlite`를
  `assets/`로 스테이징
- `sdl2Main.cpp`에 `SDL_main.h` 연결 (`__ANDROID__` 가드) — SDLActivity가 JNI로 main 호출

## Phase A1 — 파일 I/O (최우선 차단 요소) — **구현됨**

구현: `src/platform/android/AndroidBootstrap.cpp` — `prepare_assets.sh`가 생성한
`assets_manifest.txt` 목록대로 assets를 내부 저장소로 추출(매니페스트 불변 시 생략) 후 `chdir`.
`sdl2Main.cpp`에서 App 생성 전에 호출한다.

**미해결 캐비앳**: 에셋이 갱신되면 전체를 재추출하므로 기기의 `db.sqlite`(세이브 데이터)도
덮어쓴다. 세이브 보존이 필요해지면 쓰기 파일을 재추출 대상에서 제외할 것.


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

## Phase A2 — 입력 — **터치 실기 확인됨**

- 터치 → 마우스: SDL 기본 동작(TOUCH_MOUSE_EVENTS 기본 on)으로 실기에서 게임 조작 확인됨.
  기존 `Input.GetMouseX/Y`, `IsMouseDown` Lua API가 무수정으로 동작
- Android 백 버튼(`SDLK_AC_BACK`) → 종료 확인 또는 VK 매핑 결정
- 하드웨어 키보드 없는 환경이 기본이므로 `Input.IsKeyDown` 의존 씬은 터치 UI 대응 필요
  (콘텐츠 영역 — `scripts/*.lua`에서 처리)

## Phase A3 — 화면 — **구현됨 (풀 스크린 실기 확인)**

- 가로 모드: SDLActivity가 창 비율(768x896)만 보고 세로를 강제하므로
  `SDL_HINT_ORIENTATIONS`로 가로를 명시 (AppSDL2.cpp)
- 풀 스크린: `SDL_WINDOW_FULLSCREEN`(몰입 모드로 상태바/내비바 숨김) +
  `windowLayoutInDisplayCutoutMode=shortEdges`(카메라 컷아웃 영역까지 확장)
- 화면 채움: 논리 해상도의 가로를 실제 화면 비율에 맞춰 확장 (세로 896 고정) —
  씬이 `WindowWidth()/WindowHeight()` 기준으로 배치되므로 왜곡·레터박스 없이 풀 화면
- 진행 속도: 120Hz 디스플레이에서 elapsed(~8ms)가 60Hz 고정 스텝과 결합해 절반 속도가 되던
  문제를 고정 delta(16ms) 전달로 수정 (AppSDL2.cpp — 60Hz 데스크톱은 동작 동일)
- 남은 항목: 고 DPI 텍스트 가독성 실기 확인

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

- **포인터↔double 왕복**: Lua 바인딩은 C++ 포인터를 lua_Number(double)로 주고받는데,
  Android 힙 포인터 태깅(상위 바이트 0xb4)이 켜져 있으면 주소가 double의 53비트 정밀도를
  넘어 SIGSEGV가 난다 → 매니페스트 `allowNativeHeapPointerTagging=false`로 해결(구현됨).
  근본 해결은 lightuserdata 전환이지만 바인딩 전면 수정이 필요해 보류

- `lua/*.cpp`(Lua 5.0.3 C++ 빌드), `sqlite3.c`, jsoncpp, tinyxml은 모두 NDK에서 컴파일 무리 없음
- `Encrypt.cpp`·`ExperimentalFontStub` 등 macOS에서 이미 검증된 파일은 그대로 재사용
- 성능: GDI 시절 소프트웨어 렌더링과 달리 SDL_Renderer(GLES2)는 하드웨어 가속 —
  프레임 상한이 없는 메인 루프라 모바일에서 배터리 소모 큼 → 프레임 제한(vsync) 검토
