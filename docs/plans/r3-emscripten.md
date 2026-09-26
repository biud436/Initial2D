# R3. 엔진 Emscripten 빌드: 「같은 엔진이 브라우저 안에서 돈다」

> 작성일 2026-09-26. **권장 모델 Fable 5** ([index.md](index.md) 4절 표). 에디터 트랙(index.md 8절)의
> 세 번째 단계이고, 에디터 쪽 짝은 E4(게임 뷰, `InitialEditor/docs/plans/e4-embedded-play.md`)다.

## 1. 목표 (한 문장)

**네이티브와 같은 C++ 엔진을 WebAssembly 로 빌드해, 에디터의 게임 뷰(웹뷰)와 정적 웹 페이지가
알데바란을 그대로 띄운다.** 에디터가 PIXI 로 게임을 흉내 내는 것이 아니라 진짜 엔진이 canvas 에 그린다.
첫 목표였던 "플래피가 브라우저에서 뜬다"를 넘어, 저장소의 기본 게임인 알데바란 타이틀이 네이티브
골든과 픽셀 단위로 같다.

## 2. 결정

| 결정 | 이유 |
|---|---|
| **SDL2 는 Emscripten 포트로** (`-sUSE_SDL=2` 등. Homebrew 의 find_package 대신) | emcc 가 헤더 경로와 라이브러리를 스스로 준다. 첫 빌드에서 포트를 소스에서 컴파일하고 그 뒤로는 캐시된다. CMake 는 `if(EMSCRIPTEN)` 한 분기이고 네이티브 쪽 코드는 그대로다 |
| **루프는 `emscripten_set_main_loop_arg`, ASYNCIFY 는 쓰지 않는다** | 브라우저는 블로킹 루프를 허락하지 않는다. `App::Run` 의 while 본문을 `App::StepFrame()` 으로 떼어 네이티브는 while 이, 브라우저는 requestAnimationFrame 이 같은 함수를 부른다. 엔진에 블로킹 호출(`SDL_Delay`, `SDL_WaitEvent`)이 없어 ASYNCIFY(코드 크기와 속도 손해)가 필요 없다. fps 는 -1 (디스플레이 주사율) |
| **wasm 네이티브 예외** (`-fwasm-exceptions`) | vendored Lua 는 C++ 로 컴파일되어 오류를 `throw` 로 던지고 `pcall` 이 catch 한다. Emscripten 기본은 catch 를 끈 상태라 첫 Lua 오류에서 abort 했을 것이다. JS 기반 예외(`-fexceptions`)보다 빠르고 최근 브라우저는 전부 지원한다 |
| **환경 변수는 `Platform::GetEnv`** (`src/platform/Env.h`) | 브라우저에는 프로세스 환경이 없다. C++ 의 `INITIAL2D_*` 읽기를 전부 이 함수로 모으고, Emscripten 에서는 `Module.initial2dEnv[name]` 을 먼저 본 뒤 `getenv` 로 내려간다. 네이티브는 헤더 인라인의 `std::getenv` 라 동작이 같고 Windows 프로젝트 파일에 더할 소스도 없다 |
| **Lua 의 `os.getenv` 는 `Module.ENV` 로** | 스크립트는 libc 를 거치므로 로더가 런타임이 뜨기 전(`preRun`)에 같은 값을 `Module.ENV` 에 넣는다. `INITIAL2D_SCENE`, `INITIAL2D_NO_RTP` 처럼 Lua 가 읽는 설정이 그대로 통한다 (검수 7 번이 확인) |
| **핫 리로드는 TCP 대신 export** | 소켓이 없다. `HotReloadServer.cpp` 를 빌드에서 빼고, 번들을 받은 뒤 하던 일(`Script_Destroy` 뒤 `Script_Init`)을 `Script_Restart()` 로 묶어 서버와 `initial2d_reload()` 가 같은 길을 쓴다. 파일은 로더가 MEMFS 에 다시 쓴다 |
| **파일은 MEMFS 의 `/project` 에 스테이징하고 `chdir`** | 엔진은 `./game.json`, `./scripts/lua/main.lua`, `./resources/` 를 상대 경로로 연다. 프로젝트 파일을 그 모양 그대로 올리고 cwd 를 옮기면 **엔진의 파일 코드는 한 줄도 바꾸지 않는다** |
| **ES 모듈 팩토리 한 개** (`MODULARIZE` + `EXPORT_ES6`, `INVOKE_RUN=0`) | 전역을 더럽히지 않고, 에디터와 데모 페이지가 `import` 로 같은 `createInitial2D` 를 쓴다. 파일을 올린 뒤에 시작해야 하므로 `main` 은 로더가 `callMain` 으로 부른다. `EXIT_RUNTIME=0` 이라 `main` 이 돌아와도 루프와 런타임이 산다 |
| **`--features` 는 "lua wasm"** | mruby 는 아직 없다 (libmruby 교차 빌드가 필요하다). 에디터는 `wasm` 을 보고 내장 실행을 연다. JS 에서는 `initial2d_features()` export 로 같은 문자열을 얻는다 |
| **키보드는 canvas 에서만** (`SDL_HINT_EMSCRIPTEN_KEYBOARD_ELEMENT` = `#canvas`) | 기본은 window 전체라 에디터의 편집기 키까지 게임이 삼킨다. canvas 가 포커스를 가진 동안만 키가 게임으로 가고, 로더가 canvas 에 `tabindex` 를 준다 |

