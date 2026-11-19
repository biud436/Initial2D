# 엔진 3. 내보낸 게임: 「어디로 옮겨 어떻게 열어도 그 게임이 뜬다」

> 작성일: 2026-11-19. 에디터 완성도 계획(`InitialEditor/docs/plans/quality.md` 10절)의 엔진 짝 셋째.
> 에디터 짝은 Q4(게임 내보내기, 웹과 macOS)이다. 진행 상황은 [index.md](index.md) 9절의 표에 있다.

## 1. 목표 (한 문장)

> 내보낸 게임은 어느 폴더로 옮기고 어떻게 열어도(Finder 의 더블 클릭, 다른 폴더의 터미널) 자기 게임 폴더를 찾아 뜨고,
> 창 제목과 아이콘이 그 게임의 것이다.

지금 엔진은 게임 폴더를 작업 폴더로만 안다. Finder 가 앱을 열면 작업 폴더가 `/` 라서 스크립트를 찾지 못하고, 그보다 먼저
작업 폴더에 `config.setting` 을 쓰다가 실패해 예외로 끝난다. 창 제목은 상수 `test` 로 만들어지고 1초마다 FPS 숫자로 덮인다.
아이콘은 엔진 저장소의 `resources/icons/icon.png` 로 정해져 있다.

이 단계는 SDL2 데스크톱 판(macOS, Linux)만 바꾼다. Windows GDI 판은 손대지 않고, 안드로이드(AndroidBootstrap 이 내부 저장소로
옮긴다)와 웹(로더가 MEMFS 의 `/project` 로 옮긴다)은 지금 방식 그대로다. 스크립트 API 는 바뀌지 않는다.

## 2. 게임 폴더 (계약)

엔진은 시작할 때 아래 순서로 게임 폴더를 정하고, 1 이나 2 이면 그 폴더로 작업 폴더를 옮긴다. 게임 폴더는 `game.json` 이
있는 폴더다 (에디터의 프로젝트 정의와 같다). 그 뒤의 모든 상대 경로(`game.json`, `scripts/`, `resources/`)는 지금처럼 작업
폴더 기준이다.

1. **macOS 앱 묶음.** 실행 파일이 `<이름>.app/Contents/MacOS/` 에 있고 `<이름>.app/Contents/Resources/game/game.json` 이
   파일이면, 그 `game` 폴더.
2. **실행 파일 옆의 `game` 폴더.** `<실행 파일 폴더>/game/game.json` 이 파일이면, 그 `game` 폴더 (macOS 와 Linux 의 압축 묶음).
3. **작업 폴더.** 1 과 2 가 아니면 지금처럼 작업 폴더에서 읽는다. 에디터의 실행 버튼, 저장소의 개발 빌드
   (`build/Initial2D`), 검수 러너는 모두 이 경우다.

규칙:

1. 실행 파일 위치는 심볼릭 링크를 따라간 실제 자리다 (macOS `_NSGetExecutablePath` 뒤 `canonical`, Linux
   `/proc/self/exe`). `/usr/local/bin` 에 링크를 걸어 실행해도 묶음 안의 게임을 연다.
2. 1 과 2 는 작업 폴더보다 앞선다. 내보낸 게임은 어디서 실행하든 자기 게임을 연다. 작업 폴더에 다른 `game.json` 이
   있어도 그렇다.
3. `game` 폴더가 있어도 `game.json` 이 없으면(또는 `game.json` 이 폴더면) 그 후보는 없는 것으로 친다.
4. 작업 폴더를 옮기지 못하면 `Initial2D: cannot enter the game folder <경로>: <이유>` 한 줄을 stderr 에 찍고 종료 코드 1 로
   끝난다. 게임은 띄우지 않는다.
5. `--version`, `--features` 는 게임 폴더를 찾기 전에 처리한다 (작업 폴더와 상관없이 같은 답).
6. 에디터 앱의 사이드카(`InitialEditor.app/Contents/MacOS/Initial2D`)는 `Contents/Resources/game/` 이 없으므로 3 이다.
   에디터의 `Contents/Resources/` 에는 `engine/engine.json` 이 있을 뿐이다 (`InitialEditor/docs/plans/e6-packaging.md`).

