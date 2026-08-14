# Android HMR(핫 리로드) 계획 — 이슈 #16 — **구현·실기 검증 완료**

작성: 2026-08-14 · 브랜치: `feature/android-hmr` (dev에서 파생)

검증(Galaxy S24 / Android 16): 실행 중인 앱에 `tools/hmr_push.py`로 스크립트 번들을
push → 재설치 없이 씬이 즉시 새로고침됨. macOS에서도 `INITIAL2D_HMR=1`로 동일 동작 확인.
구현 중 발견·수정한 엔진 버그 2건: ① `Font::ParseFont/load` 재호출 시 텍스처 경로 오염
(리로드 후 텍스트 소실) ② 고정 스텝 입력 폴링이 16ms 미만의 짧은 클릭·탭을 유실
(SDL 이벤트 래치로 보강).

APK를 다시 빌드·설치하지 않고, 개발 머신에서 수정한 Lua 스크립트를 실행 중인
기기로 밀어 넣어 즉시 반영한다. 이슈 #16의 세 항목(소켓 서버 / 루아 번들 전달 /
번들로 새로고침)에 그대로 대응한다.

## 왜 가능한가

- 게임 로직은 전부 `scripts/*.lua` — C++ 재빌드 없이 교체 가능 ([[game-logic-in-lua]] 원칙)
- Android는 이미 assets를 내부 저장소로 추출 후 `chdir` 하므로(Phase A1),
  **cwd의 스크립트 파일을 덮어쓰면 다음 로드부터 새 코드가 읽힌다**
- 엔진의 Lua 수명주기가 단순: `Lua_Init()`(상태 생성→API 등록→main.lua→`Initialize()`),
  매 프레임 `Lua_Update/Render`, 종료 시 `Lua_Destory()`(스크립트 `Destroy()`→lua_close)
  → **새로고침 = `Lua_Destory()` + `Lua_Init()`** 재호출

## 구성 요소

### 1. 소켓 서버 — `src/platform/HotReloadServer.{h,cpp}` (비-Windows)

- 백그라운드 스레드(std::thread)가 TCP **127.0.0.1:5959** 수신
  - `adb forward tcp:5959 tcp:5959`로 접속하므로 루프백이면 충분하고,
    같은 Wi-Fi의 다른 기기가 접근할 수 없다 (개발 전용 기능의 최소 노출)
- 수신한 번들은 **메모리 큐에 적재만** 하고, 파일 쓰기와 리로드는 메인 루프가 수행
  (프레임 도중 스크립트 읽기와의 경합 방지, Lua/렌더러는 메인 스레드 전용 유지)
- 활성화: Android에서는 상시, 데스크톱에서는 `INITIAL2D_HMR=1` 환경변수 옵트인
  (macOS에서 동일 코드로 개발·검증 가능)
- Win32/GDI 경로는 무수정 (`RS_WINDOWS`에서는 컴파일 제외)

### 2. 루아 번들 전달 — `tools/hmr_push.py`

- `scripts/` 이하 `*.lua`를 번들로 묶어 전송. `--watch`는 mtime 폴링으로 저장 시 자동 push
- 프로토콜 (리틀 엔디언, 길이-프리픽스):

```
"I2DH"                      # 매직 4바이트
uint32 fileCount
반복 fileCount회:
  uint32 pathLen, path      # UTF-8, '/' 구분 상대 경로
  uint32 dataLen, data
응답: "OK\n" (성공) / "ER\n" (거부)
```

- 서버는 경로를 검증한다: 절대 경로·`..` 포함 경로 거부, cwd 밑에만 기록

### 3. 새로고침 — AppSDL2 메인 루프 훅

매 프레임 이벤트 처리 후:

1. `HotReloadServer::TakeBundle()` — 대기 중 번들이 있으면 가져온다
2. 파일들을 cwd에 기록 (필요 시 하위 디렉터리 생성)
3. `Lua_Destory()` — 스크립트의 `Destroy()`가 이미지/오디오를 해제하고 VM 종료
4. `Lua_Init()` — VM 재생성, main.lua 재로드, `Initialize()` 재호출

### 4. 부수 작업

- `AndroidManifest.xml`: `android.permission.INTERNET`
- CMake: 루트(macOS)와 `android/app/jni` 양쪽에 소스 추가

## 사용법 (구현 후)

```bash
adb forward tcp:5959 tcp:5959     # 최초 1회
python3 tools/hmr_push.py          # 1회 push
python3 tools/hmr_push.py --watch  # 저장할 때마다 자동 push
```

## 한계와 후속 과제

- **풀 리스타트 시맨틱**: VM을 새로 만들므로 게임 진행 상태(점수 등)는 초기화된다.
  상태 보존형 HMR(모듈 단위 교체)은 스크립트 구조 변경이 필요해 후속 과제
- 리소스 파일(png/ogg)은 번들 대상에 넣을 수 있으나 1차 범위는 `*.lua`만
- `PreparaFont`의 고정 텍스트 메모리 등 C++ 쪽 정적 자원은 리로드 대상 아님 —
  리로드 반복 시 누수 여부는 실기에서 관찰 (개발 전용 기능이므로 치명적이지 않음)