## 3. 바뀐 것

| 파일 | 무엇 |
|---|---|
| `CMakeLists.txt` | `if(EMSCRIPTEN)` 분기. 포트 플래그(컴파일과 링크), `-fwasm-exceptions`, mruby 탐색 생략, `HotReloadServer.cpp` 대신 `src/platform/emscripten/*.cpp`, 링크 플래그(4절), 산출물 `Initial2D.js` + `Initial2D.wasm`. 네이티브 쪽은 `INITIAL2D_SDL2_AUDIO` 와 `INITIAL2D_SDL2_GAME` 변수로 조건을 정리했을 뿐 같은 파일과 같은 메시지다 |
| `src/platform/Env.h` (신규) | `Initial2D::Platform::GetEnv(name)`. 네이티브는 인라인 `std::getenv` |
| `src/platform/emscripten/Env.cpp` (신규) | Emscripten 구현. `EM_ASM_PTR` 로 `Module.initial2dEnv[name]` 을 읽어 캐시한다 |
| `src/platform/emscripten/WebMain.h`, `WebMain.cpp` (신규) | `StartMainLoop(App*)`, 프레임 콜백(종료 시 `emscripten_cancel_main_loop` 뒤 `Teardown`), export `initial2d_reload`, `initial2d_quit`, `initial2d_features` |
| `src/platform/sdl2/AppSDL2.cpp` | `Run` 을 준비, `StepFrame`, `Teardown` 으로 나눴다 (루프 변수는 파일 안의 `LoopState`). `SDL_getenv` 일곱 곳을 `GetEnv` 로. 브라우저에서는 `SDL_Delay`(바쁜 대기)와 창 제목의 FPS(`document.title` 이 바뀐다)를 건너뛰고, 렌더러 이름을 한 줄 로그로 남긴다 |
| `src/App.h` | `#ifndef RS_WINDOWS` 안에 `StepFrame()` 과 `Teardown()` 선언 |
| `src/ScriptRuntime.h`, `.cpp` | `Script_Restart()`, `INITIAL2D_SCRIPT` 를 `GetEnv` 로, Emscripten 이면 features 에 `wasm` |
| `src/platform/sdl2/TextureManagerSDL2.cpp`, `src/mrb_prot.cpp` | `INITIAL2D_DEBUG_DRAW` 와 `System.env` 를 `GetEnv` 로 |
| `tools/build_web.sh` (신규) | `emcmake cmake -S . -B build-web -DCMAKE_BUILD_TYPE=Release` 뒤 빌드, `build-web/site/` 에 js, wasm, 페이지, 로더, 프로젝트 파일을 모으고 크기를 찍는다 |
| `tools/web/index.html`, `tools/web/initial2d-loader.js` (신규) | 데모 페이지와 로더 (5절). 빌드가 `build-web/site/` 로 복사한다 |
| `tools/web_stage.py` (신규) | `game.json`, `scripts/lua/**`, `resources/**` 를 `site/project/` 에 복사하고 목록 `project.json` 을 쓴다. `RTP.zip`, `rtp/`, `*.psd`, 닷파일, `resources/aldebaran/src/gpt/` 는 뺀다 |
| `tools/web_smoke.mjs` (신규) | 헤드리스 검수 (6절) |
| `.gitignore` | `build-web/` |