## 3. 이름과 아이콘 (`game.json`)

```json
{
  "name": "날아라 새",
  "icon": "resources/icons/bird.png",
  "windowWidth": 768,
  "windowHeight": 896
}
```

1. `name` 은 창 제목이다. 없거나 빈 문자열이면 `Initial2D`. 문자열이 아니면 무시하고
   `game.json name: expected a string` 한 줄을 stderr 에 찍는다. 에디터의 새 게임 대화상자가 이미 이 키를 쓴다.
2. `icon` 은 창 아이콘(macOS 에서는 Dock 아이콘)이다. 게임 폴더 기준 `/` 상대 경로의 PNG 이고, 씬 파일과 맵 파일의 경로와
   같은 규칙이다. 문자열이 아니면 무시하고 `game.json icon: expected a string` 한 줄.
3. `icon` 을 적었는데 읽지 못하면 `game.json icon: cannot load <경로> (<이유>)` 한 줄을 찍고 아이콘 없이 뜬다.
4. `icon` 이 없으면 `resources/icons/icon.png` 가 있을 때만 그것을 쓴다 (이 저장소와 예전 프로젝트의 동작). 그것도 없으면
   아이콘을 두지 않고 아무것도 찍지 않는다. 새 프로젝트가 아이콘이 없다고 경고를 받지 않는다.
5. 창 제목에 FPS 를 붙이지 않는다. 개발할 때 보고 싶으면 `INITIAL2D_SHOW_FPS=1` 로 띄운다. 제목이
   `<이름> (60 FPS)` 꼴로 1초마다 바뀐다.
6. 두 키는 시작할 때 한 번 읽는다. 핫 리로드는 스크립트만 다시 읽으므로 제목과 아이콘은 그대로다.
7. `game.json` 이 JSON 으로 읽히지 않으면 지금처럼 `game.json parse error: ...` 한 줄이고 모든 키가 기본값이다.

## 4. 엔진은 게임 폴더에 쓰지 않는다

SDL2 판은 시작할 때 작업 폴더에 `config.setting`(디버그 여부, 실행 파일 경로, 작업 폴더 세 줄)을 쓰던 것을 그만둔다.
그 파일을 읽는 코드는 엔진에도 스크립트에도 도구에도 없었다. 그리고 앱 묶음은 쓸 수 없는 곳일 수 있다. 인터넷에서 받은
서명 없는 앱은 macOS 가 읽기 전용 위치로 옮겨 실행하고(앱 이동 격리, App Translocation), 서명한 묶음은 안을 바꾸면 서명이
깨진다. 그 파일의 경로를 stdout 첫 줄에 찍던 것도 같이 뺐다. Windows GDI 판은 예전처럼 쓴다.

이제 엔진은 스스로 게임 폴더에 쓰지 않는다. 쓰는 것은 개발용 기능을 켰을 때뿐이다 (핫 리로드 `INITIAL2D_HMR` 가 받은
스크립트, `INITIAL2D_SCREENSHOT` 이 가리키는 파일). 게임이 남길 데이터(최고 점수, 저장)는 엔진 4 의 저장 데이터 API 가
사용자 폴더에 둔다.

## 5. macOS 앱 묶음의 모양 (에디터 Q4 의 계약)

```text
<게임 이름>.app/
  Contents/
    Info.plist
    MacOS/Initial2D          배포용 엔진(dist/Initial2D-aarch64-apple-darwin). 이름은 ASCII 로
    Resources/<아이콘>.icns  Finder 와 앱 전환기의 아이콘
    Resources/game/          game.json, scripts/, resources/ (에디터의 스테이징 규칙으로 고른 것)
```

`Info.plist` 의 키:

| 키 | 값 |
|---|---|
| `CFBundleExecutable` | `MacOS/` 안의 실행 파일 이름 (ASCII. 아래 참고) |
| `CFBundleName`, `CFBundleDisplayName` | 게임 이름 (메뉴 막대의 앱 이름이 된다) |
| `CFBundleIdentifier` | 게임마다 다른 역도메인 이름 |
| `CFBundlePackageType` | `APPL` |
| `CFBundleShortVersionString`, `CFBundleVersion` | 내보내기 대화상자의 버전 |
| `CFBundleIconFile` | `Resources/` 안의 `.icns` 이름 |
| `LSMinimumSystemVersion` | `11.0` (배포용 엔진의 minos 와 같다, [r4-dist-build.md](r4-dist-build.md)) |
| `NSHighResolutionCapable` | `true` (엔진이 `SDL_WINDOW_ALLOW_HIGHDPI` 로 창을 만든다) |

창 제목과 Dock 아이콘은 `game.json` 의 `name` 과 `icon` 에서, 메뉴 막대의 이름과 Finder 의 아이콘은 `Info.plist` 에서 온다.
둘이 같은 이름과 같은 그림이 되게 하는 것은 내보내는 쪽(에디터)의 일이다. 묶음을 다 만든 뒤에 임시 서명
(`codesign --force -s - <묶음>`)을 한 번 하면 묶음의 서명이 내용과 맞는다. 공증은 하지 않는다 (저자 결정, 서명 없음).

서명에서 확인한 것 (2026-11-19, macOS 26):

1. **실행 파일 이름은 ASCII 로 둔다.** 실행 파일 이름이 한글(`MacOS/날아라 새`)이면 임시 서명 뒤 `codesign --verify`
   가 `a sealed resource is missing or invalid` 로 실패한다. 묶음 폴더 이름(`날아라 새.app`), `CFBundleName`, 한글 이름의
   게임 파일은 문제가 없다. 서명이 맞지 않는 묶음은 이 컴퓨터에서는 뜨지만, 인터넷에서 받은 경우 Gatekeeper 가 손상된
   앱으로 본다. 메뉴 막대와 Finder 의 이름은 `CFBundleName` 과 폴더 이름이므로 실행 파일 이름은 사용자에게 보이지 않는다.
2. **`--deep` 은 쓰지 않는다.** 이 묶음에는 안에 든 코드가 실행 파일 하나뿐이라 필요 없고, 이 맥의 `codesign --deep`
   은 SIGBUS 로 죽었다. Apple 도 서명에 `--deep` 을 권하지 않는다.

## 6. 웹

엔진 쪽 일은 없다. 로더(`tools/web/initial2d-loader.js`)가 게임 파일을 MEMFS 의 `/project` 에 쓰고 그리로 옮기므로 게임
폴더는 이미 정해져 있다. 브라우저의 창 제목은 페이지의 `<title>` 이고, 엔진은 `document.title` 을 건드리지 않는다
(에디터 안의 게임 뷰가 에디터 탭 이름을 바꾸지 않게). 내보낸 웹 페이지의 `<title>` 과 파비콘을 `name` 과 `icon` 으로
채우는 것은 에디터 Q4 의 페이지가 한다.

## 7. 검수

- C++ 단위 `tests/unit/game_folder_test.cpp`: 임시 폴더에 묶음과 `game` 폴더를 만들어 2절의 후보 순서, `game.json` 이 없는
  후보, `game.json` 이 폴더인 후보, `Contents` 밖의 `MacOS` 폴더. 3절의 이름과 아이콘 읽기(없음, 빈 문자열, 문자열이 아닌 값),
  창 제목 글자.
- 통합 `tests/tools/exported_game_test.py` (검사 18개, Lua 와 Ruby 각각): 엔진 실행 파일을 임시 폴더의 묶음과 `game` 폴더
  옆에 복사하고, 다른 게임이 있는 작업 폴더와 `/` 에서, 상대 경로와 심볼릭 링크로 띄운다. 게임 스크립트가 시작할 때 찍는
  `game:<표지>` 줄로 어느 게임이 떴는지 보고, stdout 에 그 줄 말고는 없는지 본다 (예전의 `config.setting` 경로 줄).
  `game.json` 이 없는 묶음은 작업 폴더로 간다. 묶음을 읽기 전용으로 만들어도 `/` 에서 뜨고, 실행 뒤 묶음과 작업 폴더의
  파일 목록과 내용이 그대로다. 아이콘은 맞는 PNG, 기본 아이콘 파일, 아이콘 없음(셋 다 아무것도 찍지 않는다), 읽지
  못하는 파일과 문자열이 아닌 `icon` 과 `name`(한 줄씩). 인자로 배포용 실행 파일을 받고, `tests/run_all.sh` 3단계와 CI
  `dist.yml` 이 돌린다. 수정 전의 엔진(master)으로 돌리면 36개 중 32개가 실패한다 (작업 폴더가 `/` 이면
  `config.setting` 을 쓰지 못해 `std::runtime_error*` 로 끝난다). 통과하는 넷은 묶음 안에 쓰지 않는다는 검사다.