**환경 변수를 `GetEnv` 로 바꾼 C++ 호출 자리** (전부 비 Windows 경로다):
`INITIAL2D_WINDOW`, `INITIAL2D_SCALE`, `INITIAL2D_HMR`, `INITIAL2D_DEBUG_DRAW`(AppSDL2 와 TextureManagerSDL2),
`INITIAL2D_SCREENSHOT`, `INITIAL2D_SCREENSHOT_FRAME`, `INITIAL2D_EXIT_AFTER`(이상 `AppSDL2.cpp`),
`INITIAL2D_SCRIPT`(`ScriptRuntime.cpp`), 그리고 mruby 의 `System.env(name)`(`mrb_prot.cpp`).
Lua 쪽 `os.getenv`(`INITIAL2D_SCENE`, `INITIAL2D_AUTOPLAY`, `INITIAL2D_NO_RTP`, 알데바란과 데모의
검수용 변수들)는 코드 변경 없이 `Module.ENV` 로 같은 값을 본다.

## 4. 플래그

컴파일과 링크에 함께 (포트와 예외):

```
-sUSE_SDL=2 -sUSE_SDL_IMAGE=2 -sSDL2_IMAGE_FORMATS=png,jpg
-sUSE_SDL_MIXER=2 -sSDL2_MIXER_FORMATS=ogg,wav -sUSE_OGG=1 -sUSE_VORBIS=1
-fwasm-exceptions
```

링크에만 (`Initial2D` 타깃):

```
-sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=67108864 -sSTACK_SIZE=2097152
-sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_NAME=createInitial2D -sENVIRONMENT=web
-sEXPORTED_RUNTIME_METHODS=FS,ccall,cwrap,callMain,ENV,UTF8ToString,stringToNewUTF8
-sEXPORTED_FUNCTIONS=_main,_initial2d_reload,_initial2d_quit,_initial2d_features,_malloc,_free
-sFORCE_FILESYSTEM=1 -sEXIT_RUNTIME=0 -sINVOKE_RUN=0
```

`ASYNCIFY` 와 `--shell-file` 은 쓰지 않는다. 산출물은 `build-web/Initial2D.js`(177 KB)와
`build-web/Initial2D.wasm`(1.8 MB, Release). Emscripten 은 6.0.10 (`~/emsdk`, `emsdk install latest`).

## 5. 로더 API

`build-web/site/initial2d-loader.js` (원본은 `tools/web/initial2d-loader.js`). 번들러 없는 ES 모듈이다.

```js
import { bootInitial2D } from "./initial2d-loader.js";

const game = await bootInitial2D({
  canvas: document.getElementById("canvas"),   // SDL 이 그린다. 포커스를 가진 동안 키보드를 받는다
  files: { "game.json": "...", "scripts/lua/main.lua": "...", "resources/x.png": new Uint8Array(...) },
  env: { INITIAL2D_SCRIPT: "lua", INITIAL2D_SCENE: "flappy" },   // 네이티브의 환경 변수와 같은 이름
  print: (line) => console.log(line),        // Lua print (stdout)
  printErr: (line) => console.error(line),   // SDL_Log, "Lua error in ..." (stderr)
  wasmUrl: "./Initial2D.wasm",               // 선택. 기본은 Initial2D.js 옆
});

game.reload({ "scripts/lua/main.lua": "..." });   // 바뀐 파일만 올리고 VM 재시작 (initial2d_reload)
game.quit();                                       // initial2d_quit. 다시 띄우려면 새로 boot
game.features();                                   // "lua wasm"
game.module;                                       // Emscripten Module (FS, ccall ...)
```

하는 일의 순서: `createInitial2D({ canvas, print, printErr, locateFile, preRun, initial2dEnv })` 로 모듈을
만들고, `files` 를 `/project` 아래에 쓰고(디렉터리는 만든다), `FS.chdir("/project")`, `callMain([])`.
`env` 값은 문자열로 바뀌어 `Module.initial2dEnv`(C++ 의 `GetEnv`)와 `Module.ENV`(libc, Lua 의 `os.getenv`)
두 곳에 들어간다. `null`, `undefined`, `false` 는 "설정 안 함"이다. `reload(files, envPatch)` 의 두 번째
인자는 `initial2dEnv` 만 바꾼다 (libc 의 environ 은 시작 때 굳는다).

데모 페이지 `index.html` 은 `project.json`(`tools/web_stage.py` 가 만든 파일 목록)을 fetch 해 파일을
모으고, "실행" 버튼(브라우저 오디오 정책상 사용자 제스처가 필요하다)으로 위 함수를 부른다.
`?env=INITIAL2D_SCENE=flappy` 처럼 URL 로 설정을 더할 수 있다 (검수가 쓴다).

## 6. 검수

```bash
tools/build_web.sh                                              # 빌드 + build-web/site
node tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png   # 헤드리스 크로미움
```

`tools/web_smoke.mjs` 는 InitialEditor 저장소의 Playwright(`PLAYWRIGHT_DIR` 로 바꿀 수 있다)로
`build-web/site` 를 임의 포트에 띄워 다음을 본다. 콘솔에 `Lua error`, `abort(`, `RuntimeError`,
페이지 오류가 나오면 실패다 (15 초 안).

1. "실행" 을 눌러 엔진 시작 줄 `Initial2D web: renderer=... features=lua wasm` 을 기다린다.
2. `INITIAL2D_SCREENSHOT=/project/shot.bmp` 와 `INITIAL2D_SCREENSHOT_FRAME=20` 을 설정으로 넘겨
   엔진이 20 프레임째를 MEMFS 에 쓴 것을 `FS.readFile` 로 꺼낸다 (`build-web/smoke_frame20.bmp`).
   네이티브 골든과 같은 방식(같은 프레임, `INITIAL2D_NO_RTP=1`)이다.
3. canvas 를 `build-web/smoke.png` 로 찍는다.
4. `--golden` 이면 PIL 로 20 프레임 캡처를 골든과 대조한다 (차이 픽셀 비율, 허용 25%).
5. 키보드: canvas 에 포커스를 주고 아래 화살표와 Enter 를 보내 "조작 방법" 설명 창이 뜨는지
   픽셀 변화량으로 본다 (`build-web/smoke_help.png`).
6. `reload()` 와 `quit()` 이 콘솔에 자기 줄을 남기는지.
7. 두 번째 페이지에서 `main.lua` 한 장짜리 프로젝트를 올려 `os.getenv` 가 설정 객체를 보고,
   `INITIAL2D_EXIT_AFTER` 로 루프가 끝나는지.