- 자동 검사가 없는 것: 작업 폴더를 옮기지 못하는 경우(2절 규칙 4). 후보를 고를 때 그 폴더 안의 `game.json` 을 이미
  찾았으므로, 고른 뒤 옮기기 전에 폴더가 사라지거나 권한이 바뀌는 경우에만 생긴다. 시험으로 그 틈을 만들 방법이 없다.
- 배포용 실행 파일(`tools/build_dist.sh`)로도 통합 검사 36개 통과, `tools/check_dist.sh` 통과.
- 다른 판: 웹 빌드(`tools/web_ci.sh build`)와 `tools/web_smoke.mjs` 통과 (타이틀이 골든과 차이 0, Ruby 판도 같다).
  안드로이드 `assembleDebug` 성공 (arm64-v8a 와 x86_64 가 `GameIdentity.cpp` 를 컴파일한다).
  전체 스위트(`tests/run_all.sh`)는 C++ 단위 37, 도구 검사, 엔진 씬, 브리지 25, RTP 가 통과했다.
- 실제 창 (2026-11-19): 배포용 실행 파일과 플래피 씬 프로젝트로 5절 모양의 `날아라 새.app`(한글과 공백이 든 묶음 이름,
  `game.json` 의 `name` 과 `icon`, 새 그림의 `.icns`, 임시 서명)을 만들어 `open` 으로 띄웠다 (Finder 의 더블 클릭과 같은 길,
  작업 폴더 `/`). 창 제목과 메뉴 막대의 앱 이름이 `날아라 새`, Dock 에 새 아이콘, 플래피 씬이 그려지고
  `INITIAL2D_EXIT_AFTER`(묶음의 `LSEnvironment`)로 스스로 끝났다. 묶음은 저장소 밖의 임시 스크립트로 만들었다 (내보내기는
  에디터 Q4 의 일이다). 서명에서 찾은 것 둘은 5절에 있다.

## 8. 이 단계에 없는 것

- 저장 데이터 API (엔진 4)
- 실행 중에 창 제목이나 아이콘을 바꾸는 스크립트 API
- Windows 용 내보내기 (R5 는 하지 않기로 했다), 안드로이드 내보내기 (Q10)
- 내보내기 자체 (파일 고르기, `Info.plist` 와 `.icns` 쓰기, 서명)는 에디터 Q4 의 일이다

## 체크리스트

- [x] 게임 폴더 찾기 (2절)와 작업 폴더 옮기기 (`src/platform/GameIdentity.cpp`, `sdl2Main.cpp`)
- [x] `game.json` 의 `name`, `icon`, `INITIAL2D_SHOW_FPS` (3절, `AppSDL2.cpp`)
- [x] `config.setting` 을 쓰지 않기 (4절, `main.cpp` 의 SDL2 쪽만)
- [x] C++ 단위 테스트 13 케이스, 통합 테스트 36개, `tests/run_all.sh` 3단계와 CI `dist.yml` 에 넣기
- [x] 배포용 실행 파일로 통합 테스트
- [x] 실제 창으로 묶음 확인
- [x] README, index.md
- [ ] Windows GDI 판 빌드 확인 (W1 채널. 2026-11-19 에는 Windows PC 가 꺼져 있었다. `main.cpp` 의 Windows 쪽 문장과
      순서는 그대로다)
- [ ] 에디터 Q4: 5절 모양의 묶음, `game.json` 의 `icon` 을 아는 게임 속성, 새 게임 `.gitignore` 의 `config.setting` 줄 정리