**2026-09-26 결과**: 전부 통과. 헤드리스 크로미움에서 WebGL(`renderer=opengles2`)이 잡혀 소프트웨어
폴백은 쓰이지 않았다. 20 프레임 캡처는 골든 `aldebaran_title.png` 와 **차이 픽셀 0 / 688128** (평균
차이 0.01). 키보드 입력은 8.6% 의 픽셀을 바꿨다 (설명 창). 네이티브 전체 스위트(`tests/run_all.sh`, 헤드리스)는
**446 PASS / 0 FAIL** 로 무변경 통과. 새 워크트리에서는 플래피의 자리 표시 자산(`resources/*.png`, gitignore)이
없어 플래피 씬 셋이 먼저 실패했는데, `python3 tools/generate_placeholder_assets.py` 뒤 통과했다 (README 의 안내대로).

## 7. 한계와 남은 것

- **mruby 가 없다.** libmruby 를 emcc 로 교차 빌드해야 한다 (안드로이드에서도 아직 안 된 일). E4 마일스톤 6.
- **핫 리로드 TCP 서버가 없다.** `tools/hmr_push.py` 는 브라우저에 닿지 않는다. 에디터는 파일을 다시
  올리고 `reload()` 를 부른다.
- **스크린샷은 호스트 디스크가 아니라 MEMFS 에 쓰인다.** `INITIAL2D_SCREENSHOT` 은 동작하지만 파일은
  wasm 의 가상 파일 시스템 안이라 JS 가 `module.FS.readFile` 로 꺼내야 한다 (검수가 그렇게 한다).
- **오디오는 사용자 제스처 뒤에 난다.** 브라우저 정책이다. 데모 페이지의 "실행" 버튼이 그 제스처이고,
  에디터는 게임 뷰 클릭이 된다. 크로미움이 SDL 의 ScriptProcessorNode 를 deprecated 로 경고하는데
  SDL2 포트의 일이다.
- **터치는 검증하지 않았다.** SDL2 포트가 핑거 이벤트를 주고 엔진의 T1 경로가 그것을 받지만,
  모바일 브라우저 실기 확인은 없다.
- **스레드가 없다.** `Thread.cpp` 는 컴파일되지만 브라우저에서 스레드를 만들면 abort 한다. 엔진 루프는
  쓰지 않는다. `PosixProcess` 도 있지만 프로세스를 띄울 수 없다.
- **파일 스테이징은 통째로다.** 이 저장소는 148 파일 5.8 MB 라 괜찮지만, RTP 변환물 같은 큰 프로젝트는
  E4 의 "목록 먼저, 데이터는 요청 시"가 필요하다. 로더의 `stage()` 로 나중에 더 올릴 수 있다.
- **canvas 크기는 게임이 정한다** (`game.json` 의 창 크기와 배율). 에디터의 게임 뷰는 정수 배율 맞춤을
  E4 마일스톤 2 에서 한다.
- Windows GDI 경로와 Android 는 손대지 않았다. Android 의 JNI 소스 목록에는 새 파일이 들어갈 필요가
  없다 (`Env.h` 는 헤더 인라인, `emscripten/` 은 브라우저 전용).

## 8. 체크리스트

- [x] CMake `EMSCRIPTEN` 분기 (포트, 예외, HotReloadServer 와 mruby 제외, 링크 플래그)
- [x] `emscripten_set_main_loop_arg` 프레임 루프, `EXIT_RUNTIME=0`, ASYNCIFY 없음
- [x] export `initial2d_reload`, `initial2d_quit`, `initial2d_features`
- [x] `Platform::GetEnv` 와 `Module.initial2dEnv`, `Module.ENV`
- [x] `tools/build_web.sh`, `tools/web_stage.py`, `tools/web/index.html`, `tools/web/initial2d-loader.js`
- [x] `tools/web_smoke.mjs` (Playwright, 골든 대조, 키보드, export, os.getenv)
- [x] 네이티브 스위트 무변경 통과
- [x] README 「웹 빌드 (Emscripten)」, index.md 갱신
- [ ] mruby (libmruby 교차 빌드)
- [ ] 모바일 브라우저 터치 실기
- [ ] 웹 데모 배포 (저자 결정, README 의 실행 링크 자리)
